import Foundation

public enum ThermalLevel: String, Codable { case nominal, fair, serious, critical, unknown }
public struct PowerSample: Codable, Equatable {
    public var onAC: Bool?
    public var batteryPercent: Int?
    public var thermal: ThermalLevel
    public init(onAC: Bool?, batteryPercent: Int?, thermal: ThermalLevel) {
        self.onAC = onAC; self.batteryPercent = batteryPercent; self.thermal = thermal
    }
}
public struct SafetyPolicy: Codable, Equatable {
    public var requireAC: Bool
    public var minimumBattery: Int
    public init(requireAC: Bool = true, minimumBattery: Int = 20) {
        self.requireAC = requireAC; self.minimumBattery = minimumBattery
    }
    public var isValid: Bool { (10...80).contains(minimumBattery) }
}
public enum StopReason: String, Codable {
    case manual, expired, disconnected, heartbeatLost, powerDisconnected, lowBattery
    case thermalCritical, thermalSerious, telemetryUnknown, clockChanged, backendChanged, recovered
    public var message: String {
        switch self {
        case .manual: return "已手动停止"
        case .expired: return "设定时间已到"
        case .disconnected: return "应用连接已断开"
        case .heartbeatLost: return "应用心跳已失联"
        case .powerDisconnected: return "已断开电源"
        case .lowBattery: return "电量低于保护阈值"
        case .thermalCritical: return "热压力达到临界状态"
        case .thermalSerious: return "热压力持续严重"
        case .telemetryUnknown: return "无法取得保护监控数据"
        case .clockChanged: return "系统时间发生明显变化"
        case .backendChanged: return "电源设置被外部修改"
        case .recovered: return "已恢复上次遗留设置"
        }
    }
}
public struct ClockSample {
    public var wall: Date
    /// Includes time spent asleep; callers on macOS use mach_continuous_time.
    public var continuous: TimeInterval
    public init(wall: Date, continuous: TimeInterval) { self.wall = wall; self.continuous = continuous }
}
public struct SafetyEvaluator {
    private var seriousSince: TimeInterval?
    public init() {}
    public mutating func evaluate(_ sample: PowerSample, policy: SafetyPolicy,
                                  now: TimeInterval) -> StopReason? {
        guard let onAC = sample.onAC, sample.thermal != .unknown else { return .telemetryUnknown }
        if policy.requireAC && !onAC { return .powerDisconnected }
        if !onAC {
            guard let battery = sample.batteryPercent, (0...100).contains(battery) else { return .telemetryUnknown }
            if battery <= policy.minimumBattery { return .lowBattery }
        }
        switch sample.thermal {
        case .critical: return .thermalCritical
        case .serious:
            if seriousSince == nil { seriousSince = now }
            if now - seriousSince! >= 30 { return .thermalSerious }
        default: seriousSince = nil
        }
        return nil
    }
}
public enum SessionPhase: String, Codable { case off, active, recoveryRequired }
public struct SessionStatus: Codable {
    public var phase: SessionPhase
    public var leaseID: UUID?
    public var remainingSeconds: Double?
    public var stopReason: StopReason?
    public var error: String?
    public init(phase: SessionPhase = .off, leaseID: UUID? = nil, remainingSeconds: Double? = nil,
                stopReason: StopReason? = nil, error: String? = nil) {
        self.phase = phase; self.leaseID = leaseID; self.remainingSeconds = remainingSeconds
        self.stopReason = stopReason; self.error = error
    }
}
public enum AwakeError: Error, LocalizedError {
    case invalidRequest, busy, unauthorizedLease, conflict, recoveryRequired, backend(String)
    public var errorDescription: String? {
        switch self {
        case .invalidRequest: return "请求参数无效或版本不匹配"
        case .busy: return "已有保活会话，请先停止"
        case .unauthorizedLease: return "租约已失效或不属于当前连接"
        case .conflict: return "其他工具已禁用休眠，请先停止该工具"
        case .recoveryRequired: return "遗留设置尚未恢复，请先恢复设置"
        case .backend(let detail): return detail
        }
    }
}
