using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Globalization;
using System.Linq;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
using Awake.Core;
using Awake.Platform;
using Microsoft.Win32;

namespace Awake.App;

public sealed record Choice<T>(string Label, T Value);

public sealed class MainViewModel : INotifyPropertyChanged, IDisposable
{
    private readonly IPowerBackend backend;
    private readonly Func<PowerSample> readSample;
    private readonly Func<ClockSample> readClock;
    private readonly bool observeSystem;
    private readonly SessionController session;
    private readonly PreferencesStore store;
    private readonly NightDimmer dimmer = new();
    private readonly DispatcherTimer timer;
    private readonly Dictionary<string, object?> published = new();
    private Preferences preferences;
    private PowerSample sample = new(null, null, null, ThermalLevel.Unknown);
    private bool onboarded;
    private bool locked;
    private bool loginEnabled;
    private bool disposed;
    private string message = "未开启";
    private string customMinutesText;
    private string minimumBatteryText;
    private double totalSeconds;
    private DateTimeOffset? startedAt;
    private DateTimeOffset? endsAt;
    private string? lastResult;

    public event PropertyChangedEventHandler? PropertyChanged;
    public IReadOnlyList<Choice<int>> Durations { get; } = [new("30 分钟", 30), new("1 小时", 60), new("2 小时", 120), new("8 小时", 480), new("直到手动停止", -1), new("自定义…", 0)];
    public IReadOnlyList<Choice<ScreenMode>> Screens { get; } = [new("自动熄屏", ScreenMode.Automatic), new("保持常亮", ScreenMode.AlwaysOn), new("夜间柔光", ScreenMode.NightDim)];
    public ICommand ToggleCommand { get; }
    public ICommand ExtendCommand { get; }
    public ICommand RecoverCommand { get; }
    public ICommand OnboardCommand { get; }
    public ICommand DailyCommand { get; }
    public ICommand NightCommand { get; }
    public ICommand LidCommand { get; }
    public ICommand NetworkCommand { get; }

    public MainViewModel() : this(new WindowsPowerBackend(), new WindowsMonitor().Sample,
        new WindowsMonitor().Clock, new PreferencesStore(), true) { }
    internal MainViewModel(IPowerBackend powerBackend, Func<PowerSample> sampleReader,
        Func<ClockSample> clockReader, PreferencesStore preferenceStore, bool observeSystem)
    {
        backend = powerBackend; readSample = sampleReader; readClock = clockReader;
        store = preferenceStore; this.observeSystem = observeSystem;
        (preferences, onboarded, string? notice) = store.Load();
        message = notice ?? "未开启";
        customMinutesText = preferences.CustomMinutes.ToString(CultureInfo.InvariantCulture);
        minimumBatteryText = preferences.MinimumBattery.ToString(CultureInfo.InvariantCulture);
        session = new SessionController(backend, WindowsMonitor.Capabilities);
        ToggleCommand = new RelayCommand(Toggle, () => HasOnboarded && !NeedsRecovery);
        ExtendCommand = new RelayCommand(Extend, () => session.CanExtend);
        RecoverCommand = new RelayCommand(() => TryStop(), () => NeedsRecovery);
        OnboardCommand = new RelayCommand(() => { onboarded = true; Save(); Raise(nameof(HasOnboarded)); Raise(nameof(ShowWelcome)); Refresh(); });
        DailyCommand = new RelayCommand(() => Choose(Scene.Daily), () => CanEdit);
        NightCommand = new RelayCommand(() => Choose(Scene.Night), () => CanEdit);
        LidCommand = new RelayCommand(() => Choose(Scene.PluggedLid), () => CanEdit);
        NetworkCommand = new RelayCommand(() => Choose(Scene.Network), () => CanEdit);
        if (observeSystem)
        {
            try { loginEnabled = LoginStartup.IsEnabled; } catch (Exception error) { message = "无法读取登录启动：" + error.Message; }
            SystemEvents.PowerModeChanged += PowerChanged;
            SystemEvents.SessionSwitch += SessionChanged;
            Application.Current.SessionEnding += SessionEnding;
        }
        dimmer.StopRequested += (_, error) =>
        {
            TryStop("柔光更新失败"); message = "屏幕变化后柔光更新失败：" + error.Message;
            if (NeedsRecovery) message += "；待恢复：" + session.Error;
            Refresh();
        };
        timer = new DispatcherTimer(DispatcherPriority.Background) { Interval = TimeSpan.FromSeconds(1) };
        timer.Tick += (_, _) => Tick(); if (observeSystem) timer.Start(); Tick();
    }

    public bool HasOnboarded => onboarded;
    public bool ShowWelcome => !onboarded;
    public bool IsActive => session.IsActive;
    public bool NeedsRecovery => session.NeedsRecovery;
    public bool CanEdit => !IsActive && !NeedsRecovery;
    public bool IsFiniteActive => IsActive && session.RemainingSeconds is not null;
    public string PhaseText => NeedsRecovery ? "待恢复" : IsActive ? "运行中" : "待机";
    public string ActionText => IsActive ? "停止保活" : "开始保活";
    public string Message => message;
    public string RemainingText => IsActive ? session.RemainingSeconds is null ? "直到手动停止" : FormatRemaining(session.RemainingSeconds.Value)
        : NeedsRecovery ? "等待恢复" : preferences.LidMode ? "合盖尚未开放" : !preferences.RequireAC ? "电池尚未开放" : sample.OnAC != true ? "请接通电源" : "尚未开启";
    public string SceneStatusText
    {
        get
        {
            var preset = Preferences.ForScene(preferences.Scene);
            bool custom = DurationMinutes != preset.DurationMinutes || ScreenMode != preset.ScreenMode || LidMode != preset.LidMode || RequireAC != preset.RequireAC || RequireNetwork != preset.RequireNetwork;
            return SceneName(preferences.Scene) + (custom ? " · 已自定义" : "") + (IsActive ? " · 保持运行中" : "");
        }
    }
    // Same order as the Mac summary: duration · lid · power · network · screen.
    public string ConfigurationText => (DurationMinutes == -1 ? "直到手动停止" : DurationMinutes > 0 ? SessionText.Duration(DurationMinutes * 60)
            : int.TryParse(customMinutesText, out int custom) && custom is >= 1 and <= 1440 ? SessionText.Duration(custom * 60) : customMinutesText + " 分钟")
        + " · " + (LidMode ? "请求合盖" : "开盖") + " · " + (RequireAC ? "仅接电" : "允许电池") + (RequireNetwork ? " · 断网停止" : "")
        + " · " + Screens.First(choice => choice.Value == ScreenMode).Label;
    public string EndText => IsActive && endsAt is { } end ? SessionText.EndTime(end.LocalDateTime, readClock().Wall.LocalDateTime) : "";
    public string LastResultText => lastResult ?? "";
    public bool ShowLastResult => !IsActive && !NeedsRecovery && lastResult is not null;
    public bool IsDailyScene => preferences.Scene == Scene.Daily;
    public bool IsNightScene => preferences.Scene == Scene.Night;
    public bool IsLidScene => preferences.Scene == Scene.PluggedLid;
    public bool IsNetworkScene => preferences.Scene == Scene.Network;
    public double Progress => IsActive ? totalSeconds == 0 ? 1 : Math.Clamp((session.RemainingSeconds ?? 0) / totalSeconds, 0, 1) : 0;
    public string TelemetryText => (sample.OnAC is null ? "电源未知" : sample.OnAC.Value ? "已接电" : "电池供电") + " · " + (sample.BatteryPercent is null ? "电量未知 / 无电池" : sample.BatteryPercent + "%") + "    " + (sample.NetworkAvailable is null ? "网络未知" : sample.NetworkAvailable.Value ? "网络路径可用" : "无网络路径");
    public string CapabilityText => preferences.LidMode ? "合盖尚未开放：系统设置恢复与机型验证待完成。请保持开盖，或选择日常 / 夜间。" : !preferences.RequireAC ? "电池保活尚未开放：Modern Standby 行为待验证。请选中“仅接通电源时保活”。" : "当前支持：接电、开盖保活。自动熄屏仍按系统设置执行。";
    public string TrayText => IsActive ? "KeepMyMacAwake · " + (ShowCountdown ? RemainingText : "运行中") : "KeepMyMacAwake · " + PhaseText;
    public int DurationMinutes { get => preferences.DurationMinutes; set { if (!CanEdit || value == preferences.DurationMinutes) return; Update(preferences with { DurationMinutes = value }); Raise(nameof(DurationMinutes)); Raise(nameof(IsCustomDuration)); } }
    public bool IsCustomDuration => DurationMinutes == 0;
    public string CustomMinutesText
    {
        get => customMinutesText;
        set { if (!CanEdit) return; customMinutesText = value; if (int.TryParse(value, out int minutes) && minutes is >= 1 and <= 1440) Update(preferences with { CustomMinutes = minutes }); Raise(nameof(CustomMinutesText)); }
    }
    public string MinimumBatteryText
    {
        get => minimumBatteryText;
        set { if (!CanEdit) return; minimumBatteryText = value; if (int.TryParse(value, out int percent) && percent is >= 10 and <= 80) Update(preferences with { MinimumBattery = percent }); Raise(nameof(MinimumBatteryText)); }
    }
    public ScreenMode ScreenMode { get => preferences.ScreenMode; set { if (!CanEdit || value == preferences.ScreenMode) return; Update(preferences with { ScreenMode = value }); Raise(nameof(ScreenMode)); Raise(nameof(IsNightDim)); } }
    public bool IsNightDim => ScreenMode == ScreenMode.NightDim;
    public double DimAmount { get => preferences.DimAmount; set { if (!CanEdit || value == preferences.DimAmount) return; Update(preferences with { DimAmount = value }); Raise(nameof(DimAmount)); Raise(nameof(DimText)); } }
    public string DimText => "画面变暗 " + Math.Round(DimAmount * 100) + "%";
    public bool LidMode { get => preferences.LidMode; set { if (!CanEdit || value == preferences.LidMode) return; Update(preferences with { LidMode = value }); Raise(nameof(LidMode)); } }
    public bool RequireAC { get => preferences.RequireAC; set { if (!CanEdit || value == preferences.RequireAC) return; Update(preferences with { RequireAC = value }); Raise(nameof(RequireAC)); } }
    public bool RequireNetwork { get => preferences.RequireNetwork; set { if (!CanEdit || value == preferences.RequireNetwork) return; Update(preferences with { RequireNetwork = value }); Raise(nameof(RequireNetwork)); } }
    public bool ShowCountdown { get => preferences.ShowCountdown; set { if (value == preferences.ShowCountdown) return; Update(preferences with { ShowCountdown = value }); Raise(nameof(ShowCountdown)); } }
    public bool LoginEnabled
    {
        get => loginEnabled;
        set
        {
            if (value == loginEnabled) return;
            try { LoginStartup.Set(value); loginEnabled = value; message = value ? "登录时启动，保持待机" : "已关闭登录启动"; }
            catch (Exception error) { message = "登录启动设置失败：" + error.Message; }
            Raise(nameof(LoginEnabled)); Refresh();
        }
    }

    private void Choose(Scene scene)
    {
        if (!CanEdit) return;
        var next = Preferences.ForScene(scene) with { CustomMinutes = preferences.CustomMinutes, MinimumBattery = preferences.MinimumBattery, DimAmount = preferences.DimAmount, ShowCountdown = preferences.ShowCountdown };
        preferences = next;
        customMinutesText = next.CustomMinutes.ToString(CultureInfo.InvariantCulture);
        minimumBatteryText = next.MinimumBattery.ToString(CultureInfo.InvariantCulture);
        message = next.LidMode ? "此场景请求合盖保活，当前预览尚未开放。" : "未开启";
        foreach (string name in new[] { nameof(DurationMinutes), nameof(CustomMinutesText), nameof(MinimumBatteryText), nameof(IsCustomDuration), nameof(ScreenMode), nameof(IsNightDim), nameof(DimAmount), nameof(DimText), nameof(LidMode), nameof(RequireAC), nameof(RequireNetwork) }) Raise(name);
        Save(); Refresh();
    }

    private void Toggle()
    {
        if (IsActive || NeedsRecovery) { TryStop(); return; }
        try
        {
            if (DurationMinutes == 0 && (!int.TryParse(customMinutesText, out int minutes) || minutes is < 1 or > 1440)) throw new ArgumentException("自定义时间需在 1–1440 分钟范围内");
            if (!int.TryParse(minimumBatteryText, out int battery) || battery is < 10 or > 80) throw new ArgumentException("电量下限需在 10–80% 范围内");
            if (!RequireAC) throw new InvalidOperationException("此预览仅开放接电保活，请选中“仅接通电源时保活”");
            sample = readSample();
            int duration = DurationMinutes == -1 ? 0 : DurationMinutes == 0 ? preferences.CustomMinutes : DurationMinutes;
            var options = new SessionOptions(duration, RequireAC, RequireNetwork, battery, ScreenMode, LidMode, DimAmount);
            var now = readClock();
            session.Start(options, sample, now);
            totalSeconds = duration * 60;
            try { if (IsNightDim && !locked) dimmer.Start(DimAmount); }
            catch (Exception dimError)
            {
                try { session.Stop(); }
                catch (Exception stopError) { throw new AggregateException("柔光启动失败，保活释放也失败", dimError, stopError); }
                throw new InvalidOperationException("柔光启动失败：" + dimError.Message, dimError);
            }
            startedAt = now.Wall; endsAt = duration == 0 ? null : now.Wall.AddMinutes(duration);
            message = "保持运行中 · 请保持开盖；不改变锁屏策略。";
        }
        catch (Exception error)
        {
            message = Enum.TryParse<StopReason>(error.Message, out var reason) ? Explain(reason) : error.Message;
            if (NeedsRecovery && session.Error is not null) message += "；待恢复：" + session.Error;
        }
        Refresh();
    }

    private void Extend()
    {
        try { session.Extend(readSample(), readClock()); totalSeconds += 900; endsAt = endsAt?.AddSeconds(900); message = "已延长 15 分钟"; }
        catch (Exception error) { message = !IsActive && session.LastStopReason is { } reason ? Explain(reason) : error.Message; if (NeedsRecovery) message += "；待恢复：" + session.Error; }
        if (!IsActive) { dimmer.Stop(); RecordEnd(Explain(session.LastStopReason ?? StopReason.Manual)); }
        Refresh();
    }

    public bool TryStop(string reason = "已手动停止")
    {
        if (IsActive) RecordEnd(reason);
        Exception? dimError = null;
        try { dimmer.Stop(); } catch (Exception error) { dimError = error; }
        try
        {
            session.Stop();
            message = dimError is null ? "已停止保活，恢复正常电源行为" : "保活已释放，柔光撤销失败：" + dimError.Message;
            Refresh(); return dimError is null;
        }
        catch (Exception error) { message = "保活释放失败：" + error.Message; Refresh(); return false; }
    }

    private void Tick()
    {
        if (disposed) return;
        bool wasActive = IsActive;
        try { sample = readSample(); session.Tick(sample, readClock()); }
        catch (Exception error)
        {
            try { session.Stop(StopReason.TelemetryUnknown); } catch { }
            message = "监控失败，已结束会话：" + error.Message;
        }
        if (wasActive && !IsActive)
        {
            dimmer.Stop(); message = session.Error ?? Explain(session.LastStopReason ?? StopReason.Manual);
            RecordEnd(Explain(session.LastStopReason ?? StopReason.Manual));
        }
        Refresh();
    }

    internal void RefreshMonitor() => Tick();
    private void Dispatch(Action action)
    {
        var dispatcher = Application.Current.Dispatcher;
        if (!disposed && !dispatcher.HasShutdownStarted && !dispatcher.HasShutdownFinished) dispatcher.BeginInvoke(action);
    }
    private void PowerChanged(object sender, PowerModeChangedEventArgs e) => Dispatch(() =>
    {
        if (disposed) return;
        if (e.Mode is PowerModes.Suspend or PowerModes.Resume && IsActive)
        {
            dimmer.Stop(); RecordEnd("系统进入过休眠");
            try { session.Stop(StopReason.Disconnected); message = "系统进入过休眠，保活已结束；请手动重新开启"; }
            catch (Exception error) { message = error.Message; }
            Refresh();
        }
        else Tick();
    });

    private void SessionChanged(object sender, SessionSwitchEventArgs e) => Dispatch(() =>
    {
        if (disposed) return;
        if (e.Reason == SessionSwitchReason.SessionLock) { locked = true; dimmer.Stop(); }
        else if (e.Reason == SessionSwitchReason.SessionUnlock)
        {
            locked = false; Tick();
            if (IsActive && IsNightDim)
                try { dimmer.Start(DimAmount); } catch (Exception error) { TryStop("柔光恢复失败"); message = "柔光恢复失败：" + error.Message; Refresh(); }
        }
    });
    private void SessionEnding(object sender, SessionEndingCancelEventArgs e) => TryStop("系统注销或关机");
    private void RecordEnd(string reason)
    {
        if (startedAt is { } start) lastResult = SessionText.LastResult(start.LocalDateTime, readClock().Wall.LocalDateTime, reason);
        startedAt = null; endsAt = null;
    }

    private void Update(Preferences next)
    {
        if (!next.IsValid) return;
        preferences = next; Save(); Refresh();
    }
    private void Save()
    {
        try { store.Save(preferences, onboarded); }
        catch (Exception error) { message = "设置保存失败：" + error.Message; Refresh(); }
    }
    private void Raise(string name) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    private void Publish(string name, object? value)
    {
        if (published.TryGetValue(name, out var old) && Equals(old, value)) return;
        published[name] = value; Raise(name);
    }
    private void Refresh()
    {
        Publish(nameof(IsActive), IsActive); Publish(nameof(NeedsRecovery), NeedsRecovery); Publish(nameof(CanEdit), CanEdit);
        Publish(nameof(IsFiniteActive), IsFiniteActive); Publish(nameof(PhaseText), PhaseText); Publish(nameof(ActionText), ActionText);
        Publish(nameof(Message), Message); Publish(nameof(RemainingText), RemainingText); Publish(nameof(SceneStatusText), SceneStatusText); Publish(nameof(ConfigurationText), ConfigurationText);
        Publish(nameof(Progress), Progress); Publish(nameof(TelemetryText), TelemetryText); Publish(nameof(CapabilityText), CapabilityText); Publish(nameof(TrayText), TrayText);
        Publish(nameof(EndText), EndText); Publish(nameof(LastResultText), LastResultText); Publish(nameof(ShowLastResult), ShowLastResult);
        Publish(nameof(IsDailyScene), IsDailyScene); Publish(nameof(IsNightScene), IsNightScene); Publish(nameof(IsLidScene), IsLidScene); Publish(nameof(IsNetworkScene), IsNetworkScene);
        ((RelayCommand)ToggleCommand).Refresh(); ((RelayCommand)ExtendCommand).Refresh(); ((RelayCommand)RecoverCommand).Refresh();
        foreach (ICommand command in new[] { DailyCommand, NightCommand, LidCommand, NetworkCommand }) ((RelayCommand)command).Refresh();
    }
    private static string SceneName(Scene scene) => scene switch { Scene.Night => "夜间", Scene.PluggedLid => "接电合盖", Scene.Network => "有网时", _ => "日常" };
    private static string FormatRemaining(double seconds)
    {
        long value = (long)Math.Ceiling(seconds);
        return $"{value / 3600:00}:{value / 60 % 60:00}:{value % 60:00}";
    }
    private static string Explain(StopReason reason) => reason switch
    {
        StopReason.Manual => "已手动停止", StopReason.Expired => "设定时间已到", StopReason.PowerDisconnected => "已断开电源，请接电后重新开启",
        StopReason.LowBattery => "电量低于保护阈值", StopReason.NetworkDisconnected => "网络路径已断开，请联网后重新开启",
        StopReason.TelemetryUnknown => "无法取得所需保护数据", StopReason.ClockChanged => "系统时间发生明显变化",
        StopReason.ThermalCritical => "热状态达到临界状态", StopReason.ThermalSerious => "热状态持续严重",
        StopReason.Disconnected => "系统休眠或会话已断开", _ => "会话已结束：" + reason
    };
    public void Dispose()
    {
        if (disposed) return; disposed = true; timer.Stop();
        if (observeSystem)
        {
            SystemEvents.PowerModeChanged -= PowerChanged; SystemEvents.SessionSwitch -= SessionChanged;
            Application.Current.SessionEnding -= SessionEnding;
        }
        try { dimmer.Dispose(); } finally { (backend as IDisposable)?.Dispose(); }
    }
}

internal sealed class RelayCommand(Action execute, Func<bool>? canExecute = null) : ICommand
{
    private bool? lastEnabled;
    public event EventHandler? CanExecuteChanged;
    public bool CanExecute(object? parameter) => canExecute?.Invoke() ?? true;
    public void Execute(object? parameter) { if (CanExecute(parameter)) execute(); }
    public void Refresh()
    {
        bool enabled = CanExecute(null);
        if (lastEnabled == enabled) return;
        lastEnabled = enabled; CanExecuteChanged?.Invoke(this, EventArgs.Empty);
    }
}
