# Windows 开发预览

品牌暂保留 KeepMyMacAwake，窗口标注 Windows；本地版本 0.3.1，尚未发布。使用 .NET 10 / WPF，普通用户无需命令行。

| 目录 | 职责 |
| --- | --- |
| app | WPF / 托盘、偏好、柔光、登录启动，普通用户身份 |
| core | 可移植会话、保护、恢复事务与服务租约 |
| platform | 原生电源请求、采样、固定合盖设置 API |
| service | 未开放的特权恢复服务，入口硬拒绝运行 |
| tests | 核心 xUnit + 双端合约 |
| service-tests | 协议、ABI 与电源请求模拟检查，可在 Linux 跑 |
| app-tests | Windows STA / WPF 注入检查，不调用真实电源后端 |
| packaging | 普通用户安装与移除说明 |

在仓库根目录 `dotnet build windows/KeepMyMacAwake.slnx -c Release`。`scripts/build-windows.ps1`（Windows）或 `scripts/build-windows.sh`（服务器）打包自包含 ZIP。Mac 独立使用根 `Package.swift`。

普通保活源代码已实现，当前能力仅接电开盖、没有应用热保护；合盖与电池硬禁用，且不自动降级场景。服务不进入用户 ZIP，不提供安装入口。系统睡眠 / 恢复后会话结束；断网保护后不自动重新开启。

源码构建、模拟检查、注入 WPF 检查与原生真机验收分开记录。当前服务器不能验证真实 Windows 行为，下一步见 [本地交接](../docs/windows-handoff.md)，服务安全门槛见 [service/README.md](service/README.md)。

2026-10-14 已在 Mac 完成 x64 / ARM64 自包含包及 NSIS 图形安装器构建。新增最近结果持久化、默认关闭的结束通知、首次关窗托盘提示；外出合盖保留内部 `Network` 标识与原条件。`scripts/build-windows-installer.sh` 在 ZIP publish 后生成当前用户安装器，升级/卸载先请求 App 停止并退出。Windows 实际 GUI / IPC / 安装矩阵仍待验收，流程见 [Mac 双端工作流](../docs/mac-windows-workflow.md)。
