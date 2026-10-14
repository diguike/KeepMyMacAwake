import SwiftUI
import AppKit
import AwakeCore

enum PanelTab: String { case control = "控制", settings = "设置" }

/// Lets the menu bar panel open the control window on a specific page.
@MainActor final class PanelRouter: ObservableObject {
    static let shared = PanelRouter()
    @Published var tab: PanelTab = .control
}

/// Reports its height when it appears and whenever it changes.
private struct HeightReporter: View {
    let report: (CGFloat) -> Void
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .onAppear { report(geometry.size.height) }
                .onChange(of: geometry.size.height) { _, height in report(height) }
        }
    }
}

struct ControlPanel: View {
    @ObservedObject var model: AppModel
    @ObservedObject var router: PanelRouter = .shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                AppMark(size: 26)
                Text("KeepMyMacAwake").font(.system(size: 14, weight: .semibold))
                Spacer()
                PillPicker(options: [(PanelTab.control, PanelTab.control.rawValue), (PanelTab.settings, PanelTab.settings.rawValue)],
                           selection: $router.tab, compact: true)
            }
            .padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if router.tab == .settings { SettingsView(model: model) } else { controls }
                }
                .padding(.horizontal, 22).padding(.bottom, 20)
                .background(HeightReporter { ControlWindow.shared.fit(content: $0) })
            }
            .scrollIndicators(.hidden)
            // The window hugs the page instead of leaving an empty area below it.
            .background(HeightReporter { ControlWindow.shared.fit(viewport: $0) })
            if router.tab == .control {
                Divider()
                PrimaryActions(model: model).padding(.horizontal, 22).padding(.vertical, 14)
            }
        }
        .frame(width: 460).frame(minHeight: 300, idealHeight: 760, maxHeight: .infinity)
        .background(AwakeStyle.page)
        .tint(AwakeStyle.ink)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                StatusHero(model: model)
                Divider()
                ConditionChips(model: model)
                if !model.hasSession, let last = model.lastSession { LastSessionView(result: last, now: model.now) }
            }
            .awakeCard(padding: 14, radius: 16)

            if model.hasSession {
                SessionSummary(model: model)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle(text: "场景")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(AwakeStyle.scenes, id: \.name) { scene in
                            SceneCard(name: scene.name, icon: scene.icon, selected: model.scene == scene.name) { model.chooseScene(scene.name) }
                                .disabled(model.busy)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        SectionTitle(text: "选项")
                        if model.preferences.isCustomized {
                            Text("已调整").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                                .padding(.horizontal, 6).padding(.vertical, 1.5).background(AwakeStyle.well, in: Capsule())
                        }
                    }
                    options
                }
            }
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("时长").font(.system(size: 13))
                Spacer()
                Picker("时长", selection: $model.durationMinutes) {
                    Text("30 分钟").tag(30); Text("1 小时").tag(60); Text("2 小时").tag(120)
                    Text("8 小时").tag(480); Divider(); Text("不限时").tag(-1); Text("自定义…").tag(0)
                }
                .labelsHidden().fixedSize()
            }
            if model.durationMinutes == 0 {
                HStack {
                    Text("分钟").font(.system(size: 13))
                    Spacer()
                    TextField("1–1440", value: $model.customMinutes, format: .number)
                        .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).frame(width: 80)
                        .accessibilityLabel("自定义分钟")
                }
            }
            Divider()
            HStack {
                Text("屏幕").font(.system(size: 13))
                Spacer()
                PillPicker(options: ["自动熄屏", "保持常亮", "夜间柔光"].map { ($0, SessionText.screenMode($0)) },
                           selection: $model.screenMode, compact: true)
                    .help(SessionText.screenModeHelp)
            }
            if model.nightMode {
                HStack(spacing: 8) {
                    Image(systemName: "sun.max").font(.system(size: 11)).foregroundStyle(.secondary)
                    Slider(value: $model.dimAmount, in: 0.8...0.98).controlSize(.small).accessibilityLabel("调暗程度")
                    Image(systemName: "moon.fill").font(.system(size: 11)).foregroundStyle(.secondary)
                    Text("\(Int((model.dimAmount * 100).rounded()))%").font(.system(size: 11).monospacedDigit()).frame(width: 34, alignment: .trailing)
                }
            }
            Divider()
            ToggleRow(title: "合盖后继续运行", isOn: $model.lidMode).help("关闭时，合盖会正常睡眠")
            if model.lidMode && !model.helperConnected { AuthorizationCard(model: model) }
            ToggleRow(title: "仅在接通电源时运行", isOn: $model.requireAC)
            if !model.requireAC {
                HStack {
                    Text("电量下限").font(.system(size: 13))
                    Spacer()
                    Text("\(model.minimumBattery)%").font(.system(size: 13).monospacedDigit()).foregroundStyle(.secondary)
                    Stepper("电量下限", value: $model.minimumBattery, in: 10...80, step: 5).labelsHidden()
                }
                .padding(.leading, 12)
            }
            ToggleRow(title: "断网时停止", isOn: $model.requireNetwork).help("只检测系统是否有可用网络；网络恢复后不会自动开始")
        }
        .awakeCard()
        .disabled(model.busy)
    }
}

/// Read-only rules of the running session, in place of disabled controls.
struct SessionSummary: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "本次会话")
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(icon: "square.grid.2x2", title: "场景", value: model.sceneDisplayName)
                if let start = model.startTimeText {
                    InfoRow(icon: "clock", title: "开始", value: start)
                }
                InfoRow(icon: "display", title: "屏幕", value: SessionText.screenMode(model.screenMode) + (model.nightMode ? " \(Int((model.dimAmount * 100).rounded()))%" : ""))
                if model.lidMode { InfoRow(icon: "laptopcomputer", title: "合盖", value: "继续运行") }
                InfoRow(icon: "bolt", title: "供电", value: model.requireAC ? "仅接电" : "可用电池，下限 \(model.minimumBattery)%")
                if model.requireNetwork { InfoRow(icon: "wifi", title: "断网", value: "停止") }
            }
            .awakeCard()
        }
    }
}

struct SceneCard: View {
    let name: String
    let icon: String
    let selected: Bool
    let action: () -> Void
    private var preset: ScenePreset? { ScenePreset.named(name) }
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 14)).frame(width: 28, height: 28)
                    .foregroundStyle(selected ? AwakeStyle.onInk : Color.secondary)
                    .background(selected ? AwakeStyle.ink : AwakeStyle.well, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset?.displayName ?? name).font(.system(size: 13, weight: .semibold)).foregroundStyle(.primary)
                    Text(preset?.tagline ?? "").font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(AwakeStyle.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(selected ? AwakeStyle.ink.opacity(0.85) : AwakeStyle.hairline, lineWidth: selected ? 1 : 0.5))
            .shadow(color: .black.opacity(selected ? 0.07 : 0.03), radius: selected ? 5 : 3, y: selected ? 2 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preset?.displayName ?? name).accessibilityAddTraits(selected ? .isSelected : [])
        .help(preset?.preferences.summary ?? name)
    }
}

/// Power, network and thermal at a glance; orange only for unknown values or a broken rule.
struct ConditionChips: View {
    @ObservedObject var model: AppModel
    var body: some View {
        HStack(spacing: 8) {
            ConditionChip(icon: model.sample.onAC == false ? "battery.50" : "bolt.fill", value: model.powerText, warning: model.powerWarning)
            ConditionChip(icon: "wifi", value: "网络\(model.networkText)", warning: model.networkWarning)
                .help(AppModel.networkHelp)
            ConditionChip(icon: "thermometer.medium", value: "散热\(model.thermalDescription)", warning: model.thermalWarning)
                .help(AppModel.thermalHelp)
            Spacer(minLength: 0)
        }
    }
}

struct ConditionChip: View {
    let icon: String
    let value: String
    var warning = false
    var body: some View {
        Label(value, systemImage: icon).font(.system(size: 11, weight: .medium)).lineLimit(1)
            .foregroundStyle(warning ? Color.orange : Color.secondary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(warning ? Color.orange.opacity(0.12) : AwakeStyle.well, in: Capsule())
    }
}

/// Start/stop stays pinned below the scrolling controls; the line below shows errors only.
struct PrimaryActions: View {
    @ObservedObject var model: AppModel
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.needsRecovery {
                Button { Task { await model.recover() } } label: {
                    Label("恢复睡眠设置", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
                }
                .buttonStyle(AwakeButtonStyle(kind: .primary, compact: compact)).disabled(model.busy)
                .help("只撤销本应用的改动")
            } else {
                HStack(spacing: 8) {
                    Button {
                        Task { if model.hasSession { await model.stop() } else { await model.start() } }
                    } label: {
                        HStack(spacing: 6) {
                            if model.busy { ProgressView().controlSize(.small) }
                            else { Image(systemName: model.hasSession ? "stop.fill" : "play.fill") }
                            Text(model.hasSession ? "停止" : "开始")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AwakeButtonStyle(kind: model.hasSession ? .neutral : .primary, compact: compact))
                    .disabled(model.busy)
                    .keyboardShortcut(.return, modifiers: .command)
                    if model.active && !model.unlimitedSession {
                        Button { Task { await model.extendSession() } } label: { Text("+15 分钟") }
                            .buttonStyle(AwakeButtonStyle(kind: .secondary, compact: compact))
                            .disabled(model.busy || model.sessionSeconds + 900 > 86400)
                            .help("延长 15 分钟")
                    }
                }
            }
            if !model.message.isEmpty {
                Text(model.message).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            }
        }
    }
}

/// Sits right under the lid switch, so turning it on shows what is missing.
struct AuthorizationCard: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.helperBuildEnabled {
                Text(model.helperNeedsApproval ? "等待在系统设置中允许" : "合盖需要安装后台组件").font(.system(size: 12, weight: .semibold))
                Text(model.helperNeedsApproval ? "在“系统设置 > 通用 > 登录项与扩展”中打开 KeepMyMacAwake" : "合盖期间由它保持唤醒，结束后自动恢复睡眠设置")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HelperButton(model: model).buttonStyle(AwakeButtonStyle(kind: .primary, compact: true)).fixedSize()
            } else {
                Text(AppModel.unsignedLid).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(AwakeStyle.well, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// One action that matches the current helper state.
struct HelperButton: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Button(model.helperNeedsApproval ? "前往系统设置授权" : model.helperNeedsInstall ? "安装后台组件" : "重新连接") {
            Task { await model.installHelper() }
        }
        .disabled(model.busy || model.hasSession)
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var confirmUninstall = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            group("通用") {
                ToggleRow(title: "菜单栏显示剩余时间", isOn: $model.showCountdown)
                ToggleRow(title: "登录时打开", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
                ToggleRow(title: "结束时通知", detail: model.notificationMessage,
                          isOn: Binding(get: { model.notifyOnEnd }, set: { enabled in Task { await model.setNotifications(enabled) } }))
            }
            group("后台组件") {
                InfoRow(icon: "puzzlepiece.extension", title: "状态", value: model.helperState)
                if model.helperBuildEnabled {
                    HStack {
                        HelperButton(model: model)
                        Spacer()
                        Button("恢复睡眠设置") { Task { await model.recover() } }
                            .disabled(model.busy || model.active).help("只撤销本应用的改动")
                        Button("卸载后台组件…") { confirmUninstall = true }.disabled(model.busy)
                    }
                    .controlSize(.small)
                    Text("删除 App 前请先卸载后台组件。合盖运行时请放在通风处。")
                        .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(AppModel.unsignedLid).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            if !model.message.isEmpty {
                Text(model.message).font(.system(size: 11)).foregroundStyle(.secondary).textSelection(.enabled)
            }
            HStack(spacing: 10) {
                AppMark(size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text("KeepMyMacAwake \(appVersion)").font(.system(size: 12, weight: .medium))
                    Link("github.com/diguike/KeepMyMacAwake", destination: URL(string: "https://github.com/diguike/KeepMyMacAwake")!)
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button("退出") { Task { await model.quit() } }.disabled(model.busy)
            }
            .padding(.top, 4)
        }
        .confirmationDialog("卸载后台组件？", isPresented: $confirmUninstall) {
            Button("卸载", role: .destructive) { Task { await model.removeHelper() } }
        } message: {
            Text("当前会话将停止，合盖功能需要重新安装后才能使用。")
        }
    }
    /// Test hosts and `swift run` are not the app bundle; do not show their version.
    private var appVersion: String {
        guard Bundle.main.bundleIdentifier == "io.github.diguike.KeepMyMacAwake" else { return "开发版" }
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版"
    }
    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: title)
            VStack(alignment: .leading, spacing: 12) { content() }.frame(maxWidth: .infinity, alignment: .leading).awakeCard()
        }
    }
}
