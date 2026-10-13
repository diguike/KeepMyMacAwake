using Awake.Core;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace Awake.Platform;

/// <summary>Fixed power-policy operations; deliberately not wired to session Start.</summary>
public sealed class WindowsLidSettingsBackend : ILidSettingsBackend
{
    private static readonly Guid Buttons = new("4f971e89-eebd-4455-a8de-9e59040e7347");
    private static readonly Guid Lid = new("5ca83367-6e45-459f-a27b-476b1d01c936");
    public LidSetting Read()
    {
        Check(PowerGetActiveScheme(IntPtr.Zero, out var pointer));
        Guid scheme;
        try { scheme = Marshal.PtrToStructure<Guid>(pointer); } finally { LocalFree(pointer); }
        return ReadScheme(scheme);
    }
    public LidSetting ReadScheme(Guid scheme)
    {
        var buttons = Buttons; var lid = Lid;
        Check(PowerReadACValueIndex(IntPtr.Zero, ref scheme, ref buttons, ref lid, out var ac));
        Check(PowerReadDCValueIndex(IntPtr.Zero, ref scheme, ref buttons, ref lid, out var dc));
        return new(scheme, checked((int)ac), checked((int)dc));
    }
    public void Write(LidSetting setting)
    {
        if (setting.Scheme == Guid.Empty || setting.AcAction is < 0 or > 3 || setting.DcAction is < 0 or > 3)
            throw new ArgumentException("无效的合盖设置");
        // Never select a different power scheme during recovery.
        var current = Read();
        if (current.Scheme != setting.Scheme || current.DcAction != setting.DcAction) throw new InvalidOperationException("电源计划或电池合盖动作已改变；恢复被保留供人工处理");
        var scheme = setting.Scheme; var buttons = Buttons; var lid = Lid;
        Check(PowerWriteACValueIndex(IntPtr.Zero, ref scheme, ref buttons, ref lid, (uint)setting.AcAction));
        // This product owns only AC lid action. Never rewrite the DC value.
        Check(PowerSetActiveScheme(IntPtr.Zero, ref scheme));
        if (Read() != setting) throw new IOException("合盖设置读回不一致；保留恢复记录");
    }
    private static void Check(uint result) { if (result != 0) throw new Win32Exception((int)result); }
    [DllImport("powrprof.dll")] private static extern uint PowerGetActiveScheme(IntPtr root, out IntPtr scheme);
    [DllImport("kernel32.dll")] private static extern IntPtr LocalFree(IntPtr pointer);
    [DllImport("powrprof.dll")] private static extern uint PowerReadACValueIndex(IntPtr root, ref Guid scheme, ref Guid subgroup, ref Guid setting, out uint value);
    [DllImport("powrprof.dll")] private static extern uint PowerReadDCValueIndex(IntPtr root, ref Guid scheme, ref Guid subgroup, ref Guid setting, out uint value);
    [DllImport("powrprof.dll")] private static extern uint PowerWriteACValueIndex(IntPtr root, ref Guid scheme, ref Guid subgroup, ref Guid setting, uint value);
    [DllImport("powrprof.dll")] private static extern uint PowerSetActiveScheme(IntPtr root, ref Guid scheme);
}
