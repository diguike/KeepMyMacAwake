using Awake.Core;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;

namespace Awake.App.Tests;

internal sealed record CheckResult(string Name, bool Passed, string? Error);
internal sealed record PreviewImage(string File, string State, string Theme, int Scale, int Width, int Height);

/// Off-screen renders of real WPF controls with synthetic sessions and telemetry.
/// No tray, real power request, registry write, notification, or OS theme change.
internal static class UiReport
{
    private sealed class Backend : IPowerBackend
    {
        public void Start(bool keepDisplay) { }
        public void Stop() { }
    }
    private sealed class Fixture : IDisposable
    {
        private readonly string directory = Path.Combine(Path.GetTempPath(), "keepmymacawake-ui-" + Guid.NewGuid().ToString("N"));
        private double seconds;
        internal MainViewModel Model { get; }
        internal Fixture(string state)
        {
            var store = new PreferencesStore(directory);
            store.Save(new Preferences(), state != "welcome");
            var epoch = new DateTimeOffset(2026, 10, 14, 23, 30, 0, TimeSpan.Zero);
            Model = new MainViewModel(new Backend(), () => new PowerSample(true, 95, true, ThermalLevel.Unknown),
                () => new ClockSample(epoch.AddSeconds(seconds), seconds), store, false);
            switch (state)
            {
                case "night": Model.NightCommand.Execute(null); break;
                case "active":
                    Model.ToggleCommand.Execute(null); seconds = 600; Model.RefreshMonitor(); break;
                case "completed":
                    Model.DurationMinutes = 1; Model.ToggleCommand.Execute(null); seconds = 60; Model.RefreshMonitor(); break;
                case "lid-unavailable": Model.LidCommand.Execute(null); break;
            }
        }
        public void Dispose()
        {
            Model.TryStop(); Model.Dispose();
            Directory.Delete(directory, true);
        }
    }
    private sealed class BindingErrors : TraceListener
    {
        internal readonly List<string> Errors = [];
        public override void Write(string? message) { if (!string.IsNullOrWhiteSpace(message)) Errors.Add(message); }
        public override void WriteLine(string? message) => Write(message);
    }

    internal static void Write(string directory, IReadOnlyList<CheckResult> checks)
    {
        directory = Path.GetFullPath(directory);
        Directory.CreateDirectory(directory);
        var images = new List<PreviewImage>();
        var failures = new List<string>();
        var states = new (string Id, string Label)[]
        {
            ("welcome", "首次使用"), ("daily", "日常待机"), ("night", "夜间配置"),
            ("active", "运行与预计结束"), ("completed", "上次结果"),
            ("lid-unavailable", "合盖尚未开放"), ("settings", "设置")
        };
        var themes = new (string Id, string Label, bool Dark, bool Contrast)[]
        {
            ("light", "浅色", false, false), ("dark", "深色", true, false),
            ("contrast", "高对比资源预览", false, true)
        };
        var listener = new BindingErrors();
        var source = PresentationTraceSources.DataBindingSource;
        var oldLevel = source.Switch.Level;
        source.Switch.Level = SourceLevels.Error;
        source.Listeners.Add(listener);
        try
        {
            foreach (var theme in themes)
            foreach (int scale in new[] { 100, 125, 200 })
            foreach (var state in states)
            {
                string file = $"{theme.Id}-{scale}-{state.Id}.png";
                try
                {
                    AppTheme.Apply(Application.Current.Resources, theme.Dark, theme.Contrast);
                    using var fixture = new Fixture(state.Id);
                    var window = new MainWindow(fixture.Model);
                    var content = (FrameworkElement)window.Content;
                    if (state.Id == "settings") FindTabs(content).SelectedIndex = 1;
                    window.Content = null;
                    var canvas = new Border
                    {
                        Width = window.Width, Height = window.Height,
                        Background = window.Background, DataContext = fixture.Model, Child = content
                    };
                    TextElement.SetFontFamily(canvas, window.FontFamily);
                    TextElement.SetFontSize(canvas, window.FontSize);
                    canvas.Measure(new Size(canvas.Width, canvas.Height));
                    canvas.Arrange(new Rect(0, 0, canvas.Width, canvas.Height));
                    canvas.UpdateLayout();
                    Dispatcher.CurrentDispatcher.Invoke(() => { }, DispatcherPriority.Render);
                    int width = (int)Math.Round(canvas.Width * scale / 100);
                    int height = (int)Math.Round(canvas.Height * scale / 100);
                    var bitmap = new RenderTargetBitmap(width, height, 96 * scale / 100.0, 96 * scale / 100.0, PixelFormats.Pbgra32);
                    bitmap.Render(canvas);
                    var encoder = new PngBitmapEncoder();
                    encoder.Frames.Add(BitmapFrame.Create(bitmap));
                    using (var output = File.Create(Path.Combine(directory, file))) encoder.Save(output);
                    if (bitmap.PixelWidth != width || bitmap.PixelHeight != height) throw new InvalidDataException("Incorrect preview dimensions");
                    images.Add(new(file, state.Label, theme.Label, scale, width, height));
                    canvas.Child = null;
                }
                catch (Exception error) { failures.Add(file + ": " + error.Message); }
            }
        }
        finally
        {
            source.Listeners.Remove(listener); source.Switch.Level = oldLevel;
            AppTheme.Apply(Application.Current.Resources, false, false);
        }
        failures.AddRange(listener.Errors);
        var report = new
        {
            sourceCommit = Environment.GetEnvironmentVariable("GITHUB_SHA"),
            architecture = RuntimeInformation.ProcessArchitecture.ToString(),
            os = RuntimeInformation.OSDescription,
            appVersion = typeof(MainViewModel).Assembly.GetName().Version?.ToString(3),
            evidence = "Real WPF content rendered off-screen; synthetic power/session data. No physical power, tray, notification or installation acceptance.",
            highContrast = "Uses the same high-contrast resources as the app; does not enable the Windows high-contrast setting.",
            checks, images, renderingErrors = failures
        };
        File.WriteAllText(Path.Combine(directory, "report.json"), JsonSerializer.Serialize(report, new JsonSerializerOptions { WriteIndented = true }));
        var html = new StringBuilder("""
            <!doctype html><html lang="zh-CN"><meta charset="utf-8">
            <meta name="viewport" content="width=device-width,initial-scale=1"><title>Windows 界面与测试报告</title>
            <style>body{font:15px/1.6 system-ui,sans-serif;margin:32px;background:#f7f5f1;color:#292621}main{max-width:1500px;margin:auto}
            .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:20px}figure{margin:0;background:white;padding:12px;border:1px solid #ded8cf;border-radius:8px}
            img{width:100%;height:auto}figcaption{padding:10px 0}a{color:#965023}.pass{color:#286c3e}.fail{color:#a12424}code{overflow-wrap:anywhere}</style><main>
            <h1>Windows 界面与测试报告</h1>
            <p>真实 WPF 控件的离屏渲染，使用模拟电源和固定会话数据；不含系统标题栏。高对比项预览应用资源，未更改系统高对比设置。</p>
            <p>此报告不验证真实托盘、系统通知、普通用户安装、休眠、拔电或合盖。<a href="report.json">原始报告</a></p>
            """);
        html.Append($"<p>版本 {Encode(report.appVersion ?? "")} · {Encode(report.architecture)} · 提交 <code>{Encode(report.sourceCommit ?? "local")}</code></p><h2>WPF 注入检查</h2><ul>");
        foreach (var check in checks)
            html.Append($"<li class=\"{(check.Passed ? "pass" : "fail")}\">{(check.Passed ? "通过" : "失败")} · {Encode(check.Name)}{(check.Error is null ? "" : " · " + Encode(check.Error))}</li>");
        html.Append("</ul>");
        foreach (string failure in failures) html.Append($"<p class=\"fail\">{Encode(failure)}</p>");
        html.Append("<h2>界面图片</h2><div class=\"grid\">");
        foreach (var item in images)
            html.Append($"<figure><a href=\"{item.File}\"><img loading=\"lazy\" src=\"{item.File}\" alt=\"{Encode(item.State + " · " + item.Theme)}\"></a><figcaption>{Encode(item.State)} · {Encode(item.Theme)} · {item.Scale}% · {item.Width}×{item.Height}</figcaption></figure>");
        html.Append("</div></main></html>");
        File.WriteAllText(Path.Combine(directory, "index.html"), html.ToString(), Encoding.UTF8);
        Console.WriteLine($"WPF preview report: {images.Count} images, {failures.Count} rendering/binding errors; {directory}");
        if (failures.Count != 0) throw new InvalidOperationException("WPF preview rendering or binding failed; inspect report.json");
    }
    private static string Encode(string value) => WebUtility.HtmlEncode(value);
    private static TabControl FindTabs(DependencyObject root)
    {
        if (root is TabControl tabs) return tabs;
        foreach (object child in LogicalTreeHelper.GetChildren(root))
            if (child is DependencyObject node && TryFindTabs(node) is { } found) return found;
        throw new InvalidOperationException("MainWindow TabControl not found");
    }
    private static TabControl? TryFindTabs(DependencyObject root)
    {
        if (root is TabControl tabs) return tabs;
        foreach (object child in LogicalTreeHelper.GetChildren(root))
            if (child is DependencyObject node && TryFindTabs(node) is { } found) return found;
        return null;
    }
}
