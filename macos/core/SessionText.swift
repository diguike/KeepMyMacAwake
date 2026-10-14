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
    public var displayName: String { name == "有网时" ? "外出合盖" : name }
    /// Scene cards only state what differs from the others.
    public var tagline: String {
        switch name {
        case "夜间": return "8 小时 · 屏幕调暗"
        case "接电合盖": return "不限时"
        case "有网时": return "2 小时 · 断网即停"
        default: return "1 小时"
        }
    }
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
        if durationMinutes == -1 { return "不限时" }
        return SessionText.duration(Double((durationMinutes == 0 ? customMinutes : durationMinutes) * 60))
    }
    /// Full rules for tooltips, e.g. "8 小时，需开盖，仅接电，屏幕调暗".
    var summary: String {
        [durationText, lidMode ? "可合盖" : "需开盖", requireAC ? "仅接电" : "可用电池",
         requireNetwork ? "断网即停" : nil, "屏幕" + SessionText.screenMode(screenMode)].compactMap { $0 }.joined(separator: "，")
    }
    /// Duration plus the one rule most worth noticing, e.g. "8 小时 · 调暗".
    var brief: String {
        let flag: String? = lidMode ? "合盖" : screenMode != "自动熄屏" ? SessionText.screenMode(screenMode) : requireNetwork ? "断网即停" : nil
        return [durationText, flag].compactMap { $0 }.joined(separator: " · ")
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
    /// Stored screen-mode identifiers stay unchanged for saved preferences and
    /// specs/scenes.json; these are the names people see.
    public static func screenMode(_ mode: String) -> String {
        switch mode {
        case "自动熄屏": return "自动关闭"
        case "保持常亮": return "常亮"
        case "夜间柔光": return "调暗"
        default: return mode
        }
    }
    public static let screenModeHelp = "自动关闭：按系统设置关闭屏幕\n常亮：屏幕保持点亮\n调暗：保持点亮并加一层软件暗色遮罩，不调节硬件亮度"
    public struct NumberPart: Equatable {
        public let value: String
        public let unit: String
        public init(_ value: String, _ unit: String) { self.value = value; self.unit = unit }
    }
    /// Large-number layout: "6 小时 28 分", or "45 分 12 秒" in the last hour.
    /// Planned durations pass `seconds: false` and drop zero minutes ("8 小时").
    public static func parts(_ seconds: Double, seconds showSeconds: Bool = true) -> [NumberPart] {
        let total = max(0, Int(seconds.rounded(.up)))
        let hours = total / 3600, minutes = total / 60 % 60, rest = total % 60
        if hours > 0 {
            if !showSeconds && minutes == 0 { return [NumberPart("\(hours)", "小时")] }
            return [NumberPart("\(hours)", "小时"), NumberPart("\(minutes)", "分")]
        }
        return showSeconds ? [NumberPart("\(minutes)", "分"), NumberPart("\(rest)", "秒")] : [NumberPart("\(max(1, minutes))", "分钟")]
    }
    /// "01:05:09" for elapsed or remaining session time.
    public static func timer(_ seconds: Double) -> String {
        let value = max(0, Int(seconds.rounded(.down)))
        return String(format: "%02d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
    }
    public static func clock(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
    /// "07:30 结束", "明天 07:30 结束" or "2 天后 00:10 结束".
    public static func endTime(_ end: Date, now: Date, calendar: Calendar = .current) -> String {
        "\(dayPrefix(end, now: now, calendar: calendar))\(clock(end, calendar: calendar)) 结束"
    }
    /// When a past session ended: "07:10", "昨天 07:10" or "10/13 07:10".
    public static func endedAt(_ end: Date, now: Date, calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: end), to: calendar.startOfDay(for: now)).day ?? 0
        if days == 0 { return clock(end, calendar: calendar) }
        if days == 1 { return "昨天 " + clock(end, calendar: calendar) }
        let parts = calendar.dateComponents([.month, .day], from: end)
        return String(format: "%d/%d ", parts.month ?? 0, parts.day ?? 0) + clock(end, calendar: calendar)
    }
    private static func dayPrefix(_ end: Date, now: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: end)).day ?? 0
        return days <= 0 ? "" : days == 1 ? "明天 " : "\(days) 天后 "
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
        func stamp(_ date: Date) -> String {
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            return String(format: "%04d/%02d/%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0) + " " + clock(date, calendar: calendar)
        }
        return "上次 \(stamp(start))–\(stamp(end)) · 运行 \(duration(end.timeIntervalSince(start))) · \(reason)"
    }
}
