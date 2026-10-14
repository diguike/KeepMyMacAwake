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
    private EventWaitHandle? updateRequest;
    private RegisteredWaitHandle? updateWait;
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
        if (e.Args.Contains("--prepare-update", StringComparer.OrdinalIgnoreCase))
        {
            int result = 0;
            if (!first)
            {
                try
                {
                    ownsMutex = InstallationLifecycle.RequestExit(instance, @"Local\KeepMyMacAwake.Windows.Update." + user, TimeSpan.FromSeconds(20));
                    if (!ownsMutex) result = 2;
                }
                catch (Exception error) when (error is WaitHandleCannotBeOpenedException or UnauthorizedAccessException)
                { result = 2; }
            }
            IsExiting = true; Shutdown(result); return;
        }
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
            updateRequest = new EventWaitHandle(false, EventResetMode.AutoReset, @"Local\KeepMyMacAwake.Windows.Update." + user);
            updateWait = ThreadPool.RegisterWaitForSingleObject(updateRequest,
                (_, _) => Dispatcher.BeginInvoke(RequestExit), null, Timeout.Infinite, false);
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
            MessageBox.Show("睡眠阻止尚未取消，请点击恢复后再退出。", "KeepMyMacAwake", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }
        IsExiting = true; Shutdown();
    }

    internal void ShowCloseHint() => tray?.ShowCloseHint();

    private void ThemeChanged(object sender, UserPreferenceChangedEventArgs e)
    {
        if (!Dispatcher.HasShutdownStarted && !Dispatcher.HasShutdownFinished) Dispatcher.BeginInvoke(ApplyTheme);
    }
    private void ApplyTheme()
    {
        using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
        bool dark = key?.GetValue("AppsUseLightTheme") is int value && value == 0;
        AppTheme.Apply(Resources, dark, SystemParameters.HighContrast);
    }

    protected override void OnExit(ExitEventArgs e)
    {
        SystemEvents.UserPreferenceChanged -= ThemeChanged;
        activationWait?.Unregister(null);
        updateWait?.Unregister(null);
        updateRequest?.Dispose();
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
