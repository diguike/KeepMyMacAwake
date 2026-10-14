namespace Awake.Core;

/// Single-thread confined: UI dispatches all operations on its dispatcher.
public sealed class SessionController(IPowerBackend backend, PlatformCapabilities capabilities)
{
    private SessionOptions? options;
    private ClockSample? start;
    private double duration;
    private SafetyEvaluator safety = new();
    public bool IsActive { get; private set; }
    public double? RemainingSeconds { get; private set; }
    public StopReason? LastStopReason { get; private set; }
    public string? Error { get; private set; }
    public bool NeedsRecovery { get; private set; }
    public bool CanExtend => IsActive && duration > 0 && duration + 900 <= 86400;
    public void Start(SessionOptions options, PowerSample sample, ClockSample now)
    {
        if (IsActive || NeedsRecovery) throw new InvalidOperationException("请先停止或恢复当前会话");
        // An idle start is a new attempt: old expiry/backend errors must not
        // masquerade as the reason this attempt failed.
        LastStopReason = null; Error = null;
        if (!options.IsValid || !double.IsFinite(now.Continuous)) throw new ArgumentException("会话参数无效");
        if (options.LidMode && (!capabilities.LidSupported || !capabilities.ThermalSupported)) throw new InvalidOperationException(capabilities.LidUnavailableReason ?? "合盖能力尚未通过验证");
        if (!capabilities.BatterySupported && sample.OnAC == false) throw new InvalidOperationException("Windows 使用电池保持唤醒尚未通过验证，请接电后开始");
        safety = new();
        var reason = safety.Evaluate(sample, options, capabilities, now.Continuous);
        if (reason is not null) { LastStopReason = reason; throw new InvalidOperationException(reason.ToString()); }
        // Start may partially acquire resources. A failed rollback remains recoverable.
        NeedsRecovery = true;
        try { backend.Start(options.ScreenMode != ScreenMode.Automatic); }
        catch (Exception original)
        {
            Error = original.Message;
            try { backend.Stop(); NeedsRecovery = false; } catch (Exception recovery) { Error += "; " + recovery.Message; }
            throw;
        }
        this.options = options; start = now; duration = options.DurationMinutes * 60;
        IsActive = true; NeedsRecovery = false; LastStopReason = null; Error = null;
        RemainingSeconds = duration == 0 ? null : duration;
    }
    public void Tick(PowerSample sample, ClockSample now)
    {
        if (!IsActive || start is null || options is null) return;
        double elapsed = now.Continuous - start.Continuous;
        StopReason? reason = null;
        if (!double.IsFinite(elapsed) || elapsed < 0 || Math.Abs((now.Wall - start.Wall).TotalSeconds - elapsed) > 60) reason = StopReason.ClockChanged;
        else if (duration > 0 && elapsed >= duration) reason = StopReason.Expired;
        else reason = safety.Evaluate(sample, options, capabilities, now.Continuous);
        if (reason is not null) { try { Stop(reason.Value); } catch { /* NeedsRecovery and Error preserve failure. */ } }
        else RemainingSeconds = duration == 0 ? null : Math.Max(0, duration - elapsed);
    }
    public void Extend(PowerSample sample, ClockSample now)
    {
        Tick(sample, now);
        if (!CanExtend) throw new InvalidOperationException("已结束、无限时或超过24小时的会话不能续时");
        duration += 900;
        RemainingSeconds = Math.Max(0, duration - (now.Continuous - start!.Continuous));
    }
    public void Stop(StopReason reason = StopReason.Manual)
    {
        if (!IsActive && !NeedsRecovery) return;
        bool retry = NeedsRecovery && !IsActive;
        IsActive = false; RemainingSeconds = null;
        if (!retry) LastStopReason = reason;
        NeedsRecovery = true;
        try { backend.Stop(); NeedsRecovery = false; Error = null; }
        catch (Exception error) { Error = error.Message; throw; }
    }
}
