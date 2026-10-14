import SwiftUI
import AppKit
import AwakeCore

/// Shared look for the control window and the menu bar panel.
enum AwakeStyle {
    /// Warm copper; brighter in dark mode so text and strokes keep contrast.
    static let accent = Color(nsColor: NSColor(name: "AwakeAccent") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.96, green: 0.67, blue: 0.38, alpha: 1)
            : NSColor(red: 0.73, green: 0.38, blue: 0.13, alpha: 1)
    })
    /// Text on the accent fill: white on dark copper, near-black on light copper.
    static let onAccent = Color(nsColor: NSColor(name: "AwakeOnAccent") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.13, green: 0.08, blue: 0.04, alpha: 1) : .white
    })
    static let surface = Color.primary.opacity(0.04)
    static let stroke = Color.primary.opacity(0.07)
    static func tint(_ phase: AppModel.Phase) -> Color {
        switch phase {
        case .off: return .secondary
        case .on: return .green
        case .confirming: return .orange
        case .recovery: return .red
        }
    }
    static let scenes: [(name: String, icon: String)] = [
        ("日常", "cup.and.saucer"), ("夜间", "moon.stars"), ("接电合盖", "powerplug"), ("有网时", "laptopcomputer")
    ]
}

extension View {
    func awakeCard(padding: CGFloat = 14, radius: CGFloat = 14) -> some View {
        self.padding(padding)
            .background(AwakeStyle.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(AwakeStyle.stroke, lineWidth: 1))
    }
}

/// Small rounded mark that echoes the app icon without relying on the bundle.
struct AppMark: View {
    var size: CGFloat = 38
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(LinearGradient(colors: [Color(red: 0.20, green: 0.22, blue: 0.27), Color(red: 0.08, green: 0.10, blue: 0.13)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(Image(systemName: "cup.and.saucer.fill").font(.system(size: size * 0.46, weight: .medium))
                .foregroundStyle(Color(red: 1, green: 0.90, blue: 0.75), Color(red: 0.95, green: 0.70, blue: 0.37)))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct PhaseBadge: View {
    let phase: AppModel.Phase
    let text: String
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(AwakeStyle.tint(phase)).frame(width: 7, height: 7)
                .shadow(color: phase == .on ? .green.opacity(0.6) : .clear, radius: 3)
            Text(text).font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(phase == .on ? Color.green.opacity(0.12) : AwakeStyle.surface, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

struct StatusRing: View {
    let progress: Double
    let active: Bool
    let symbol: String
    var size: CGFloat = 72
    var body: some View {
        ZStack {
            Circle().stroke(AwakeStyle.accent.opacity(0.13), lineWidth: size * 0.06)
            Circle().trim(from: 0, to: progress)
                .stroke(AwakeStyle.accent.opacity(active ? 1 : 0.35), style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle().fill(AwakeStyle.accent.opacity(active ? 0.12 : 0.06)).padding(size * 0.14)
            Image(systemName: symbol).font(.system(size: size * 0.32, weight: .regular)).foregroundStyle(AwakeStyle.accent)
        }
        .frame(width: size, height: size).accessibilityHidden(true)
    }
}

/// Drawn in SwiftUI so the main action looks the same in every state and theme.
struct AwakeButtonStyle: ButtonStyle {
    enum Kind { case primary, neutral, secondary }
    var kind: Kind = .primary
    var compact = false
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 13 : 14, weight: kind == .secondary ? .medium : .semibold))
            .foregroundStyle(kind == .primary ? AwakeStyle.onAccent : Color.primary)
            .padding(.horizontal, 14).frame(height: compact ? 34 : 40)
            .background(background, in: RoundedRectangle(cornerRadius: compact ? 9 : 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: compact ? 9 : 10, style: .continuous)
                .stroke(kind == .secondary ? AwakeStyle.stroke : .clear, lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 10))
    }
    private var background: Color {
        switch kind {
        case .primary: return AwakeStyle.accent
        case .neutral: return Color.primary.opacity(0.10)
        case .secondary: return AwakeStyle.surface
        }
    }
}

struct LastSessionView: View {
    let result: SessionResult
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "clock.arrow.circlepath").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary).frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("上次结束").foregroundStyle(.secondary)
                    Text(result.reason).foregroundStyle(.primary)
                }
                Text("\(SessionText.span(start: result.start, end: result.end)) · 运行 \(SessionText.duration(result.end.timeIntervalSince(result.start)))")
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 11.5)).textSelection(.enabled)
        .accessibilityElement(children: .combine).help(result.text)
    }
}

/// Remaining time, elapsed time, or the readiness of the next start.
struct StatusHero: View {
    @ObservedObject var model: AppModel
    var compact = false
    var body: some View {
        HStack(spacing: compact ? 14 : 18) {
            StatusRing(progress: model.sessionProgress, active: model.active, symbol: symbol, size: compact ? 54 : 68)
            VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                Text(caption).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                if model.active && model.unlimitedSession {
                    // Only the view ticks; the model publishes nothing for an unchanged unlimited session.
                    TimelineView(.periodic(from: .now, by: 1)) { _ in title(SessionText.timer(model.elapsedSeconds ?? 0)) }
                } else { title(model.statusTitle) }
                if !(compact && model.phase == .off) {
                    Text(model.statusDetail).font(.system(size: compact ? 11 : 12)).foregroundStyle(.secondary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
    private var symbol: String {
        if model.phase == .recovery || model.phase == .confirming { return "exclamationmark.triangle" }
        if model.lidMode && model.active { return "laptopcomputer" }
        return model.nightMode ? "moon.stars.fill" : model.active ? "cup.and.saucer.fill" : "cup.and.saucer"
    }
    private var caption: String {
        switch model.phase {
        case .on: return model.unlimitedSession ? "已运行" : "剩余时间"
        case .off: return "\(model.sceneDisplayName)场景\(model.preferences.isCustomized ? "（已调整）" : "")"
        case .confirming: return "请稍候"
        case .recovery: return "需要处理"
        }
    }
    private func title(_ text: String) -> some View {
        let isClock = model.active
        return Text(text)
            .font(.system(size: isClock ? (compact ? 28 : 34) : (compact ? 20 : 24), weight: isClock ? .semibold : .medium, design: .rounded))
            .monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            .foregroundStyle(model.phase == .recovery ? Color.red : Color.primary)
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    var warning = false
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary).frame(width: 16)
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).multilineTextAlignment(.trailing).foregroundStyle(warning ? Color.orange : Color.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12)).accessibilityElement(children: .combine)
    }
}

/// A switch row with an optional one-line explanation of its effect.
struct ToggleRow: View {
    let title: String
    var detail: String? = nil
    @Binding var isOn: Bool
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13))
                if let detail {
                    Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
        .accessibilityElement(children: .combine)
    }
}

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).textCase(nil)
    }
}
