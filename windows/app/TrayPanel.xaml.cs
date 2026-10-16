using System;
using System.Windows;
using System.Windows.Input;
using Forms = System.Windows.Forms;

namespace Awake.App;

/// A short-lived view of the same session model; hiding it never stops a session.
public partial class TrayPanel : Window
{
    private readonly Action<bool> openPage;
    private readonly Action exit;
    private Forms.Screen? screen;

    internal TrayPanel(MainViewModel model, Action<bool> openPage, Action exit)
    {
        Resources["HeroNumberSize"] = 34d;
        InitializeComponent(); DataContext = model;
        this.openPage = openPage; this.exit = exit;
        SizeChanged += (_, _) => PositionAtTray();
    }
    internal void Toggle()
    {
        if (IsVisible) { Hide(); return; }
        screen = Forms.Screen.FromPoint(Forms.Cursor.Position);
        Show(); PositionAtTray(); Activate(); Focus();
    }
    private void PositionAtTray()
    {
        if (screen is null || PresentationSource.FromVisual(this)?.CompositionTarget is not { } target) return;
        // WorkingArea is in physical pixels; WPF placement is in DIPs on this monitor.
        var area = screen.WorkingArea;
        var cursor = Forms.Cursor.Position;
        var bounds = new Rect(area.X, area.Y, area.Width, area.Height);
        bounds.Transform(target.TransformFromDevice);
        var anchor = target.TransformFromDevice.Transform(new Point(cursor.X, cursor.Y));
        Left = Math.Clamp(anchor.X - ActualWidth + 16, bounds.Left + 8, Math.Max(bounds.Left + 8, bounds.Right - ActualWidth - 8));
        Top = Math.Clamp(anchor.Y - ActualHeight - 12, bounds.Top + 8, Math.Max(bounds.Top + 8, bounds.Bottom - ActualHeight - 8));
    }
    private void PanelDeactivated(object? sender, EventArgs e) => Hide();
    private void PanelKeyDown(object sender, KeyEventArgs e) { if (e.Key == Key.Escape) { Hide(); e.Handled = true; } }
    private void ControlClicked(object sender, RoutedEventArgs e) { Hide(); openPage(false); }
    private void SettingsClicked(object sender, RoutedEventArgs e) { Hide(); openPage(true); }
    private void ExitClicked(object sender, RoutedEventArgs e) { Hide(); exit(); }
}
