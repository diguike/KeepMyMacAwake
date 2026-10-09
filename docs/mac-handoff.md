# 今晚的 Mac 开发与测试入口

这是开发预览的验收步骤，下面的 Mac 命令尚未在服务器执行。普通防闲置与合盖模式分开验证。

## 先跑普通模式

```sh
git clone https://github.com/diguike/KeepMyMacAwake.git
cd KeepMyMacAwake
swift test
./scripts/build-macos.sh
open dist/KeepMyMacAwake.app
```

已有 clone 时先 `git pull --ff-only`。要求 macOS 14+ 和 Swift 5.9+；可用 `open Package.swift` 在 Xcode 编辑。默认 ad-hoc 构建禁用 root helper 注册，普通模式可用。

确认顶部出现杯子图标，阅读首次说明。接通电源、保持“合盖后也保持运行”关闭，设定自定义 1 分钟并启动。观察倒计时、手动停止、到时停止、屏幕可关闭和锁屏仍有效。IOPMAssertion 不保证合盖工作。

## 再跑签名 helper

```sh
security find-identity -v -p codesigning
SIGN_IDENTITY='Apple Development: Your Name (TEAMID)' ./scripts/build-macos.sh
```

把 App 放入固定目录，先停止并退出旧 App，再启动签名版；不要覆盖活动中的 App。启用合盖选项，点击“安装 / 检查授权”，在系统设置批准后台组件。检查 UI 的“后台组件已连接”，再开始会话。若权限被企业管理限制，记录原因，不解除限制。

没有证书时今晚先完成普通模式、UI 和编译测试。不要手工以 sudo 启动 helper 代替正式注册；不要去掉签名校验来绕过安装问题。可在 Xcode 配置 Apple Development 身份；是否满足 LaunchDaemon 授权需实际验证。

开始合盖之前先验证**开盖状态下**的恢复链路：

1. 记录 `pmset -g`；如果缺少明确的 SleepDisabled 0/1，后端会读取 IOPMrootDomain 的明确布尔属性；该属性也未知时拒绝运行。可用 ioreg -r -n IOPMrootDomain -d 1 只读核对，不将缺失当成 false。
2. 开启 1 分钟合盖模式，确认 SleepDisabled 1；手动停止并确认恢复 0。
3. 再开启，退出 App 后确认恢复 0；检查恢复文件按预期清理。
4. 强杀 UI，目标 20 秒失联阈值后至多一个巡检周期开始恢复；另加 pmset 调用时间。读取真实日志，不把模拟测试当证据。
5. 强杀 helper，验证 launchd 重启、先恢复、App 不误报就绪。
6. 完成重启与卸载链路后，再在通风桌面上无外接屏接电合盖，观察连续任务心跳与时间戳。

测试开始前停用其他保活工具。不要在设备被放进包里时测试，不人为制造过热。低电量和热压力边界先用已有模拟测试。

## 只读诊断与记录

```sh
sw_vers
uname -m
pmset -g
pmset -g assertions
pmset -g batt
launchctl print system/io.github.diguike.KeepMyMacAwake.helper
```

按 docs/validation.md 的矩阵记录日期、提交号、型号、系统构建号、供电、显示器、锁屏、授权、网络、持续时间和实际结果。电源日志只截取必要时间窗，提交前脱敏。系统开关成功读回不代表合盖连续任务成功。

根恢复记录固定为 `/var/db/io.github.diguike.keepmymacawake/recovery.json`，root 私有。记录仅含版本、原始基线 false 和时间，不含任务、凭据或用户日志。

## 故障恢复与卸载

正常卸载：App 点击“停止并移除后台组件”，确认恢复和注销成功后再删除 App。升级也先完成这一步。恢复失败时保留 App、helper 和记录，不能直接删除记录假装成功。

如果已删除／移动 App 或禁用后台权限，应先将同一签名版本放回原路径并恢复后台批准，尝试图形化“恢复设置”。开发测试中如无法启动 App，只有在核对恢复记录基线 false、确认没有其他保活工具持有该设置后，管理员才可在本机人工执行 `sudo /usr/bin/pmset -a disablesleep 0` 并读回确认；这是应急恢复，不是普通产品操作，也不由服务器远程执行。记录损坏时不猜测基线，不执行 restoredefaults。

如果日志显示调用失败、读回未知或权限拒绝，记录为失败并停止测试。首次验收结果写入 docs/status.md；没有真机结果之前不要打正式版本标签。
