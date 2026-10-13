using Awake.Core;
using Awake.Platform;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System.IO.Pipes;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Text.Json;

namespace Awake.Service;

internal sealed class RecoveryWorker(ILogger<RecoveryWorker> log) : BackgroundService
{
    private readonly SemaphoreSlim gate = new(1);
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var recovery = new LidRecoveryCoordinator(new WindowsLidSettingsBackend(), new ProtectedRecoveryStore());
        var engine = new LeaseEngine(recovery, WindowsMonitor.Capabilities);
        var monitor = new WindowsMonitor();
        try { engine.Recover(); } catch (Exception error) { log.LogError(error, "启动恢复失败；记录保留"); }
        using var patrolCancellation = CancellationTokenSource.CreateLinkedTokenSource(stoppingToken);
        var timer = Patrol(engine, monitor, patrolCancellation.Token);
        try
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                using var pipe = CreatePipe();
                await pipe.WaitForConnectionAsync(stoppingToken);
                // Bound each request; one local administrator client at a time.
                using var deadline = CancellationTokenSource.CreateLinkedTokenSource(stoppingToken);
                deadline.CancelAfter(TimeSpan.FromSeconds(3));
                try
                {
                    bool admin = false;
                    pipe.RunAsClient(() => { using var identity = WindowsIdentity.GetCurrent(); admin = new WindowsPrincipal(identity).IsInRole(WindowsBuiltInRole.Administrator) || identity.IsSystem; });
                    if (!admin) throw new UnauthorizedAccessException("仅本机管理员可查询恢复");
                    var data = new byte[ProtocolPolicy.MaxBytes + 1]; int length = 0;
                    do
                    {
                        int read = await pipe.ReadAsync(data.AsMemory(length), deadline.Token);
                        if (read == 0) throw new IOException("请求不完整");
                        length += read;
                        if (length > ProtocolPolicy.MaxBytes) throw new InvalidDataException("请求过长");
                    } while (!pipe.IsMessageComplete);
                    var request = ProtocolPolicy.Parse(data.AsSpan(0, length));
                    ServiceResponse response;
                    await gate.WaitAsync(deadline.Token);
                    try
                    {
                        if (!ProtocolPolicy.MayExecute(request)) response = ProtocolPolicy.Denied();
                        else
                        {
                            if (request.Operation == "recover") engine.Recover();
                            response = new(1, !engine.NeedsRecovery, engine.NeedsRecovery ? "needsRecovery" : "idle", engine.Error);
                        }
                    }
                    finally { gate.Release(); }
                    await pipe.WriteAsync(JsonSerializer.SerializeToUtf8Bytes(response), deadline.Token);
                }
                catch (Exception error) when (error is not OperationCanceledException || !stoppingToken.IsCancellationRequested)
                { log.LogWarning(error, "固定恢复请求被拒绝或失败"); }
            }
        }
        finally { patrolCancellation.Cancel(); await timer; try { engine.Recover(); } catch (Exception error) { log.LogError(error, "退出恢复失败；记录保留"); } }
    }
    private async Task Patrol(LeaseEngine engine, WindowsMonitor monitor, CancellationToken cancellationToken)
    {
        try
        {
            using var timer = new PeriodicTimer(TimeSpan.FromSeconds(1));
            while (await timer.WaitForNextTickAsync(cancellationToken))
            {
                await gate.WaitAsync(cancellationToken);
                try { engine.Tick(monitor.Sample(), monitor.Clock()); }
                catch (Exception error) { log.LogError(error, "恢复巡检失败"); }
                finally { gate.Release(); }
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested) { }
    }
    private static NamedPipeServerStream CreatePipe()
    {
        var acl = new PipeSecurity(); acl.SetAccessRuleProtection(true, false);
        // Network logons are denied even when the caller is an administrator.
        acl.AddAccessRule(new PipeAccessRule(new SecurityIdentifier(WellKnownSidType.NetworkSid, null), PipeAccessRights.FullControl, AccessControlType.Deny));
        foreach (var sid in new[] { WellKnownSidType.LocalSystemSid, WellKnownSidType.BuiltinAdministratorsSid })
            acl.AddAccessRule(new PipeAccessRule(new SecurityIdentifier(sid, null), PipeAccessRights.FullControl, AccessControlType.Allow));
        return NamedPipeServerStreamAcl.Create(ProtocolPolicy.PipeName, PipeDirection.InOut, 1, PipeTransmissionMode.Message,
            PipeOptions.Asynchronous, 2048, 2048, acl);
    }
}
