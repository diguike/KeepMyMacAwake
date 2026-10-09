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
