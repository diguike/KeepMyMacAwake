namespace Awake.Core;

public sealed record LidSetting(Guid Scheme, int AcAction, int DcAction);
public sealed record LidRecoveryRecord(int Version, LidSetting Baseline, LidSetting Applied, DateTimeOffset Created);
public interface ILidSettingsBackend { LidSetting Read(); void Write(LidSetting setting); }
public interface IRecoveryStore { LidRecoveryRecord? Load(); void Save(LidRecoveryRecord record); void Clear(); }

/// Service-owned transactional journal. All methods must run on a single serial loop.
public sealed class LidRecoveryCoordinator(ILidSettingsBackend backend, IRecoveryStore store)
{
    public bool NeedsRecovery { get; private set; }
    public string? Error { get; private set; }
    public void Begin(DateTimeOffset now)
    {
        if (NeedsRecovery || store.Load() is not null) throw new InvalidOperationException("遗留设置需先恢复");
        var baseline = backend.Read();
        if (baseline.AcAction == 0) throw new InvalidOperationException("合盖设置已由其他工具或用户禁用");
        if (baseline.AcAction is < 0 or > 3 || baseline.DcAction is < 0 or > 3 || baseline.Scheme == Guid.Empty) throw new InvalidOperationException("合盖基线无效");
        var applied = baseline with { AcAction = 0 };
        // Journal persisted before any power-setting mutation.
        store.Save(new(1, baseline, applied, now));
        NeedsRecovery = true;
        try
        {
            backend.Write(applied);
            if (backend.Read() != applied) throw new InvalidOperationException("合盖设置读回失败");
            Error = null;
        }
        catch (Exception original)
        {
            Error = original.Message;
            try { Restore(); } catch { }
            throw;
        }
    }
    public void Restore()
    {
        NeedsRecovery = true;
        try
        {
            var record = store.Load();
            if (record is null) { NeedsRecovery = false; Error = null; return; }
            if (record.Version != 1 || record.Baseline.Scheme == Guid.Empty || record.Baseline.AcAction is < 1 or > 3 || record.Baseline.DcAction is < 0 or > 3 || record.Applied != (record.Baseline with { AcAction = 0 })) throw new InvalidOperationException("恢复记录无效");
            var current = backend.Read();
            // Never activate another plan or overwrite a third-party setting.
            // A changed active plan retains the journal until its owner can resolve it.
            if (current != record.Baseline)
            {
                if (current != record.Applied) throw new InvalidOperationException("电源计划或设置已被外部修改，恢复记录保留");
                backend.Write(record.Baseline);
                if (backend.Read() != record.Baseline) throw new InvalidOperationException("恢复读回失败");
            }
            store.Clear(); NeedsRecovery = false; Error = null;
        }
        catch (Exception error) { Error = error.Message; throw; }
    }
    public bool IsOwnedSetting => store.Load() is { } record && backend.Read() == record.Applied;
}

/// Independent service loop enforces expiry, ownership, and client loss. Not exposed through IPC yet.
public sealed class LeaseEngine(LidRecoveryCoordinator recovery, PlatformCapabilities capabilities)
{
    public const double HeartbeatTimeout = 20;
    private Guid? leaseId;
    private Guid owner;
    private ClockSample? start;
    private double heartbeat;
    private double duration;
    private SessionOptions? options;
    private SafetyEvaluator safety = new();
    public bool IsActive => leaseId is not null;
    public bool NeedsRecovery => recovery.NeedsRecovery;
    public StopReason? LastStopReason { get; private set; }
    public string? Error { get; private set; }
    public void Recover() { leaseId = null; recovery.Restore(); Error = null; LastStopReason = StopReason.Recovered; }
    public Guid Acquire(Guid owner, SessionOptions options, PowerSample sample, ClockSample now)
    {
        if (owner == Guid.Empty || !options.IsValid || !options.LidMode || !double.IsFinite(now.Continuous)) throw new ArgumentException("无效合盖租约");
        if (IsActive || NeedsRecovery) throw new InvalidOperationException("已有租约或待恢复设置");
        if (!capabilities.LidSupported || !capabilities.ThermalSupported) throw new InvalidOperationException("合盖保护能力尚未验证");
        safety = new();
        if (safety.Evaluate(sample, options, capabilities, now.Continuous) is { } reason) { LastStopReason = reason; throw new InvalidOperationException(reason.ToString()); }
        recovery.Begin(now.Wall);
        this.owner = owner; this.options = options; start = now; heartbeat = now.Continuous; duration = options.DurationMinutes * 60;
        leaseId = Guid.NewGuid(); LastStopReason = null; Error = null;
        return leaseId.Value;
    }
    public void Renew(Guid id, Guid owner, PowerSample sample, ClockSample now)
    {
        Tick(sample, now); Authorize(id, owner); heartbeat = now.Continuous;
    }
    public void Extend(Guid id, Guid owner, PowerSample sample, ClockSample now)
    {
        Tick(sample, now); Authorize(id, owner);
        if (duration == 0 || duration + 900 > 86400) throw new InvalidOperationException("无法续时");
        duration += 900; heartbeat = now.Continuous;
    }
    public void Release(Guid id, Guid owner) { Authorize(id, owner); End(StopReason.Manual); }
    public void Disconnected(Guid owner) { if (IsActive && this.owner == owner) { try { End(StopReason.Disconnected); } catch { } } }
    public void Tick(PowerSample sample, ClockSample now)
    {
        if (!IsActive) { if (NeedsRecovery) { try { recovery.Restore(); Error = null; } catch (Exception error) { Error = error.Message; } } return; }
        var elapsed = now.Continuous - start!.Continuous;
        StopReason? reason;
        if (!double.IsFinite(elapsed) || elapsed < 0 || Math.Abs((now.Wall - start.Wall).TotalSeconds - elapsed) > 60) reason = StopReason.ClockChanged;
        else if (duration > 0 && elapsed >= duration) reason = StopReason.Expired;
        else if (now.Continuous - heartbeat >= HeartbeatTimeout) reason = StopReason.HeartbeatLost;
        else reason = safety.Evaluate(sample, options!, capabilities, now.Continuous);
        if (reason is null) { try { if (!recovery.IsOwnedSetting) reason = StopReason.BackendChanged; } catch (Exception error) { Error = error.Message; reason = StopReason.BackendChanged; } }
        if (reason is { } value) { try { End(value); } catch { } }
    }
    private void Authorize(Guid id, Guid owner) { if (leaseId != id || this.owner != owner) throw new InvalidOperationException("租约已结束或不属于当前连接"); }
    private void End(StopReason reason)
    {
        leaseId = null; LastStopReason = reason;
        try { recovery.Restore(); Error = null; } catch (Exception error) { Error = error.Message; throw; }
    }
}
