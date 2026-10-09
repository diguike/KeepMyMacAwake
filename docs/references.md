# 资料与开源参考

访问／检索日期：2026-10-09。下面保留来源链接和阅读目的，不复制第三方全文。链接与仓库内容可能改变，正式实现时应记录参考的具体提交。

## Apple 原始资料

| 来源 | 用途 |
| --- | --- |
| [IOPMLib.h](https://github.com/apple-oss-distributions/IOKitUser/blob/main/pwr_mgt.subproj/IOPMLib.h) | 公开电源断言语义与合盖限制 |
| [QA1340](https://developer.apple.com/library/archive/qa/qa1340/_index.html) | 闲置／强制休眠及通知机制；归档资料 |
| [caffeinate 手册](https://github.com/apple-oss-distributions/PowerManagement/blob/main/caffeinate/caffeinate.8) | 参数和供电条件 |
| [pmset 源码](https://github.com/apple-oss-distributions/PowerManagement/blob/main/pmset/pmset.m) | disablesleep 的解析与系统级设置 |
| [PMAssertions.c](https://github.com/apple-oss-distributions/PowerManagement/blob/main/pmconfigd/PMAssertions.c) | 系统自身的合盖状态重算 |
| [XNU IOPMrootDomain.cpp](https://github.com/apple-oss-distributions/xnu/blob/main/iokit/Kernel/IOPMrootDomain.cpp) | 后续内核电源路径研究入口 |
| [Apple M3 双显示器说明](https://support.apple.com/en-us/117373) | 特定机器的官方合盖组合 |
| [配件连接授权](https://support.apple.com/en-us/102282) | Apple Silicon 外部配件首次授权 |
| [MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra) | 原生菜单栏 UI |
| [SMAppService register](https://developer.apple.com/documentation/servicemanagement/smappservice/register()) | 服务注册及管理员批准 |
| [ProcessInfo.ThermalState](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum) | 系统热状态，非绝对温度 |

## 最值得参考的同类项目

| 项目 | 仓库说明中的能力 | 参考重点 |
| --- | --- | --- |
| [Sleepless / Aboudjem](https://github.com/Aboudjem/Sleepless) | 原生菜单栏、pmset 合盖保活、定时、电量下限；标注 MIT | 简单交互、图形化保护设置 |
| [macowl](https://github.com/Cobnex-HQ/macowl) | 菜单栏工具、睁眼／闭眼图标、合盖设置及下次启动检查；标注 MIT | 状态图标和轻量面板 |
| [clawake](https://github.com/ItaiZeilig/clawake) | 原生菜单栏、helper、工作电脑锁屏策略版本 | helper 通信与保活／锁屏分离 |
| [KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake) | 防闲置休眠；README 明确不支持合盖 | 菜单栏交互与能力边界说明 |
| [Liddy](https://github.com/bygelo/liddy) | 作者描述 root daemon、心跳、任务租约与保护策略；标注 MIT | 独立恢复和任务绑定的设计思路 |
| [Amphetamine 官方资源](https://github.com/x74353/Amphetamine) | Power Protect 与 Apple Silicon 电源切换问题 | 供电变化兼容性；资源仓库不是完整 App 源码 |

## 其他研究入口

- [Sleepless / dandyrandy](https://github.com/dandyrandy/sleepless)：同名不同仓库；README 描述正常退出恢复和异常强杀后的残留问题，可用于反例分析。
- [rucksack 电源设计](https://github.com/noahnawara/rucksack/blob/main/docs/POWER.md)：基线、租约、电源变化和网络的职责边界。
- [OpenLid](https://github.com/openlid/openlid)：菜单栏与偏好设置组织，功能需要独立验证。
- [Keep Mac Awake](https://github.com/kemalandic/keep-mac-awake)：同类原生菜单栏和 helper；其设置跨退出保持的产品策略与本项目自动恢复目标不同。
- [LidRun](https://github.com/aibrickai/lidrun)：公开仓库声明产品闭源，不应当作可复用开源源码。

## 使用原则

仓库 README 是作者声明，不能替代代码审阅或本项目的真机验证。不要照抄 README 中关于安全、SIP、兼容范围或“唯一办法”的绝对表述。

当前只参考资料，没有复制第三方代码、图标或文案。若后续复用，先检查具体文件与对应提交的许可证，并保留要求的版权声明；本项目采用 MIT 许可证。

## 实现时核对的官方接口

- [NSXPCConnection.setCodeSigningRequirement](https://developer.apple.com/documentation/foundation/nsxpcconnection/setcodesigningrequirement(_:))：macOS 13 起可在 resume 前强制 peer 代码签名要求。
- [SMAppService.daemon](https://developer.apple.com/documentation/servicemanagement/smappservice/daemon(plistname:))：内嵌 LaunchDaemon plist 位置。
- [更新 helper 布局](https://developer.apple.com/documentation/servicemanagement/updating-helper-executables-from-earlier-versions-of-macos)：BundleProgram 与 App 内相对路径。

这些接口文档用于实现依据，实际注册、签名与服务生命周期仍需 Mac 验证。
