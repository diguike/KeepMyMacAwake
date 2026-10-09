import SwiftUI
import AppKit

@main struct KeepMyMacAwakeApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        MenuBarExtra {
            AwakePanel(model: model)
        } label: {
            Image(systemName: model.active ? "cup.and.saucer.fill" : "cup.and.saucer")
                .accessibilityLabel(model.active ? "KeepMyMacAwake 正在运行" : "KeepMyMacAwake 未开启")
        }
        .menuBarExtraStyle(.window)
    }
}
struct AwakePanel: View {
    @ObservedObject var model: AppModel
    private let scenes = [("日常", "cup.and.saucer"), ("夜间", "moon"), ("接电合盖", "powerplug"), ("有网时", "wifi")]
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "cup.and.saucer.fill").font(.title2).foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text("KeepMyMacAwake").font(.headline)
                    Text("让 Mac 按你的节奏休息").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Circle().fill(model.active ? Color.green : Color.secondary.opacity(0.35)).frame(width: 7, height: 7)
            }
            if !model.onboarded {
                Text("日常长任务、夜间低亮度，或合盖继续工作，从菜单栏一键开启。合盖需批准后台组件，并在你的 Mac 上验证效果。")
                    .font(.callout)
                Text("请保持通风；锁屏仍然有效。网络可用不代表远端服务始终可达。")
                    .font(.caption).foregroundStyle(.secondary)
                Button("开始使用") { model.acknowledge() }.buttonStyle(.borderedProminent)
            } else {
                HStack(spacing: 6) {
                    ForEach(scenes, id: \.0) { name, icon in
                        Button { model.chooseScene(name) } label: {
                            VStack(spacing: 5) {
                                Image(systemName: icon).font(.system(size: 17))
                                Text(name).font(.caption)
                            }.frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(model.scene == name ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain).disabled(model.hasSession || model.busy)
                            .accessibilityLabel("选择\(name)场景")
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.active ? (model.unlimitedSession ? "直到手动停止" : "剩余 \(Int(ceil(model.remaining / 60))) 分钟") : "准备好再开启")
                        .font(.title2.weight(.medium)).monospacedDigit()
                    Text(model.message).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                Group {
                    Picker("持续时间", selection: $model.durationMinutes) {
                        Text("30 分钟").tag(30); Text("1 小时").tag(60); Text("2 小时").tag(120)
                        Text("8 小时").tag(480); Text("直到手动停止").tag(-1); Text("自定义").tag(0)
                    }
                    if model.durationMinutes == 0 {
                        HStack { Text("分钟"); TextField("1–1440", value: $model.customMinutes, format: .number).frame(width: 90) }
                    }
                    Toggle("合盖后也保持运行", isOn: $model.lidMode)
                    Toggle("仅在接通电源时运行", isOn: $model.requireAC)
                    Toggle("断网时停止保活", isOn: $model.requireNetwork)
                    if model.nightMode {
                        HStack {
                            Text("画面变暗").font(.caption)
                            Slider(value: $model.dimAmount, in: 0.8...0.98).accessibilityLabel("夜间画面变暗程度")
                            Text("\(Int(model.dimAmount * 100))%").font(.caption.monospacedDigit()).frame(width: 34)
                        }
                        Text("夜间使用临时遮罩，非硬件亮度调节；停止后恢复。菜单栏保留可见。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.disabled(model.hasSession || model.busy)
                if model.lidMode {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.helperState).font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button("安装 / 检查授权") { model.authorize() }.disabled(model.busy || model.hasSession)
                            Button("系统设置") { model.openApprovalSettings() }
                        }
                        if !model.helperBuildEnabled {
                            Text("此预览未启用合盖组件，需使用证书签名版。").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Button {
                    Task { if model.hasSession { await model.stop() } else { await model.start() } }
                } label: {
                    Label(model.busy ? "正在处理…" : model.hasSession ? "停止保活" : "开始保活", systemImage: model.hasSession ? "stop.fill" : "play.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 5)
                }.buttonStyle(.borderedProminent).controlSize(.large).disabled(model.busy)
                HStack {
                    Label(model.sample.onAC.map { $0 ? "接电" : "电池" } ?? "电源未知", systemImage: "bolt")
                    Text(model.sample.batteryPercent.map { "\($0)%" } ?? "电量未知")
                    Spacer()
                    Label(model.sample.networkAvailable.map { $0 ? "有网络" : "无网络" } ?? "网络未知", systemImage: "wifi")
                }.font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("更多设置") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("保持屏幕常亮", isOn: $model.keepDisplay).disabled(model.hasSession || model.busy || model.nightMode)
                        Toggle("夜间画面变暗", isOn: $model.nightMode).disabled(model.hasSession || model.busy)
                        if !model.requireAC {
                            Stepper("电量 ≤ \(model.minimumBattery)% 时停止", value: $model.minimumBattery, in: 10...80, step: 5)
                                .disabled(model.hasSession || model.busy)
                        }
                        Toggle("登录时启动", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
                        Text("登录后不自动保活。热压力持续严重或临界时停止；网络仅检测可用路径，断网停止后需手动重开。")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button("恢复设置") { Task { await model.recover() } }.disabled(model.busy || model.hasSession)
                            Button("移除后台组件") { Task { await model.removeHelper() } }.disabled(model.busy)
                        }
                        Link("开源与帮助", destination: URL(string: "https://github.com/diguike/KeepMyMacAwake")!)
                    }.padding(.top, 8)
                }
            }
            Divider()
            HStack {
                Text("KeepMyMacAwake · 开发预览").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Button("退出") { Task { await model.quit() } }.disabled(model.busy)
            }
        }.padding(18).frame(width: 370)
    }
}
