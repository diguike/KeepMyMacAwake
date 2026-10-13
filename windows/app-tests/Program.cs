using Awake.Core;
using System.IO;

namespace Awake.App.Tests;

/// Windows-only STA integration checks. Real WPF and view model; injected power
/// and clocks. No native power requests, system-service installation, or startup
/// registry writes. These checks do not establish physical lid compatibility.
internal static class Program
{
    [STAThread]
    private static int Main()
    {
        if (!OperatingSystem.IsWindows()) throw new PlatformNotSupportedException("WPF integration checks require Windows");
        var application = new global::Awake.App.App();
        application.InitializeComponent();
        var tests = new (string Name, Action Run)[]
        {
            ("first authorization updates command availability", FirstAuthorization),
            ("network scene preserves its unsupported policy", NetworkScene),
            ("24-hour countdown retains total hours and expires", TwentyFourHours),
            ("new unsupported start does not reuse expiry reason", NewUnsupportedStart),
            ("invalid custom input does not reuse expiry reason", InvalidCustomAfterExpiry),
            ("partial backend failure does not mask next validation", PartialStartFailure),
            ("release failure blocks restart until explicit recovery", RecoveryFlow),
            ("unchanged idle monitoring publishes no updates", IdleNotifications),
            ("scene parameter edits are visibly customized", CustomizedScene),
            ("ended session keeps end time and last result visible", LastResultSurvivesSceneChange),
            ("completed result persists without replaying notification or session", PersistedResult),
            ("notifications are opt in and first-close hint persists", NotificationAndTrayHint),
            ("installer waits for exit and refuses an unconfirmed shutdown", InstallerHandoff),
            ("MainWindow XAML loads with real resources and bindings", WindowLoads)
        };
        int failed = 0;
        foreach (var (name, run) in tests)
        {
            try { run(); Console.WriteLine("PASS " + name); }
            catch (Exception error) { failed++; Console.Error.WriteLine("FAIL " + name + "\n" + error); }
        }
        Console.WriteLine($"WPF integration checks: {tests.Length - failed} passed, {failed} failed");
        application.Shutdown();
        return failed == 0 ? 0 : 1;
    }

    private sealed class Backend : IPowerBackend, IDisposable
    {
        public bool Active, FailStart, FailStop;
        public int Starts;
        public void Start(bool keepDisplay) { Starts++; Active = true; if (FailStart) throw new InvalidOperationException("injected partial acquisition failure"); }
        public void Stop() { if (FailStop) throw new InvalidOperationException("injected release failure"); Active = false; }
        public void Dispose() => Stop();
    }
    private sealed class Fixture : IDisposable
    {
        private readonly string directory = Path.Combine(Path.GetTempPath(), "keepmymacawake-app-tests-" + Guid.NewGuid().ToString("N"));
        public Backend Power { get; } = new();
        public double Seconds;
        public PowerSample Sample = new(true, 95, true, ThermalLevel.Unknown);
        public MainViewModel Model { get; }
        public PreferencesStore Store { get; }
        public Fixture(bool onboarded = true)
        {
            var store = Store = new PreferencesStore(directory);
            store.Save(new Preferences(), onboarded);
            Model = new MainViewModel(Power, () => Sample,
                () => new ClockSample(DateTimeOffset.UnixEpoch.AddSeconds(Seconds), Seconds), store, observeSystem: false);
        }
        public void ExpireOneMinute()
        {
            Model.DurationMinutes = 1; Model.ToggleCommand.Execute(null);
            Check(Model.IsActive && Power.Active, "ordinary preview did not acquire injected backend");
            Seconds = 60; Model.RefreshMonitor();
            Check(!Model.IsActive && !Power.Active, "expiry did not release backend");
            Check(Model.Message.Contains("设定时间已到", StringComparison.Ordinal), Model.Message);
        }
        public void Dispose()
        {
            Power.FailStop = false;
            Model.TryStop(); Model.Dispose();
            if (Directory.Exists(directory)) Directory.Delete(directory, true);
        }
    }
    private static void Check(bool condition, string detail)
    { if (!condition) throw new InvalidOperationException(detail); }

    private static void FirstAuthorization()
    {
        using var f = new Fixture(false); int changes = 0;
        f.Model.ToggleCommand.CanExecuteChanged += (_, _) => changes++;
        Check(!f.Model.ToggleCommand.CanExecute(null), "start enabled before welcome acceptance");
        f.Model.OnboardCommand.Execute(null);
        Check(f.Model.HasOnboarded && !f.Model.ShowWelcome && f.Model.ToggleCommand.CanExecute(null), "welcome acceptance did not enable start");
        Check(changes > 0, "command binding was not notified");
        Check(!f.Model.IsActive, "welcome acceptance started a session");
    }
    private static void NetworkScene()
    {
        using var f = new Fixture(); f.Model.NetworkCommand.Execute(null);
        Check(f.Model.LidMode && !f.Model.RequireAC && f.Model.RequireNetwork, "network scene silently degraded");
        f.Model.ToggleCommand.Execute(null);
        Check(!f.Model.IsActive && f.Power.Starts == 0, "unsupported network scene acquired backend");
        Check(f.Model.Message.Contains("接电", StringComparison.Ordinal) || f.Model.Message.Contains("合盖", StringComparison.Ordinal), f.Model.Message);
        f.Model.LidMode = false; f.Model.RequireAC = true;
        f.Model.ToggleCommand.Execute(null);
        Check(f.Model.IsActive, "explicitly customized ordinary network policy cannot start");
        f.Sample = f.Sample with { NetworkAvailable = false }; f.Seconds = 1; f.Model.RefreshMonitor();
        Check(!f.Model.IsActive, "network policy did not stop");
        f.Sample = f.Sample with { NetworkAvailable = true }; f.Seconds = 2; f.Model.RefreshMonitor();
        Check(!f.Model.IsActive, "network restoration restarted session");
    }
    private static void TwentyFourHours()
    {
        using var f = new Fixture(); f.Model.DurationMinutes = 1440; f.Model.ToggleCommand.Execute(null);
        Check(f.Model.RemainingText == "24:00:00", f.Model.RemainingText);
        f.Seconds = 86400; f.Model.RefreshMonitor();
        Check(!f.Model.IsActive && !f.Power.Active && !f.Model.ExtendCommand.CanExecute(null), "24-hour expiry left active state");
    }
    private static void NewUnsupportedStart()
    {
        using var f = new Fixture(); f.ExpireOneMinute(); f.Model.LidCommand.Execute(null); f.Model.ToggleCommand.Execute(null);
        Check(!f.Model.IsActive && f.Model.Message.Contains("合盖", StringComparison.Ordinal), f.Model.Message);
        Check(!f.Model.Message.Contains("设定时间已到", StringComparison.Ordinal), "old expiry replaced unsupported error");
    }
    private static void InvalidCustomAfterExpiry()
    {
        using var f = new Fixture(); f.ExpireOneMinute(); f.Model.DurationMinutes = 0; f.Model.CustomMinutesText = "invalid"; f.Model.ToggleCommand.Execute(null);
        Check(f.Model.Message.Contains("自定义时间", StringComparison.Ordinal), f.Model.Message);
        Check(!f.Model.IsActive && f.Power.Starts == 1, "invalid input acquired another backend");
    }
    private static void PartialStartFailure()
    {
        using var f = new Fixture(); f.Power.FailStart = true; f.Model.ToggleCommand.Execute(null);
        Check(!f.Model.IsActive && !f.Power.Active && !f.Model.NeedsRecovery, "partial start rollback failed");
        Check(f.Model.Message.Contains("injected partial", StringComparison.Ordinal), f.Model.Message);
        f.Model.DurationMinutes = 0; f.Model.CustomMinutesText = "invalid"; f.Model.ToggleCommand.Execute(null);
        Check(f.Model.Message.Contains("自定义时间", StringComparison.Ordinal), "old start error masked current input: " + f.Model.Message);
    }
    private static void RecoveryFlow()
    {
        using var f = new Fixture(); f.Model.DurationMinutes = 1; f.Model.ToggleCommand.Execute(null);
        f.Power.FailStop = true; f.Seconds = 60; f.Model.RefreshMonitor();
        Check(!f.Model.IsActive && f.Model.NeedsRecovery && !f.Model.ToggleCommand.CanExecute(null), "failed release did not block restart");
        Check(f.Model.RecoverCommand.CanExecute(null) && f.Model.Message.Contains("injected release", StringComparison.Ordinal), f.Model.Message);
        f.Power.FailStop = false; f.Model.RecoverCommand.Execute(null);
        Check(!f.Model.NeedsRecovery && !f.Power.Active && !f.Model.IsActive, "explicit recovery did not release backend");
        Check(f.Model.ToggleCommand.CanExecute(null), "recovery did not restore start command availability");
    }
    private static void IdleNotifications()
    {
        using var f = new Fixture(); int changes = 0; f.Model.PropertyChanged += (_, _) => changes++;
        for (int second = 1; second <= 300; second++) { f.Seconds = second; f.Model.RefreshMonitor(); }
        Check(changes == 0, $"unchanged idle sample raised {changes} notifications");
    }
    private static void CustomizedScene()
    {
        using var f = new Fixture(); f.Model.DailyCommand.Execute(null); f.Model.DurationMinutes = 120;
        Check(f.Model.SceneStatusText.Contains("自定义", StringComparison.Ordinal), f.Model.SceneStatusText);
    }
    private static void LastResultSurvivesSceneChange()
    {
        using var f = new Fixture(); f.Model.DurationMinutes = 1; f.Model.ToggleCommand.Execute(null);
        Check(f.Model.EndText.StartsWith("预计", StringComparison.Ordinal) && !f.Model.ShowLastResult, f.Model.EndText);
        f.Seconds = 60; f.Model.RefreshMonitor();
        f.Model.NightCommand.Execute(null);
        Check(f.Model.IsNightScene && !f.Model.IsDailyScene, "scene selection flags did not follow the chosen scene");
        Check(f.Model.ShowLastResult && f.Model.EndText.Length == 0, "last result hidden or stale end time shown after expiry");
        Check(f.Model.LastResultText.Contains("运行 1 分钟", StringComparison.Ordinal) && f.Model.LastResultText.Contains("设定时间已到", StringComparison.Ordinal), f.Model.LastResultText);
    }
    private static void WindowLoads()
    {
        using var f = new Fixture(); var window = new MainWindow(f.Model);
        Check(ReferenceEquals(window.DataContext, f.Model), "XAML window lost view model");
        Check(window.Content is not null, "XAML content was not loaded");
        Check(!window.IsVisible, "construction unexpectedly showed window");
        // Application.Shutdown closes it after all checks; no UI interaction claimed.
    }
    private static void PersistedResult()
    {
        using var f = new Fixture(); f.Model.NotifyOnEnd = true;
        int notices = 0; f.Model.SessionEnded += _ => notices++;
        f.ExpireOneMinute(); f.Model.RefreshMonitor();
        Check(notices == 1, "completion notification duplicated");
        using var next = new MainViewModel(new Backend(), () => f.Sample,
            () => new ClockSample(DateTimeOffset.UnixEpoch.AddSeconds(60), 60), f.Store, false);
        Check(next.LastResultText == f.Model.LastResultText && next.ShowLastResult, "result lost on restart");
        Check(!next.IsActive && next.NotifyOnEnd && notices == 1, "restart resumed or replayed notification");
    }
    private static void NotificationAndTrayHint()
    {
        using var f = new Fixture(); int notices = 0; f.Model.SessionEnded += _ => notices++;
        f.ExpireOneMinute(); Check(notices == 0, "default settings sent notification");
        Check(f.Model.ConsumeTrayHint() && !f.Model.ConsumeTrayHint(), "first-close hint not one-time");
        f.Model.NotifyOnEnd = true; f.Model.NetworkCommand.Execute(null);
        Check(f.Model.NotifyOnEnd && f.Model.SceneStatusText.Contains("外出合盖", StringComparison.Ordinal), "scene lost notification preference or display name");
        using var next = new MainViewModel(new Backend(), () => f.Sample,
            () => new ClockSample(DateTimeOffset.UnixEpoch, 0), f.Store, false);
        Check(!next.ConsumeTrayHint(), "close hint repeated after restart");
    }
    private static void InstallerHandoff()
    {
        foreach (bool release in new[] { true, false })
        {
            string id = @"Local\keepmymacawake-tests-" + Guid.NewGuid().ToString("N");
            using var request = new EventWaitHandle(false, EventResetMode.AutoReset, id + ".exit");
            using var ready = new ManualResetEventSlim();
            using var finish = new ManualResetEventSlim();
            var owner = new Thread(() =>
            {
                using var held = new Mutex(true, id); ready.Set();
                request.WaitOne(); if (!release) finish.Wait(); held.ReleaseMutex();
            });
            owner.Start(); ready.Wait();
            using var client = new Mutex(false, id);
            bool confirmed = InstallationLifecycle.RequestExit(client, id + ".exit", TimeSpan.FromMilliseconds(250));
            if (confirmed) client.ReleaseMutex();
            finish.Set(); owner.Join();
            Check(confirmed == release, "installer accepted unconfirmed exit or refused released owner");
        }
    }
}
