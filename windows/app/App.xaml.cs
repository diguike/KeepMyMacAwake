using System;
using System.Linq;
using System.Security.Principal;
using System.Threading;
using System.Windows;
using Microsoft.Win32;

namespace Awake.App;

public partial class App : Application
{
    private Mutex? instance;
    private EventWaitHandle? activation;
    private RegisteredWaitHandle? activationWait;
    private MainViewModel? model;
    private TrayController? tray;
    private bool ownsMutex;
    internal bool IsExiting { get; private set; }

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        using var identity = WindowsIdentity.GetCurrent();
        string user = identity.User!.Value;
        instance = new Mutex(true, @"Local\KeepMyMacAwake.Windows." + user, out bool first);
        ownsMutex = first;
        activation = new EventWaitHandle(false, EventResetMode.AutoReset, @"Local\KeepMyMacAwake.Windows.Show." + user);
        if (!first) { activation.Set(); IsExiting = true; Shutdown(); return; }
        try
        {
            ApplyTheme();
            SystemEvents.UserPreferenceChanged += ThemeChanged;
            model = new MainViewModel();
            var window = new MainWindow(model);
            MainWindow = window;
            tray = new TrayController(model, () => window.Reveal(), RequestExit);
            activationWait = ThreadPool.RegisterWaitForSingleObject(activation,
                (_, _) => Dispatcher.BeginInvoke(() => window.Reveal()), null, Timeout.Infinite, false);
            if (!e.Args.Contains("--startup", StringComparer.OrdinalIgnoreCase) || !model.HasOnboarded) window.Show();
        }
        catch (Exception error)
        {
            MessageBox.Show("无法启动：" + error.Message, "KeepMyMacAwake", MessageBoxButton.OK, MessageBoxImage.Error);
            IsExiting = true; Shutdown(1);
        }
    }

    public void RequestExit()
    {
        if (model is not null && !model.TryStop())
        {
            MainWindow?.Show();
            MessageBox.Show("保活尚未释放，请点击恢复后再退出。", "KeepMyMacAwake", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }
        IsExiting = true; Shutdown();
    }

    private void ThemeChanged(object sender, UserPreferenceChangedEventArgs e)
    {
        if (!Dispatcher.HasShutdownStarted && !Dispatcher.HasShutdownFinished) Dispatcher.BeginInvoke(ApplyTheme);
    }
    private void ApplyTheme()
    {
        using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
        bool dark = key?.GetValue("AppsUseLightTheme") is int value && value == 0;
        string[] names = ["PageBrush", "CardBrush", "TextBrush", "MutedBrush", "LineBrush", "AccentBrush", "AccentTextBrush", "AccentSoftBrush"];
        string[] colors = dark
            ? ["#211F1D", "#302C28", "#F0EBE4", "#B6AEA4", "#51483F", "#DD9865", "#211F1D", "#4A3424"]
            : ["#FBF9F6", "#F0EBE4", "#292621", "#716A62", "#DAD3C9", "#B55E2C", "#FFFFFF", "#F5E3D5"];
        for (int i = 0; i < names.Length; i++)
            Resources[names[i]] = new System.Windows.Media.SolidColorBrush((System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString(colors[i]));
        if (SystemParameters.HighContrast)
        {
            Resources["PageBrush"] = SystemColors.WindowBrush; Resources["CardBrush"] = SystemColors.ControlBrush;
            Resources["TextBrush"] = SystemColors.WindowTextBrush; Resources["MutedBrush"] = SystemColors.WindowTextBrush;
            Resources["LineBrush"] = SystemColors.WindowTextBrush; Resources["AccentBrush"] = SystemColors.HighlightBrush;
            Resources["AccentTextBrush"] = SystemColors.HighlightTextBrush; Resources["AccentSoftBrush"] = SystemColors.WindowBrush;
        }
    }

    protected override void OnExit(ExitEventArgs e)
    {
        SystemEvents.UserPreferenceChanged -= ThemeChanged;
        activationWait?.Unregister(null);
        try { tray?.Dispose(); }
        finally
        {
            try { model?.Dispose(); }
            finally
            {
                activation?.Dispose();
                try { if (ownsMutex) instance?.ReleaseMutex(); }
                finally { instance?.Dispose(); base.OnExit(e); }
            }
        }
    }
}
