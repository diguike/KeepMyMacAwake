# 项目进度与下一会话入口

更新：2026-10-10。已从 diguike/KeepMyMacAwake 克隆到 Mac 本地，分支 feat/mac-scenarios。用户授权继续本机开发，并要求夜间低亮度、接电合盖、有网络时合盖及永久保活。

## 当前功能

- 原生菜单栏面板：日常、夜间、接电合盖、有网时四种快捷场景；具体规则可以调整。
- 定时 30 分钟、1/2/8 小时、自定义 1–1440 分钟，或直到手动停止。
- 夜间临时画面变暗遮罩（默认 94%，可调 80–98%），支持多个屏幕及切换 Space，结束撤销；不是硬件背光调节。
- 普通防系统闲置休眠与可选屏幕常亮分别持有公开 IOPMAssertion，停止时释放。
- 接电、电量、网络、热压力条件；未知保护数据时停止。网络为可用路径，非远端服务探测；断网停止后不会自动重启。
- v2 固定 XPC 协议；App/helper 独立观察网络；无限时会话仍有连接所有权、20 秒失联保护和恢复记录。
- 系统 SleepDisabled 读取兼容 pmset 未输出该键：使用 IOPMrootDomain 明确的 CFBoolean 读回，不推断缺失为 false。
- write-ahead 恢复记录、签名身份校验、启动先恢复、先恢复后移除后台组件保持有效。
- 修复本机证书构建中 codesign requirement 字符串被当成路径的问题；Swift 6 Sendable 警告已修正。

## 本机实际验证

环境：Apple Silicon arm64 / Mac16,5，macOS 26.4.1（25E253），Xcode Swift 6.3.1。

- swift test：34 项 XCTest 全部通过（28 项纯逻辑与恢复测试，6 项 Mac 原生测试）。
- 原生测试实际取得并读回本进程系统／显示断言，验证释放后不再持有；普通模式没有显示断言。
- AppModel 无限时普通会话实际启动、刷新、停止成功；没有注册 helper 或改动全局电源配置。
- 夜间遮罩在本机实际创建与撤销，停止后无残留可见窗口；菜单栏可操作性、全屏与 Space 切换仍需人工 UI 验收。
- SleepDisabled 的 IOKit 只读路径已实际执行成功。本机 pmset -g 缺少此键，ioreg 明确显示 false。
- 默认 ad-hoc 构建和 Apple Development 证书构建、App/helper 严格签名与 designated requirement 校验已执行。产物为 dist/KeepMyMacAwake.app，开发自用，未公证。
- 图形 App 已启动为用户进程；菜单栏 App 的 cua.getApp 自动化连接连续超时，未完成视觉与点击验收。不是 App 崩溃证据，也不将进程启动计作 UI 全部通过。
- git diff --check 无空白错误。

此前 Linux / macOS CI 已对初版 24 项测试及 ad-hoc 打包验证通过：提交 5db0e14，[CI #37917896611](https://github.com/diguike/KeepMyMacAwake/actions/runs/37917896611)。新分支没有推送或触发远端 CI，不能沿用旧 CI 作为此次改动的验证结果。

## 尚未完成的物理与授权验收

本轮没有安装／批准 root 后台组件，没有执行真实 pmset disablesleep 写入，没有物理合盖、拔插电源、断开真实网络、强杀 helper、重启及卸载的系统级验收。模拟后端测试不能代替这些结果。

下一步从 mac-handoff.md 开始：

1. 停止退出旧 App，将签名预览放在固定位置。菜单栏检查四种场景、自定义时间与夜间菜单可用性。
2. 授权后台组件，验证 XPC 双向连接与非授权客户端拒绝；v1/v2 组件不能混用。
3. 开盖状态测试 1 分钟合盖租约的全局状态读回、手动停止、到期恢复及强杀 UI 后恢复。
4. 再在通风桌面、无外接屏条件下做接电合盖与有网时电池合盖，记录连续任务心跳与时间戳。测试拔电／断网后保护停止与恢复读回。
5. helper 强杀、重启、升级及卸载恢复矩阵完成前，不宣布机型支持或发布正式发行包。

无限时不保证永不停止；未知遥测、保护条件、退出、失联或重启均会结束。全局开关无法识别其他工具写入相同值，仍需避免多工具争用。Apple Development 是本机开发身份，不等于 Developer ID、公证或完成发行验收。

公开仓库：https://github.com/diguike/KeepMyMacAwake ，默认分支 main，MIT，作者递归客（diguike）。
