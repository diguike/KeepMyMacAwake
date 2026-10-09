# 参与开发

请先读 AGENTS.md、README.md 与 docs/status.md。修改源代码后运行 `swift test`；Mac 相关改动还应在 Mac 执行 `./scripts/build-macos.sh`。Linux 的测试通过不能作为 macOS 构建、授权或合盖成功的证据。

涉及电源设置时，先用模拟后端测试失败、强杀、时钟跳变和恢复路径，再按 docs/validation.md 记录真机结果。不要复用任意 shell 命令接口，不把用户任务放到 root 下运行。

PR 应描述具体行为变化、实际验证结果和未验证项。请勿上传机器日志、证书、密钥或私有信息。新目录使用小写。

本项目采用 MIT 许可证；引入第三方源码必须核对原始许可证并保留所要求的版权声明。
