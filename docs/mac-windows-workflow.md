# 在 Mac 上完成双端开发与 Windows 打包

更新：2026-10-14。本轮先在 Mac 完成代码与产物，后续再讨论 Windows 原生验收环境。源码版本：Mac 0.2.2、Windows 0.3.1；尚未发布。

## 工作分工

| 环境 | 能完成的工作 | 证据边界 |
| --- | --- | --- |
| 当前 Mac | Swift 原生测试、Mac 窗口操作、双架构 App；Windows 核心/模拟测试、WPF 交叉编译、x64/ARM64 ZIP 与 EXE 安装器 | Windows 包生成不等于已运行 Windows App |
| Windows 11 虚拟机或远程 Windows 开发机 | WPF 注入检查、实际窗口/托盘、主题、通知、安装/升级/卸载 | 虚拟机电源与合盖行为不能代表物理笔记本 |
| Windows 物理电脑 | PowerRequest、锁屏持续任务、拔电/睡眠、长时间运行；未来合盖与恢复矩阵 | 按机型、系统、睡眠模型记录，不能泛化 |

WPF 运行依赖 Windows，Mac 可通过 `EnableWindowsTargeting` 下载目标包并编译。项目已开启此配置。自包含发布包含对应 Windows 运行时，使用者无需安装 SDK。[微软跨平台构建说明](https://learn.microsoft.com/en-us/dotnet/core/tools/sdk-errors/netsdk1100)、[WPF 平台说明](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/overview/)、[自包含部署](https://learn.microsoft.com/en-us/dotnet/core/deploying/)。

## Mac 开发工具

需要 Xcode Command Line Tools / Swift、.NET 10 SDK、Python 3.8+。EXE 安装器另需 NSIS `makensis`；可通过 Homebrew 安装 `makensis`。

本轮采用微软官方安装脚本，把 SDK 放到用户目录 `~/.local/share/keepmymacawake/dotnet`，不改全局 PATH。该脚本适合隔离工具链；长期标准开发环境也可使用微软官方 macOS SDK 安装器。[SDK 安装脚本](https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-install-script)。

在仓库根目录，仅为当前终端设置：

```sh
export AWAKE_DOTNET="$HOME/.local/share/keepmymacawake/dotnet/dotnet"
./scripts/validate-local.sh
ARCHITECTURES='arm64 x86_64' CONFIGURATION=release ./scripts/build-macos.sh
open dist/KeepMyMacAwake.app
```

`validate-local.sh` 依次运行 Swift 测试、Windows 核心测试、服务模拟检查、完整 .NET 编译和空白检查。它不会在 Mac 尝试执行 WPF 检查，也不会安装后台服务或改系统电源设置。Mac 默认 ad-hoc 产物只用于普通模式，合盖仍需证书签名与独立验收。

## Windows 用户包

```sh
./scripts/build-windows.sh
./scripts/build-windows-installer.sh
AWAKE_WINDOWS_RUNTIME=win-arm64 ./scripts/build-windows.sh
AWAKE_WINDOWS_RUNTIME=win-arm64 ./scripts/build-windows-installer.sh
```

每个架构分别输出到 `dist/windows/win-x64/` 或 `dist/windows/win-arm64/`：

- `KeepMyMacAwake-0.3.1-Windows-<架构>-preview.zip`：解压后双击使用。
- `KeepMyMacAwake-0.3.1-Windows-<架构>-setup-preview.exe`：中文图形安装器，Windows 11，当前用户安装。
- `SHA256SUMS.txt`：同时覆盖 ZIP 和 EXE。

安装器固定使用当前用户的 `LocalAppData/Programs/KeepMyMacAwake`，提供开始菜单入口与系统卸载入口，不要求管理员权限。升级/卸载用固定事件请求 App 停止退出，再等待单实例互斥锁交接；20 秒仍未确认时退出非零，安装器中止。卸载只删除包内文件和属于本安装的登录启动项，保留偏好与最近一次结果。[NSIS 权限与脚本说明](https://nsis.sourceforge.io/Docs/Chapter4.html)。

普通包不包含未开放服务，合盖/电池能力继续关闭，安装器不会更改合盖设置。安装器是未签名开发预览；生成和静态检查已在 Mac 完成，实际安装/卸载仍需 Windows。现有旧 ZIP 用户应先停止退出，再安装；不要通过覆盖活动程序升级旧便携包。

重新发布 ZIP 前，脚本要求移走上次的 `dist/windows/<runtime>/app`，保证输出目录干净。仅操作生成目录；源码与用户设置无需清理。SDK 与包输出都不提交到 Git。

## Windows 环境接续

Apple Silicon Mac 可把 ARM64 包交给 Windows 11 ARM 虚拟机；使用 x64 Windows 远程机时交付 x64 包。具体虚拟机产品、授权与设备选择留待讨论。本轮没有安装虚拟机或创建远程设备。

在 Windows 工程目录运行 `dotnet run --project windows/app-tests/Awake.App.Tests.csproj -c Release`，执行 14 项 WPF 注入检查，其中包括结果持久化、通知默认关闭、首次关窗提示、安装退出交接的确认/超时。再通过实际 GUI 完成安装、运行中升级、释放失败中止、卸载/登录启动清理、通知与三种主题验收，记录在 [Windows 交接](windows-handoff.md)。

上述注入检查本轮只在 Mac 编译，未执行；上一轮远端 11 项通过不能覆盖本轮新增项。物理 Windows 与 Mac 合盖矩阵继续独立验收。AI 任务绑定仍属后续产品阶段，本轮不判断任务完成。
