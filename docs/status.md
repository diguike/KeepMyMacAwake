# 项目进度与下一会话入口

更新：2026-10-15，Mac 0.4.0 中性配色与质感修订、文案精简与菜单栏信息面板；v0.4.0 Pre-release 已发布并安装到本机。最新验证见文末，既有本地验证、发布与 CI 记录保留为历史证据。

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
- [PR #4](https://github.com/diguike/KeepMyMacAwake/pull/4) 的 [push CI #38389490270](https://github.com/diguike/KeepMyMacAwake/actions/runs/38389490270) 与 [PR CI #38389519211](https://github.com/diguike/KeepMyMacAwake/actions/runs/38389519211) 全部通过：macOS runner 编译 SwiftUI 改动并执行 56 项 XCTest（含扩充的到期原生测试）、ad-hoc 打包成功；Windows runner 执行 11 项 WPF 注入检查全部通过。CI 不代替菜单栏宽度、换行和三种主题的目视检查。
- 2026-10-14 已通过 PR #4 合入 main（`bdea7ae`）；未发布新版本。下一步：“有网时”改名、结束通知、结果持久化、Windows 首次关窗提示等待用户决定。

## 2026-10-14：体验优化主分支交付

用户明确要求全部本地代码合入主分支并推送远端。[PR #4](https://github.com/diguike/KeepMyMacAwake/pull/4) 已于 2026-10-14 00:16（Asia/Singapore）合入远端 main，合并提交 `bdea7ae`，包含代码提交 `bb1b361` 和 CI 记录提交 `5a691a2`。服务器本地已切换到 main 并快进同步；全部本地分支提交均已包含在 main 中。

本轮检查：重新同步远端，核对原 push / PR CI 均成功；确认最新分支提交只修改 docs/status.md，代码与通过验证的 `bb1b361` 相同；`git diff --check` 通过。合并后源码树与原体验优化分支完全一致，无冲突。

合并后的 [main CI #38429199645](https://github.com/diguike/KeepMyMacAwake/actions/runs/38429199645) 四个任务全部通过：Linux Swift 测试、Linux Windows 核心与服务模拟检查、Mac 测试及双架构打包、Windows 构建与核心／模拟／WPF 注入检查及自包含打包。本轮未修改源码，未在服务器重复运行平台测试；本交付记录仅为文档更新。未增加功能或发布安装包；原生 UI 目视检查、物理合盖和 Windows 真机矩阵仍按上文及交接文档完成。

## 2026-10-14：Mac 本地评审落实与 Windows 安装包

用户要求拉取最新代码，把仓库内修改意见在本地完成，明确还需要 Windows 版与安装包，开发完再讨论 Mac 上的流程。已从干净 main 快进到 `23e6bdd`，在本地分支 `codex/local-review-completion` 工作；远端 PR #3/#4 没有未处理评论。未修改远端 main，未发布新 Release。

### 已完成

- 双端最近结果从仅内存改为本机结构化保存，显示完整日期/时间、运行时长和停止原因。只保留最近一次已结束会话，不恢复活动租约、不保存任务内容；错误记录不会冒充成功恢复。
- 双端结束通知默认关闭。Mac 只在设置开启时请求系统允许，处理拒绝和过期授权回复；Windows 使用托盘气泡。重复轮询、切场景和重新打开均不重复发结束通知。
- Windows 首次关窗的托盘去向提示与跨重启标记；点击提示重开控制窗口。场景切换保留通知偏好。
- “外出合盖”替换“有网时”的显示名称，内部字符串/枚举与场景规则保留，旧偏好兼容；共享 JSON 和双端契约检查比对显示名称。
- Windows NSIS 中文图形安装器：Windows 11，当前用户 LocalAppData 安装、开始菜单和系统卸载入口，不提升权限、不打包或安装未开放服务。升级/卸载先通过固定事件请求 App 停止退出，最多等待 20 秒互斥锁交接；未确认则中止。卸载只删除清单内文件与属于本安装的启动项，保留偏好/最近结果。
- Mac 实际检查发现 ad-hoc 预览会尝试查询已安装签名 helper，并影响待机退出；已修复为普通预览不连接或移除该组件。原生读屏场景名称同步改为“外出合盖”；保护数据未知时不显示准备好。
- 本地源码版本 Mac 0.2.2 / build 4，Windows 0.3.1。新增 `scripts/validate-local.sh`、Windows 安装器脚本与 [Mac 双端工作流](mac-windows-workflow.md)。AI 任务绑定继续属于原定后续产品阶段。

### 本机实际检查

环境：Apple Silicon arm64、macOS 26.4.1、Swift 6.3.1、.NET SDK 10.0.401。SDK 使用微软官方脚本隔离安装到用户目录；Homebrew NSIS 3.12 和 7-Zip 26.03 用于编译与检查产物。没有 Windows 虚拟机或远程 Windows 运行环境。

- 同步后基线 `swift test` 56 项通过。最终 `scripts/validate-local.sh`：Swift 61 项（39 核心 + 22 Mac 原生）通过，无跳过；Windows 核心 39 项通过，协议/ABI/请求模拟 27 项通过；7 个 .NET 项目构建 0 警告、0 错误；空白检查通过。
- 新增 Mac 原生回归覆盖已结束结果重开不续跑/不重发通知、默认关闭与拒绝通知、损坏结果不恢复会话、未知电源不就绪、ad-hoc 不查询已安装 helper。测试通知使用注入回调，不请求真实通知权限。
- `ARCHITECTURES='arm64 x86_64' CONFIGURATION=release ./scripts/build-macos.sh` 生成双架构 ad-hoc App/helper；严格签名与两个二进制架构检查通过。不是证书签名或公证包，没有更新 `/Applications` 的既有签名安装版，也没有重新注册 helper。
- 本地 Mac 原生 UI：日常自定义一分钟会话真实倒计时到期，显示完整日期/时间和“运行 1 分钟 · 设定时间已到”；主启停入口始终可见，结果行与设置通知开关/说明目视可读。新构建重开后结果仍在、保持待机，读屏报告“选择外出合盖场景”。通过 App 正常退出，精确进程查询及 `pmset -g assertions` 没有该预览进程或 KeepMyMacAwake 保活断言残留。
- Windows x64 与 ARM64 分别交叉 publish 自包含 ZIP，并由 NSIS 生成 EXE 安装器，输出到 `dist/windows/win-x64/`、`dist/windows/win-arm64/`。ZIP 完整性、对应 PE 架构、GUI/asInvoker、随包运行时、中文说明/许可证与服务排除检查通过；ZIP / EXE 最终 SHA-256 均复核通过。
- 7-Zip 检查/解包两个 NSIS 安装器，逐文件比对 x64 的 479 个、ARM64 的 478 个应用文件与对应 publish 输出，全部一致；卸载程序存在，服务排除，安装器 asInvoker。解包检查不计为实际 Windows 安装或卸载。
- 新增 3 项 WPF 注入检查，总数 14：结果重开、通知/首次托盘提示、安装退出交接确认/超时；本轮仅交叉编译，未执行。旧 CI 的 11 项结果不是本轮新增代码验证。
- shell 语法与 `git diff --check` 通过。构建产物、运行日志、用户偏好及本机 SDK 不提交到仓库。

### 尚需原生/物理验收

Windows：执行 14 项 WPF 注入检查；实际主题、通知、首次关窗、安装/升级/卸载、退出事件与请求释放；真实锁屏任务、拔电/恢复和夜间长跑。Windows 合盖/电池与特权服务的原有安全门槛保持关闭。

Mac：实际系统通知投递未验收；本轮使用默认关闭与注入回调验证授权/发送逻辑。物理合盖、多屏/Space/全屏组合、完整 helper 故障恢复矩阵与公证仍按既有交接完成。本轮没有全局 pmset 写入、helper 注册或物理合盖操作。

下一步讨论采用 Windows 11 ARM 虚拟机还是远程/物理 Windows 环境，按 mac-windows-workflow.md 接续；Windows 虚拟机不能代替笔记本物理合盖。新代码没有远端 CI；本轮按用户要求先保留本地代码和产物。

## 2026-10-14：GitHub Windows 流程

用户已明确选择优先用 GitHub 完成 Windows 测试、打包和界面报告，本地 Windows 环境后续再调研。已新增双架构 CI、手动 windows/all 入口、Windows NSIS PowerShell 打包与包核验、临时主机安装器生命周期检查，以及 63 张真实 WPF 控件渲染图片/HTML/JSON 报告。应用和报告复用主题资源；Windows 页脚改读实际版本，修复原先硬编码 0.3.0。

本机检查：7 个 .NET 项目交叉构建 0 警告/0 错误；核心 39 项、协议/请求模拟 27 项通过；workflow YAML 解析与空白检查通过。WPF 渲染和 PowerShell/NSIS/安装器生命周期随后在 GitHub 实际执行，结果见下文。Mac 源码未再修改，前一轮 61 项本机结果保留，远端再次执行双端回归。

操作说明见 github-windows-build.md，实际运行、修复和下载回执见下文。尚未创建 Release，也没有安装本地 Windows 环境。

### 实际 GitHub 执行与集成

最终代码提交 ac5595d 的 [push CI #38442050479](https://github.com/diguike/KeepMyMacAwake/actions/runs/38442050479) 与 [PR CI #38442056254](https://github.com/diguike/KeepMyMacAwake/actions/runs/38442056254) 五个任务全部通过。每个 Windows 架构实际执行核心 39 项、协议/后端模拟 27 项、WPF 注入 14 项；生成 63 张 PNG，渲染/绑定错误为 0；EXE/ZIP 包核验及 5 项实际静默安装器生命周期检查通过。Linux Swift 39 项、macOS 61 项及双架构 ad-hoc 构建通过。

从 GitHub 下载了最终双架构报告，复核 JSON 全部通过、126 张图片齐全；目视检查浅/深/高对比资源及自定义分钟、跨日结果示例。前一版 1e02bd9 的双架构 EXE/ZIP 已回下载并核对 SHA-256；ac5595d 只调整报告模拟数据，最终 CI 对各自包再次执行完整校验。

实际运行中修复：NSIS 使用兼容 Mac/Windows 的路径分隔符；静默拒绝返回错误码 2，避免等待不可见提示；升级测试等待实际更新事件就绪，并确认正在运行的打包 App 正常退出。报告复审发现暗色页签/主按钮受到隐式 TextBlock 样式影响，已明确文字颜色；Windows 版本显示从程序集读取。一次性 CI 检查保留既有用户数据的守卫，不能用于自托管或本地主机。

[PR #5](https://github.com/diguike/KeepMyMacAwake/pull/5) 于 2026-10-14 01:59（Asia/Singapore）合入 main，合并提交 4f65fcc。本地 main 已快进同步，合并源码树与通过验证的 ac5595d 完全相同。GitHub 默认分支已有 Run workflow 的 windows/all 手动入口；合并后的 [main CI #38443061474](https://github.com/diguike/KeepMyMacAwake/actions/runs/38443061474) 五个任务也全部通过。

main CI 产物可直接下载：[Windows x64 包](https://github.com/diguike/KeepMyMacAwake/actions/runs/38443061474/artifacts/11837561540)、[Windows ARM64 包](https://github.com/diguike/KeepMyMacAwake/actions/runs/38443061474/artifacts/11837941831)、[x64 界面/测试报告](https://github.com/diguike/KeepMyMacAwake/actions/runs/38443061474/artifacts/11837101607)、[ARM64 界面/测试报告](https://github.com/diguike/KeepMyMacAwake/actions/runs/38443061474/artifacts/11837696872)。附件保留 14 天，过期后可通过手动入口重新生成；报告解压后在 Mac 打开 ui/index.html。版本仍是未签名 Windows 0.3.1 开发预览，不是公开 Release。

本轮没有安装本地 Windows 环境、运行真实 Windows 保活会话、部署未开放服务、上传签名凭据或发布 Release。云端安装器检查使用管理员/UAC 关闭环境；普通用户权限、实际系统通知及物理电源/合盖仍由后续设备验收。

## 2026-10-15：Mac 0.3.0 界面重设计与菜单栏信息面板

用户反馈实际用过几次，保活效果好，要求界面更精美、名词更准确、优化交互，在状态栏小图标中查看信息，完成后推送 GitHub 并优化仓库介绍。用户另外说明之前测试合盖都能用；这是用户反馈，未补充机型、时长和步骤，不计入物理合盖验收矩阵。

### 已完成

- Mac 控制窗口重做：自适应高度（最高 900pt，可纵向调整）、状态卡合并剩余时间/预计结束与电源/网络/散热、两列场景卡片附用途说明、开关附效果说明、固定在底部的开始/停止/延长。主按钮改为自绘样式，浅/深色对比度单独处理。
- 菜单栏面板改为 320pt 信息面板：状态、剩余或已运行时间、开始时刻、已运行、规则、电源/网络/散热、合盖组件、上次结束，以及场景切换、开始/停止/延长、控制窗口/设置/退出。菜单栏图标按状态切换空杯/实心杯/警示三角。
- 去掉首次“开始使用”拦截页（用户指出多余），改为可关闭的“使用须知”卡片；第一次开始会话视为已读。
- 用语统一为保持唤醒、未开启、睡眠、允许熄屏/屏幕常亮/调暗常亮、自动停止条件、散热状态等；存储标识、`specs/scenes.json` 和 C# 枚举不变，旧偏好无需迁移。未签名构建改为提示“未签名构建无法合盖”。Windows 同步同一套文案（未改结构）。
- 新增结构化“上次结束”（原因 + 时间段 + 运行时长）、`SessionText.screenMode/span/timer` 与场景用途说明；新增离屏截图测试 `ScreenshotTests`（需设置 `AWAKE_SCREENSHOTS`），README 展示图由其渲染后合成。
- 版本：Mac 0.3.0 / build 5，Windows 0.3.2。README 重写为面向用户的介绍，新增 README.en.md；随包安装说明、Mac 交接与架构文档的按钮名称同步。

### 本机实际检查

环境：Apple Silicon arm64、macOS 26.4.1、Swift 6.3.1、.NET SDK 10.0.401（用户目录隔离安装）。

- 基线 `swift test` 61 项通过。最终 `scripts/validate-local.sh`：Swift 65 项执行，64 通过，1 项为按需截图测试跳过；Windows 核心 39 项、协议/ABI/请求模拟 27 项通过；7 个 .NET 项目 0 警告 0 错误；空白检查通过。新增回归覆盖菜单栏信息随阶段变化、已运行时间、未知电源/网络/散热显示“未知”、结构化上次结果跨重启保留、屏幕模式显示名不改变存储标识。
- 离屏渲染首次使用、控制页待机/运行（浅/深）、设置页与菜单栏面板待机/运行（浅/深）共 10 张截图并逐张目视检查；据此修正了开关和步进器未右对齐、首屏被截断、标语重复、测试宿主版本号误显示等问题。截图使用注入的时钟与遥测；运行态截图取得并释放了真实普通 IOPMAssertion，未创建夜间遮罩。
- 从源码启动未签名调试构建，通过辅助功能接口确认控制窗口实际尺寸 460×900、菜单栏状态项存在；用户在屏幕上看到该调试窗口并提出上述两点反馈，随即关闭。辅助功能读取在两个同名进程间会定位到已安装的 0.2.1，未用作新界面证据。
- `ARCHITECTURES='arm64 x86_64' CONFIGURATION=release` 使用 Apple Development 证书构建 0.3.0：App/helper 双架构、严格签名与稳定 designated requirement 校验通过，`AwakeHelperEnabled` 为 true。没有覆盖 `/Applications` 中的 0.2.1 安装版，没有重新注册 helper，没有全局 pmset 写入或物理合盖操作。

### 待验证

- 签名安装版中菜单栏面板的真实弹出尺寸、“控制窗口…/设置…”是否先收起面板、刘海遮挡与菜单栏倒计时宽度，需要安装后目视确认。
- Windows WPF 文案变更需由 GitHub Windows 主机执行 14 项注入检查并重新生成界面报告。

### 远端验证与交付

代码提交 `5c890af` 的 [push CI #38607053056](https://github.com/diguike/KeepMyMacAwake/actions/runs/38607053056) 与 [PR CI #38607086065](https://github.com/diguike/KeepMyMacAwake/actions/runs/38607086065) 五个任务全部通过：macOS runner 执行 65 项 XCTest（1 项按需截图测试跳过）并完成双架构 ad-hoc 构建；Linux Swift 与 Windows 核心/模拟检查通过；Windows x64 / ARM64 各执行 14 项 WPF 注入检查、安装器生命周期检查并生成 63 张界面图，渲染/绑定错误为 0，报告版本 0.3.2。下载 x64 报告抽查运行态浅色图，新文案（保持唤醒中、允许熄屏、仅在接通电源时运行、延长 15 分钟）显示正常。

[PR #6](https://github.com/diguike/KeepMyMacAwake/pull/6) 于 2026-10-15 合入 main，合并提交 `4255d07`，源码树与通过验证的 `5c890af` 一致；合并后的 [main CI #38607898926](https://github.com/diguike/KeepMyMacAwake/actions/runs/38607898926) 五个任务全部通过。GitHub 仓库简介改为面向用户的中英文说明，并补充 keep-awake、prevent-sleep、clamshell、menubar-app、claude-code 等话题标签。

### 本机安装与 v0.3.0 发布

用户随后明确选择“帮我安装”和“发布 v0.3.0”。

- 安装前确认旧 0.2.1 空闲：无 KeepMyMacAwake 断言，SleepDisabled 为 0。通过辅助功能接口在旧 App 设置页点击“停止并移除组件”，界面显示“已恢复设置并移除后台组件”，helper 进程退出、SleepDisabled 仍为 0；随后正常退出旧 App，备份到 `dist/previous-0.2.1.app`（不提交）。
- `scripts/release-macos.sh` 从 main `e746cc4` 构建 Apple Development 签名通用包；DMG 校验、只读挂载与 ZIP 解包签名检查通过。安装到 `/Applications/KeepMyMacAwake.app`，严格签名通过，主程序 SHA-256 与 dist 及 ZIP 内 App 一致。
- 新版读取原偏好（场景“接电合盖”）。点击“安装后台组件”后 helper 重新注册并直接连接，此前的系统批准保留，本次没有出现本人认证提示。
- 真实菜单栏面板：320×479pt，显示状态、规则、电源/网络/散热与“合盖组件 已连接”。从面板选择日常并开始，面板显示剩余 00:59:59、预计结束、开始于、已运行，系统持有本进程 PreventUserIdleSystemSleep；菜单栏项宽 85pt，读屏标签“保持唤醒中，剩余 59 分钟”。停止后断言释放，显示“已停止，本应用不再阻止睡眠”。点“设置…”后面板收起，控制窗口切到设置页。按钮与“上次结束”行的读屏文本位于 AXAttributedDescription。验收后把场景恢复为“接电合盖”，留在未开启；本机记录了这次约 1 分钟的手动停止结果。
- 没有开启合盖会话、没有全局 pmset 写入、没有物理合盖或拔电操作。
- [v0.3.0 Pre-release](https://github.com/diguike/KeepMyMacAwake/releases/tag/v0.3.0) 已于 2026-10-15 公开，tag 指向 `e746cc4`；DMG（约 2.4 MiB）、ZIP（约 2.0 MiB）与 SHA256SUMS.txt 上传后回下载校验通过，与安装版为同次构建。仍是 Apple Development 签名、未公证的体验包。

下一步：用户日常使用时观察菜单栏面板与刘海遮挡；物理合盖与多机型矩阵、Windows 去掉首次拦截页、Developer ID 与公证仍按既有计划接续。

## 2026-10-15：0.3.1 文案、交互与配色修订

用户指出“可以开始”等文字不必要、带 AI 味，并要求请子 agent 评审；随后指出铜橙配色接近 Claude Code 常用色调。子 agent 以只读方式审阅 7 个源文件与 10 张截图，给出删改清单、结构建议与用语表；采纳与取舍见 decisions.md 同日第二节。

### 已完成

- 删除头部标语与状态徽章、使用须知卡、页脚、控件解释行和所有成功提示；消息区只显示错误。空闲标题为“未开启”或橙色阻止原因；运行时显示“剩余/已运行”、“07:10 结束”和“可以合盖”或“可以锁屏，请勿合盖”。
- 运行中用只读“本次会话”卡替代置灰控件；授权卡移到合盖开关下方；关闭“仅在接通电源时运行”时就地显示电量下限；设置页去掉“自动停止条件”组，散热/网络/调暗说明改为悬停提示；卸载后台组件加确认对话框；“退出”移到设置页底部。
- 菜单栏面板去掉标题行；运行中显示时段（23:10–07:10）、电源/网络/散热与（合盖时）后台组件；页脚为“更多选项…/设置…/退出”。
- 用语按 decisions.md 用语表统一；停止原因改为简短事实短语；修正读不到网络或电量时原因写成“电源或散热”的错误；通知正文改为“时间到，共运行 8 小时”。
- 界面强调色改为系统强调色；App 图标改为深蓝夜色、白杯、浅蓝蒸汽与月牙。README 展示图改用冷色背景重新合成。
- Mac 版本 0.3.1 / build 6。Windows 本轮未修改，仍为上一版文案与配色。

### 本机实际检查

- `scripts/validate-local.sh`：Swift 65 项执行，64 通过、1 项按需截图测试跳过；Windows 核心 39、协议/模拟 27 通过；7 个 .NET 项目 0 警告 0 错误。测试按新文案更新，并新增上次结束时间（当天/昨天/日期）与场景简短摘要用例。
- 离屏渲染 9 张截图（控制页待机/运行浅深色、设置页、菜单栏面板待机/运行浅深色）逐张目视检查；新图标 256px 预览目视检查。

### 0.3.1 本机安装验收

- PR #7 的 push / PR 两轮 CI 共 10 个任务全部通过，合入 main `30083cd`。从 main 用 Apple Development 证书构建通用发布包，DMG/ZIP 校验通过。
- 升级：0.3.0 空闲（无断言、SleepDisabled 0），通过辅助功能接口点击其“停止并卸载后台组件”，显示“已恢复睡眠设置并卸载后台组件”，helper 退出；正常退出后备份到 `dist/previous-0.3.0.app`（不提交），安装 0.3.1，严格签名通过且主程序哈希与构建一致。
- 真实窗口读回新文案：阻止原因“合盖需要后台组件”、电池/网络/散热胶囊与悬停提示、场景用途、选项、授权卡紧贴合盖开关、电量下限就地显示。点击“安装后台组件”后 helper 重新注册并连接，未出现本人认证提示，标题变为“未开启”。真实菜单栏面板 320×366，显示“未开启，2 小时 · 合盖”、电源/网络/散热、后台组件“已连接”、上次结束与场景按钮。用户当前选择“外出合盖”，本次未在真机开启会话，也没有合盖设置写入。
- 读回发现“上次结束”的悬停提示在辅助功能数据中重复三次（`.help` 在合并辅助功能元素之前），已调整修饰符顺序；用调试构建自身的偏好域写入测试记录后读回，提示只出现一次，测试记录已删除。

## 2026-10-15：0.4.0 中性配色与质感

用户认为蓝色用得太多、整体质感不足，给出 nowdex.app 作为质感参考，并强调“有 AI 之前那种精品 Mac 软件”的高级感。用无头 Chrome 截取参考站首页与菜单栏面板展示区并阅读后，归纳为中性色、数字为主角、细节克制三点；落实方式见 decisions.md 同日“中性配色与质感”一节。

- 新增 `SessionText.parts` 大数字拆分与测试；视觉组件重写为墨色/卡片/胶囊切换/细刻度条/圆形图标按钮；菜单栏面板去掉页脚改为标题右侧图标按钮；控制窗口按内容自动收放；图标改为石墨黑。Mac 0.4.0 / build 7。
- 本机：`swift test` 66 项执行，65 通过、1 项按需截图跳过；离屏渲染 9 张截图与图标预览逐张目视检查。调试构建实测控制窗口由 900pt 自动收至 702pt（日常场景待机），两三次布局内稳定；首轮尝试用 PreferenceKey 测量读回为 0，已改为 GeometryReader onAppear/onChange。调试窗口出现在用户屏幕上后被关闭，未继续在调试构建上操作。
- PR #8（上次结束悬停提示只附加一次）CI 10 项通过，已合入 main `9726b98`。
- 升级 0.3.1 时真机读回卸载确认框，系统提供的取消按钮显示为英文 “Cancel”。已在确认框显式加入“取消”，并在 Info.plist 声明 `CFBundleDevelopmentRegion` 为 zh_CN、`CFBundleLocalizations` 为 zh-Hans，使系统自带文字随中文界面显示。

### 0.4.0 本机安装验收

- PR #9（中性配色）与 PR #10（中文系统文字）各自 push/PR 两轮 CI 共 10 项通过，合入 main `f1de79d`；从 main 构建 Apple Development 签名通用包，DMG/ZIP 校验通过。
- 升级：0.3.1 空闲时在设置页点击“卸载后台组件…”，确认框（当时显示英文 Cancel）中确认“卸载”，读回“后台组件已卸载”、helper 退出、SleepDisabled 0；备份到 `dist/previous-0.3.1.app`（不提交）后安装 0.4.0，严格签名通过，主程序哈希与构建一致。
- 真机读回：控制窗口按内容自动为 460×877（外出合盖 + 授权卡 + 电量下限），安装后台组件并连接后收为 815，设置页 457、切回控制页 815；确认框按钮为中文“取消 / 卸载”，点“取消”后无改动、后台组件仍已连接。菜单栏面板 320×395，标题右侧三个图标按钮带悬停提示，状态、电源、网络、散热、后台组件与上次结束显示正确。没有开启会话、没有合盖设置写入。
- 用户确认发布。[v0.4.0 Pre-release](https://github.com/diguike/KeepMyMacAwake/releases/tag/v0.4.0) 已公开，tag 指向构建提交 `f1de79d`；DMG（约 2.0 MiB）、ZIP（约 1.6 MiB）与 SHA256SUMS.txt 回下载校验通过，ZIP 内主程序与本机安装版哈希一致。仍是 Apple Development 签名、未公证。

下一步：Windows 按同一用语表与中性配色对齐（含去掉首次拦截页）并复核界面报告；物理合盖多机型矩阵、Developer ID 与公证按既有计划接续。
