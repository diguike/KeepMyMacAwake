import Foundation
import AwakeCore
import AwakeShared

private final class ReplyGate: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false
    func once(_ block: () -> Void) {
        lock.lock()
        if finished { lock.unlock(); return }
        finished = true; lock.unlock(); block()
    }
}
@MainActor final class HelperClient {
    private var connection: NSXPCConnection?
    func disconnect() { connection?.invalidate(); connection = nil }
    func send(_ request: HelperRequest) async throws -> HelperReply {
        if connection == nil {
            let executable = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/HelperTools/KeepMyMacAwakeHelper")
            let requirement = try Signing.requirement(for: executable)
            let next = NSXPCConnection(machServiceName: ServiceIdentity.helper, options: .privileged)
            next.setCodeSigningRequirement(requirement)
            next.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
            next.resume(); connection = next
        }
        guard let connection = connection else { throw AwakeError.backend("后台组件不可达") }
        let encoded = try JSONEncoder().encode(request)
        let data: Data = try await withCheckedThrowingContinuation { continuation in
            let gate = ReplyGate()
            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                gate.once { continuation.resume(throwing: error) }
            } as? HelperProtocol
            guard let proxy = proxy else {
                gate.once { continuation.resume(throwing: AwakeError.backend("后台协议不可用")) }; return
            }
            proxy.send(encoded) { reply in gate.once { continuation.resume(returning: reply) } }
            DispatchQueue.global().asyncAfter(deadline: .now() + 8) {
                gate.once { continuation.resume(throwing: AwakeError.backend("后台组件响应超时，状态未知")) }
            }
        }
        let reply = try JSONDecoder().decode(HelperReply.self, from: data)
        guard reply.version == ServiceIdentity.version else { throw AwakeError.invalidRequest }
        return reply
    }
}
