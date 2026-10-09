import Foundation
import AwakeCore

public enum ServiceIdentity {
    public static let app = "io.github.diguike.KeepMyMacAwake"
    public static let helper = "io.github.diguike.KeepMyMacAwake.helper"
    public static let plist = helper + ".plist"
    public static let version = 2
}
public enum Operation: String, Codable { case status, acquire, renew, release, recover }
public struct HelperRequest: Codable {
    public let version: Int
    public let operation: Operation
    public var leaseID: UUID?
    public var duration: Double?
    public var policy: SafetyPolicy?
    public init(_ operation: Operation, leaseID: UUID? = nil, duration: Double? = nil, policy: SafetyPolicy? = nil) {
        version = ServiceIdentity.version; self.operation = operation
        self.leaseID = leaseID; self.duration = duration; self.policy = policy
    }
}
public struct HelperReply: Codable {
    public let version: Int
    public var status: SessionStatus
    public var sample: PowerSample
    public var error: String?
    public init(status: SessionStatus, sample: PowerSample, error: String? = nil) {
        version = ServiceIdentity.version; self.status = status; self.sample = sample; self.error = error
    }
}
@objc public protocol HelperProtocol {
    func send(_ request: Data, withReply reply: @escaping (Data) -> Void)
}
