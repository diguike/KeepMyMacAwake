# 项目协作说明

## 项目与范围

- App 名称：KeepMyMacAwake。目录：keepmymacawake；所有新目录使用小写。
- 面向普通用户的原生桌面 App：Mac 菜单栏、Windows 系统托盘；用户不需要命令行。不要将 CLI 作为主产品。
- 2026-10-13 用户授权在服务器实现 Windows 开发预览与同仓库双端结构重构，名字暂保留 KeepMyMacAwake；允许产品评审与实现 Agent 协作。核心用途为 AI 长任务在用户离开、合盖或夜间休息时继续运行。
- 第一版：一键保活、定时结束、合盖运行、保护策略、故障恢复与图形化首次授权。
- 2026-10-10 用户明确授权本机开发、安装与系统组件注册，并要求验证通过后推送远端、合入 main。系统要求本人触控 ID／密码时不得代填或绕过。物理合盖支持需单独验证。
- 不承诺永不断网、装包运行安全或自动判定任意 AI 任务完成。

## 阅读顺序

开始工作先读 README.md 和 docs/status.md；按任务读取 docs/product.md、docs/research.md、docs/architecture.md、docs/validation.md。
设计理由在 docs/decisions.md，来源在 docs/references.md。
AGENTS.md 是主说明；CLAUDE.md 仅提供入口，避免双份规则漂移。

## 环境与验证

- 2026-10-10 的 Mac 验证见历史记录；2026-10-13 本轮环境为 Linux 服务器。Linux 执行双端纯逻辑和 Windows 模拟 API 检查，可跨编译 Windows 源码；原生 API、UI、锁屏与物理合盖必须分别记录真机证据。
- Swift Package：`swift test` 验证纯逻辑；Mac 用 `./scripts/build-macos.sh` 编译和打包。结果要按实际执行记录。
- 当前实现 SwiftUI + AppKit + IOKit + SMAppService 独立特权 helper；macOS 14+。合盖后端仍需验证。
- Windows 使用 .NET 10 / WPF；`dotnet build windows/KeepMyMacAwake.slnx` 构建，`dotnet test windows/tests/Awake.Core.Tests.csproj` 和 `dotnet run --project windows/service-tests/Awake.Service.Tests.csproj` 可在 Linux 跑；`windows/app-tests/` 必须在 Windows 执行。构建入口 `scripts/build-windows.sh` / `.ps1`。
- 源码为 `macos/`、`windows/`；共享产品合约在 `specs/`，根 `Package.swift` 与 Mac 构建脚本入口兼容保留。不要改 Mac bundle / helper 签名身份作为目录重构的一部分。
- Windows 预览仅接电开盖，无应用热保护；合盖与电池能力关闭，服务有不可绕过的启动拒绝门槛。不得删除门槛或将服务打进用户 ZIP 来宣称已支持合盖。
- 每项变更记录实际运行的检查、未运行的原因和需要 Mac 验证的部分。
- 公开资料、产品作者宣称、代码审阅、真机验证分开表述。开源 Apple 代码不等于当前系统行为保证。

## 工程约束

- 用户任务和 UI 以普通用户身份运行；helper 只接受有限的电源与租约操作，不执行客户端任意命令。
- 合盖保活要在合盖前就绪；不能依赖收到休眠通知后临时阻止强制休眠。
- 系统级设置必须有独立恢复机制；退出回调或 shell trap 不能覆盖 kill -9。
- 不改变锁屏策略，不绕过企业设备限制；权限不可用时显示明确原因。
- 监控数值未知时显示未知，不能用虚假的正常状态替代。
- 修改系统设置前记录基线与所有权；发现其他保活工具冲突时不要强行覆盖。
- 退出、异常恢复、升级、卸载需要一起设计。
- 不在未经验证的机器上宣称支持；普通防闲置休眠和合盖保活分开测试。

## AI 原生工作流

- 先读取状态与相关文档，给出此次工作的具体范围，再实现用户授权内容。
- 有意义的架构变化更新 docs/decisions.md；完成阶段工作更新 docs/status.md。
- 保持下一会话可接续：记录完成项、阻塞项、待验证项及下一步，而不是仅在聊天里保留。
- 不自动部署、发布、安装系统服务或操作真实设备电源设置；这些由实际开发任务与明确授权决定。
- 不将凭据、签名证书、用户日志或机器私有信息提交到仓库。
- Linux 的 Swift 只测试 `macos/core/`；macOS 目标通过条件编译加入 Package.swift。Windows 模拟检查不运行原生电源 API。修改协议时同步 App/helper 并保持签名校验；共享场景变化同时更新 `specs/` 与双端合约检查。
