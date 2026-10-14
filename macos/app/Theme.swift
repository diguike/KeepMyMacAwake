import SwiftUI
import AppKit
import AwakeCore

/// Shared look for the control window and the menu bar panel.
enum AwakeStyle {
    /// Follows the accent color chosen in System Settings > Appearance, like built-in apps.
    static let accent = Color(nsColor: .controlAccentColor)
    static let onAccent = Color.white
    static let surface = Color.primary.opacity(0.04)
    static let stroke = Color.primary.opacity(0.07)
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
            .fill(LinearGradient(colors: [Color(red: 0.21, green: 0.29, blue: 0.50), Color(red: 0.07, green: 0.10, blue: 0.22)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(Image(systemName: "cup.and.saucer.fill").font(.system(size: size * 0.46, weight: .medium))
                .foregroundStyle(Color.white, Color(red: 0.72, green: 0.80, blue: 0.96)))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
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

/// One line: when the last session ended and why; the full record is in the tooltip.
struct LastSessionView: View {
    let result: SessionResult
    let now: Date
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            Text("上次结束").foregroundStyle(.secondary)
            Text("\(SessionText.endedAt(result.end, now: now)) \(result.reason)").foregroundStyle(.primary)
        }
        .font(.system(size: 11.5)).lineLimit(1)
        .help(result.text).accessibilityElement(children: .combine)
    }
}

/// Remaining or elapsed time while running; otherwise the state, or what blocks a start.
struct StatusHero: View {
    @ObservedObject var model: AppModel
    var compact = false
    var body: some View {
        HStack(spacing: compact ? 14 : 18) {
            StatusRing(progress: model.sessionProgress, active: model.active, symbol: symbol, size: compact ? 54 : 68)
            VStack(alignment: .leading, spacing: compact ? 2 : 3) {
                if model.active {
                    Text(model.unlimitedSession ? "已运行" : "剩余").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                }
                if model.active && model.unlimitedSession {
                    // Only the view ticks; the model publishes nothing for an unchanged unlimited session.
                    TimelineView(.periodic(from: .now, by: 1)) { _ in title(SessionText.timer(model.elapsedSeconds ?? 0)) }
                } else { title(model.statusTitle) }
                if (compact || model.phase != .off) && !model.statusDetail.isEmpty {
                    Text(model.statusDetail).font(.system(size: compact ? 11 : 12)).foregroundStyle(.secondary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
                if let hint = model.runningHint {
                    let lid = model.leaseIDActive
                    Label(hint, systemImage: lid ? "laptopcomputer" : "lock")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(lid ? Color.green : Color.secondary)
                        .padding(.top, 2)
                        .help(lid ? "请放在通风处，不要放进包里" : "当前没有开启合盖，合盖后会正常睡眠")
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
    private func title(_ text: String) -> some View {
        let isClock = model.active
        let color: Color = model.phase == .recovery ? .red : model.isBlocked ? .orange : .primary
        return Text(text)
            .font(.system(size: isClock ? (compact ? 28 : 34) : (compact ? 19 : 24), weight: isClock ? .semibold : .medium, design: .rounded))
            .monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            .foregroundStyle(color)
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
