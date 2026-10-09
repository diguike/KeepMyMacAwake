import Foundation

public protocol SleepBackend: AnyObject {
    func readDisabled() throws -> Bool
    func setDisabled(_ value: Bool) throws
}
public struct RecoveryRecord: Codable, Equatable {
    public let version: Int
    public let baselineDisabled: Bool
    public let created: Date
    public init(created: Date) { version = 1; baselineDisabled = false; self.created = created }
}
public protocol RecoveryStore: AnyObject {
    func load() throws -> RecoveryRecord?
    func save(_ record: RecoveryRecord) throws
    func clear() throws
}
/// Call only on the helper's serial queue. One manual session for the MVP.
public final class LeaseEngine {
    private struct Lease {
        let id: UUID
        let owner: UUID
        let start: ClockSample
        let duration: Double
        let policy: SafetyPolicy
        var heartbeat: Double
        var safety = SafetyEvaluator()
    }
    private let backend: SleepBackend
    private let store: RecoveryStore
    private var lease: Lease?
    private var recoveryPending = false
    private var lastReason: StopReason?
    private var lastError: String?
    public static let heartbeatTimeout: Double = 20
    public init(backend: SleepBackend, store: RecoveryStore) {
        self.backend = backend; self.store = store
    }
    /// Always run before accepting XPC connections. Never resumes old leases.
    public func recover() throws {
        lease = nil
        do {
            if let record = try store.load() {
                guard record.version == 1, !record.baselineDisabled else { throw AwakeError.recoveryRequired }
                recoveryPending = true
                try restore()
                lastReason = .recovered
            }
            recoveryPending = false; lastError = nil
        } catch {
            recoveryPending = true; lastError = error.localizedDescription; throw error
        }
    }
    public func acquire(owner: UUID, duration: Double, policy: SafetyPolicy,
                        sample: PowerSample, now: ClockSample) throws -> UUID {
        guard duration.isFinite, (60...86400).contains(duration), policy.isValid else { throw AwakeError.invalidRequest }
        guard !recoveryPending else { throw AwakeError.recoveryRequired }
        guard lease == nil else { throw AwakeError.busy }
        var safety = SafetyEvaluator()
        if let reason = safety.evaluate(sample, policy: policy, now: now.continuous) {
            lastReason = reason; throw AwakeError.backend(reason.message)
        }
        guard !(try backend.readDisabled()) else { throw AwakeError.conflict }
        // Durable write ahead: if pmset or this process fails, launchd can restore.
        try store.save(RecoveryRecord(created: now.wall))
        recoveryPending = true
        do {
            try backend.setDisabled(true)
            guard try backend.readDisabled() else { throw AwakeError.backend("设置读回失败") }
            let id = UUID()
            lease = Lease(id: id, owner: owner, start: now, duration: duration,
                          policy: policy, heartbeat: now.continuous, safety: safety)
            recoveryPending = false; lastError = nil; lastReason = nil
            return id
        } catch {
            let original = error
            do { try restore(); recoveryPending = false } catch { lastError = error.localizedDescription }
            throw original
        }
    }
    public func renew(id: UUID, owner: UUID, sample: PowerSample, now: ClockSample) throws {
        // Do not let a late heartbeat revive an expired session.
        tick(sample: sample, now: now)
        guard var current = lease, current.id == id, current.owner == owner else { throw AwakeError.unauthorizedLease }
        current.heartbeat = now.continuous; lease = current
    }
    public func release(id: UUID, owner: UUID) throws {
        guard let current = lease, current.id == id, current.owner == owner else { throw AwakeError.unauthorizedLease }
        try end(.manual)
    }
    public func disconnected(owner: UUID) {
        guard lease?.owner == owner else { return }
        do { try end(.disconnected) } catch { /* status and journal preserve the error */ }
    }
    public func tick(sample: PowerSample, now: ClockSample) {
        if recoveryPending {
            do { try recover() } catch { }
            return
        }
        guard var current = lease else { return }
        let elapsed = now.continuous - current.start.continuous
        var reason: StopReason?
        if elapsed < 0 || abs(now.wall.timeIntervalSince(current.start.wall) - elapsed) > 60 { reason = .clockChanged }
        else if elapsed >= current.duration { reason = .expired }
        else if now.continuous - current.heartbeat >= Self.heartbeatTimeout { reason = .heartbeatLost }
        else { reason = current.safety.evaluate(sample, policy: current.policy, now: now.continuous) }
        lease = current
        if reason == nil {
            do { if !(try backend.readDisabled()) { reason = .backendChanged } }
            catch { lastError = error.localizedDescription; reason = .backendChanged }
        }
        if let reason = reason { do { try end(reason) } catch { } }
    }
    public func leaseID(for owner: UUID) -> UUID? {
        guard lease?.owner == owner else { return nil }; return lease?.id
    }
    public func status(now: ClockSample) -> SessionStatus {
        if recoveryPending { return SessionStatus(phase: .recoveryRequired, stopReason: lastReason, error: lastError) }
        if let current = lease {
            return SessionStatus(phase: .active, leaseID: current.id,
                                 remainingSeconds: max(0, current.duration - (now.continuous - current.start.continuous)))
        }
        return SessionStatus(stopReason: lastReason, error: lastError)
    }
    private func end(_ reason: StopReason) throws {
        lease = nil; lastReason = reason; recoveryPending = true
        do { try restore(); recoveryPending = false; lastError = nil }
        catch { lastError = error.localizedDescription; throw error }
    }
    private func restore() throws {
        // Only restore when our write-ahead record exists. Unknown/corrupt baseline fails closed.
        guard let record = try store.load(), record.version == 1, !record.baselineDisabled else {
            throw AwakeError.recoveryRequired
        }
        if try backend.readDisabled() { try backend.setDisabled(false) }
        guard !(try backend.readDisabled()) else { throw AwakeError.backend("休眠设置恢复读回失败") }
        try store.clear()
    }
}
