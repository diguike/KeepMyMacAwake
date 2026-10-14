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
    /// One short line for scene cards: when to use it and what it does.
    public var tagline: String {
        switch name {
        case "夜间": return "睡前开启 · 8 小时 · 调暗屏幕"
        case "接电合盖": return "合上盖子 · 直到手动停止"
        case "有网时": return "用电池合盖 · 断网即停"
        default: return "离开一会儿 · 1 小时"
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
        if durationMinutes == -1 { return "直到手动停止" }
        return SessionText.duration(Double((durationMinutes == 0 ? customMinutes : durationMinutes) * 60))
    }
    /// What a start will request, e.g. "8 小时 · 需开盖 · 仅接电 · 调暗常亮".
    var summary: String {
        [durationText, lidMode ? "可合盖" : "需开盖", requireAC ? "仅接电" : "可用电池",
         requireNetwork ? "断网停止" : nil, SessionText.screenMode(screenMode)].compactMap { $0 }.joined(separator: " · ")
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
        case "自动熄屏": return "允许熄屏"
        case "保持常亮": return "屏幕常亮"
        case "夜间柔光": return "调暗常亮"
        default: return mode
        }
    }
    public static func screenModeDetail(_ mode: String) -> String {
        switch mode {
        case "保持常亮": return "屏幕保持点亮，方便随时查看进度。"
        case "夜间柔光": return "屏幕保持点亮，并盖上一层可调的暗色遮罩；不是硬件亮度调节。"
        default: return "屏幕按系统设置自动关闭，Mac 继续运行。"
        }
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
    /// "10/13 23:10 – 10/14 07:10", or "10/14 01:10 – 02:10" within one day.
    public static func span(start: Date, end: Date, calendar: Calendar = .current) -> String {
        func day(_ date: Date) -> String {
            let parts = calendar.dateComponents([.month, .day], from: date)
            return String(format: "%d/%d", parts.month ?? 0, parts.day ?? 0)
        }
        let tail = calendar.isDate(start, inSameDayAs: end) ? clock(end, calendar: calendar) : "\(day(end)) \(clock(end, calendar: calendar))"
        return "\(day(start)) \(clock(start, calendar: calendar)) – \(tail)"
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
