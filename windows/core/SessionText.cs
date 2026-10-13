namespace Awake.Core;

/// Plain-language session text, kept in step with macos/core/SessionText.swift.
/// Wall-clock times are presentation only; deadlines use the continuous clock.
public static class SessionText
{
    public static string SceneName(Scene scene) => scene switch { Scene.Night => "夜间", Scene.PluggedLid => "接电合盖", Scene.Network => "外出合盖", _ => "日常" };
    public static string Clock(DateTime local) => local.ToString("HH:mm", System.Globalization.CultureInfo.InvariantCulture);
    /// "预计 07:30 结束", or "预计明天 07:30 结束" when the deadline crosses midnight.
    public static string EndTime(DateTime endLocal, DateTime nowLocal)
    {
        int days = (endLocal.Date - nowLocal.Date).Days;
        string day = days == 0 ? " " : days == 1 ? "明天 " : $" {days} 天后 ";
        return "预计" + day + Clock(endLocal) + " 结束";
    }
    public static string Duration(double seconds)
    {
        long minutes = (long)(Math.Max(0, seconds) / 60);
        if (minutes < 1) return "不足 1 分钟";
        long hours = minutes / 60, rest = minutes % 60;
        if (hours == 0) return $"{rest} 分钟";
        return rest == 0 ? $"{hours} 小时" : $"{hours} 小时 {rest} 分钟";
    }
    /// Retained after a session ends so a returning user can see what happened.
    public static string LastResult(DateTime startLocal, DateTime endLocal, string reason) =>
        $"上次 {Stamp(startLocal)}–{Stamp(endLocal)} · 运行 {Duration((endLocal - startLocal).TotalSeconds)} · {reason}";
    private static string Stamp(DateTime value) => value.ToString("yyyy/MM/dd HH:mm", System.Globalization.CultureInfo.InvariantCulture);
}
