# 技术调研

调研日期：2026-10-09。证据为在线文档、Apple 开源代码和同类项目说明；尚无本项目的 Mac 实测。

## 核心结论

熄屏、闲置休眠与合盖休眠是不同问题。公开的闲置保活断言可以允许屏幕熄灭而保持系统运行，但不能据此承诺无外接屏合盖工作。

Apple 的 [IOPMLib.h](https://github.com/apple-oss-distributions/IOKitUser/blob/main/pwr_mgt.subproj/IOPMLib.h) 明确说明 PreventUserIdleSystemSleep 仍允许合盖、Apple 菜单、低电量等原因触发休眠。[QA1340](https://developer.apple.com/library/archive/qa/qa1340/_index.html) 区分闲置与强制休眠；该文档较旧，应结合当前系统实测。

## 路线比较

| 路线 | 证据与条件 | 产品判断 |
| --- | --- | --- |
| caffeinate / IOPMAssertion | 公开断言；-i 防闲置休眠；-s 仅接电有效 | 普通保活后端，不承诺合盖 |
| 外部显示器合盖模式 | Apple 支持的桌面使用组合包含电源、显示器及外部输入设备 | 兼容场景，不能覆盖无显示器需求 |
| HDMI 诱骗器 | 模拟连接外部显示器的思路；具体适配和其他条件需验证 | 可做对照测试，不能宣称插上就一定有效 |
| pmset disablesleep | Apple 开源 pmset 实现系统级开关；同类项目使用 | 暂定合盖后端，需 root、独立恢复与版本验证 |
| 内部 IOKit 合盖控制 | Apple 电源管理代码存在 kPMSetClamshellSleepState | 实验路线，不作为首版稳定承诺 |

## caffeinate 的限制

[Apple 手册源码](https://github.com/apple-oss-distributions/PowerManagement/blob/main/caffeinate/caffeinate.8) 描述 -i、-d、-s、-t 和 -w。断言可以绑定命令或进程生命周期，适合开盖的长任务。不同断言、供电状态和系统内部行为不能混为一谈。

本项目应直接使用公开 IOPMAssertion API 表达保活原因，普通模式不必启动 caffeinate 子进程。不要为了 CPU 保活而默认保持显示器常亮或模拟用户输入。

## 外接屏与诱骗器

[Apple M3 双显示器说明](https://support.apple.com/en-us/117373) 提供一个具体型号的合盖工作组合，不能外推为所有型号和供电状态的保证。[配件授权说明](https://support.apple.com/en-us/102282) 指出 Apple Silicon 合盖使用前需先允许显示器、鼠标和键盘连接。

诱骗器只是外接显示器路径的一部分。无电源、无输入设备、转接器差异、首次配件授权和拔插行为均属于待实测项。

## pmset 路线

[Apple pmset 源码](https://github.com/apple-oss-distributions/PowerManagement/blob/main/pmset/pmset.m) 接受 disablesleep，并写入系统级 SleepDisabled 设置。这不是一个随 UI 进程退出自动释放的租约。

候选操作为 /usr/bin/pmset -a disablesleep 1；基线原来为关闭时，恢复为 disablesleep 0。不要无条件恢复 0，更不要 restoredefaults 或直接改整个 plist。

这个开关不是有明确第三方兼容承诺的公开合盖 API。同类作者描述中的“Apple supported”“所有机器有效”不作为本项目结论。是否覆盖特定机器、是否跨重启保留、是否影响手动睡眠、供电切换是否失效，都需要实测。不可把本项目退出、SIGTERM 或下一次启动的恢复当作完整崩溃保护。

[Amphetamine 官方资源](https://github.com/x74353/Amphetamine) 记录 Apple Silicon 上连接／断开外部电源时合盖模式可能异常，并提供 Power Protect。由此得出的设计要求是监听并验证供电变化，而不是无限循环强行覆盖系统设置。

## 内部 IOKit 路线

[Apple PMAssertions.c](https://github.com/apple-oss-distributions/PowerManagement/blob/main/pmconfigd/PMAssertions.c) 存在 kPMSetClamshellSleepState 调用及状态重算逻辑。一些产品声称无管理员权限即可控制合盖；这类营销声明尚未由本项目验证。

系统自身使用接口，不代表普通第三方进程能稳定使用。需要验证权限、实际合盖连续运行、拔插电源、锁屏、崩溃后的残留及系统更新。不根据函数返回成功就宣布支持。

## 网络与任务

系统睡眠会暂停普通任务；避免睡眠可以解决这一来源的暂停，但不会修复热点断开、VPN 到期、DNS 故障或远端错误。网络探测需要说明检测范围，不把某次请求成功表示为“永不断网”。

终端退出、SIGHUP、交互式工具等待输入等属于任务／会话生命周期问题。MVP 不托管终端会话，不承诺任意任务完成识别；后续集成需要明确事件协议。
