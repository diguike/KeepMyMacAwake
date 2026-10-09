import Foundation

public struct AwakePreferences: Codable, Equatable {
    public var scene = "日常"
    public var durationMinutes = 60
    public var customMinutes = 90
    public var lidMode = false
    public var requireAC = true
    public var requireNetwork = false
    public var screenMode = "自动熄屏"
    public var minimumBattery = 20
    public var dimAmount = 0.94
    public var showCountdown = true
    public init() {}
    public var isValid: Bool {
        ["日常", "夜间", "接电合盖", "有网时"].contains(scene) &&
        (durationMinutes == -1 || durationMinutes == 0 || (1...1440).contains(durationMinutes)) &&
        (1...1440).contains(customMinutes) && (10...80).contains(minimumBattery) &&
        ["自动熄屏", "保持常亮", "夜间柔光"].contains(screenMode) &&
        dimAmount.isFinite && (0.8...0.98).contains(dimAmount)
    }
}
