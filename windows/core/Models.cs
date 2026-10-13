namespace Awake.Core;

public enum Scene { Daily, Night, PluggedLid, Network }
public enum ScreenMode { Automatic, AlwaysOn, NightDim }
public enum ThermalLevel { Nominal, Fair, Serious, Critical, Unknown }
public enum StopReason { Manual, Expired, Disconnected, HeartbeatLost, PowerDisconnected, LowBattery, NetworkDisconnected, ThermalCritical, ThermalSerious, TelemetryUnknown, ClockChanged, BackendChanged, Recovered }
public sealed record PowerSample(bool? OnAC, int? BatteryPercent, bool? NetworkAvailable, ThermalLevel Thermal);
public sealed record ClockSample(DateTimeOffset Wall, double Continuous);
public sealed record PlatformCapabilities(bool LidSupported, bool BatterySupported, bool ThermalSupported, string? LidUnavailableReason = null);
public sealed record SessionOptions(int DurationMinutes, bool RequireAC, bool RequireNetwork, int MinimumBattery, ScreenMode ScreenMode, bool LidMode = false, double DimAmount = 0.94)
{
    public bool IsValid => DurationMinutes is >= 0 and <= 1440 && MinimumBattery is >= 10 and <= 80 && Enum.IsDefined(ScreenMode) && double.IsFinite(DimAmount) && DimAmount is >= .8 and <= .98;
}
public sealed record Preferences
{
    public Scene Scene { get; init; } = Scene.Daily;
    public int DurationMinutes { get; init; } = 60;
    public int CustomMinutes { get; init; } = 90;
    public bool RequireAC { get; init; } = true;
    public bool RequireNetwork { get; init; }
    public int MinimumBattery { get; init; } = 20;
    public ScreenMode ScreenMode { get; init; } = ScreenMode.Automatic;
    public bool LidMode { get; init; }
    public double DimAmount { get; init; } = .94;
    public bool ShowCountdown { get; init; } = true;
    public bool IsValid => Enum.IsDefined(Scene) && DurationMinutes is >= -1 and <= 1440 && CustomMinutes is >= 1 and <= 1440 && MinimumBattery is >= 10 and <= 80 && Enum.IsDefined(ScreenMode) && double.IsFinite(DimAmount) && DimAmount is >= .8 and <= .98;
    public static Preferences ForScene(Scene scene) => scene switch
    {
        Scene.Daily => new(),
        Scene.Night => new() { Scene = scene, DurationMinutes = 480, ScreenMode = ScreenMode.NightDim },
        Scene.PluggedLid => new() { Scene = scene, DurationMinutes = -1, LidMode = true },
        Scene.Network => new() { Scene = scene, DurationMinutes = 120, LidMode = true, RequireAC = false, RequireNetwork = true },
        _ => throw new ArgumentException("未知场景")
    };
}
public interface IPowerBackend { void Start(bool keepDisplay); void Stop(); }

internal sealed class SafetyEvaluator
{
    private double? seriousSince;
    public StopReason? Evaluate(PowerSample sample, SessionOptions options, PlatformCapabilities capabilities, double now)
    {
        if (sample.OnAC is null) return StopReason.TelemetryUnknown;
        if ((options.RequireAC || !capabilities.BatterySupported) && sample.OnAC == false) return StopReason.PowerDisconnected;
        if (options.RequireNetwork)
        {
            if (sample.NetworkAvailable is null) return StopReason.TelemetryUnknown;
            if (sample.NetworkAvailable == false) return StopReason.NetworkDisconnected;
        }
        if (sample.OnAC == false)
        {
            if (sample.BatteryPercent is null or < 0 or > 100) return StopReason.TelemetryUnknown;
            if (sample.BatteryPercent <= options.MinimumBattery) return StopReason.LowBattery;
        }
        if (sample.Thermal == ThermalLevel.Unknown && (capabilities.ThermalSupported || options.LidMode)) return StopReason.TelemetryUnknown;
        if (sample.Thermal == ThermalLevel.Critical) return StopReason.ThermalCritical;
        if (sample.Thermal == ThermalLevel.Serious)
        {
            seriousSince ??= now;
            if (now - seriousSince >= 30) return StopReason.ThermalSerious;
        }
        else seriousSince = null;
        return null;
    }
}
