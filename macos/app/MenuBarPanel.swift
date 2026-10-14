import SwiftUI
import AppKit
import AwakeCore

/// Compact status panel shown from the menu bar icon: what is running, until
/// when, under which conditions, plus the few actions needed without the window.
struct MenuBarPanel: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("KeepMyMacAwake").font(.system(size: 12.5, weight: .semibold))
                Spacer()
                IconButton(symbol: "slider.horizontal.3", label: "更多选项") { open(.control) }
                IconButton(symbol: "gearshape", label: "设置") { open(.settings) }
                IconButton(symbol: "power", label: "退出") { Task { await model.quit() } }.disabled(model.busy)
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 4)
            content
        }
        .frame(width: 320)
        .background(AwakeStyle.page)
        .tint(AwakeStyle.ink)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusHero(model: model, compact: true).awakeCard(padding: 14, radius: 14)
            VStack(alignment: .leading, spacing: 7) {
                if let period = model.periodText {
                    InfoRow(icon: "clock", title: model.unlimitedSession ? "开始于" : "时段", value: period)
                    Divider().padding(.vertical, 2)
                }
                InfoRow(icon: model.sample.onAC == false ? "battery.50" : "bolt.fill", title: "电源", value: model.powerText, warning: model.powerWarning)
                InfoRow(icon: "wifi", title: "网络", value: model.networkText, warning: model.networkWarning).help(AppModel.networkHelp)
                InfoRow(icon: "thermometer.medium", title: "散热", value: model.thermalDescription, warning: model.thermalWarning).help(AppModel.thermalHelp)
                if model.lidMode {
                    InfoRow(icon: "puzzlepiece.extension", title: "后台组件", value: model.helperState, warning: !model.helperConnected)
                }
            }
            .awakeCard(padding: 12, radius: 12)
            if !model.hasSession, let last = model.lastSession { LastSessionView(result: last, now: model.now).padding(.horizontal, 2) }
            if !model.hasSession {
                PillPicker(options: AwakeStyle.scenes.map { ($0.name, ScenePreset.named($0.name)?.displayName ?? $0.name) },
                           selection: Binding(get: { model.scene }, set: { model.chooseScene($0) }), compact: true)
                    .frame(maxWidth: .infinity).disabled(model.busy)
            }
            PrimaryActions(model: model, compact: true)
        }
        .padding(14)
    }

    private func open(_ tab: PanelTab) {
        // Close the menu bar panel first so the control window can take focus.
        if let panel = NSApp.keyWindow, panel !== ControlWindow.shared.window { panel.close() }
        ControlWindow.shared.show(tab: tab)
    }
}

/// Menu bar icon and optional countdown. Shape, not just color, signals state.
struct MenuBarLabel: View {
    @ObservedObject var model: AppModel
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
            if model.active && model.showCountdown {
                Text(model.unlimitedSession ? "∞" : SessionText.menuBar(remaining: model.remaining)).monospacedDigit()
            }
        }
        .accessibilityLabel(accessibility)
    }
    private var symbol: String {
        switch model.phase {
        case .on: return "cup.and.saucer.fill"
        case .off: return "cup.and.saucer"
        case .confirming, .recovery: return "exclamationmark.triangle"
        }
    }
    private var accessibility: String {
        if model.active && !model.unlimitedSession {
            return "KeepMyMacAwake 保持唤醒中，剩余 \(SessionText.duration(model.remaining))"
        }
        return "KeepMyMacAwake \(model.phaseText)"
    }
}
