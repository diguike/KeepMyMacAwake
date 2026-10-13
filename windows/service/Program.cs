using Awake.Service;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

InstallationTrust.RequireProductionIdentity();
var builder = Host.CreateApplicationBuilder(args);
builder.Services.AddWindowsService(options => options.ServiceName = "KeepMyMacAwakeRecovery");
builder.Services.AddHostedService<RecoveryWorker>();
await builder.Build().RunAsync();
