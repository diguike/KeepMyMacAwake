using System.ComponentModel;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

namespace Awake.Platform;

// Explicit union reserves the complete SDK REASON_CONTEXT on x64/arm64.
// Distribution deliberately excludes x86: its union has a different ABI.
[StructLayout(LayoutKind.Explicit, Size = 32)]
internal struct ReasonContext
{
    [FieldOffset(0)] public uint Version;
    [FieldOffset(4)] public uint Flags;
    [FieldOffset(8)] public IntPtr SimpleReasonString;
}

internal sealed class PowerRequestHandle : SafeHandleZeroOrMinusOneIsInvalid
{
    public PowerRequestHandle() : base(true) { }
    protected override bool ReleaseHandle() => NativePower.CloseHandle(handle);
}

internal static class NativePower
{
    [DllImport("kernel32.dll", SetLastError = true)] internal static extern PowerRequestHandle PowerCreateRequest(ref ReasonContext context);
    [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool PowerSetRequest(PowerRequestHandle handle, int type);
    [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool PowerClearRequest(PowerRequestHandle handle, int type);
    [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool CloseHandle(IntPtr handle);
    [DllImport("kernel32.dll")] internal static extern ulong GetTickCount64();
    [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool GetSystemPowerStatus(out SystemPowerStatus status);
}

[StructLayout(LayoutKind.Sequential)]
internal struct SystemPowerStatus
{
    public byte ACLineStatus, BatteryFlag, BatteryLifePercent, SystemStatusFlag;
    public uint BatteryLifeTime, BatteryFullLifeTime;
}
