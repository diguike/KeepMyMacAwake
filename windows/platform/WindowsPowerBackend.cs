using Awake.Core;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace Awake.Platform;

/// <summary>Owns one request per session. Extending a timer never acquires another request.</summary>
public sealed class WindowsPowerBackend : IPowerBackend, IDisposable
{
    private readonly object gate = new();
    private readonly IRequestFactory factory;
    private IPowerRequest? request;
    private bool systemSet, displaySet, disposed;
    public WindowsPowerBackend() : this(new NativeRequestFactory()) { }
    internal WindowsPowerBackend(IRequestFactory factory) { this.factory = factory; }

    public void Start(bool keepDisplay)
    {
        lock (gate)
        {
            ObjectDisposedException.ThrowIf(disposed, this);
            if (request is not null) throw new InvalidOperationException("已有保活请求");
            try
            {
                request = factory.Create();
                request.Set(1); systemSet = true;
                if (keepDisplay) { request.Set(0); displaySet = true; }
            }
            catch (Exception original)
            {
                try { Release(); } catch (Exception cleanup) { throw new AggregateException(original, cleanup); }
                throw;
            }
        }
    }

    public void Stop() { lock (gate) { Release(); } }
    private void Release()
    {
        if (request is null) return;
        // Closing the request also destroys its outstanding counts if a clear fails.
        try
        {
            try { if (displaySet) request.Clear(0); }
            finally { if (systemSet) request.Clear(1); }
        }
        finally { request.Dispose(); request = null; systemSet = displaySet = false; }
    }
    public void Dispose() { lock (gate) { try { Release(); } finally { disposed = true; } } }
}

internal interface IRequestFactory { IPowerRequest Create(); }
internal interface IPowerRequest : IDisposable { void Set(int type); void Clear(int type); }
internal sealed class NativeRequestFactory : IRequestFactory
{
    public IPowerRequest Create()
    {
        if (!OperatingSystem.IsWindows() || IntPtr.Size != 8) throw new PlatformNotSupportedException("Windows x64/arm64 only");
        var reason = Marshal.StringToHGlobalUni("KeepMyMacAwake：用户指定的长任务会话");
        try
        {
            var context = new ReasonContext { Version = 0, Flags = 1, SimpleReasonString = reason };
            var handle = NativePower.PowerCreateRequest(ref context);
            if (handle.IsInvalid) { int error = Marshal.GetLastWin32Error(); handle.Dispose(); throw new Win32Exception(error); }
            return new NativeRequest(handle);
        }
        finally { Marshal.FreeHGlobal(reason); }
    }
    private sealed class NativeRequest(PowerRequestHandle handle) : IPowerRequest
    {
        public void Set(int type) { if (!NativePower.PowerSetRequest(handle, type)) throw new Win32Exception(Marshal.GetLastWin32Error()); }
        public void Clear(int type) { if (!NativePower.PowerClearRequest(handle, type)) throw new Win32Exception(Marshal.GetLastWin32Error()); }
        public void Dispose() => handle.Dispose();
    }
}
