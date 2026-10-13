# Windows 恢复服务源码预览

此组件目前 **不能安装或启动**。`InstallationTrust.RequireProductionIdentity()` 无条件拒绝启动；没有设置、环境变量或 IPC 可以解除门槛。普通接电保活使用进程内 PowerRequest，无需服务。

服务源码与恢复协调器用于下一轮 Windows 本机开发。保留以下安全机制：

- version 1 固定 JSON 操作，消息最多 1024 字节；只预备 `status` / `recover`，`begin` / `renew` / `extend` / `release` 显式拒绝。不接受命令、路径、计划 GUID 等客户端参数。
- 命名管道 `KeepMyMacAwake.Recovery.v1`：SYSTEM 与本机 Administrators ACL，拒绝 Network SID；每请求模拟客户端并再次检查管理员身份，3 秒读取上限。
- 独立巡检、启动及停止先恢复；租约引擎内部实现 20 秒失联与计时、电源、保护检查。当前没有可通过 IPC 获得的租约。
- ProgramData 下由未来可信安装程序预置的受保护目录，服务不创建或收养目录；每次操作检查父目录/文件链接与 ACL，write-ahead 记录持久化 flush、原子重命名。已有不安全 ACL 或链接被拒绝。恢复只处理记录中的原计划和本应用可识别的改动；外部修改保留记录。
- PowrProf 只写固定合盖子组/设置 UUID 的 AC 动作，DC 仅读取验证；从不运行 shell，从不在恢复时切换电源计划。系统设置写入未被 App 连接或启用。

下一轮必须实现并人工验收受保护 Program Files 安装目录链、WinVerifyTrust 签名验证和固定发布者身份、客户端进程身份、UAC 安装/卸载与 SCM 恢复选项，之后才能替换硬拒绝门槛；不能仅删除门槛发布。还必须获得可靠热保护或明确调整产品承诺，并完成合盖/Modern Standby/强杀/重启/外部修改/卸载矩阵。本轮没有执行任何 Windows 原生 API、安装服务或修改电源设置。

Linux 可运行：

```sh
dotnet build windows/service/Awake.Service.csproj
dotnet run --project windows/service-tests/Awake.Service.Tests.csproj
```

模拟测试覆盖固定协议的拒绝、REASON_CONTEXT x64/arm64 大小及 union 偏移、重复启动不增加请求计数、部分申请失败/clear 失败时释放 handle。纯恢复/租约测试在 `windows/tests/`。这些证据不证明真机行为。

实现参考：[PowerCreateRequest](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-powercreaterequest)、[PowerSetRequest](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-powersetrequest)、[NLM connectivity 含义](https://devblogs.microsoft.com/oldnewthing/20230112-00/?p=107700)、[GetConnectivity](https://learn.microsoft.com/en-us/windows/win32/api/netlistmgr/nf-netlistmgr-inetworklistmanager-getconnectivity)。网络仅表示 Windows 检测到本地网络/Internet 路径，不保证 AI 服务可达。热遥测始终 Unknown，电池与合盖能力关闭；没有应用级热保护。PowerRequest 不覆盖主动休眠或合盖休眠。

恢复服务、安装信任链与系统级崩溃恢复尚未完成验收；上述内容是预备源码，不是当前用户可用能力。路径检查仍是按路径进行，不能抵御管理员/SYSTEM本身的并发替换；启用服务之前须在Windows验证ACL继承、ProgramData父级删除权限和使用handle防链接的实际行为。
