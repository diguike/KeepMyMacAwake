# 双端产品合约

`scenes.json` 描述四个场景的默认时长、供电、网络、合盖与屏幕规则；`scenarios.json` 描述两端应一致的会话停止行为。Swift / C# 实现分别读取同一组数据，避免文档中同名场景拥有不同规则。

Mac 测试入口：根目录 `swift test`，`macos/tests/ContractTests.swift`。Windows：`dotnet test windows/tests/Awake.Core.Tests.csproj`。场景数据验证偏好合法性；Mac App 的场景实现仍在 `macos/app/AppModel.swift`，不能把数据合法性测试当作完整 UI 场景映射验收。

Windows 当前没有应用热保护，普通开盖的未知热状态与 Mac 必需热状态语义不同。共享 `thermal-unknown` 用例使用支持热监测的模拟能力验证保守停止，不代表 Windows 本机能读到热状态。平台差异由 Windows 自身能力测试覆盖，合盖 / 电池不可用时不能忽略参数继续启动。

本轮合约是测试和产品规则，不要求两端共用一份 Swift / C# 源码，也不把机器运行会话保存到文件后跨端恢复。
