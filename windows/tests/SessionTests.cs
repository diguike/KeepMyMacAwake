using Awake.Core;
using Xunit;
using System.Text.Json;
namespace Awake.Core.Tests;
public class SessionTests
{
    internal sealed class Backend : IPowerBackend
    {
        public bool Active, KeepDisplay, FailStart, FailStop;
        public void Start(bool keepDisplay) { Active = true; KeepDisplay = keepDisplay; if (FailStart) throw new InvalidOperationException("start"); }
        public void Stop() { if (FailStop) throw new InvalidOperationException("stop"); Active = false; }
    }
    internal static readonly PowerSample Good = new(true, 90, true, ThermalLevel.Nominal);
    internal static ClockSample Clock(double seconds = 0) => new(DateTimeOffset.UnixEpoch.AddSeconds(seconds), seconds);
    internal static SessionOptions Options(int minutes = 60) => new(minutes, true, false, 20, ScreenMode.Automatic);
    internal static readonly PlatformCapabilities Supported = new(true, true, true);
    [Fact] public void SharedScenarioContract()
    {
        using var json = JsonDocument.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory,"specs/scenarios.json")));
        foreach (var row in json.RootElement.EnumerateArray())
        {
            var backend = new Backend(); var controller = new SessionController(backend, Supported);
            controller.Start(Options(row.GetProperty("durationMinutes").GetInt32()) with { RequireNetwork = row.GetProperty("requireNetwork").GetBoolean() }, Good, Clock());
            var sample = new PowerSample(row.GetProperty("onAC").GetBoolean(),90,row.GetProperty("network").ValueKind == JsonValueKind.Null ? null : row.GetProperty("network").GetBoolean(),Enum.Parse<ThermalLevel>(row.GetProperty("thermal").GetString()!,true));
            controller.Tick(sample,new(DateTimeOffset.UnixEpoch.AddSeconds(row.GetProperty("wallSeconds").GetDouble()),row.GetProperty("tickSeconds").GetDouble()));
            string? reason = row.GetProperty("reason").GetString();
            Assert.Equal(reason is null,controller.IsActive);
            Assert.Equal(reason is null ? null : Enum.Parse<StopReason>(reason,true),controller.LastStopReason);
        }
    }
    [Fact] public void SharedSceneContract()
    {
        using var json = JsonDocument.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory,"specs/scenes.json")));
        foreach (var row in json.RootElement.EnumerateArray())
        {
            var value = Preferences.ForScene(Enum.Parse<Scene>(row.GetProperty("scene").GetString()!));
            Assert.True(value.IsValid); Assert.Equal(row.GetProperty("durationMinutes").GetInt32(),value.DurationMinutes);
            Assert.Equal(Enum.Parse<ScreenMode>(row.GetProperty("screenMode").GetString()!),value.ScreenMode);
            Assert.Equal(row.GetProperty("lidMode").GetBoolean(),value.LidMode); Assert.Equal(row.GetProperty("requireAC").GetBoolean(),value.RequireAC); Assert.Equal(row.GetProperty("requireNetwork").GetBoolean(),value.RequireNetwork);
        }
    }
    [Theory] [InlineData(ScreenMode.Automatic,false)] [InlineData(ScreenMode.AlwaysOn,true)] [InlineData(ScreenMode.NightDim,true)]
    public void DisplayAssertionMatchesMode(ScreenMode mode,bool keepDisplay) { var backend = new Backend(); var controller = new SessionController(backend,Supported); controller.Start(Options() with {ScreenMode=mode},Good,Clock()); Assert.Equal(keepDisplay,backend.KeepDisplay); }
    [Fact] public void OrdinaryUnknownThermalAllowedOnlyWithoutThermalCapability()
    {
        var controller = new SessionController(new Backend(),new(false,false,false));
        controller.Start(Options(),Good with {Thermal=ThermalLevel.Unknown},Clock()); Assert.True(controller.IsActive);
        controller.Tick(Good with {Thermal=ThermalLevel.Critical},Clock(1)); Assert.Equal(StopReason.ThermalCritical,controller.LastStopReason);
        Assert.Throws<InvalidOperationException>(()=>new SessionController(new Backend(),Supported).Start(Options(),Good with {Thermal=ThermalLevel.Unknown},Clock()));
    }
    [Fact] public void UnsupportedLidAndBatteryNeverAcquireBackend()
    {
        var backend=new Backend(); var controller=new SessionController(backend,new(false,false,false));
        Assert.Throws<InvalidOperationException>(()=>controller.Start(Options() with {LidMode=true},Good,Clock()));
        Assert.Throws<InvalidOperationException>(()=>controller.Start(Options() with {RequireAC=false},Good with {OnAC=false},Clock()));
        Assert.False(backend.Active);
    }
    [Fact] public void SeriousHeatMustPersistThirtySecondsAndReset()
    {
        var controller=new SessionController(new Backend(),Supported); controller.Start(Options(),Good,Clock());
        controller.Tick(Good with {Thermal=ThermalLevel.Serious},Clock(1)); controller.Tick(Good,Clock(30));
        controller.Tick(Good with {Thermal=ThermalLevel.Serious},Clock(31)); controller.Tick(Good with {Thermal=ThermalLevel.Serious},Clock(60)); Assert.True(controller.IsActive);
        controller.Tick(Good with {Thermal=ThermalLevel.Serious},Clock(61)); Assert.Equal(StopReason.ThermalSerious,controller.LastStopReason);
    }
    [Fact] public void ExpiredCannotExtendOrRevive()
    {
        var backend=new Backend(); var controller=new SessionController(backend,Supported); controller.Start(Options(1),Good,Clock());
        Assert.Throws<InvalidOperationException>(()=>controller.Extend(Good,Clock(60))); controller.Tick(Good,Clock(61)); Assert.False(controller.IsActive); Assert.False(backend.Active); Assert.Equal(StopReason.Expired,controller.LastStopReason);
    }
    [Fact] public void FailedStopPreservesReasonAndSupportsRetry()
    {
        var backend=new Backend(); var controller=new SessionController(backend,Supported); controller.Start(Options(1),Good,Clock()); backend.FailStop=true;
        controller.Tick(Good,Clock(60)); Assert.True(controller.NeedsRecovery); Assert.False(controller.IsActive); Assert.Equal(StopReason.Expired,controller.LastStopReason);
        Assert.Throws<InvalidOperationException>(()=>controller.Start(Options(),Good,Clock(61))); backend.FailStop=false; controller.Stop(); Assert.False(controller.NeedsRecovery); Assert.Equal(StopReason.Expired,controller.LastStopReason);
    }
    [Fact] public void PartialStartFailureIsRolledBackOrBlockedUntilRecovery()
    {
        var backend=new Backend {FailStart=true,FailStop=true}; var controller=new SessionController(backend,Supported);
        Assert.Throws<InvalidOperationException>(()=>controller.Start(Options(),Good,Clock())); Assert.True(controller.NeedsRecovery); backend.FailStop=false; controller.Stop(); Assert.False(backend.Active);
    }
    [Fact] public void TwentyFourHourCapAndInfiniteNoExtension()
    {
        var controller=new SessionController(new Backend(),Supported); controller.Start(Options(1440),Good,Clock()); Assert.False(controller.CanExtend); controller.Stop(); controller.Start(Options(0),Good,Clock()); Assert.False(controller.CanExtend);
    }
    [Fact] public void FreshControllerRestoresNoActiveSession() { var controller=new SessionController(new Backend(),Supported); Assert.False(controller.IsActive); Assert.True(new Preferences().IsValid); Assert.False((new Preferences {DimAmount=double.NaN}).IsValid); }
    [Fact] public void DisconnectedNetworkNeverAutomaticallyRestarts()
    {
        var controller=new SessionController(new Backend(),Supported);controller.Start(Options() with {RequireNetwork=true},Good,Clock());
        controller.Tick(Good with {NetworkAvailable=false},Clock(1));controller.Tick(Good,Clock(2));Assert.False(controller.IsActive);Assert.Equal(StopReason.NetworkDisconnected,controller.LastStopReason);
    }
    [Theory] [InlineData(null,StopReason.TelemetryUnknown)] [InlineData(-1,StopReason.TelemetryUnknown)] [InlineData(101,StopReason.TelemetryUnknown)] [InlineData(20,StopReason.LowBattery)]
    public void BatteryTelemetryIsValidatedWhenCapabilityExists(int? percent,StopReason reason)
    {
        var controller=new SessionController(new Backend(),Supported);controller.Start(Options() with {RequireAC=false},Good,Clock());
        controller.Tick(Good with {OnAC=false,BatteryPercent=percent},Clock(1));Assert.Equal(reason,controller.LastStopReason);
    }
    [Fact] public void FiniteExtensionAddsFifteenMinutesWithoutResettingStart()
    {
        var controller=new SessionController(new Backend(),Supported);controller.Start(Options(1),Good,Clock());controller.Extend(Good,Clock(30));Assert.Equal(930,controller.RemainingSeconds);
        controller.Tick(Good,Clock(959));Assert.True(controller.IsActive);controller.Tick(Good,Clock(960));Assert.Equal(StopReason.Expired,controller.LastStopReason);
    }

    [Fact] public void IdleStartFailureDoesNotReuseOldStopReasonOrError()
    {
        var backend=new Backend();var controller=new SessionController(backend,new(false,false,false));controller.Start(Options(1),Good,Clock());controller.Tick(Good,Clock(60));
        Assert.Equal(StopReason.Expired,controller.LastStopReason);
        Assert.Throws<InvalidOperationException>(()=>controller.Start(Options() with {LidMode=true},Good,Clock(61)));Assert.Null(controller.LastStopReason);
        backend.FailStart=true;Assert.Throws<InvalidOperationException>(()=>controller.Start(Options(),Good,Clock(62)));Assert.Equal("start",controller.Error);
        Assert.Throws<ArgumentException>(()=>controller.Start(Options(-1),Good,Clock(63)));Assert.Null(controller.Error);Assert.Null(controller.LastStopReason);
    }
    [Fact] public void ExtendAtExpiryPreservesReleaseFailureForRecovery()
    {
        var backend=new Backend();var controller=new SessionController(backend,Supported);controller.Start(Options(1),Good,Clock());backend.FailStop=true;
        Assert.Throws<InvalidOperationException>(()=>controller.Extend(Good,Clock(60)));Assert.Equal(StopReason.Expired,controller.LastStopReason);Assert.Equal("stop",controller.Error);Assert.True(controller.NeedsRecovery);Assert.False(controller.IsActive);
        backend.FailStop=false;controller.Stop();Assert.Equal(StopReason.Expired,controller.LastStopReason);Assert.False(controller.NeedsRecovery);
    }

}
