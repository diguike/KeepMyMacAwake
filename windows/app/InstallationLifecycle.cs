using System;
using System.Threading;

namespace Awake.App;

internal static class InstallationLifecycle
{
    // A confirmed mutex handoff means the previous process released its resources.
    // A failed stop leaves the first app running and the installer aborts.
    internal static bool RequestExit(Mutex instance, string eventName, TimeSpan timeout)
    {
        using var request = EventWaitHandle.OpenExisting(eventName);
        request.Set();
        try { return instance.WaitOne(timeout); }
        catch (AbandonedMutexException) { return true; }
    }
}
