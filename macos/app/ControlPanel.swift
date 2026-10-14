import SwiftUI
import AppKit
import AwakeCore

enum PanelTab: String { case control = "控制", settings = "设置" }

/// Lets the menu bar panel open the control window on a specific page.
@MainActor final class PanelRouter: ObservableObject {
    static let shared = PanelRouter()
    @Published var tab: PanelTab = .control
}

struct ControlPanel: View {
    @ObservedObject var model: AppModel
    @ObservedObject var router: PanelRouter = .shared
    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 14)
            Picker("页面", selection: $router.tab) {
                Text(PanelTab.control.rawValue).tag(PanelTab.control)
                Text(PanelTab.settings.rawValue).tag(PanelTab.settings)
            }
            .pickerStyle(.segmented).labelsHidden().padding(.horizontal, 22).padding(.bottom, 14)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if router.tab == .settings { SettingsView(model: model) }
                    else { controls }
                }
                .padding(.horizontal, 22).padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            if router.tab == .control {
                Divider()
                PrimaryActions(model: model).padding(.horizontal, 22).padding(.vertical, 14)
            }
            footer
        }
        .frame(width: 460).frame(minHeight: 560, idealHeight: 886, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(AwakeStyle.accent)
    }

    private var header: some View {
        HStack(spacing: 12) {
            AppMark(size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("KeepMyMacAwake").font(.system(size: 16, weight: .semibold))
                Text("让 Mac 在你离开时继续工作").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            PhaseBadge(phase: model.phase, text: model.phaseText)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !model.onboarded { FirstRunCard(model: model) }
            VStack(alignment: .leading, spacing: 12) {
                StatusHero(model: model)
                Divider()
                HStack(spacing: 8) {
                    ConditionChip(icon: model.sample.onAC == false ? "battery.50" : "bolt.fill", value: model.powerText,
                                  warning: model.sample.onAC == nil || (model.requireAC && model.sample.onAC == false))
                    ConditionChip(icon: "wifi", value: "网络\(model.networkText)",
                                  warning: model.sample.networkAvailable != true && model.requireNetwork)
                    ConditionChip(icon: "thermometer.medium", value: "散热\(model.thermalDescription)",
                                  warning: model.sample.thermal == .unknown || model.sample.thermal == .serious || model.sample.thermal == .critical)
                    Spacer(minLength: 0)
                }
                if !model.active, let last = model.lastSession { LastSessionView(result: last) }
            }
            .awakeCard(padding: 14, radius: 16)

            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(text: "场景")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(AwakeStyle.scenes, id: \.name) { scene in
                        SceneCard(name: scene.name, icon: scene.icon, selected: model.scene == scene.name) { model.chooseScene(scene.name) }
                            .disabled(model.hasSession || model.busy)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionTitle(text: "本次设置")
                    Spacer()
                    if model.preferences.isCustomized {
                        Text("已调整").font(.system(size: 10, weight: .medium)).foregroundStyle(AwakeStyle.accent)
                            .padding(.horizontal, 6).padding(.vertical, 2).background(AwakeStyle.accent.opacity(0.12), in: Capsule())
                    }
                }
                sessionSettings
            }

            if model.lidMode && !model.helperConnected { AuthorizationCard(model: model) }
        }
    }

    private var sessionSettings: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("时长").font(.system(size: 13))
                Spacer()
                Picker("时长", selection: $model.durationMinutes) {
                    Text("30 分钟").tag(30); Text("1 小时").tag(60); Text("2 小时").tag(120)
                    Text("8 小时").tag(480); Divider(); Text("直到手动停止").tag(-1); Text("自定义…").tag(0)
                }
                .labelsHidden().fixedSize()
            }
            if model.durationMinutes == 0 {
                HStack {
                    Text("自定义分钟").font(.system(size: 13))
                    Spacer()
                    TextField("1–1440", value: $model.customMinutes, format: .number)
                        .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).frame(width: 80)
                        .accessibilityLabel("自定义分钟")
                    Text("分钟").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("屏幕").font(.system(size: 13))
                    Spacer()
                    Picker("屏幕", selection: $model.screenMode) {
                        ForEach(["自动熄屏", "保持常亮", "夜间柔光"], id: \.self) { Text(SessionText.screenMode($0)).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                }
                Text(SessionText.screenModeDetail(model.screenMode)).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if model.nightMode {
                    HStack(spacing: 8) {
                        Image(systemName: "sun.max").font(.system(size: 11)).foregroundStyle(.secondary)
                        Slider(value: $model.dimAmount, in: 0.8...0.98).controlSize(.small).accessibilityLabel("屏幕调暗程度")
                        Image(systemName: "moon.fill").font(.system(size: 11)).foregroundStyle(.secondary)
                        Text("\(Int((model.dimAmount * 100).rounded()))%").font(.system(size: 11).monospacedDigit()).frame(width: 34, alignment: .trailing)
                    }
                }
            }
            Divider()
            ToggleRow(title: "合盖后继续运行", detail: model.lidMode ? "需要已授权的后台组件；合盖前确认显示“可以合盖”" : "关闭时请保持开盖，合盖会正常睡眠", isOn: $model.lidMode)
            ToggleRow(title: "仅在接通电源时运行", detail: model.requireAC ? "拔掉电源会自动停止" : "使用电池时，电量降到 \(model.minimumBattery)% 自动停止", isOn: $model.requireAC)
            ToggleRow(title: "断网时停止", detail: model.requireNetwork ? "网络断开后自动停止，恢复后需手动重新开始" : nil, isOn: $model.requireNetwork)
        }
        .awakeCard()
        .disabled(model.hasSession || model.busy)
    }

    private var footer: some View {
        HStack {
            Label("菜单栏杯子图标可随时查看状态", systemImage: "menubar.arrow.up.rectangle").foregroundStyle(.secondary)
            Spacer()
            Button("退出") { Task { await model.quit() } }.buttonStyle(.plain).foregroundStyle(.secondary).disabled(model.busy)
        }
        .font(.system(size: 11)).padding(.horizontal, 22).padding(.vertical, 12)
        .background(Color.primary.opacity(0.03))
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
                Image(systemName: icon).font(.system(size: 15, weight: .medium)).frame(width: 30, height: 30)
                    .foregroundStyle(selected ? AwakeStyle.accent : Color.secondary)
                    .background(selected ? AwakeStyle.accent.opacity(0.15) : Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset?.displayName ?? name).font(.system(size: 13, weight: .semibold)).foregroundStyle(.primary)
                    Text(preset?.tagline ?? "").font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? AwakeStyle.accent.opacity(0.08) : AwakeStyle.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(selected ? AwakeStyle.accent.opacity(0.55) : AwakeStyle.stroke, lineWidth: selected ? 1.5 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("选择\(preset?.displayName ?? name)场景").accessibilityAddTraits(selected ? .isSelected : [])
        .help(preset?.preferences.summary ?? name)
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
            .background(warning ? Color.orange.opacity(0.12) : Color.primary.opacity(0.05), in: Capsule())
    }
}

/// Start/stop stays pinned below the scrolling controls.
struct PrimaryActions: View {
    @ObservedObject var model: AppModel
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    Task { if model.hasSession { await model.stop() } else { await model.start() } }
                } label: {
                    Label(model.busy ? "正在处理…" : model.hasSession ? "停止" : "开始保持唤醒",
                          systemImage: model.hasSession ? "stop.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AwakeButtonStyle(kind: model.hasSession ? .neutral : .primary, compact: compact))
                .disabled(model.busy || model.needsRecovery)
                .keyboardShortcut(.return, modifiers: .command)
                if model.active && !model.unlimitedSession {
                    Button { Task { await model.extendSession() } } label: {
                        Label("延长 15 分钟", systemImage: "plus")
                    }
                    .buttonStyle(AwakeButtonStyle(kind: .secondary, compact: compact))
                    .disabled(model.busy || model.sessionSeconds + 900 > 86400)
                }
            }
            if model.needsRecovery {
                Button("恢复睡眠设置") { Task { await model.recover() } }.disabled(model.busy)
            }
            if !model.message.isEmpty {
                Text(model.message).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            }
        }
    }
}

struct AuthorizationCard: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("合盖前需要授权后台组件", systemImage: "lock.shield").font(.system(size: 13, weight: .semibold))
            Text("合盖后系统会强制睡眠。后台组件负责在合盖期间保持唤醒，并在结束、断电或 App 退出时自动恢复睡眠设置。")
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            InfoRow(icon: "puzzlepiece.extension", title: "后台组件", value: model.helperState)
            if model.helperBuildEnabled {
                HelperButton(model: model).buttonStyle(AwakeButtonStyle(kind: .primary, compact: true)).fixedSize()
                if model.helperNeedsApproval {
                    Text("在“系统设置 → 通用 → 登录项与扩展”中允许 KeepMyMacAwake 在后台运行，用触控 ID 或登录密码确认。")
                        .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("这是未签名的开发构建，无法安装合盖组件，只能开盖使用。签名版本（例如 Release 下载版）支持合盖。")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(AwakeStyle.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AwakeStyle.accent.opacity(0.25), lineWidth: 1))
    }
}

/// One action that matches the current helper state.
struct HelperButton: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Button(model.helperNeedsApproval ? "前往系统设置授权" : model.helperNeedsInstall ? "安装后台组件" : "重新检查连接") {
            Task { await model.installHelper() }
        }
        .disabled(model.busy || model.hasSession)
    }
}

/// Shown once above the controls; it never blocks starting a session.
struct FirstRunCard: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("使用须知", systemImage: "hand.wave").font(.system(size: 13, weight: .semibold)).foregroundStyle(AwakeStyle.accent)
                Spacer()
                Button("知道了") { model.acknowledge() }.buttonStyle(.plain).font(.system(size: 12, weight: .medium)).foregroundStyle(AwakeStyle.accent)
            }
            VStack(alignment: .leading, spacing: 6) {
                tip("选好场景和时长，点“开始保持唤醒”；Mac 不会因闲置而睡眠，到点自动恢复。")
                tip("可以锁屏离开。合盖继续运行需要先授权一次后台组件。")
                tip("请放在通风处。本应用只负责保持唤醒，不判断 AI 任务是否完成。")
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(AwakeStyle.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AwakeStyle.accent.opacity(0.22), lineWidth: 1))
    }
    private func tip(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Circle().fill(AwakeStyle.accent.opacity(0.7)).frame(width: 4, height: 4).offset(y: -2)
            Text(text).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            group("通用", icon: "gearshape") {
                ToggleRow(title: "菜单栏显示剩余时间", detail: "例如 7h59m；不限时显示 ∞", isOn: $model.showCountdown)
                ToggleRow(title: "登录时启动", detail: "只打开 App 并留在菜单栏，不会自动开始保持唤醒",
                          isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
                ToggleRow(title: "结束时发送通知", detail: model.notificationMessage,
                          isOn: Binding(get: { model.notifyOnEnd }, set: { enabled in Task { await model.setNotifications(enabled) } }))
                Text("场景和设置会自动记住；本机只保存最近一次结束的时间和原因，不保存任务内容。")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            group("自动停止条件", icon: "shield.lefthalf.filled") {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("使用电池时，电量 ≤ \(model.minimumBattery)% 停止").font(.system(size: 13))
                        Text("仅在关闭“仅在接通电源时运行”后生效").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Stepper("电量下限", value: $model.minimumBattery, in: 10...80, step: 5).labelsHidden()
                }
                .disabled(model.hasSession || model.busy)
                InfoRow(icon: "thermometer.medium", title: "当前散热状态", value: model.thermalDescription,
                        warning: model.sample.thermal == .unknown || model.sample.thermal == .serious || model.sample.thermal == .critical)
                Text("散热状态较高持续 30 秒或达到严重时自动停止；读不到电源或散热状态时也会停止。散热状态来自系统，不是温度读数。")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            group("合盖后台组件", icon: "laptopcomputer") {
                InfoRow(icon: "puzzlepiece.extension", title: "状态", value: model.helperState)
                if model.helperBuildEnabled {
                    HStack {
                        HelperButton(model: model)
                        Button("打开登录项设置") { model.openApprovalSettings() }
                    }
                    .controlSize(.small)
                    if model.helperNeedsApproval {
                        Text("首次启用需要你本人用触控 ID 或登录密码确认。").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Divider()
                    HStack {
                        Button("恢复睡眠设置") { Task { await model.recover() } }.disabled(model.busy || model.active)
                        Button("停止并卸载后台组件") { Task { await model.removeHelper() } }.disabled(model.busy)
                    }
                    .controlSize(.small)
                    Text("删除 App 前，请先卸载后台组件。“恢复”只撤销本应用的改动，不保证 Mac 立即睡眠。")
                        .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("这是未签名的开发构建，不连接也不管理后台组件。签名版本（例如 Release 下载版）支持合盖。")
                        .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            if !model.message.isEmpty {
                Text(model.message).font(.system(size: 11)).foregroundStyle(.secondary).textSelection(.enabled)
            }
            HStack(spacing: 12) {
                AppMark(size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("KeepMyMacAwake \(appVersion)")
                        .font(.system(size: 12, weight: .medium))
                    Text("递归客 · MIT 开源").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Link("GitHub 主页 ↗", destination: URL(string: "https://github.com/diguike/KeepMyMacAwake")!).font(.system(size: 12))
            }
            .padding(.top, 4)
        }
    }
    /// Test hosts and `swift run` are not the app bundle; do not show their version.
    private var appVersion: String {
        guard Bundle.main.bundleIdentifier == "io.github.diguike.KeepMyMacAwake" else { return "开发版" }
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版"
    }
    private func group<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) { content() }.frame(maxWidth: .infinity, alignment: .leading).awakeCard()
        }
    }
}
