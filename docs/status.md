# 项目进度与下一会话入口

更新：2026-10-09。用户已明确授权开始开发，并使用递归客身份创建同名公开仓库。

## 已完成

- 原生 SwiftUI MenuBarExtra App：首次说明、定时、普通防休眠、合盖模式授权入口、保护设置、网络路径、恢复与卸载入口。
- 独立 root helper：版本化 XPC 固定操作、连接级租约、20 秒失联截止、2 秒巡检、24 小时硬上限。
- write-ahead 恢复记录：私有目录、无跟随链接读取、原子写入、fsync、失败保留与重试；启动先恢复，不续跑旧租约。
- App/helper 双向代码签名要求；构建时将客户端身份固定到 helper 的签名元数据。
- Swift Package、Mac 打包及公证脚本、Linux / macOS GitHub Actions、MIT 许可证和贡献说明。
- Linux Swift 6.0.3：`swift test` 实际执行 24 项 XCTest，全部通过。

## 当前实际验证边界

Linux 已验证纯逻辑及恢复文件读写，测试使用模拟后端，不会调用真实电源命令。服务器未直接执行 macOS SDK 编译、helper 注册、真实 pmset 修改、证书签名、公证或物理合盖测试。

GitHub macOS CI 已执行 `swift test`（24 项通过）以及 `./scripts/build-macos.sh`；App/helper 编译、ad-hoc 打包与 `codesign --verify --deep --strict` 全部通过。对应源码提交 `5db0e14`，运行证据：[CI #37917896611](https://github.com/diguike/KeepMyMacAwake/actions/runs/37917896611)。CI 没有启动图形 App，没有注册 root 服务，没有改动真实电源设置；证书构建与双向 XPC 实际连接仍需本机验收。

所有真机行为仍待验收。没有正式发行物，不宣布支持某一机型，也不保证 helper 在 App 被删除／后台权限被管理员关闭时仍能运行。

## 今晚在 Mac 上

从 [mac-handoff.md](mac-handoff.md) 开始。先拉取、跑 `swift test` 和默认 ad-hoc 构建，验证 UI 与普通防闲置模式。若有证书，构建签名版，再测试授权、恢复和合盖。

最高优先级：

1. 本机 UI 运行与证书签名检查；SMAppService 与 XPC 双向身份检查，非授权客户端不可调用。
2. `pmset -g` 是否明确输出 SleepDisabled 0/1；缺失时当前后端会拒绝修改，不推断为正常。
3. 无显示器接电合盖的真实持续运行；合盖、手动睡眠和拔插电源行为。
4. App 强杀、helper 强杀、修改后重启，恢复记录与系统设置读回。
5. 移除组件、升级与路径移动，先恢复后卸载。

## 未完成及依赖

- Apple Silicon Air/Pro 和系统版本的物理验收；Intel 未承诺支持。
- 没有服务器可用的 Developer ID 身份，正式签名、公证和 Gatekeeper 分发验收未执行。
- 系统 SleepDisabled 开关不能识别其他工具写入相同值，需独占使用。
- 首版只实现一个手动租约，多租约和任务绑定留后续。
- 正式 App 图标、安装包与自动更新不属于当前已验证产物。

下一会话读 AGENTS.md、README.md、本文件和 Mac 交接清单，记录实际机型／系统／提交号以及验证结果，不重复初始化项目。

公开仓库：https://github.com/diguike/KeepMyMacAwake ，默认分支 main，MIT，作者递归客（diguike）。源码和交接文档已推送。没有发布正式二进制或安装系统服务。
