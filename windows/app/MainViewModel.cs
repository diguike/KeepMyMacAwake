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
    private string message = "";
    private string customMinutesText;
    private string minimumBatteryText;
    private double totalSeconds;
    private DateTimeOffset? startedAt;
    private DateTimeOffset? endsAt;
    private SessionResult? lastResult;
    private double startedContinuous;
    private string? historyNotice;

    public event PropertyChangedEventHandler? PropertyChanged;
    public event Action<SessionResult>? SessionEnded;
    public IReadOnlyList<Choice<int>> Durations { get; } = [new("30 分钟", 30), new("1 小时", 60), new("2 小时", 120), new("8 小时", 480), new("不限时", -1), new("自定义…", 0)];
    public IReadOnlyList<Choice<ScreenMode>> Screens { get; } = [new("自动关闭", ScreenMode.Automatic), new("常亮", ScreenMode.AlwaysOn), new("调暗", ScreenMode.NightDim)];
    public ICommand ToggleCommand { get; }
    public ICommand ExtendCommand { get; }
    public ICommand RecoverCommand { get; }
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
        message = notice ?? "";
        var (result, resultNotice) = store.LoadResult();
        lastResult = result;
        historyNotice = resultNotice;
        customMinutesText = preferences.CustomMinutes.ToString(CultureInfo.InvariantCulture);
        minimumBatteryText = preferences.MinimumBattery.ToString(CultureInfo.InvariantCulture);
        session = new SessionController(backend, WindowsMonitor.Capabilities);
        ToggleCommand = new RelayCommand(Toggle, () => !NeedsRecovery);
        ExtendCommand = new RelayCommand(Extend, () => session.CanExtend);
        RecoverCommand = new RelayCommand(() => TryStop(), () => NeedsRecovery);
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
            TryStop("调暗遮罩更新失败"); message = "屏幕变化后调暗遮罩更新失败：" + error.Message;
            if (NeedsRecovery) message += "；待恢复：" + session.Error;
            Refresh();
        };
        timer = new DispatcherTimer(DispatcherPriority.Background) { Interval = TimeSpan.FromSeconds(1) };
        timer.Tick += (_, _) => Tick(); if (observeSystem) timer.Start(); Tick();
    }

    public bool HasOnboarded => onboarded;
    public bool IsActive => session.IsActive;
    public bool NeedsRecovery => session.NeedsRecovery;
    public bool CanEdit => !IsActive && !NeedsRecovery;
    public bool IsFiniteActive => IsActive && session.RemainingSeconds is not null;
    public bool ShowConfiguration => !IsActive && !NeedsRecovery;
    public bool HasMessage => message.Length > 0;
    public bool IsBlocked => !IsActive && !NeedsRecovery && BlockedReason.Length > 0;
    public string BlockedReason => LidMode ? "合盖尚未开放" : !RequireAC ? "电池使用尚未开放"
        : sample.OnAC is null ? "电源状态未知" : sample.OnAC == false ? "请接通电源"
        : RequireNetwork && sample.NetworkAvailable is null ? "网络状态未知"
        : RequireNetwork && sample.NetworkAvailable == false ? "网络未连接" : "";
    public string PhaseText => NeedsRecovery ? "需要处理" : IsActive ? session.RemainingSeconds is null ? "已运行" : "剩余" : "未开启";
    public string ActionText => IsActive ? "停止" : "开始";
    public string Message => message;
    public string VersionText => "Windows 开发预览 · " + typeof(MainViewModel).Assembly.GetName().Version?.ToString(3);
    public string HistoryNotice => historyNotice ?? "";
    public string RemainingText => IsActive ? FormatRemaining(session.RemainingSeconds ?? Math.Max(0, readClock().Continuous - startedContinuous))
        : NeedsRecovery ? "睡眠设置未恢复" : IsBlocked ? BlockedReason : "未开启";
    public bool HasHeadlineNumbers => !NeedsRecovery && !IsBlocked && (IsActive || DurationMinutes != -1);
    public string HeadlineText => NeedsRecovery ? "睡眠设置未恢复" : IsBlocked ? BlockedReason : "不限时";
    public IReadOnlyList<SessionText.NumberPart> NumberParts => SessionText.Parts(IsActive
        ? session.RemainingSeconds ?? Math.Max(0, readClock().Continuous - startedContinuous)
        : (DurationMinutes == 0 ? preferences.CustomMinutes : Math.Max(0, DurationMinutes)) * 60, IsActive);
    public string HeroHint => IsActive ? "可以锁屏，请勿合盖" : IsBlocked || NeedsRecovery ? "" : RequireNetwork ? "需开盖，断网即停" : "需开盖，仅接电";
    public string SceneName => SessionText.SceneName(preferences.Scene);
    public bool IsCustomized
    {
        get
        {
            var preset = Preferences.ForScene(preferences.Scene);
            return DurationMinutes != preset.DurationMinutes || ScreenMode != preset.ScreenMode || LidMode != preset.LidMode || RequireAC != preset.RequireAC || RequireNetwork != preset.RequireNetwork;
        }
    }
    public string SceneStatusText => SceneName + (IsCustomized ? " · 已调整" : "");
    public string ScreenText => Screens.First(choice => choice.Value == ScreenMode).Label + (IsNightDim ? $" {Math.Round(DimAmount * 100)}%" : "");
    public string StartedText => startedAt is { } start ? SessionText.Clock(start.LocalDateTime) : "";
    public string PowerRuleText => RequireAC ? "仅接电" : $"可用电池，下限 {preferences.MinimumBattery}%";
    public string EndText => IsActive && endsAt is { } end ? SessionText.EndTime(end.LocalDateTime, readClock().Wall.LocalDateTime) : "";
    public string LastResultText => lastResult?.Text ?? "";
    public string LastResultSummary => lastResult is { } result ? "上次结束 " + SessionText.EndedAt(result.End.LocalDateTime, readClock().Wall.LocalDateTime) + " " + result.Reason : "";
    public bool ShowLastResult => !IsActive && !NeedsRecovery && lastResult is not null;
    public bool IsDailyScene => preferences.Scene == Scene.Daily;
    public bool IsNightScene => preferences.Scene == Scene.Night;
    public bool IsLidScene => preferences.Scene == Scene.PluggedLid;
    public bool IsNetworkScene => preferences.Scene == Scene.Network;
    public double Progress => IsActive ? totalSeconds == 0 ? 1 : Math.Clamp((session.RemainingSeconds ?? 0) / totalSeconds, 0, 1) : 0;
    public string PowerText => (sample.OnAC is null ? "电源未知" : sample.OnAC.Value ? "已接电" : "使用电池") + (sample.BatteryPercent is { } percent ? $" {percent}%" : " 电量未知");
    public string NetworkText => sample.NetworkAvailable is null ? "网络未知" : sample.NetworkAvailable.Value ? "网络已连接" : "网络未连接";
    public bool PowerWarning => sample.OnAC != true;
    public bool NetworkWarning => sample.NetworkAvailable is null || (RequireNetwork && sample.NetworkAvailable == false);
    public string TrayText => IsActive ? "KeepMyMacAwake · " + (ShowCountdown ? PhaseText + " " + RemainingText : "保持唤醒中") : "KeepMyMacAwake · " + PhaseText;
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
    public bool IsAutomaticScreen { get => ScreenMode == ScreenMode.Automatic; set { if (value) ScreenMode = ScreenMode.Automatic; } }
    public bool IsAlwaysOnScreen { get => ScreenMode == ScreenMode.AlwaysOn; set { if (value) ScreenMode = ScreenMode.AlwaysOn; } }
    public bool IsNightDim { get => ScreenMode == ScreenMode.NightDim; set { if (value) ScreenMode = ScreenMode.NightDim; } }
    public double DimAmount { get => preferences.DimAmount; set { if (!CanEdit || value == preferences.DimAmount) return; Update(preferences with { DimAmount = value }); Raise(nameof(DimAmount)); Raise(nameof(DimText)); } }
    public string DimText => "调暗 " + Math.Round(DimAmount * 100) + "%";
    public bool LidMode { get => preferences.LidMode; set { if (!CanEdit || value == preferences.LidMode) return; Update(preferences with { LidMode = value }); Raise(nameof(LidMode)); } }
    public bool RequireAC { get => preferences.RequireAC; set { if (!CanEdit || value == preferences.RequireAC) return; Update(preferences with { RequireAC = value }); Raise(nameof(RequireAC)); } }
    public bool RequireNetwork { get => preferences.RequireNetwork; set { if (!CanEdit || value == preferences.RequireNetwork) return; Update(preferences with { RequireNetwork = value }); Raise(nameof(RequireNetwork)); } }
    public bool ShowCountdown { get => preferences.ShowCountdown; set { if (value == preferences.ShowCountdown) return; Update(preferences with { ShowCountdown = value }); Raise(nameof(ShowCountdown)); } }
    public bool NotifyOnEnd { get => preferences.NotifyOnEnd; set { if (value == preferences.NotifyOnEnd) return; Update(preferences with { NotifyOnEnd = value }); Raise(nameof(NotifyOnEnd)); } }
    internal bool ConsumeTrayHint()
    {
        if (store.TrayHintShown) return false;
        try { store.RememberTrayHint(); }
        catch (Exception error) { message = "首次托盘提示记录失败：" + error.Message; Refresh(); }
        return true;
    }
    public bool LoginEnabled
    {
        get => loginEnabled;
        set
        {
            if (value == loginEnabled) return;
            try { LoginStartup.Set(value); loginEnabled = value; message = ""; }
            catch (Exception error) { message = "登录启动设置失败：" + error.Message; }
            Raise(nameof(LoginEnabled)); Refresh();
        }
    }

    private void Choose(Scene scene)
    {
        if (!CanEdit) return;
        var next = Preferences.ForScene(scene) with { CustomMinutes = preferences.CustomMinutes, MinimumBattery = preferences.MinimumBattery, DimAmount = preferences.DimAmount, ShowCountdown = preferences.ShowCountdown, NotifyOnEnd = preferences.NotifyOnEnd };
        preferences = next;
        customMinutesText = next.CustomMinutes.ToString(CultureInfo.InvariantCulture);
        minimumBatteryText = next.MinimumBattery.ToString(CultureInfo.InvariantCulture);
        message = "";
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
            if (!RequireAC) throw new InvalidOperationException("此预览仅支持接电使用，请勾选“仅在接通电源时运行”");
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
                catch (Exception stopError) { throw new AggregateException("调暗遮罩启动失败，睡眠阻止也未能取消", dimError, stopError); }
                throw new InvalidOperationException("调暗遮罩启动失败：" + dimError.Message, dimError);
            }
            startedAt = now.Wall; startedContinuous = now.Continuous;
            endsAt = duration == 0 ? null : now.Wall.AddMinutes(duration);
            message = "";
            if (!onboarded) { onboarded = true; Save(); Raise(nameof(HasOnboarded)); }
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
        try { session.Extend(readSample(), readClock()); totalSeconds += 900; endsAt = endsAt?.AddSeconds(900); message = ""; }
        catch (Exception error) { message = !IsActive && session.LastStopReason is { } reason ? Explain(reason) : error.Message; if (NeedsRecovery) message += "；待恢复：" + session.Error; }
        if (!IsActive) { dimmer.Stop(); RecordEnd(Explain(session.LastStopReason ?? StopReason.Manual)); }
        Refresh();
    }

    public bool TryStop(string reason = "手动停止")
    {
        bool wasActive = IsActive;
        Exception? dimError = null;
        try { dimmer.Stop(); } catch (Exception error) { dimError = error; }
        try
        {
            session.Stop();
            if (wasActive) RecordEnd(reason);
            message = dimError is null ? "" : "已取消睡眠阻止，但调暗遮罩撤销失败：" + dimError.Message;
            Refresh(); return dimError is null;
        }
        catch (Exception error) { if (wasActive) RecordEnd(reason + "；未能取消睡眠阻止，需要恢复"); message = "未能取消睡眠阻止：" + error.Message; Refresh(); return false; }
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
            dimmer.Stop(); message = session.Error ?? "";
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
            dimmer.Stop();
            try { session.Stop(StopReason.Disconnected); RecordEnd("系统进入过睡眠"); message = "系统进入过睡眠，保持唤醒已结束；请手动重新开始"; }
            catch (Exception error) { RecordEnd("系统进入过睡眠；未能取消睡眠阻止，需要恢复"); message = error.Message; }
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
                try { dimmer.Start(DimAmount); } catch (Exception error) { TryStop("调暗遮罩恢复失败"); message = "调暗遮罩恢复失败：" + error.Message; Refresh(); }
        }
    });
    private void SessionEnding(object sender, SessionEndingCancelEventArgs e) => TryStop("系统注销或关机");
    private void RecordEnd(string reason)
    {
        if (startedAt is { } start)
        {
            var end = readClock().Wall;
            var result = new SessionResult(start, end < start ? start : end, reason + (NeedsRecovery && !reason.Contains("需要恢复", StringComparison.Ordinal) ? "；未能取消睡眠阻止，需要恢复" : ""));
            lastResult = result;
            try { store.SaveResult(result); historyNotice = null; }
            catch (Exception error) { historyNotice = "上次结果保存失败：" + error.Message; }
            if (NotifyOnEnd) SessionEnded?.Invoke(result);
        }
        startedAt = null; endsAt = null;
    }

    private void Update(Preferences next)
    {
        if (!next.IsValid) return;
        preferences = next; message = ""; Save(); Refresh();
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
        Publish(nameof(Message), Message); Publish(nameof(RemainingText), RemainingText); Publish(nameof(SceneStatusText), SceneStatusText);
        Publish(nameof(Progress), Progress); Publish(nameof(TrayText), TrayText);
        Publish(nameof(EndText), EndText); Publish(nameof(LastResultText), LastResultText); Publish(nameof(ShowLastResult), ShowLastResult);
        Publish(nameof(HistoryNotice), HistoryNotice);
        Publish(nameof(ShowConfiguration), ShowConfiguration); Publish(nameof(HasMessage), HasMessage);
        Publish(nameof(IsBlocked), IsBlocked); Publish(nameof(HasHeadlineNumbers), HasHeadlineNumbers); Publish(nameof(HeadlineText), HeadlineText);
        Publish(nameof(NumberParts), string.Join("|", NumberParts.Select(part => part.Value + part.Unit)));
        Publish(nameof(HeroHint), HeroHint); Publish(nameof(SceneName), SceneName); Publish(nameof(IsCustomized), IsCustomized);
        Publish(nameof(ScreenText), ScreenText); Publish(nameof(StartedText), StartedText); Publish(nameof(PowerRuleText), PowerRuleText);
        Publish(nameof(LastResultSummary), LastResultSummary); Publish(nameof(PowerText), PowerText); Publish(nameof(NetworkText), NetworkText);
        Publish(nameof(PowerWarning), PowerWarning); Publish(nameof(NetworkWarning), NetworkWarning);
        Publish(nameof(IsAutomaticScreen), IsAutomaticScreen); Publish(nameof(IsAlwaysOnScreen), IsAlwaysOnScreen);
        Publish(nameof(IsDailyScene), IsDailyScene); Publish(nameof(IsNightScene), IsNightScene); Publish(nameof(IsLidScene), IsLidScene); Publish(nameof(IsNetworkScene), IsNetworkScene);
        ((RelayCommand)ToggleCommand).Refresh(); ((RelayCommand)ExtendCommand).Refresh(); ((RelayCommand)RecoverCommand).Refresh();
        foreach (ICommand command in new[] { DailyCommand, NightCommand, LidCommand, NetworkCommand }) ((RelayCommand)command).Refresh();
    }
    private static string FormatRemaining(double seconds)
    {
        long value = (long)Math.Ceiling(seconds);
        return $"{value / 3600:00}:{value / 60 % 60:00}:{value % 60:00}";
    }
    private static string Explain(StopReason reason) => reason switch
    {
        StopReason.Manual => "手动停止", StopReason.Expired => "时间到", StopReason.PowerDisconnected => "电源已断开",
        StopReason.LowBattery => "电量达到下限", StopReason.NetworkDisconnected => "网络已断开",
        StopReason.TelemetryUnknown => "无法读取电源、网络或电量状态", StopReason.ClockChanged => "系统时间发生明显变化",
        StopReason.ThermalCritical => "散热状态严重", StopReason.ThermalSerious => "散热状态持续较高",
        StopReason.Disconnected => "系统睡眠或会话已断开", _ => "会话已结束：" + reason
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
