# 构建、签名与分发

源码使用 Swift Package；菜单栏 executable 打包为 LSUIElement App。内嵌 helper 路径为 `Contents/Library/HelperTools/KeepMyMacAwakeHelper`；LaunchDaemon 位于 `Contents/Library/LaunchDaemons`，使用相对 `BundleProgram`，经 SMAppService 注册。macOS 最低版本为 14。

`./scripts/build-macos.sh` 默认 debug / ad-hoc，仅支持普通模式。App 的 Info.plist 明确禁止注册 helper。helper 仍参与编译，内嵌的身份要求不允许 ad-hoc 预览连接。没有为了方便开发而接纳任意客户端。

证书构建指定 `SIGN_IDENTITY`。脚本先获取 App 的证书 designated requirement，嵌入 helper 的签名 `__TEXT,__info_plist`，签名 helper，最后签名 App 并验证身份要求仍然匹配。含 cdhash 的不稳定身份不能用于启用 helper。签名要求覆盖 bundle identifier 和证书身份；每次 XPC 连接都在 resume 前设置要求。

本地 Apple Development 签名用于真机开发；Developer ID Application 用于向用户分发。ad-hoc 预览不是 Gatekeeper 可接受的发行物。首版不提供自动更新；升级前先停止并移除旧后台组件，保留 App 路径稳定，再启动新版本注册，直到完整升级矩阵通过。

正式公证在 Mac 上使用已有本地 keychain profile：

```sh
SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='your-existing-profile' ./scripts/notarize-macos.sh
```

脚本构建 release、提交公证、staple 并验证 Gatekeeper，输出 zip。脚本不会创建 GitHub Release 或上传安装包。签名主体、公证和正式发布仍需要开发者身份及真机验收。当前没有执行公证。

CI 的 artifact 只是构建证据，不作为已签名发行物。通过网页解压下载的 artifact 可能丢失权限；本地开发优先从源码构建。

## 0.2.0 跨机器体验包

用户于 2026-10-10 明确要求将当前版本打包到 GitHub Release，供另一台 Mac 下载试用。该授权覆盖体验包发布；仍不把未公证、未完成物理合盖验收的包标为正式稳定发行物。

```sh
SIGN_IDENTITY='Apple Development: Your Name (TEAMID)' ./scripts/release-macos.sh
```

脚本对 App 和 helper 分别编译 arm64 / x86_64、使用 lipo 合并，再签名。输出 `dist/releases/KeepMyMacAwake-0.2.0-macOS-universal.dmg`、ZIP 和 SHA256SUMS.txt。DMG 内有 App、Applications 快捷入口、中文安装说明和 MIT 许可证；ZIP 包含 App、说明及许可证。压缩后分别挂载／解压校验完整签名，核对两个可执行文件均有双架构。构建时可用 `ARCHITECTURES='arm64 x86_64' CONFIGURATION=release ./scripts/build-macos.sh` 单独生成通用 App。

当前机器只有 Apple Development 身份，没有 Developer ID Application，因而此次发布为 GitHub **Pre-release**，标签 `v0.2.0`。不创建新证书、不提交公证，构建产物作为同一仓库的 Release 附件提供。

跨机器首次下载可能触发 Gatekeeper，使用 Apple 的单 App “仍要打开”流程；不提供关闭全局保护或删除隔离属性的命令。公司管理策略可能禁止该例外。helper 仍要求在目标机单独批准后台活动。

依据：[Apple 通用二进制说明](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary)、[公证证书要求](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)、[首次安全打开 App](https://support.apple.com/zh-cn/102445)。
