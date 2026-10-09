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
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "cup.and.saucer").font(.title)
                VStack(alignment: .leading) {
                    Text("KeepMyMacAwake").font(.headline)
                    Text("合盖继续运行，到时恢复休眠").font(.caption).foregroundStyle(.secondary)
                }
            }
            if !model.onboarded {
                Text("在通风桌面上使用。保活不保证网络不断；锁屏策略保持有效。合盖功能需要系统批准后台组件，当前版本需先在你的 Mac 上验证。")
                    .font(.callout)
                Button("了解并开始") { model.acknowledge() }.buttonStyle(.borderedProminent)
            } else {
                Text(model.message).font(.callout).textSelection(.enabled)
                if model.active {
                    Text("剩余 \(Int(ceil(model.remaining / 60))) 分钟").font(.title2.monospacedDigit())
                }
                HStack {
                    Button(model.hasSession ? "立即停止" : "保持运行") {
                        Task { if model.hasSession { await model.stop() } else { await model.start() } }
                    }.buttonStyle(.borderedProminent).disabled(model.busy)
                    if !model.active { Button("恢复设置") { Task { await model.recover() } }.disabled(model.busy) }
                }
                Group {
                    Picker("持续时间", selection: $model.durationMinutes) {
                        Text("30 分钟").tag(30); Text("1 小时").tag(60); Text("2 小时").tag(120); Text("自定义").tag(0)
                    }
                    if model.durationMinutes == 0 {
                        HStack { Text("分钟"); TextField("1–1440", value: $model.customMinutes, format: .number).frame(width: 90) }
                    }
                    Toggle("合盖后也保持运行", isOn: $model.lidMode)
                    Toggle("仅在接通电源时运行", isOn: $model.requireAC)
                    if !model.requireAC {
                        Stepper("电量 ≤ \(model.minimumBattery)% 时停止", value: $model.minimumBattery, in: 10...80, step: 5)
                    }
                }.disabled(model.hasSession || model.busy)
                Divider()
                Text(model.helperState).font(.caption).foregroundStyle(.secondary)
                if model.lidMode {
                    HStack {
                        Button("安装 / 检查授权") { model.authorize() }.disabled(model.busy || model.active)
                        Button("系统设置") { model.openApprovalSettings() }
                    }
                }
                Text("电源：\(model.sample.onAC.map { $0 ? "接通电源" : "电池供电" } ?? "未知") · 电量：\(model.sample.batteryPercent.map { "\($0)%" } ?? "未知")")
                    .font(.caption)
                Text("热状态：\(model.sample.thermal.rawValue) · \(model.network)").font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("设置与恢复") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("登录时启动（不自动保活）", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
                        Button("停止并移除后台组件") { Task { await model.removeHelper() } }.disabled(model.busy)
                        Link("开源与帮助", destination: URL(string: "https://github.com/diguike/KeepMyMacAwake")!)
                        Text("严重热压力持续 30 秒或达到临界状态时停止；保护数据未知时停止。恢复设置不代表机器立即入睡。")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.top, 8)
                }
            }
            Divider()
            Button("停止并退出") { Task { await model.quit() } }.disabled(model.busy)
        }.padding(20).frame(width: 380)
    }
}
