# 安全问题

请不要在公开 issue 中提交凭据、私有日志或可直接利用的漏洞细节。可使用 GitHub 仓库的 private vulnerability reporting（若已开启）报告安全问题。

当前是开发预览。helper 只接受版本化的固定租约操作；连接按构建时固定的客户端签名要求校验，客户端同时校验 helper 的签名身份。未签名预览不开放 helper 注册。

恢复记录保存在固定的 root 私有目录，修改系统设置前持久化，恢复失败时保留。管理员删除 App、关闭后台权限、停止 launchd 服务或磁盘损坏仍可能阻止恢复。这些场景需要明确的人工恢复流程，见 docs/mac-handoff.md。
