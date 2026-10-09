import XCTest
@testable import AwakeCore

private final class Backend: SleepBackend {
    var disabled = false
    var writes: [Bool] = []
    var failEnable = false
    var failRestore = false
    var readFails = false
    var onWrite: ((Bool) -> Void)?
    func readDisabled() throws -> Bool {
        if readFails { throw AwakeError.backend("read failed") }; return disabled
    }
    func setDisabled(_ value: Bool) throws {
        onWrite?(value); writes.append(value)
        if value && failEnable || !value && failRestore { throw AwakeError.backend("write failed") }
        disabled = value
    }
}
private final class Store: RecoveryStore {
    var record: RecoveryRecord?
    var failSave = false
    var failClear = false
    func load() throws -> RecoveryRecord? { record }
    func save(_ value: RecoveryRecord) throws {
        if failSave { throw AwakeError.backend("disk full") }; record = value
    }
    func clear() throws { if failClear { throw AwakeError.backend("clear failed") }; record = nil }
}
final class LeaseEngineTests: XCTestCase {
    private let ac = PowerSample(onAC: true, batteryPercent: 80, thermal: .nominal)
    private func clock(_ seconds: Double, wallOffset: Double = 0) -> ClockSample {
        ClockSample(wall: Date(timeIntervalSince1970: 1000 + seconds + wallOffset), continuous: seconds)
    }
    private func setup() throws -> (LeaseEngine, Backend, Store) {
        let b = Backend(); let s = Store(); let e = LeaseEngine(backend: b, store: s)
        try e.recover(); return (e, b, s)
    }
    func testWriteAheadAndRelease() throws {
        let (e, b, s) = try setup(); let owner = UUID()
        b.onWrite = { _ in XCTAssertNotNil(s.record) }
        let id = try e.acquire(owner: owner, duration: 60, policy: SafetyPolicy(), sample: ac, now: clock(0))
        XCTAssertTrue(b.disabled); XCTAssertEqual(e.status(now: clock(0)).phase, .active)
        try e.release(id: id, owner: owner)
        XCTAssertFalse(b.disabled); XCTAssertNil(s.record); XCTAssertEqual(b.writes, [true, false])
    }
    func testConflictDoesNotWrite() throws {
        let (e, b, s) = try setup(); b.disabled = true
        XCTAssertThrowsError(try e.acquire(owner: UUID(), duration: 60, policy: SafetyPolicy(), sample: ac, now: clock(0)))
        XCTAssertTrue(b.writes.isEmpty); XCTAssertNil(s.record)
    }
    func testDiskFailurePreventsMutation() throws {
        let (e, b, s) = try setup(); s.failSave = true
        XCTAssertThrowsError(try e.acquire(owner: UUID(), duration: 60, policy: SafetyPolicy(), sample: ac, now: clock(0)))
        XCTAssertTrue(b.writes.isEmpty)
    }
    func testEnableFailureRestores() throws {
        let (e, b, s) = try setup(); b.failEnable = true
        XCTAssertThrowsError(try e.acquire(owner: UUID(), duration: 60, policy: SafetyPolicy(), sample: ac, now: clock(0)))
        XCTAssertNil(s.record); XCTAssertEqual(e.status(now: clock(0)).phase, .off)
    }
    func testHardDeadlineCannotBeExtendedByHeartbeat() throws {
        let (e, b, _) = try setup(); let owner = UUID()
        let id = try e.acquire(owner: owner, duration: 60, policy: SafetyPolicy(), sample: ac, now: clock(0))
        for t in stride(from: 5.0, through: 55, by: 5) { try e.renew(id: id, owner: owner, sample: ac, now: clock(t)) }
        e.tick(sample: ac, now: clock(60))
        XCTAssertFalse(b.disabled); XCTAssertEqual(e.status(now: clock(60)).stopReason, .expired)
        XCTAssertThrowsError(try e.renew(id: id, owner: owner, sample: ac, now: clock(61)))
    }
    func testLostHeartbeatAndWrongOwner() throws {
        let (e, b, _) = try setup(); let owner = UUID()
        let id = try e.acquire(owner: owner, duration: 3600, policy: SafetyPolicy(), sample: ac, now: clock(0))
        XCTAssertThrowsError(try e.release(id: id, owner: UUID()))
        XCTAssertThrowsError(try e.renew(id: UUID(), owner: owner, sample: ac, now: clock(5)))
        e.disconnected(owner: UUID()); XCTAssertTrue(b.disabled)
        XCTAssertThrowsError(try e.renew(id: id, owner: owner, sample: ac, now: clock(20)))
        XCTAssertFalse(b.disabled); XCTAssertEqual(e.status(now: clock(20)).stopReason, .heartbeatLost)
    }
    func testDisconnectRestores() throws {
        let (e, b, _) = try setup(); let owner = UUID()
        _ = try e.acquire(owner: owner, duration: 3600, policy: SafetyPolicy(), sample: ac, now: clock(0))
        e.disconnected(owner: owner); XCTAssertFalse(b.disabled)
    }
    func testRestoreFailureKeepsJournalAndRetries() throws {
        let (e, b, s) = try setup(); let owner = UUID()
        let id = try e.acquire(owner: owner, duration: 60, policy: SafetyPolicy(), sample: ac, now: clock(0))
        b.failRestore = true
        XCTAssertThrowsError(try e.release(id: id, owner: owner)); XCTAssertNotNil(s.record)
        XCTAssertEqual(e.status(now: clock(0)).phase, .recoveryRequired)
        XCTAssertThrowsError(try e.acquire(owner: owner, duration: 60, policy: SafetyPolicy(), sample: ac, now: clock(1)))
        b.failRestore = false; e.tick(sample: ac, now: clock(2))
        XCTAssertFalse(b.disabled); XCTAssertNil(s.record)
    }
    func testRestartRecoversWithoutResuming() throws {
        let (e, b, s) = try setup()
        _ = try e.acquire(owner: UUID(), duration: 3600, policy: SafetyPolicy(), sample: ac, now: clock(0))
        let restarted = LeaseEngine(backend: b, store: s); try restarted.recover()
        XCTAssertFalse(b.disabled); XCTAssertEqual(restarted.status(now: clock(1)).phase, .off)
    }
    func testClockJumpStops() throws {
        let (e, b, _) = try setup()
        _ = try e.acquire(owner: UUID(), duration: 3600, policy: SafetyPolicy(), sample: ac, now: clock(0))
        e.tick(sample: ac, now: clock(5, wallOffset: -120))
        XCTAssertFalse(b.disabled); XCTAssertEqual(e.status(now: clock(5)).stopReason, .clockChanged)
    }
    func testPowerLossStopsDefaultSession() throws {
        let (e, b, _) = try setup()
        _ = try e.acquire(owner: UUID(), duration: 3600, policy: SafetyPolicy(), sample: ac, now: clock(0))
        e.tick(sample: PowerSample(onAC: false, batteryPercent: 80, thermal: .nominal), now: clock(5))
        XCTAssertFalse(b.disabled); XCTAssertEqual(e.status(now: clock(5)).stopReason, .powerDisconnected)
    }
    func testUnknownTelemetryStopsAndInvalidRequestsDoNotWrite() throws {
        let (e, b, _) = try setup()
        for duration in [Double.nan, Double.infinity, 0, 59, 86401] {
            XCTAssertThrowsError(try e.acquire(owner: UUID(), duration: duration, policy: SafetyPolicy(), sample: ac, now: clock(0)))
        }
        XCTAssertThrowsError(try e.acquire(owner: UUID(), duration: 60, policy: SafetyPolicy(minimumBattery: 0), sample: ac, now: clock(0)))
        XCTAssertTrue(b.writes.isEmpty)
        _ = try e.acquire(owner: UUID(), duration: 60, policy: SafetyPolicy(), sample: ac, now: clock(0))
        e.tick(sample: PowerSample(onAC: nil, batteryPercent: nil, thermal: .unknown), now: clock(5))
        XCTAssertFalse(b.disabled)
    }
    func testExternalChangeDoesNotReEnable() throws {
        let (e, b, _) = try setup()
        _ = try e.acquire(owner: UUID(), duration: 60, policy: SafetyPolicy(), sample: ac, now: clock(0))
        b.disabled = false; e.tick(sample: ac, now: clock(5))
        XCTAssertEqual(b.writes, [true]); XCTAssertEqual(e.status(now: clock(5)).stopReason, .backendChanged)
    }
    func testSafetyThresholdAndThermalHysteresis() {
        var s = SafetyEvaluator(); let policy = SafetyPolicy(requireAC: false)
        XCTAssertEqual(s.evaluate(PowerSample(onAC: false, batteryPercent: 20, thermal: .nominal), policy: policy, now: 0), .lowBattery)
        XCTAssertEqual(s.evaluate(PowerSample(onAC: false, batteryPercent: nil, thermal: .nominal), policy: policy, now: 0), .telemetryUnknown)
        let hot = PowerSample(onAC: true, batteryPercent: nil, thermal: .serious)
        XCTAssertNil(s.evaluate(hot, policy: policy, now: 0))
        XCTAssertNil(s.evaluate(hot, policy: policy, now: 29))
        XCTAssertEqual(s.evaluate(hot, policy: policy, now: 30), .thermalSerious)
        XCTAssertNil(s.evaluate(ac, policy: policy, now: 31))
        XCTAssertNil(s.evaluate(hot, policy: policy, now: 32))
        XCTAssertEqual(s.evaluate(PowerSample(onAC: true, batteryPercent: nil, thermal: .critical), policy: policy, now: 33), .thermalCritical)
    }
    func testClearFailureIsNotReportedAsSuccess() throws {
        let (e, b, s) = try setup(); let owner = UUID()
        let id = try e.acquire(owner: owner, duration: 60, policy: SafetyPolicy(), sample: ac, now: clock(0))
        s.failClear = true; XCTAssertThrowsError(try e.release(id: id, owner: owner))
        XCTAssertFalse(b.disabled); XCTAssertNotNil(s.record)
        XCTAssertEqual(e.status(now: clock(0)).phase, .recoveryRequired)
    }
    func testUnavailableBaselineDoesNotWrite() throws {
        let (e, b, s) = try setup(); b.readFails = true
        XCTAssertThrowsError(try e.acquire(owner: UUID(), duration: 60, policy: SafetyPolicy(), sample: ac, now: clock(0)))
        XCTAssertTrue(b.writes.isEmpty); XCTAssertNil(s.record)
    }
}
