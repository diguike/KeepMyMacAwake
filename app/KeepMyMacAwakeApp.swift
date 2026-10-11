import SwiftUI
import AppKit
import CoreServices

@main struct KeepMyMacAwakeApp: App {
    @NSApplicationDelegateAdaptor(AwakeAppDelegate.self) private var delegate
    @StateObject private var model = AppModel.shared
    var body: some Scene {
        MenuBarExtra {
            AwakePanel(model: model, compact: true)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: model.active ? "cup.and.saucer.fill" : "cup.and.saucer")
                if model.active && model.showCountdown {
                    Text(model.unlimitedSession ? "∞" : "\(Int(ceil(model.remaining / 60)))m").monospacedDigit()
                }
            }.accessibilityLabel(model.active ? "KeepMyMacAwake 正在运行" : "KeepMyMacAwake 未开启")
        }.menuBarExtraStyle(.window)
    }
}

@MainActor final class AwakeAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        let properties = event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))
        let isLogin = event?.eventID == AEEventID(kAEOpenApplication) && properties?.enumCodeValue == OSType(keyAELaunchedAsLogInItem)
        if !isLogin { ControlWindow.shared.show() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        ControlWindow.shared.show(); return true
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if !AppModel.shared.hasSession { return .terminateNow }
        Task { let stopped = await AppModel.shared.stop(); sender.reply(toApplicationShouldTerminate: stopped) }
        return .terminateLater
    }
}

@MainActor final class ControlWindow {
    static let shared = ControlWindow()
    private var window: NSWindow?
    func show() {
        if window == nil {
            let next = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 470, height: 720),
                                styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            next.title = "KeepMyMacAwake"
            next.titlebarAppearsTransparent = true
            next.isReleasedWhenClosed = false
            next.contentView = NSHostingView(rootView: AwakePanel(model: .shared, compact: false))
            next.center(); window = next
        }
        window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
}

struct AwakePanel: View {
    @ObservedObject var model: AppModel
    var compact = true
    @State private var tab = "保活"
    private let amber = Color(red: 0.77, green: 0.40, blue: 0.16)
    private let scenes = [("日常", "cup.and.saucer", "专心长任务"), ("夜间", "moon", "柔光伴你休息"),
                          ("接电合盖", "powerplug", "断电时停止"), ("有网时", "wifi", "断网时停止")]
    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 22).padding(.top, compact ? 18 : 22).padding(.bottom, 16)
            if model.onboarded {
                Picker("页面", selection: $tab) { Text("保活").tag("保活"); Text("设置").tag("设置") }
                    .pickerStyle(.segmented).labelsHidden().padding(.horizontal, 22).padding(.bottom, 12)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !model.onboarded { welcome }
                    else if tab == "设置" { settings }
                    else { controls }
                }.padding(.horizontal, 22).padding(.bottom, 20)
            }.scrollIndicators(.hidden)
            if model.onboarded && tab == "保活" { primaryAction.padding(.horizontal, 22).padding(.vertical, 12) }
            footer
        }
        .frame(width: compact ? 390 : 470, height: compact ? 620 : 720)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(amber)
    }
    private var header: some View {
        HStack(spacing: 11) {
            Image(systemName: "cup.and.saucer.fill").font(.system(size: 23, weight: .medium))
                .foregroundStyle(amber).frame(width: 42, height: 42)
                .background(amber.opacity(0.10), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 3) {
                Text("KeepMyMacAwake").font(.system(size: 17, weight: .semibold))
                Text("工作继续，安心休息。").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(model.active ? .green : Color.secondary.opacity(0.5)).frame(width: 6, height: 6)
                Text(model.active ? "运行中" : "待机").font(.system(size: 10, weight: .medium))
            }.padding(.horizontal, 9).padding(.vertical, 6)
                .background(Color.primary.opacity(0.04), in: Capsule())
        }
    }
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "moon.stars").font(.system(size: 50, weight: .ultraLight)).foregroundStyle(amber)
                .frame(maxWidth: .infinity).padding(.vertical, 20)
            Text("把长任务留给 Mac。\n把时间留给自己。").font(.system(size: 29, weight: .medium, design: .rounded)).lineSpacing(6)
            Text("一个安静的菜单栏小工具。设定时长，选择场景，放心让下载、构建和远程工作继续。")
                .font(.callout).foregroundStyle(.secondary).lineSpacing(4)
            VStack(alignment: .leading, spacing: 12) {
                Label("定时结束，也能直到手动停止", systemImage: "timer")
                Label("夜间柔光，结束后自动恢复", systemImage: "moon")
                Label("合盖前准备好，电量与热状态保护", systemImage: "laptopcomputer")
            }.font(.callout)
            Text("请保持通风。保活不会绕过锁屏；合盖需要批准后台组件。")
                .font(.caption).foregroundStyle(.secondary)
            Button("开始使用") { model.acknowledge() }
                .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
                .keyboardShortcut(.defaultAction)
        }
    }
    private var controls: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(amber.opacity(0.12), lineWidth: 4)
                    Circle().trim(from: 0, to: model.sessionProgress).stroke(amber.opacity(model.active ? 1 : 0.4),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
                    Image(systemName: model.nightMode ? "moon.zzz" : "cup.and.saucer.fill")
                        .font(.system(size: 28, weight: .light)).foregroundStyle(amber)
                }.frame(width: 70, height: 70).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 7) {
                    Text(model.statusTitle).font(.system(size: compact ? 25 : 30, weight: .medium, design: .rounded)).monospacedDigit()
                    Text(model.active ? "\(model.scene) · 保持运行中" : "选好场景，一键开始").font(.caption).foregroundStyle(.secondary)
                }
            }.padding(.vertical, 8)
            HStack(spacing: 7) {
                ForEach(scenes, id: \.0) { name, icon, detail in
                    Button { model.chooseScene(name) } label: {
                        VStack(spacing: 7) {
                            Image(systemName: icon).font(.system(size: 18, weight: .medium))
                            Text(name).font(.system(size: 11, weight: .medium))
                        }.frame(maxWidth: .infinity).padding(.vertical, 12)
                            .foregroundStyle(model.scene == name ? amber : Color.secondary)
                            .background(model.scene == name ? amber.opacity(0.10) : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(model.scene == name ? amber.opacity(0.35) : .clear, lineWidth: 1))
                    }.buttonStyle(.plain).disabled(model.hasSession || model.busy)
                        .accessibilityLabel("选择\(name)场景").help(detail)
                }
            }
            VStack(alignment: .leading, spacing: 13) {
                Picker("持续时间", selection: $model.durationMinutes) {
                    Text("30 分钟").tag(30); Text("1 小时").tag(60); Text("2 小时").tag(120)
                    Text("8 小时").tag(480); Text("直到手动停止").tag(-1); Text("自定义…").tag(0)
                }
                if model.durationMinutes == 0 {
                    HStack { Text("自定义分钟"); Spacer(); TextField("1–1440", value: $model.customMinutes, format: .number)
                        .textFieldStyle(.roundedBorder).frame(width: 100).accessibilityLabel("自定义分钟") }
                }
                Divider()
                Text("屏幕").font(.caption).foregroundStyle(.secondary)
                Picker("屏幕模式", selection: $model.screenMode) {
                    Text("自动熄屏").tag("自动熄屏"); Text("保持常亮").tag("保持常亮"); Text("夜间柔光").tag("夜间柔光")
                }.pickerStyle(.segmented).labelsHidden()
                if model.nightMode {
                    HStack {
                        Image(systemName: "sun.min").foregroundStyle(.secondary)
                        Slider(value: $model.dimAmount, in: 0.8...0.98).accessibilityLabel("夜间画面变暗程度")
                        Text("\(Int(model.dimAmount * 100))%").font(.caption.monospacedDigit()).frame(width: 34)
                    }
                    Text("临时柔光遮罩，非硬件背光调节。停止后恢复，菜单栏仍可操作。")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Divider()
                Toggle("合盖继续运行", isOn: $model.lidMode).toggleStyle(.switch)
                Toggle("仅接通电源时保活", isOn: $model.requireAC).toggleStyle(.switch)
                Toggle("断网时停止", isOn: $model.requireNetwork).toggleStyle(.switch)
            }.font(.system(size: 12)).padding(14).card().disabled(model.hasSession || model.busy)
            if model.lidMode && !model.helperConnected { authorization }
            telemetry
        }
    }
    private var primaryAction: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task { if model.hasSession { await model.stop() } else { await model.start() } }
            } label: {
                Label(model.busy ? "正在处理…" : model.hasSession ? "停止保活" : "开始保活", systemImage: model.hasSession ? "stop.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 7)
            }.buttonStyle(.borderedProminent).controlSize(.large).disabled(model.busy || model.needsRecovery)
                .keyboardShortcut(.return, modifiers: .command)
            if model.active && !model.unlimitedSession {
                Button("再加 15 分钟") { Task { await model.extendSession() } }
                    .frame(maxWidth: .infinity).disabled(model.busy || model.sessionSeconds + 900 > 86400)
            }
            Text(model.message).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            if model.needsRecovery { Button("恢复设置") { Task { await model.recover() } }.disabled(model.busy) }
        }
    }
    private var authorization: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("合盖前，需要后台组件", systemImage: "lock.shield").font(.system(size: 12, weight: .medium))
            Text(model.helperState).font(.caption).foregroundStyle(.secondary)
            Button(model.helperNeedsApproval ? "打开系统授权" : "安装 / 检查授权") { Task { await model.installHelper() } }.disabled(model.busy || model.hasSession)
            if model.helperNeedsApproval { Text("在系统设置开启 KeepMyMacAwake 后台活动，使用触控 ID 或登录密码批准。").font(.caption).foregroundStyle(.secondary) }
            if !model.helperBuildEnabled { Text("此构建仅支持普通模式。合盖功能需证书签名。").font(.caption).foregroundStyle(.secondary) }
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(amber.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
    private var telemetry: some View {
        HStack(spacing: 9) {
            Label(model.sample.onAC.map { $0 ? "已接电" : "电池" } ?? "电源未知", systemImage: "bolt")
            Text(model.sample.batteryPercent.map { "\($0)%" } ?? "—")
            Spacer()
            Label(model.sample.networkAvailable.map { $0 ? "网络可用" : "无网络" } ?? "网络未知", systemImage: "wifi")
        }.font(.system(size: 10)).foregroundStyle(.secondary)
    }
    private var settings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("按你的习惯。").font(.system(size: 25, weight: .medium, design: .rounded)).padding(.vertical, 6)
            VStack(alignment: .leading, spacing: 14) {
                Label("日常使用", systemImage: "slider.horizontal.3").font(.headline)
                Toggle("菜单栏显示剩余时间", isOn: $model.showCountdown).toggleStyle(.switch)
                Toggle("登录时启动", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) })).toggleStyle(.switch)
                Text("记住场景和设置；登录或重启后不会自动保活。").font(.caption).foregroundStyle(.secondary)
            }.padding(16).card()
            VStack(alignment: .leading, spacing: 14) {
                Label("保护条件", systemImage: "shield.lefthalf.filled").font(.headline)
                Stepper("电量 ≤ \(model.minimumBattery)% 时停止", value: $model.minimumBattery, in: 10...80, step: 5).disabled(model.hasSession || model.busy)
                LabeledContent("当前热状态", value: model.thermalDescription)
                Text("电池模式使用电量保护。持续严重或临界热压力时停止；断网停止后需手动重开。网络可用路径不保证远端服务可达。")
                    .font(.caption).foregroundStyle(.secondary).lineSpacing(2)
            }.font(.callout).padding(16).card()
            VStack(alignment: .leading, spacing: 12) {
                Label("合盖后台组件", systemImage: "laptopcomputer").font(.headline)
                Text(model.helperState).font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(model.helperNeedsApproval ? "打开系统授权" : "安装 / 检查授权") { Task { await model.installHelper() } }.disabled(model.busy || model.hasSession)
                    Button("系统设置") { model.openApprovalSettings() }
                }
                if model.helperNeedsApproval { Text("首次启用需要本人用触控 ID 或登录密码批准后台活动。").font(.caption).foregroundStyle(.secondary) }
                Divider()
                HStack {
                    Button("恢复设置") { Task { await model.recover() } }.disabled(model.busy || model.active)
                    Button("停止并移除组件") { Task { await model.removeHelper() } }.disabled(model.busy)
                }
                Text("卸载 App 前先移除组件。恢复只撤销本应用的改动，不保证机器立即入睡。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(16).card()
            Text(model.message).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            Link("开源项目与使用说明 ↗", destination: URL(string: "https://github.com/diguike/KeepMyMacAwake")!)
                .font(.callout)
            Text("KeepMyMacAwake \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版") · 递归客\n原生 macOS · MIT 开源").font(.caption).foregroundStyle(.secondary).lineSpacing(3)
        }
    }
    private var footer: some View {
        HStack {
            if compact { Button("打开控制窗口") { ControlWindow.shared.show() }.buttonStyle(.plain) }
            else { Text("菜单栏的杯子图标，随时可用。").foregroundStyle(.secondary) }
            Spacer()
            Button("退出") { Task { await model.quit() } }.buttonStyle(.plain).disabled(model.busy)
        }.font(.system(size: 10)).padding(.horizontal, 22).padding(.vertical, 14)
            .background(Color.primary.opacity(0.025))
    }
}
private extension View {
    func card() -> some View {
        self.background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.055), lineWidth: 1))
    }
}
