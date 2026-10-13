using Awake.Core;
using System.Runtime.InteropServices;

namespace Awake.Platform;

public sealed class WindowsMonitor
{
    public static PlatformCapabilities Capabilities { get; } = new(false, false, false,
        "Windows 合盖与恢复尚未真机验收；没有可靠热遥测。本预览仅支持接电、开盖运行。");
    public PowerSample Sample()
    {
        bool? ac = null; int? battery = null;
        if (NativePower.GetSystemPowerStatus(out var status))
        {
            ac = status.ACLineStatus switch { 0 => false, 1 => true, _ => null };
            if ((status.BatteryFlag & 128) == 0 && status.BatteryFlag != 255 && status.BatteryLifePercent <= 100)
                battery = status.BatteryLifePercent;
        }
        return new(ac, battery, ReadNetworkPath(), ThermalLevel.Unknown);
    }
    public ClockSample Clock() => new(DateTimeOffset.UtcNow, NativePower.GetTickCount64() / 1000d);

    private static bool? ReadNetworkPath()
    {
        object? manager = null;
        try
        {
            // NLM local-network/internet flags identify a routable path. Subnet-only
            // and no-traffic do not qualify. This does not probe an AI service.
            var type = Type.GetTypeFromCLSID(new Guid("DCB00C01-570F-4A9B-8D69-199FDBA5723B"), true)!;
            manager = Activator.CreateInstance(type)!;
            uint connectivity = ((INetworkListManager)manager).GetConnectivity();
            return (connectivity & (0x20u | 0x40u | 0x200u | 0x400u)) != 0;
        }
        catch (Exception e) when (e is COMException or InvalidCastException or TypeLoadException) { return null; }
        finally { if (manager is not null && Marshal.IsComObject(manager)) Marshal.ReleaseComObject(manager); }
    }
    [ComImport, Guid("DCB00000-570F-4A9B-8D69-199FDBA5723B"), InterfaceType(ComInterfaceType.InterfaceIsDual)]
    private interface INetworkListManager
    {
        [DispId(1)] object GetNetworks(int flags);
        [DispId(2)] object GetNetwork([In] Guid networkId);
        [DispId(3)] object GetNetworkConnections();
        [DispId(4)] object GetNetworkConnection([In] Guid connectionId);
        [DispId(5)] bool IsConnectedToInternet { get; }
        [DispId(6)] bool IsConnected { get; }
        [DispId(7)] uint GetConnectivity();
    }
}
