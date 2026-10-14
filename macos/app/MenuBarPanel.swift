import SwiftUI
import AppKit
import AwakeCore

/// Compact status panel shown from the menu bar icon: what is running, until
/// when, under which conditions, plus the few actions needed without the window.
struct MenuBarPanel: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                AppMark(size: 24)
                Text("KeepMyMacAwake").font(.system(size: 13, weight: .semibold))
                Spacer()
                PhaseBadge(phase: model.phase, text: model.phaseText)
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)
            Divider()
            content
            Divider()
            HStack(spacing: 14) {
                Button("控制窗口…") { open(.control) }
                Button("设置…") { open(.settings) }
                Spacer()
                Button("退出") { Task { await model.quit() } }.disabled(model.busy)
            }
            .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .frame(width: 320)
        .tint(AwakeStyle.accent)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusHero(model: model, compact: true)
            VStack(alignment: .leading, spacing: 7) {
                if model.active, let start = model.startTimeText {
                    InfoRow(icon: "clock", title: "开始于", value: start)
                    if !model.unlimitedSession, let elapsed = model.elapsedSeconds {
                        TimelineView(.periodic(from: .now, by: 30)) { _ in
                            InfoRow(icon: "hourglass", title: "已运行", value: SessionText.duration(model.elapsedSeconds ?? elapsed))
                        }
                    }
                }
                InfoRow(icon: "slider.horizontal.3", title: "规则", value: model.preferences.summary)
                Divider().padding(.vertical, 2)
                InfoRow(icon: model.sample.onAC == false ? "battery.50" : "bolt.fill", title: "电源", value: model.powerText,
                        warning: model.sample.onAC == nil || (model.requireAC && model.sample.onAC == false))
                InfoRow(icon: "wifi", title: "网络", value: model.networkText,
                        warning: model.requireNetwork && model.sample.networkAvailable != true)
                InfoRow(icon: "thermometer.medium", title: "散热", value: model.thermalDescription,
                        warning: model.sample.thermal == .unknown || model.sample.thermal == .serious || model.sample.thermal == .critical)
                if model.lidMode || model.helperConnected {
                    InfoRow(icon: "laptopcomputer", title: "合盖组件", value: model.helperState, warning: model.lidMode && !model.helperConnected)
                }
            }
            .awakeCard(padding: 12, radius: 12)
            if !model.active, let last = model.lastSession { LastSessionView(result: last).padding(.horizontal, 2) }
            if !model.hasSession {
                HStack(spacing: 6) {
                    ForEach(AwakeStyle.scenes, id: \.name) { scene in
                        sceneButton(scene.name, icon: scene.icon)
                    }
                }
            }
            PrimaryActions(model: model, compact: true)
        }
        .padding(14)
    }

    private func sceneButton(_ name: String, icon: String) -> some View {
        let selected = model.scene == name
        let title = ScenePreset.named(name)?.displayName ?? name
        return Button { model.chooseScene(name) } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 13, weight: .medium))
                Text(title).font(.system(size: 10, weight: .medium)).lineLimit(1)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 7)
            .foregroundStyle(selected ? AwakeStyle.accent : Color.secondary)
            .background(selected ? AwakeStyle.accent.opacity(0.12) : AwakeStyle.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(selected ? AwakeStyle.accent.opacity(0.5) : .clear, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(model.busy)
        .accessibilityLabel("选择\(title)场景").accessibilityAddTraits(selected ? .isSelected : [])
        .help(ScenePreset.named(name)?.preferences.summary ?? title)
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
