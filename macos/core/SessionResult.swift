import Foundation

/// Only a completed session is retained. This is never a resumable lease.
public struct SessionResult: Codable, Equatable {
    public let start: Date
    public let end: Date
    public let reason: String
    public init(start: Date, end: Date, reason: String) {
        self.start = start; self.end = max(start, end); self.reason = reason
    }
    public var isValid: Bool {
        start.timeIntervalSince1970.isFinite && end.timeIntervalSince1970.isFinite &&
        end >= start && !reason.isEmpty && reason.count <= 300
    }
    public var text: String { SessionText.lastResult(start: start, end: end, reason: reason) }
}
