using System;
using System.ComponentModel;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Windows;
using Forms = System.Windows.Forms;

namespace Awake.App;

internal sealed class TrayController : IDisposable
{
    private readonly MainViewModel model;
    private readonly Forms.NotifyIcon tray;
    private readonly Forms.ContextMenuStrip menu = new();
    private readonly Forms.ToolStripMenuItem toggle;
    private readonly Forms.ToolStripMenuItem extend;
    private readonly Forms.ToolStripMenuItem stop;
    private readonly TrayPanel panel;
    private readonly Icon idleIcon = CreateIcon(false);
    private readonly Icon activeIcon = CreateIcon(true);

    public TrayController(MainViewModel model, Action<bool> openPage, Action exit)
    {
        this.model = model;
        panel = new TrayPanel(model, openPage, exit);
        menu.Items.Add("打开控制窗口", null, (_, _) => openPage(false));
        menu.Items.Add("设置…", null, (_, _) => openPage(true));
        toggle = new Forms.ToolStripMenuItem("开始", null, (_, _) => model.ToggleCommand.Execute(null)); menu.Items.Add(toggle);
        extend = new Forms.ToolStripMenuItem("延长 15 分钟", null, (_, _) => model.ExtendCommand.Execute(null)); menu.Items.Add(extend);
        stop = new Forms.ToolStripMenuItem("恢复睡眠设置", null, (_, _) => model.TryStop()); menu.Items.Add(stop);
        menu.Items.Add(new Forms.ToolStripSeparator()); menu.Items.Add("退出", null, (_, _) => exit());
        tray = new Forms.NotifyIcon { Icon = idleIcon, Text = "KeepMyMacAwake", ContextMenuStrip = menu, Visible = true };
        tray.MouseClick += (_, e) => { if (e.Button == Forms.MouseButtons.Left) panel.Toggle(); };
        tray.BalloonTipClicked += (_, _) => openPage(false);
        model.SessionEnded += SessionEnded;
        model.PropertyChanged += Changed; Update();
        model.ToggleCommand.CanExecuteChanged += CommandChanged;
        model.ExtendCommand.CanExecuteChanged += CommandChanged;
    }
    private void CommandChanged(object? sender, EventArgs e) => Update();
    public void ShowCloseHint()
    {
        if (model.ConsumeTrayHint()) ShowBalloon("仍在系统托盘", "关闭窗口不会结束会话。点击托盘杯子查看状态；退出请用托盘菜单中的“退出”。");
    }
    private void SessionEnded(Awake.Core.SessionResult result) => ShowBalloon("保持唤醒已结束", result.Text);
    private void ShowBalloon(string title, string body)
    {
        try { tray.ShowBalloonTip(5000, title, body, Forms.ToolTipIcon.Info); }
        catch (System.ComponentModel.Win32Exception) { /* A disabled system notification never blocks stopping. */ }
    }
    private void Changed(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(MainViewModel.TrayText) or nameof(MainViewModel.IsActive) or nameof(MainViewModel.IsFiniteActive) or nameof(MainViewModel.NeedsRecovery) or nameof(MainViewModel.HasOnboarded)) Update();
    }
    private void Update()
    {
        tray.Text = model.TrayText.Length > 63 ? model.TrayText[..63] : model.TrayText;
        Icon icon = model.IsActive ? activeIcon : idleIcon; if (tray.Icon != icon) tray.Icon = icon;
        toggle.Text = model.ActionText; toggle.Enabled = model.ToggleCommand.CanExecute(null);
        extend.Enabled = model.ExtendCommand.CanExecute(null); extend.Visible = model.IsFiniteActive;
        stop.Visible = model.NeedsRecovery;
    }
    private static Icon CreateIcon(bool active)
    {
        using var image = new Bitmap(32, 32);
        using var drawing = Graphics.FromImage(image);
        drawing.SmoothingMode = SmoothingMode.AntiAlias;
        var color = active ? Color.FromArgb(255, 106, 43) : Color.FromArgb(150, 145, 138);
        using var pen = new Pen(color, 2.2f);
        using var fill = new SolidBrush(color);
        if (active) drawing.FillRectangle(fill, 5, 11, 18, 12);
        drawing.DrawRectangle(pen, 5, 11, 18, 12); drawing.DrawArc(pen, 18, 12, 11, 9, -90, 180);
        drawing.DrawLine(pen, 3, 27, 26, 27);
        drawing.DrawBezier(pen, 10, 8, 7, 6, 13, 4, 10, 2);
        drawing.DrawBezier(pen, 17, 8, 14, 6, 20, 4, 17, 2);
        nint handle = image.GetHicon();
        try { using var native = Icon.FromHandle(handle); return (Icon)native.Clone(); }
        finally { DestroyIcon(handle); }
    }
    [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] private static extern bool DestroyIcon(nint icon);
    public void Dispose()
    {
        model.PropertyChanged -= Changed;
        model.SessionEnded -= SessionEnded;
        model.ToggleCommand.CanExecuteChanged -= CommandChanged; model.ExtendCommand.CanExecuteChanged -= CommandChanged;
        panel.Close(); tray.Visible = false; tray.Dispose(); menu.Dispose(); idleIcon.Dispose(); activeIcon.Dispose();
    }
}
