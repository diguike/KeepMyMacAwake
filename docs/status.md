# 项目进度与下一会话入口

更新：2026-10-11，0.2.1 UI 刷新修复。最新验证见文末；0.2.0 记录保留为历史证据。用户明确授权开发、安装、组件注册及验证后推送和合入 main。

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

上述回归验证了发现的触发路径；用户具体看到的刷新形态尚未补充。物理合盖与多屏／Space／全屏切换矩阵仍待人工验收，不将模拟时钟、XPC 回复或屏幕通知计作物理验证。
