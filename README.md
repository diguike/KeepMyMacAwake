# KeepMyMacAwake

原生 macOS 菜单栏应用：**合盖继续运行，到时恢复休眠。**

由 [递归客](https://github.com/diguike) 开源，MIT 许可证。

当前是 **0.1.0 开发预览**：已实现应用、helper 和可移植逻辑测试；实际支持的机型与合盖行为仍需真机验证。没有已签名、公证的正式安装包。保持运行不保证网络不断，也不自动判断 AI 任务是否完成。

## 功能

- 普通防闲置休眠，允许屏幕关闭和正常锁屏。
- 定时 30 分钟、1 小时、2 小时或自定义 1–1440 分钟。
- 合盖实验模式：图形化安装与批准独立 helper，后端确认后显示就绪。
- 默认仅接电；电池模式显式开启，可设置电量保护下限。
- 严重热压力持续 30 秒或临界热状态时停止；保护数据未知时停止。
- helper 维护有限期租约、20 秒失联截止和持久化恢复记录；进程重启先恢复遗留设置。
- 菜单提供停止、恢复、登录启动和停止并移除后台组件。
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
SIGN_IDENTITY='Apple Development: Your Name (TEAMID)' ./scripts/build-macos.sh
```

将 App 放到固定位置（建议 `/Applications`），通过菜单点击“安装 / 检查授权”，在系统设置批准后台组件。首次合盖测试必须按照 [Mac 交接清单](docs/mac-handoff.md) 操作。不要在活动会话中移动或覆盖 App。

签名和公证脚本见 [分发说明](docs/distribution.md)。仓库不包含任何签名证书或凭据。

## Linux 上验证

安装 Swift 5.9+ 后运行：

```sh
swift test
```

Linux 只构建纯逻辑库及测试，不构建 SwiftUI、IOKit、XPC 或 ServiceManagement。测试使用模拟电源后端，不能证明实际合盖工作或真实崩溃恢复。CI 在 Linux 跑逻辑测试，在 macOS 编译 App/helper 和打包预览。

## 源码

| 目录 | 内容 |
| --- | --- |
| `app/` | SwiftUI 菜单栏、状态协调、IOPMAssertion、授权与网络路径 |
| `core/` | 租约、保护策略、持久化恢复记录；可在 Linux 测试 |
| `helper/` | 独立 root XPC 服务、固定 pmset 后端、监控和恢复 |
| `shared/` | 版本化协议、Mac 遥测、签名校验 |
| `packaging/` | App / LaunchDaemon 配置 |
| `scripts/` | 构建、签名与公证 |
| `tests/` | 故障注入与状态转换测试 |

## 使用边界与卸载

合盖后端使用系统级 `pmset disablesleep`，兼容性尚未验证，可能影响手动睡眠。发现已被其他工具启用时拒绝接管；系统级开关没有可归属的多方所有权，不能识别另一个工具中途写入相同值。请避免同时使用多个合盖保活工具。

只在通风桌面上使用。热状态不是温度读数，也无法检测电脑是否在包内。恢复设置只撤销本应用改动，不保证电脑立即入睡。管理策略、权限或遥测不可用时应显示原因，不绕过企业限制。

卸载前点击“停止并移除后台组件”，确认成功后再删除 App。不要在活动会话中直接删除 App 或关闭系统后台权限：这可能阻止 helper 重启及恢复，详见 [故障恢复](docs/mac-handoff.md)。

## 文档

[进度与待验证项](docs/status.md) · [Mac 交接](docs/mac-handoff.md) · [技术设计](docs/architecture.md) · [验证矩阵](docs/validation.md) · [产品范围](docs/product.md) · [决策](docs/decisions.md) · [研究](docs/research.md) · [资料](docs/references.md)

参与开发前请读 [AGENTS.md](AGENTS.md) 和 [CONTRIBUTING.md](CONTRIBUTING.md)。
