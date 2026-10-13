using System.Windows;
using System.Windows.Media;

namespace Awake.App;

/// The app and CI previews use the same resources; previews never change OS settings.
internal static class AppTheme
{
    internal static void Apply(ResourceDictionary resources, bool dark, bool highContrast)
    {
        string[] names = ["PageBrush", "CardBrush", "TextBrush", "MutedBrush", "LineBrush", "AccentBrush", "AccentTextBrush", "AccentSoftBrush"];
        string[] colors = dark
            ? ["#211F1D", "#302C28", "#F0EBE4", "#B6AEA4", "#51483F", "#DD9865", "#211F1D", "#4A3424"]
            : ["#FBF9F6", "#F0EBE4", "#292621", "#716A62", "#DAD3C9", "#B55E2C", "#FFFFFF", "#F5E3D5"];
        for (int i = 0; i < names.Length; i++)
            resources[names[i]] = new SolidColorBrush((Color)ColorConverter.ConvertFromString(colors[i]));
        if (!highContrast) return;
        resources["PageBrush"] = SystemColors.WindowBrush; resources["CardBrush"] = SystemColors.ControlBrush;
        resources["TextBrush"] = SystemColors.WindowTextBrush; resources["MutedBrush"] = SystemColors.WindowTextBrush;
        resources["LineBrush"] = SystemColors.WindowTextBrush; resources["AccentBrush"] = SystemColors.HighlightBrush;
        resources["AccentTextBrush"] = SystemColors.HighlightTextBrush; resources["AccentSoftBrush"] = SystemColors.WindowBrush;
    }
}
