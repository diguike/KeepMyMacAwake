# KeepMyMacAwake

原生 macOS 菜单栏应用：**合盖继续运行，到时恢复休眠。**

现扩展为同仓库的 Mac / Windows 原生客户端，名字暂保留 KeepMyMacAwake。核心用途：让已启动的 AI 长任务在你离开或休息时继续运行。Mac 体验版仍为 0.2.1；Windows 0.3.0 为服务器开发预览，支持范围与验证证据分别记录。

由 [递归客](https://github.com/diguike) 开源，MIT 许可证。

当前是 **0.2.1 本机体验版**：修复后台轮询导致按钮周期性闪动、未变化的状态重复刷新，以及屏幕通知重建夜间遮罩的问题。保留场景、永久保活、夜间柔光、续时和设置保存。2026-10-11 在 Mac 本机通过 49 项测试（含 17 项原生验证）；具体证据和远端 CI 见 [实际进度](docs/status.md)。合盖组件需要目标 Mac 本人批准，物理合盖仍待验收。本机使用 Apple Development 签名，尚未公证。

## 下载体验包

[下载 0.2.1（GitHub Release）](https://github.com/diguike/KeepMyMacAwake/releases/tag/v0.2.1)。macOS 14+，DMG 和 ZIP 均包含 Apple Silicon / Intel 双架构。DMG 打开后把 App 拖到 Applications；ZIP 解压后放入“应用程序”。包内含中文安装说明。

这是 Apple Development 签名的 **未公证体验版**，首次下载可能需要系统设置中的单 App “仍要打开”；具体见 Release 和 [Apple 说明](https://support.apple.com/zh-cn/102445)。合盖功能需要在目标 Mac 单独批准后台组件，物理合盖兼容性尚待验收。

## 功能

- 普通防闲置休眠，允许屏幕关闭和正常锁屏。
- 定时 30 分钟、1/2/8 小时、自定义 1–1440 分钟，或直到手动停止；有限会话可续时 15 分钟。
- 日常、夜间、接电合盖、有网时四种场景快捷入口。
- 夜间临时画面变暗遮罩（非硬件亮度），结束自动撤销；可单独设置屏幕常亮。
- 可选断网时停止；电池模式仍受电量和热状态保护。
- 合盖实验模式：图形化安装与批准独立 helper，后端确认后显示就绪。
- 默认仅接电；电池模式显式开启，可设置电量保护下限。
- 严重热压力持续 30 秒或临界热状态时停止；保护数据未知时停止。
- helper 维护有限期租约、20 秒失联截止和持久化恢复记录；进程重启先恢复遗留设置。
- 菜单栏显示剩余时间，独立控制窗口方便操作；自动记住偏好，重启不会自动保活。
- 设置提供恢复、登录启动和停止并移除后台组件。
- 网络路径与电源状态分别显示；未知状态不会显示为正常。

## 在 Mac 上开发

要求 macOS 14+、Xcode 或 Command Line Tools，Swift 5.9+。产品由 Swift Package 和打包脚本构建，不需要生成 Xcode 工程。

```sh
git clone https://github.com/diguike/KeepMyMacAwake.git
cd KeepMyMacAwake
swift test
./scripts/build-macos.sh
open dist/KeepMyMacAwake.app
```

默认构建为 ad-hoc 预览，**只开放普通防闲置休眠**。它可用于本地 UI 开发，不是可分发的公证安装包。可用 `open Package.swift` 在 Xcode 中编辑。

合盖 helper 需要证书签名构建；先用 `security find-identity -v -p codesigning` 查找本机身份，再构建：

```sh
CONFIGURATION=release SIGN_IDENTITY='Apple Development: Your Name (TEAMID)' ./scripts/build-macos.sh
```

将 App 放到固定位置（建议 `/Applications`）。打开后可直接体验普通保活和夜间柔光；菜单栏杯子图标打开紧凑面板。合盖场景点击“安装 / 检查授权”或“打开系统授权”，在系统设置 → 通用 → 登录项与扩展开启 KeepMyMacAwake 后台活动，并使用触控 ID 或登录密码批准。首次合盖测试必须按照 [Mac 交接清单](docs/mac-handoff.md) 操作。不要在活动会话中移动或覆盖 App。

签名和公证脚本见 [分发说明](docs/distribution.md)。仓库不包含任何签名证书或凭据。

## Windows 开发预览

WPF 控制窗口与系统托盘、日常 / 夜间场景、定时 / 无限时 / 加 15 分钟、屏幕模式、断网停止、偏好及登录启动已实现源码。普通保活采用公开 PowerRequest，不模拟键鼠、不改变锁屏策略。

**此预览只开放接电、开盖保活；合盖和电池保活关闭，应用热保护不可用。** 合盖恢复逻辑、固定设置后端和受限服务源码已准备；后台服务缺少可信安装和签名身份验收，入口硬拒绝启动，不进入用户 ZIP。首次打开显示边界，未支持场景不会静默降级。

服务器可运行 Windows 纯逻辑 / 模拟检查并跨编译 WPF。Linux 编译成功不证明真实锁屏、熄屏、夜间长跑或合盖行为；Windows 本地验收见 [Windows 交接](docs/windows-handoff.md)。当前没有公开 Windows Release。

开发要求 .NET 10 SDK。Windows 上运行：

```powershell
dotnet build windows/KeepMyMacAwake.slnx -c Release
dotnet test windows/tests/Awake.Core.Tests.csproj -c Release
dotnet run --project windows/service-tests/Awake.Service.Tests.csproj -c Release
dotnet run --project windows/app-tests/Awake.App.Tests.csproj -c Release
dotnet run --project windows/app/Awake.App.csproj -c Release
./scripts/build-windows.ps1
```

最后一步生成自包含、未签名体验 ZIP，普通用户解压后双击 `KeepMyMacAwake.Windows.exe`，不需要安装 SDK。服务器使用 `./scripts/build-windows.sh` 交叉打包；`.NET` 路径可通过 `AWAKE_DOTNET` 指定。不会自动安装服务或发布产物。

## Linux 上验证

安装 Swift 5.9+ 后运行：

```sh
swift test
```

该 Swift 命令只构建 Mac 可移植逻辑及测试，不构建 SwiftUI、IOKit、XPC 或 ServiceManagement。测试使用模拟电源后端，不能证明实际合盖工作或真实崩溃恢复。Windows 的 `dotnet test windows/tests/Awake.Core.Tests.csproj` 和 `dotnet run --project windows/service-tests/Awake.Service.Tests.csproj` 也可在 Linux 执行，不调用 Windows 电源 API。

## 源码

| 目录 | 内容 |
| --- | --- |
| `macos/` | 原有 App、core、helper、shared、tests、native-tests、packaging 与平台脚本 |
| `windows/app/` | WPF 控制窗口、系统托盘、柔光、偏好与登录启动 |
| `windows/core/` | 场景、会话、保护、合盖恢复与独立租约逻辑 |
| `windows/platform/` | PowerRequest、Windows 采样与固定合盖设置后端 |
| `windows/service/` | 被安全门槛禁用的恢复服务源码；不能安装或运行 |
| `windows/tests/` / `service-tests/` / `app-tests/` | 核心、模拟请求及 Windows WPF 注入集成检查 |
| `specs/` | 两端共用场景与行为测试数据 |
| `scripts/` | 保留 Mac 兼容入口，增加 Windows 构建打包入口 |

根目录 `Package.swift` 保持 `swift test` / `open Package.swift` 入口。Mac bundle ID、helper 名称、协议、签名要求和构建产物位置没有改名。

## 使用边界与卸载

合盖后端使用系统级 `pmset disablesleep`，兼容性尚未验证，可能影响手动睡眠。发现已被其他工具启用时拒绝接管；系统级开关没有可归属的多方所有权，不能识别另一个工具中途写入相同值。请避免同时使用多个合盖保活工具。

只在通风桌面上使用。热状态不是温度读数，也无法检测电脑是否在包内。恢复设置只撤销本应用改动，不保证电脑立即入睡。管理策略、权限或遥测不可用时应显示原因，不绕过企业限制。

卸载前点击“停止并移除后台组件”，确认成功后再删除 App。不要在活动会话中直接删除 App 或关闭系统后台权限：这可能阻止 helper 重启及恢复，详见 [故障恢复](docs/mac-handoff.md)。

## 文档

[进度与待验证项](docs/status.md) · [Mac 交接](docs/mac-handoff.md) · [技术设计](docs/architecture.md) · [验证矩阵](docs/validation.md) · [产品范围](docs/product.md) · [决策](docs/decisions.md) · [研究](docs/research.md) · [资料](docs/references.md)

Windows 的体验对齐、产品评审和本地接续见 [双端方案](docs/windows-plan.md) · [产品评审](docs/product-review-windows.md) · [Windows 交接](docs/windows-handoff.md)。

参与开发前请读 [AGENTS.md](AGENTS.md) 和 [CONTRIBUTING.md](CONTRIBUTING.md)。
