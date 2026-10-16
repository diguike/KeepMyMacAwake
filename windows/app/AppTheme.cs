using System.Windows;
using System.Windows.Media;

namespace Awake.App;

/// Warm-sun palette shared by the app and real-WPF CI renders. High contrast uses OS colors.
internal static class AppTheme
{
    internal static void Apply(ResourceDictionary resources, bool dark, bool highContrast)
    {
        string[] names = ["PageBrush", "CardBrush", "RaisedBrush", "TextBrush", "MutedBrush", "LineBrush",
            "AccentBrush", "AccentTextBrush", "AccentSoftBrush", "WarningBrush", "DangerBrush", "WellBrush",
            "HeroInkBrush", "HeroLineBrush", "ChipBrush", "MeterTrackBrush", "AmberBrush"];
        string[] colors = dark
            ? ["#17130F", "#231D18", "#3D342D", "#FFF4EA", "#C2B1A3", "#28FFFFFF",
               "#FF6A2B", "#FFFFFF", "#2E231C", "#FF8A50", "#FF8B82", "#12FFFFFF",
               "#FFF4EA", "#14FFFFFF", "#14FFFFFF", "#28FFFFFF", "#FFA940"]
            : ["#FFFAF4", "#FFFFFF", "#FFFFFF", "#30261E", "#77685D", "#2030261E",
               "#FF6A2B", "#FFFFFF", "#FFF6F0", "#C94A12", "#B42318", "#0C30261E",
               "#4A2A12", "#2EFF6A2B", "#B3FFFFFF", "#1A30261E", "#FFA940"];
        for (int i = 0; i < names.Length; i++) resources[names[i]] = Brush(colors[i]);
        resources["HeroBrush"] = Gradient(dark ? "#3A2716" : "#FFF4E2", dark ? "#2A1D12" : "#FFE3C7");
        resources["PrimaryBrush"] = Gradient("#FF7A3D", "#ED571A");
        resources["MarkBrush"] = Gradient("#FF8A4C", "#F2541B");
        if (!highContrast) return;
        foreach (string name in new[] { "PageBrush", "CardBrush", "RaisedBrush", "AccentSoftBrush", "WellBrush", "HeroBrush", "ChipBrush" })
            resources[name] = SystemColors.WindowBrush;
        foreach (string name in new[] { "TextBrush", "MutedBrush", "LineBrush", "HeroInkBrush", "HeroLineBrush", "WarningBrush", "DangerBrush", "MeterTrackBrush" })
            resources[name] = SystemColors.WindowTextBrush;
        foreach (string name in new[] { "AccentBrush", "PrimaryBrush", "MarkBrush", "AmberBrush" }) resources[name] = SystemColors.HighlightBrush;
        resources["AccentTextBrush"] = SystemColors.HighlightTextBrush;
    }
    private static SolidColorBrush Brush(string hex) => new((Color)ColorConverter.ConvertFromString(hex));
    private static LinearGradientBrush Gradient(string top, string bottom) => new(
        (Color)ColorConverter.ConvertFromString(top), (Color)ColorConverter.ConvertFromString(bottom), new Point(0, 0), new Point(1, 1));
}
