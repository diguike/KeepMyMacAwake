# 项目进度与下一会话入口

更新：2026-10-13，服务器 Windows 开发预览与双端仓库重构；同日三视角体验优化见文末。最新验证见文末；0.2.0 / 0.2.1 Mac 记录保留为历史证据。用户明确授权开发、安装、组件注册及验证后推送和合入 main；本轮系统服务安装与真机行为留待本地。

## 已实现并安装

- 原生菜单栏杯子图标、剩余时间、独立控制窗口；暖铜色场景卡片、倒计时圆环、固定启停按钮和独立设置页。正常打开显示控制窗口，登录启动静默留在菜单栏。
- 日常、夜间、接电合盖、有网时四种快捷场景；具体规则可调整。
- 30 分钟、1/2/8 小时、自定义 1–1440 分钟、直到手动停止；有限会话可续时 15 分钟，累计不超过 24 小时，已结束的会话不能续活。
- 三种屏幕模式：自动熄屏、保持常亮、夜间柔光。夜间临时遮罩默认 94%，可调 80–98%，结束撤销；不是硬件背光调节。
- 普通模式使用公开 IOPMAssertion；系统与显示断言分开，停止时释放，不改锁屏规则。
- 接电、电量、网络路径和热压力保护；必需数据未知时停止。断网停止后不自动重启。
- 验证后保存设置；重启只恢复偏好，不恢复活动租约。可设置登录启动和菜单栏倒计时。
- v3 固定 XPC 协议；App/helper 独立监测网络、签名身份校验、连接所有权、20 秒失联保护、write-ahead 恢复记录与先恢复后移除组件。
- SleepDisabled 在 pmset 未输出时读取 IOPMrootDomain 的明确 CFBoolean；不推断缺失为 false。
- 自绘原生 App 图标，版本 0.2.0 / build 2。签名 release 已安装到 `/Applications/KeepMyMacAwake.app`。

## 本机实际验证

环境：Apple Silicon arm64，macOS 26.4.1，Xcode Swift 6.3.1。

- `swift test`：42 项 XCTest 通过，32 项纯逻辑及恢复／偏好测试，10 项 Mac 原生测试。
- 实际取得并读回本进程系统／显示断言，释放后不再持有；普通模式没有显示断言。
- 无限时普通会话实际启停；注入时钟／网络的 App 生命周期测试仍使用真实 IOPMAssertion，验证到期释放、断网停止且不重启、到期不可续时、偏好恢复但不自动开会话。
- 安装版原生 UI 已通过 cua 打开并操作：场景切换、自定义 1 分钟、真实倒计时自动结束、8 小时夜间启动／加 15 分钟／手动停止、退出重开保存偏好；固定启停按钮一直可见。
- 夜间遮罩实际创建、结束撤销，测试读回没有残留可见窗口。多屏／Space／全屏物理组合仍需人工验收。
- SleepDisabled 只读路径成功；本机 `ioreg` 明确为 false。没有执行全局 pmset 写入。
- ad-hoc 和 Apple Development 证书构建、App/helper 严格签名与稳定 designated requirement 校验成功。安装版为 release；未公证。
- 原先无窗口菜单栏 App 的自动化连接问题已通过原生控制窗口解决，完成可见 UI 验收。
- `git diff --check` 无空白错误。

## 2026-10-10 后台组件的实际状态与阻塞（历史）

安装版已通过 SMAppService 注册，状态为 requiresApproval；系统设置中的 KeepMyMacAwake 后台活动开关可见但关闭。启用时 macOS 显示“使用触控 ID 或输入密码允许此操作”，需要本人认证。已取消该认证提示，不代填或绕过。root 服务尚未启动，`launchctl print` 确认服务不存在；没有活动合盖租约或全局设置改动。

修正了首次 `.notFound` 时不注册的问题，以及注册返回 EPERM 但已进入 requiresApproval 时误报失败的问题。App 现在显示“打开系统授权”，清楚说明本人认证步骤。

明天打开 App → 接电合盖 → 打开系统授权 → 通用／登录项与扩展 → 开启 KeepMyMacAwake 后台活动。批准后等待 App 显示“后台组件已连接”，再按 [合盖验收步骤](mac-handoff.md) 从开盖一分钟租约与恢复开始。

尚未执行真实 XPC 租约／pmset 写入、物理合盖、真实拔电或断网、强杀 helper、重启及系统级卸载矩阵。逻辑模拟和普通断言测试不能代替这些结果。没有宣布当前机型的合盖兼容性通过。

## 远端集成

代码提交 `0e4466e` 的 push 与 PR 两轮 CI 全部通过：[PR CI #37972944776](https://github.com/diguike/KeepMyMacAwake/actions/runs/37972944776)、[push CI #37972940156](https://github.com/diguike/KeepMyMacAwake/actions/runs/37972940156)。Linux 32 项逻辑测试；macOS 42 项测试（无跳过）与 ad-hoc 打包成功。

CI 首轮发现旧 Swift 对屏幕变更回调弱引用捕获的并发检查差异，已改为先取得强引用再交给 MainActor；本机重跑 42 项测试与签名 release 构建通过，并更新本机安装。安装版主程序与最终 dist 的 SHA-256 一致，严格签名校验成功。

[PR #1](https://github.com/diguike/KeepMyMacAwake/pull/1) 已于 2026-10-10 02:25（Asia/Singapore）合入 main，合并提交 `669bd71`。本地 main 已快进同步。合并后的 [main CI #37973145079](https://github.com/diguike/KeepMyMacAwake/actions/runs/37973145079) 也全部通过。后续仅提交交付记录，无代码变化。旧 CI 不作为本轮改动证据。

## 后续验证边界

无限时仍受保护条件、退出、失联和重启约束。网络可用路径不保证远端服务可达。全局开关不能识别其他工具中途写入相同值，避免多工具争用。Apple Development 仅用于本机体验；Developer ID、公证与物理验收完成前，不发布正式发行包。

## 0.2.0 Release 下载交付

用户要求在另一台 Mac 下载试用，已于 2026-10-10 发布 [v0.2.0 Pre-release](https://github.com/diguike/KeepMyMacAwake/releases/tag/v0.2.0)，源提交 `2845ada`。同仓库 Release 附件为通用 DMG（约 2.1 MB）、ZIP（约 1.7 MB）和 SHA256SUMS.txt；包内附中文安装说明与 MIT 许可证。

- App 和 helper 均含 arm64／x86_64，最低部署版本均为 macOS 14；双架构严格签名校验通过。DMG 校验、只读挂载签名检查、ZIP 解包后签名检查均成功。
- x86_64 的 42 项 XCTest 在本机 Rosetta 下全部通过。SwiftPM 原生 arm64 测试驱动无法加载 x86_64 测试包，改用 `arch -x86_64 xctest` 执行，未计作物理 Intel 机验证。
- 新增双架构 release 构建后，[CI #38051967579](https://github.com/diguike/KeepMyMacAwake/actions/runs/38051967579) 的 Linux 32 项测试、macOS 42 项测试及通用 ad-hoc 构建全部通过。
- 只有 Apple Development 签名、没有 Developer ID，`spctl` 默认评估实际拒绝；本包未公证。首次下载的单 App 例外和目标机后台本人认证步骤写入 Release 与包内说明，不绕过公司管理限制。

正式稳定发行的边界保持不变；本轮用户明确授权的是跨电脑体验包发布。

公开仓库：https://github.com/diguike/KeepMyMacAwake ，默认分支 main，MIT，作者递归客（diguike）。

## 2026-10-11：0.2.1 UI 刷新修复

用户报告界面隔一段时间刷新。代码检查发现后台 `refresh()` 每秒切换公开 busy，五秒 XPC 轮询等待期间会禁用按钮并改变主按钮文案；未变化的采样与状态也重复发布。夜间模式收到屏幕通知时原先先撤掉全部遮罩再重建，重复通知亦可能导致亮闪。

- 后台轮询使用私有重入标志，公开 busy 仅用于用户操作；相同监控和状态值不再触发 UI 更新。每秒保护和每五秒 helper 心跳频率保持。
- 增加操作代数，防止较旧后台回复或错误覆盖用户刚完成的启停、续时和恢复。
- 夜间遮罩按显示器 ID 复用，只在尺寸、透明度或连接屏幕确实变化时更新；停止后排队通知不能重建遮罩。
- 增加 7 项回归：注入五分钟空闲轮询和 61 次 helper 请求，未变化时无 objectWillChange；无限时会话无无效倒计时更新；异步轮询不阻止开始／停止且旧回复不覆盖；重复屏幕通知复用真实窗口；停止后无遮罩重现。
- arm64 `swift test`：49 项 XCTest 全部通过，无跳过。x86_64 测试包构建后通过 Rosetta `xctest` 执行，同样 49 项通过；不算物理 Intel 验证。
- 0.2.1 / build 3 通用 Apple Development 签名 release 构建通过；DMG 校验和只读挂载、ZIP 解包、App/helper 双架构与严格签名检查均成功。设置页版本改从 Bundle 读取。
- 已通过旧 App 的“停止并移除组件”确认恢复和注销后升级 `/Applications/KeepMyMacAwake.app`；安装版严格签名通过，主程序 SHA-256 与构建产物一致。
- 本轮开始时旧 helper 已批准并运行。升级后通过 App 重新注册，已有系统批准保留，新 helper 可连接。本轮未开启实际合盖租约，恢复后 SleepDisabled 只读明确为 No。
- 安装版 UI 实测：空闲编辑自定义分钟两分多钟后，辅助功能树保持不变、输入焦点仍在原字段，按钮可用。随后实际开启普通一分钟会话；UI 自动显示“设定时间已到”，本进程保活断言释放。设置页显示 0.2.1 与“后台组件已连接”，验收后留在待机。

代码提交 `0024ed7` 的 [push CI #38103734888](https://github.com/diguike/KeepMyMacAwake/actions/runs/38103734888) 与 [PR CI #38103767618](https://github.com/diguike/KeepMyMacAwake/actions/runs/38103767618) 全部通过。[PR #2](https://github.com/diguike/KeepMyMacAwake/pull/2) 已合入 main，合并提交 `9e6de89`；[main CI #38103842400](https://github.com/diguike/KeepMyMacAwake/actions/runs/38103842400) 同样通过。远端 Linux 32 项测试，macOS 49 项测试与双架构构建成功。

[v0.2.1 Pre-release](https://github.com/diguike/KeepMyMacAwake/releases/tag/v0.2.1) 已于 2026-10-11 10:04（Asia/Singapore）公开，tag 指向 `9e6de89`。DMG、ZIP 与 SHA256SUMS.txt 上传后回下载校验通过；安装版与下载包使用同次构建。仍是 Apple Development 签名、未公证的体验包。

上述回归验证了发现的触发路径；用户具体看到的刷新形态尚未补充。物理合盖与多屏／Space／全屏切换矩阵仍待人工验收，不将模拟时钟、XPC 回复或屏幕通知计作物理验证。

## 2026-10-13：Windows 与双端体验方案

已在 Linux 工作区通过 `git pull --ff-only` 同步 main 至 `ebb1cfc`（0.2.1 文档交付提交）。用户反馈曾使用应用完成离线及联网夜间任务；未提供该体验的机型、模式、时长与提交号，不将反馈计入物理合盖验收矩阵。

用户希望宣传时 Windows 用户也能使用，并要求两端尽量接近；本轮明确选择先定双端方案。新增 [windows-plan.md](windows-plan.md)：统一场景、计时、屏幕模式、保护与状态语义，建议 Windows 原生 C# / WPF、独立合盖恢复服务与同仓库组织，并列出能力差异和阶段验收标准。Windows 名称与技术栈是建议，尚未开始编码。

本轮检查：阅读当前场景实现，查阅微软官方电源与 WPF 文档；文档修改运行 `git diff --check`。未修改源码，不运行 Swift 回归；本环境为 Linux，未执行 Windows 构建、API、服务安装或真机验证。没有 Windows 下载包，没有提交、推送或发布。

下一步：用户确定进入开发后，建立普通保活预览，同时验证 Windows 合盖设置恢复、Modern Standby 电池限制和可靠热遥测。未满足保护与恢复门槛的合盖能力保持关闭；双端宣传按实际交付与机型支持范围表述。

## 2026-10-13：服务器开发、产品评审与结构重构

用户后续明确授权服务器实现 Windows 开发、重构整个项目结构，并允许产品经理与实现 Agent 并行评审/开发；依赖电脑的部分留待本地。名称讨论延期，继续使用 KeepMyMacAwake，Windows 标明平台。核心用途为 AI 长任务在用户离开、合盖或夜间休息时继续运行，不自动判断或保证完成。

### 本轮已实现

- 单仓库 `macos/` / `windows/` / `specs/`：Mac 现有源文件、测试、packaging 逐字节与原 main 一致，仅搬路径。根 Package.swift 和 Mac build/release/notarize 脚本兼容入口保留；bundle/helper ID、协议、签名要求与 dist 产物路径不变。
- Windows .NET 10 / WPF 控制窗口与系统托盘：首用说明、保活/设置、同名场景、时长、自定义、无限时、15分钟续时、屏幕模式、柔光、参数保存、登录启动；关闭留托盘，二次启动打开原实例。普通 App asInvoker。
- Windows PowerRequest 真实后端源码，系统/显示请求分开；不会通过续时重复计数；部分申请失败仍清理资源，clear失败仍关闭句柄。供电、电量、NLM网络路径与含休眠时间的时钟源码；热状态始终未知。
- 会话计时、保护停止、时钟跳变、恢复状态、不自动重启规则；系统睡眠/恢复后停止。UI不沿用旧失败原因、不误报合盖就绪；自定义场景展示实际参数，24小时显示总小时，空闲不重复发布未变化状态。
- 合盖事务、write-ahead恢复与20秒失联租约、固定PowrProf设置API、受保护记录与受限服务源码。服务生产签名和可信安装未完成，入口硬拒绝启动；合盖/电池能力关闭，不进入普通用户ZIP，不提供安装入口。
- 共享四场景、九行为JSON合约与Swift/C#验证；Windows注入WPF检查覆盖10项命令、错误、到期、恢复、通知与XAML加载。
- 双端CI、Windows自包含ZIP打包脚本、安装说明和 [Windows交接](windows-handoff.md)。[产品评审](product-review-windows.md) 的旧错误覆盖、场景误导、托盘首次启用和24小时显示问题已按源码修正，原生验收仍独立保留。

### 服务器实际检查

环境：Ubuntu 20.04 x86_64；.NET SDK 10.0.401（运行时10.0.12），位于 `/tmp/keepmymacawake-toolchain/dotnet`。原服务器没有Swift，使用官方Swift 6.0.3镜像执行纯逻辑测试，未安装Mac SDK。

- Swift `swift test`：Docker隔离构建，34项XCTest全部通过（原32项加2项共享合约）。不执行Mac原生测试。
- Windows核心 `dotnet test windows/tests/Awake.Core.Tests.csproj -c Release`：30项通过，无跳过。
- `dotnet run --project windows/service-tests/Awake.Service.Tests.csproj -c Release`：27项协议、ABI和native-request模拟检查通过；不调用Windows API。
- `dotnet build windows/KeepMyMacAwake.slnx -c Release`：7个项目构建成功，0警告、0错误，包含WPF与服务源码。10项WPF注入检查本机仅编译，不在Linux执行。
- `scripts/build-windows.sh`：实际交叉publish win-x64自包含App，生成未签名ZIP与SHA256；服务只编译，不进包。第一次打包遇到服务器Python3.8不支持removeprefix，已改兼容写法并成功重跑。
- Mac搬迁文件逐字节核对；shell语法、JSON/XML/XAML结构与 `git diff --check` 通过。当前本机没有macOS，不直接验证Mac打包与签名。

### 能力与待本地事项

Windows普通预览只开放接电开盖，明确无应用热保护。合盖、电池、签名安装/卸载与可部署恢复服务未完成；不能把内部算法或模拟测试称为系统级恢复已可用。原生PowerRequest、锁屏、柔光多屏/DPI、睡眠通知、强杀请求释放、实际夜间长跑仍需Windows真机验收。

没有发布Windows Release，没有安装系统服务，没有修改真实机器电源设置。Windows现有包用于本地开发交接；Mac仍保持0.2.1体验版。下一步先按windows-handoff.md做普通模式验收，再完善服务信任与恢复矩阵，验证热保护和Modern Standby边界。

### 远端验证与交付

源码提交 `443d4b1` 的 [push CI #38365801719](https://github.com/diguike/KeepMyMacAwake/actions/runs/38365801719) 与 [PR CI #38366426619](https://github.com/diguike/KeepMyMacAwake/actions/runs/38366426619) 四个任务全部通过：

- Linux Swift 34项；Windows核心30项与协议/ABI/请求模拟27项，在Linux及Windows均通过。
- macOS runner实际执行51项XCTest（原49项加共享合约2项），双架构ad-hoc App/helper编译、打包、严格签名校验通过；没有注册服务、改真实设置或物理合盖。
- Windows runner实际执行10项STA/WPF注入检查全部通过，加载真实MainWindow XAML并检查ViewModel；不是操作完整可见UI、不是调用真实PowerRequest或物理验收。
- Windows PowerShell自包含x64打包与CI artifact上传通过。服务器本地产物约70.4MiB；另核对ZIP完整性、SHA256、x64 PE架构、随包运行时、说明/许可证与服务排除。

[PR #3](https://github.com/diguike/KeepMyMacAwake/pull/3) 已于2026-10-13 16:04（Asia/Singapore）合入main，合并提交 `78b1237`。服务器已快进同步；本地可以直接拉取main继续开发。普通功能的Windows原生使用、合盖/电池与签名安装仍按交接矩阵完成，不把CI通过表述为真机功能支持。

## 2026-10-13：三视角体验优化（分支 feat/ux-round）

用户要求从 AI 使用者、产品经理、UI 设计师视角做一轮优化。评审与取舍见 [ux-review.md](ux-review.md)。

### 本轮改动

- 两端：运行中显示“预计（明天）HH:mm 结束”；会话结束后保留“上次 起–止 · 运行时长 · 停止原因”，切换场景不清除，开始新会话时隐藏。只在内存中保留，不跨重启。
- Mac：场景默认值移到核心 `ScenePreset`，契约测试逐字段比对 `specs/scenes.json`；待机标题显示阻塞原因；待机副标题为配置摘要与“已调整”标记；菜单栏倒计时 `7h59m`；欢迎页以 AI 任务为主并说明不判断任务完成。
- Windows：场景按钮选中态（含暗色、高对比度画刷与读屏“已选择”）；配置摘要与 Mac 同序并含屏幕模式；新增 1 项 WPF 注入检查（结束时刻、上次结果、场景选中标志）。
- 文案只描述设计行为：普通模式“不影响锁屏，请保持开盖”；未新增任何平台能力声明。

### 服务器实际检查

- Swift `swift test`（Docker，官方 Swift 6.0.3 镜像）：39 项通过（原 34 项 + 5 项 SessionText / 预设）。不含 Mac 原生测试。
- `dotnet test windows/tests/Awake.Core.Tests.csproj -c Release`：36 项通过（原 30 + 6 项 SessionText，与 Swift 用例相同）。
- `dotnet run --project windows/service-tests/...`：27 项通过。
- `dotnet build windows/KeepMyMacAwake.slnx -c Release`：7 个项目 0 警告 0 错误，含 WPF XAML 编译。11 项 WPF 注入检查只编译，未在 Linux 执行。

### 待验证

- Mac：SwiftUI / AppModel 改动未在本机编译；需 macOS CI 或本机执行 `swift test`（含扩充后的到期原生测试）与 `./scripts/build-macos.sh`，并目视检查菜单栏宽度、副标题换行、上次结果行。
- Windows：Windows runner 执行 `windows/app-tests/`；真机目视检查场景选中态在亮色、暗色、高对比度下的效果。
- 尚未提交 PR、未推送、未发布。下一步：推送分支后由双端 CI 验证；“有网时”改名、结束通知、结果持久化、Windows 首次关窗提示等待用户决定。
