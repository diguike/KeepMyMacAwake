# Windows 本地开发与验收交接

更新：2026-10-14。品牌保留 KeepMyMacAwake；本地 Windows 开发预览 0.3.1，Mac 源码 0.2.2，公开 Mac 体验包仍为 0.2.1。本轮 Mac 实际记录见 status.md，以下保留原服务器交接说明。

## 服务器已准备什么

同仓库 `macos/`、`windows/`、`specs/` 分层；Mac 原有 Swift 源码仅搬目录，根 `swift test`、构建脚本、bundle ID、签名身份与产物路径保留。Windows WPF、系统托盘、会话与屏幕模式、监控后端、纯逻辑恢复事务、固定设置后端、受限服务源码均已准备。

当前可用功能的目标是 **接电开盖普通保活**，允许熄屏或选择常亮 / 柔光，支持定时 / 无限时 / 续时、可选网络条件、偏好与登录启动。不能宣称真实 Windows 已验收；服务器仅执行纯逻辑、模拟检查及交叉编译。合盖和电池模式不可用，应用没有可靠热保护。

`windows/service/` 启动入口硬拒绝，不能安装、运行或打进用户 ZIP。签名、可信安装器、客户端身份、目录操作的系统级验证尚未完成。内部恢复算法与模拟测试不是已部署的崩溃恢复机制。

源码已通过 [CI #38365801719](https://github.com/diguike/KeepMyMacAwake/actions/runs/38365801719)：Windows实际执行10项WPF注入检查、构建与PowerShell打包，Mac实际执行51项测试及双架构打包；不含物理合盖或真实Windows电源请求验收。[PR #3](https://github.com/diguike/KeepMyMacAwake/pull/3) 已合入main，可直接拉取。

## 在 Windows 上打开工程

首个验收环境建议受支持的 Windows 11 x64；安装 .NET 10 SDK，IDE 可用支持此 SDK 的 Visual Studio 或 VS Code。普通用户最终使用自包含 ZIP，不安装 SDK。

在仓库根执行：

```powershell
git pull --ff-only
dotnet build windows/KeepMyMacAwake.slnx -c Release
dotnet test windows/tests/Awake.Core.Tests.csproj -c Release
dotnet run --project windows/service-tests/Awake.Service.Tests.csproj -c Release
dotnet run --project windows/app-tests/Awake.App.Tests.csproj -c Release
dotnet run --project windows/app/Awake.App.csproj -c Release
```

WPF 注入检查覆盖真实 ViewModel 命令与 MainWindow XAML 加载，使用假电源后端、注入时钟和临时偏好目录；不调用真实电源 API、不修改登录启动。这仍不同于实际使用 App 与物理测试。

需要在 Visual Studio 打开 `windows/KeepMyMacAwake.slnx`；根 `Package.swift` 是 Mac / Swift 入口。

## 打包给普通用户

```powershell
./scripts/build-windows.ps1
```

生成 `dist/windows/win-x64/` 下的未签名自包含 ZIP 与 SHA256SUMS.txt。将整个 ZIP 解压到固定目录，双击 KeepMyMacAwake.Windows.exe；不要只复制一个 EXE。不要以管理员身份运行普通 App。

脚本拒绝复用已存在的 `dist/windows/<runtime>/app`，避免把旧二进制混进新包。重新打包时先退出旧应用，将此生成目录移走或清理后再构建。脚本会构建服务供开发检查，但不会把服务放进用户包，也不会安装服务。

Linux 服务器可以 `AWAKE_DOTNET=/path/to/dotnet ./scripts/build-windows.sh`，需要 Python 3.8+；构建后的 Windows 包不能在 Linux 运行。ARM64 可用 `-Runtime win-arm64` / `AWAKE_WINDOWS_RUNTIME=win-arm64` 准备编译，但必须另记本机验收，首个交付只标 x64。

当前没有 Authenticode 证书或已验收的 Windows 分发信誉。Windows / 企业策略阻止包运行时不要关闭防护、放宽策略或改成管理员启动来规避。正式分发需签名与 SmartScreen / 目标系统验收。

2026-10-14 增加 NSIS 当前用户 EXE 安装器；Mac 已生成 x64 / ARM64 包，命令见 [Mac 双端工作流](mac-windows-workflow.md)。安装器不提升权限、没有服务，升级/卸载先请求应用停止退出；20 秒未确认则中止。需在 Windows 补充验证：首次安装/开始菜单、活动会话升级、释放失败拒绝覆盖、卸载移除属于本安装的登录项、保留偏好、架构不匹配拒绝、通知与首次关窗提示。本轮 14 项 WPF 注入检查只编译，尚未执行。

## 普通模式先验收

每项记录型号、Windows 版本/构建、提交、应用版本、电源、睡眠模型、外接显示器、网络/VPN、锁屏状态、测试时长与实际结果。

| 项目 | 操作与期待 |
| --- | --- |
| 首次打开 | 欢迎页明确接电、开盖与无应用热保护，开始使用后托盘命令立即可用 |
| 关闭 / 重开 | 关闭窗口留托盘；再次启动同一个 EXE 打开原窗口，不创建第二个会话 |
| 普通一分钟 | 接电开盖、启动连续任务心跳、一分钟会话；到期释放本应用请求，显示设定时间已到 |
| 自动熄屏 | 屏幕按系统超时熄灭；任务心跳持续。用只读 `powercfg /requests` 核对本进程请求 |
| 常亮 / 柔光 | 两者持有显示请求；柔光不冒充硬件亮度，停止后遮罩撤销 |
| 多屏 / DPI | 多缩放比例、屏幕插拔、任务栏位置、全屏应用切换；遮罩按屏幕复用，不遮住托盘与控制窗口 |
| 外观 / 可访问性 | 系统明暗主题、高对比、键盘、读屏与窗口缩放；检查控件文字可读和启停入口可达 |
| 锁屏 | 锁屏规则继续生效，遮罩撤下；独立记录任务是否持续和请求状态，解锁不复活已结束会话 |
| 断网 | 只有勾选断网停止时结束；路径恢复不重新启动。路径可用不等于指定AI服务可达 |
| 拔电 | 此预览始终结束普通会话，不以未验证电池模式继续 |
| 手动睡眠 / 恢复 | 系统睡眠后结束会话，不自动重新保活；醒来不能假显示活动请求 |
| 无限时 / 续时 | 无限时保留保护；有限时加15分钟，总计不超24小时，24小时显示24:00:00 |
| 不支持场景 | 接电合盖 / 外出合盖（原有网时）默认参数不能启动；用户显式取消合盖、改成仅接电后显示已自定义及实际规则 |
| 偏好 / 重启 | 保存有效偏好；重新打开保持待机。非法文件或字段有明确提示，不恢复活动任务 |
| 强杀 | 普通App强杀后系统请求是否释放；程序句柄的设计意图需实际核对，不把模拟清理当证据 |
| 登录启动 | 使用已打包EXE启用；重新登录后静默留托盘、保持待机；移动路径前关闭此设置 |
| 移除 / 升级 | 关闭登录启动、停止、退出，再替换或删除完整目录 |

只读诊断 `powercfg /a` 用于辨别 S3 / Modern Standby；`powercfg /requests` 用于核对电源请求。不要提交包含机器或用户隐私的完整日志。实际锁屏、API返回成功、计时测试和长时间夜间运行分别记录，不互相代替。

## 合盖本地开发门槛

依赖真机的工作留在此处，不能仅删除服务拒绝入口就发布：

1. 完成 Program Files 安装与目录链、程序/服务签名、WinVerifyTrust 固定发布者、连接客户端进程身份及升级路径；普通 UI 不提升权限。
2. 完成固定操作 IPC 和按用户/连接绑定的租约；不得提供任意命令、文件路径、电源计划 GUID 或任意设置参数。当前管理员查询原型不等于最终普通用户授权方案。
3. 可信安装器预置 ProgramData 保护目录；在 Windows 验证 ACL、重解析点、文件句柄与重命名竞争，SCM 崩溃自动重启、启动先恢复和卸载前恢复。记录异常不可读时不能当作没有遗留设置。
4. 用固定电源 API 临时改 AC 合盖动作，记录原方案/基线/所有权，只恢复本应用的字段；计划切换或第三方改动时不强行覆盖。相同值的外部写入仍有所有权辨识边界。
5. 建立可靠热遥测或明确重新审议合盖保护标准。通用 WMI 温度不能默认可靠；数据未知时不能显示热保护正常。
6. 独立验证接电合盖的连续任务；电池及 Modern Standby 另做矩阵。原生请求存在系统边界，不能假定无限时等于不限平台条件。
7. 验证20秒失联、服务强杀、App强杀、重启、写入后立刻异常、恢复失败留记录/重试、外部改值、升级和卸载。

更多设计与官方依据见 [双端方案](windows-plan.md)、[产品评审](product-review-windows.md)、[服务说明](../windows/service/README.md)。
