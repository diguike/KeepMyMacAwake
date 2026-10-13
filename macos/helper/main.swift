import Foundation
import Darwin
import AwakeCore
import AwakeShared

final class HelperService: NSObject, HelperProtocol {
    let owner = UUID()
    let engine: LeaseEngine
    let queue: DispatchQueue
    init(engine: LeaseEngine, queue: DispatchQueue) { self.engine = engine; self.queue = queue }
    func send(_ request: Data, withReply reply: @escaping (Data) -> Void) {
        queue.async { [self] in
            let sample = MacMonitor.sample()
            let now = MacMonitor.clock()
            var failure: String?
            do {
                guard request.count <= 4096 else { throw AwakeError.invalidRequest }
                let input = try JSONDecoder().decode(HelperRequest.self, from: request)
                guard input.version == ServiceIdentity.version else { throw AwakeError.invalidRequest }
                engine.tick(sample: sample, now: now)
                switch input.operation {
                case .status: break
                case .acquire:
                    guard let duration = input.duration, let policy = input.policy else { throw AwakeError.invalidRequest }
                    _ = try engine.acquire(owner: owner, duration: duration, policy: policy, sample: sample, now: now)
                case .renew:
                    guard let id = input.leaseID else { throw AwakeError.invalidRequest }
                    try engine.renew(id: id, owner: owner, sample: sample, now: now)
                case .extend:
                    guard let id = input.leaseID, let seconds = input.duration else { throw AwakeError.invalidRequest }
                    try engine.extend(id: id, owner: owner, seconds: seconds, sample: sample, now: now)
                case .release:
                    guard let id = input.leaseID else { throw AwakeError.invalidRequest }
                    try engine.release(id: id, owner: owner)
                case .recover:
                    guard engine.status(now: now).phase != .active else { throw AwakeError.busy }
                    try engine.recover()
                }
            } catch { failure = error.localizedDescription }
            var status = engine.status(now: MacMonitor.clock())
            // Do not expose another connection's capability token.
            if status.leaseID != engine.leaseID(for: owner) { status.leaseID = nil }
            let response = HelperReply(status: status, sample: sample, error: failure)
            reply((try? JSONEncoder().encode(response)) ?? Data())
        }
    }
}
final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    let engine: LeaseEngine
    let queue: DispatchQueue
    let clientRequirement: String
    init(engine: LeaseEngine, queue: DispatchQueue, clientRequirement: String) {
        self.engine = engine; self.queue = queue; self.clientRequirement = clientRequirement
    }
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard connection.effectiveUserIdentifier != 0 else { return false }
        connection.setCodeSigningRequirement(clientRequirement)
        let service = HelperService(engine: engine, queue: queue)
        connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.exportedObject = service
        connection.invalidationHandler = { [engine, queue, owner = service.owner] in
            queue.async { engine.disconnected(owner: owner) }
        }
        connection.interruptionHandler = connection.invalidationHandler
        connection.resume()
        return true
    }
}

guard geteuid() == 0 else { fputs("Helper must run through its approved LaunchDaemon.\n", stderr); exit(1) }
do {
    let requirement = try Signing.allowedClientRequirement()
    let store = try FileRecoveryStore(directory: URL(fileURLWithPath: "/var/db/io.github.diguike.keepmymacawake"))
    let engine = LeaseEngine(backend: PMSetBackend(), store: store)
    let queue = DispatchQueue(label: "io.github.diguike.keepmymacawake.helper")
    // Recover before accepting clients; failed recovery stays visible and retried.
    do { try engine.recover() } catch { fputs("Recovery pending: \(error.localizedDescription)\n", stderr) }
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now(), repeating: 2)
    timer.setEventHandler { engine.tick(sample: MacMonitor.sample(), now: MacMonitor.clock()) }
    timer.resume()
    let delegate = ListenerDelegate(engine: engine, queue: queue, clientRequirement: requirement)
    let listener = NSXPCListener(machServiceName: ServiceIdentity.helper)
    listener.delegate = delegate
    listener.resume()
    withExtendedLifetime((delegate, listener, timer)) { RunLoop.current.run() }
} catch {
    fputs("Helper unavailable: \(error.localizedDescription)\n", stderr)
    exit(1)
}
