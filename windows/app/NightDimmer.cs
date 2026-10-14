using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using Microsoft.Win32;
using Forms = System.Windows.Forms;

namespace Awake.App;

/// Temporary click-through windows; never changes brightness, input, or lock policy.
internal sealed class NightDimmer : IDisposable
{
    private sealed class DimWindow : Forms.Form
    {
        public DimWindow()
        {
            FormBorderStyle = Forms.FormBorderStyle.None; ShowInTaskbar = false;
            AutoScaleMode = Forms.AutoScaleMode.None; StartPosition = Forms.FormStartPosition.Manual;
            BackColor = System.Drawing.Color.Black; TopMost = true;
        }
        protected override bool ShowWithoutActivation => true;
        protected override Forms.CreateParams CreateParams
        {
            get { var p = base.CreateParams; p.ExStyle |= 0x08000000 | 0x00000020 | 0x00000080; return p; }
        }
    }
    private readonly Dictionary<string, DimWindow> windows = new(StringComparer.Ordinal);
    private bool running;
    private bool disposed;
    private double amount;
    private bool previousTopmost;
    public event EventHandler<Exception>? StopRequested;
    public NightDimmer() { SystemEvents.DisplaySettingsChanged += ScreensChanged; }
    public void Start(double amount)
    {
        ObjectDisposedException.ThrowIf(disposed, this);
        if (!double.IsFinite(amount) || amount is < .8 or > .98) throw new ArgumentException("调暗程度无效");
        this.amount = amount;
        if (!running) previousTopmost = Application.Current.MainWindow?.Topmost ?? false;
        running = true;
        try { Update(); } catch { Stop(); throw; }
    }
    private void ScreensChanged(object? sender, EventArgs e)
    {
        var dispatcher = Application.Current.Dispatcher;
        if (disposed || !running || dispatcher.HasShutdownStarted || dispatcher.HasShutdownFinished) return;
        dispatcher.BeginInvoke(() =>
        {
            if (disposed || !running) return;
            try { Update(); } catch (Exception error) { Stop(); StopRequested?.Invoke(this, error); }
        });
    }
    private void Update()
    {
        if (!running) return;
        var screens = Forms.Screen.AllScreens;
        var names = screens.Select(s => s.DeviceName).ToHashSet(StringComparer.Ordinal);
        foreach (string missing in windows.Keys.Where(k => !names.Contains(k)).ToArray())
        { windows[missing].Dispose(); windows.Remove(missing); }
        foreach (var screen in screens)
        {
            if (!windows.TryGetValue(screen.DeviceName, out var window))
            {
                window = new DimWindow(); windows.Add(screen.DeviceName, window);
                window.Bounds = screen.WorkingArea; window.Opacity = amount; window.Show();
            }
            else
            {
                if (window.Bounds != screen.WorkingArea) window.Bounds = screen.WorkingArea;
                if (window.Opacity != amount) window.Opacity = amount;
            }
        }
        // Preserve access to stop controls above overlays; the taskbar stays uncovered.
        if (Application.Current.MainWindow is Window control)
        { control.Topmost = false; control.Topmost = true; }
    }
    public void Stop()
    {
        bool wasRunning = running; running = false;
        foreach (var window in windows.Values) window.Dispose(); windows.Clear();
        if (wasRunning && Application.Current.MainWindow is Window control) control.Topmost = previousTopmost;
    }
    public void Dispose()
    {
        if (disposed) return; disposed = true;
        SystemEvents.DisplaySettingsChanged -= ScreensChanged; Stop();
    }
}
