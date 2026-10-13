import Foundation

/// Scene defaults shared with specs/scenes.json. The app applies these when a
/// scene is chosen; tests compare them with the shared contract.
public struct ScenePreset: Equatable {
    public let name: String
    public let durationMinutes: Int
    public let screenMode: String
    public let lidMode: Bool
    public let requireAC: Bool
    public let requireNetwork: Bool
    public static let all = [
        ScenePreset(name: "日常", durationMinutes: 60, screenMode: "自动熄屏", lidMode: false, requireAC: true, requireNetwork: false),
        ScenePreset(name: "夜间", durationMinutes: 480, screenMode: "夜间柔光", lidMode: false, requireAC: true, requireNetwork: false),
        ScenePreset(name: "接电合盖", durationMinutes: -1, screenMode: "自动熄屏", lidMode: true, requireAC: true, requireNetwork: false),
        ScenePreset(name: "有网时", durationMinutes: 120, screenMode: "自动熄屏", lidMode: true, requireAC: false, requireNetwork: true)
    ]
    public static func named(_ name: String) -> ScenePreset? { all.first { $0.name == name } }
    public var preferences: AwakePreferences {
        var value = AwakePreferences()
        value.scene = name; value.durationMinutes = durationMinutes; value.screenMode = screenMode
        value.lidMode = lidMode; value.requireAC = requireAC; value.requireNetwork = requireNetwork
        return value
    }
}

public extension AwakePreferences {
    var durationText: String {
        if durationMinutes == -1 { return "直到手动停止" }
        return SessionText.duration(Double((durationMinutes == 0 ? customMinutes : durationMinutes) * 60))
    }
    /// What a start will request, e.g. "8 小时 · 开盖 · 仅接电 · 夜间柔光".
    var summary: String {
        [durationText, lidMode ? "合盖" : "开盖", requireAC ? "仅接电" : "允许电池",
         requireNetwork ? "断网停止" : nil, screenMode].compactMap { $0 }.joined(separator: " · ")
    }
    /// True when the main rules differ from the chosen scene's defaults.
    var isCustomized: Bool {
        guard let preset = ScenePreset.named(scene) else { return false }
        return durationMinutes != preset.durationMinutes || screenMode != preset.screenMode || lidMode != preset.lidMode ||
            requireAC != preset.requireAC || requireNetwork != preset.requireNetwork
    }
}

/// Plain-language session text. Wall-clock times are presentation only; session
/// deadlines remain measured with the continuous clock.
public enum SessionText {
    public static func clock(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
    /// "预计 07:30 结束", or "预计明天 07:30 结束" when the deadline crosses midnight.
    public static func endTime(_ end: Date, now: Date, calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: end)).day ?? 0
        let day = days == 0 ? " " : days == 1 ? "明天 " : " \(days) 天后 "
        return "预计\(day)\(clock(end, calendar: calendar)) 结束"
    }
    public static func duration(_ seconds: Double) -> String {
        let minutes = Int(max(0, seconds) / 60)
        if minutes < 1 { return "不足 1 分钟" }
        let hours = minutes / 60, rest = minutes % 60
        if hours == 0 { return "\(rest) 分钟" }
        return rest == 0 ? "\(hours) 小时" : "\(hours) 小时 \(rest) 分钟"
    }
    /// Compact menu bar countdown: "45m", "7h05m".
    public static func menuBar(remaining: Double) -> String {
        let minutes = Int(ceil(max(0, remaining) / 60))
        return minutes < 60 ? "\(minutes)m" : String(format: "%dh%02dm", minutes / 60, minutes % 60)
    }
    /// Retained after a session ends so a returning user can see what happened.
    public static func lastResult(start: Date, end: Date, reason: String, calendar: Calendar = .current) -> String {
        "上次 \(clock(start, calendar: calendar))–\(clock(end, calendar: calendar)) · 运行 \(duration(end.timeIntervalSince(start))) · \(reason)"
    }
}
