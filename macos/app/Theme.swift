import SwiftUI
import AppKit
import AwakeCore

/// Shared look for the control window and the menu bar panel: neutral surfaces,
/// near-black ink, and color only for state (green running, orange warning).
enum AwakeStyle {
    private static func dynamic(_ name: String, light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: NSColor.Name(name)) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light })
    }
    /// Primary fill and selection color.
    static let ink = dynamic("AwakeInk", light: NSColor(white: 0.11, alpha: 1), dark: NSColor(white: 0.93, alpha: 1))
    static let onInk = dynamic("AwakeOnInk", light: .white, dark: NSColor(white: 0.08, alpha: 1))
    /// Window background, with cards a step lighter (light) or raised (dark).
    static let page = dynamic("AwakePage", light: NSColor(red: 0.972, green: 0.970, blue: 0.962, alpha: 1), dark: NSColor(white: 0.115, alpha: 1))
    static let card = dynamic("AwakeCard", light: .white, dark: NSColor(white: 0.165, alpha: 1))
    static let well = Color.primary.opacity(0.045)
    /// Selected pill on a recessed track; lighter than cards in dark mode so it still reads.
    static let raised = dynamic("AwakeRaised", light: .white, dark: NSColor(white: 0.30, alpha: 1))
    static let hairline = Color.primary.opacity(0.08)
    /// Graphite switches instead of the system accent.
    static let switchTint = dynamic("AwakeSwitch", light: NSColor(white: 0.22, alpha: 1), dark: NSColor(white: 0.62, alpha: 1))
    static let scenes: [(name: String, icon: String)] = [
        ("日常", "cup.and.saucer"), ("夜间", "moon"), ("接电合盖", "powerplug"), ("有网时", "laptopcomputer")
    ]
}

extension View {
    /// White card with a hairline and a soft shadow that only shows in light mode.
    func awakeCard(padding: CGFloat = 14, radius: CGFloat = 14) -> some View {
        self.padding(padding)
            .background(AwakeStyle.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(AwakeStyle.hairline, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}

/// Small rounded mark that echoes the app icon without relying on the bundle.
struct AppMark: View {
    var size: CGFloat = 38
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(LinearGradient(colors: [Color(white: 0.24), Color(white: 0.07)], startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: size * 0.27, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
            .overlay(Image(systemName: "cup.and.saucer.fill").font(.system(size: size * 0.44, weight: .regular))
                .foregroundStyle(Color.white, Color(white: 0.72)))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Segmented tick bar for the remaining share of a session; fine ticks sized to the width.
struct TickMeter: View {
    let progress: Double
    var height: CGFloat = 16
    var body: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 2.5
            let count = max(8, Int((geometry.size.width + spacing) / (2.5 + spacing)))
            let width = max(1, (geometry.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))
            let filled = Int((progress * Double(count)).rounded(.up))
            HStack(spacing: spacing) {
                ForEach(0..<count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: width / 2, style: .continuous)
                        .fill(index < filled ? AwakeStyle.ink : AwakeStyle.ink.opacity(0.12))
                        .frame(width: width)
                }
            }
        }
        .frame(height: height).accessibilityHidden(true)
    }
}

/// Capsule switcher drawn in SwiftUI: a recessed track with a raised selected pill.
struct PillPicker<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value
    var compact = false
    @Environment(\.isEnabled) private var isEnabled
    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { option in
                let selected = option.value == selection
                Button { selection = option.value } label: {
                    Text(option.title).font(.system(size: compact ? 11.5 : 12, weight: selected ? .medium : .regular))
                        .foregroundStyle(selected ? Color.primary : Color.secondary)
                        .padding(.horizontal, compact ? 10 : 14).frame(height: compact ? 24 : 26)
                        .background {
                            if selected {
                                Capsule().fill(AwakeStyle.raised).shadow(color: .black.opacity(0.10), radius: 2, y: 1)
                                    .overlay(Capsule().stroke(AwakeStyle.hairline, lineWidth: 0.5))
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(2).background(AwakeStyle.well, in: Capsule())
        .opacity(isEnabled ? 1 : 0.5)
    }
}

/// Round icon button for panel headers; the label lives in the tooltip and for VoiceOver.
struct IconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11.5, weight: .medium)).foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(AwakeStyle.card, in: Circle())
                .overlay(Circle().stroke(AwakeStyle.hairline, lineWidth: 0.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain).help(label).accessibilityLabel(label)
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
            .font(.system(size: compact ? 13 : 13.5, weight: .medium))
            .foregroundStyle(kind == .primary ? AwakeStyle.onInk : Color.primary)
            .padding(.horizontal, 14).frame(height: compact ? 32 : 38)
            .background(background, in: RoundedRectangle(cornerRadius: compact ? 8 : 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: compact ? 8 : 9, style: .continuous)
                .stroke(kind == .secondary ? AwakeStyle.hairline : .clear, lineWidth: 0.5))
            .shadow(color: .black.opacity(kind == .primary ? 0.12 : 0), radius: 2, y: 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: 9))
    }
    private var background: Color {
        switch kind {
        case .primary: return AwakeStyle.ink
        case .neutral: return Color.primary.opacity(0.07)
        case .secondary: return AwakeStyle.card
        }
    }
}

/// One line: when the last session ended and why; the full record is in the tooltip.
struct LastSessionView: View {
    let result: SessionResult
    let now: Date
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath").font(.system(size: 10.5)).foregroundStyle(.tertiary)
            Text("上次结束").foregroundStyle(.secondary)
            Text("\(SessionText.endedAt(result.end, now: now)) \(result.reason)").foregroundStyle(.primary)
        }
        .font(.system(size: 11.5)).lineLimit(1)
        // Combine first so the tooltip is attached once, not to every child.
        .accessibilityElement(children: .combine).help(result.text)
    }
}

/// Large number with small units, e.g. 6 小时 28 分.
struct BigNumber: View {
    let parts: [SessionText.NumberPart]
    var size: CGFloat = 40
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                Text(part.value).font(.system(size: size, weight: .light)).monospacedDigit()
                Text(part.unit).font(.system(size: size * 0.32, weight: .regular)).foregroundStyle(.secondary)
                    .padding(.trailing, index < parts.count - 1 ? size * 0.12 : 0)
            }
        }
        .lineLimit(1).minimumScaleFactor(0.6)
    }
}

/// The state at a glance: a status line, one large number, a tick meter and a hint.
struct StatusHero: View {
    @ObservedObject var model: AppModel
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(spacing: 6) {
                Circle().fill(dotColor).frame(width: 6, height: 6)
                Text(model.phaseText).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                if !model.trailingStatus.isEmpty {
                    Text(model.trailingStatus).font(.system(size: 12)).foregroundStyle(.secondary).monospacedDigit()
                }
            }
            headline
            if model.active && !model.unlimitedSession {
                TickMeter(progress: model.sessionProgress, height: compact ? 14 : 16)
            }
            if let hint = model.runningHint {
                let lid = model.leaseIDActive
                Label(hint, systemImage: lid ? "laptopcomputer" : "lock")
                    .font(.system(size: 11.5)).foregroundStyle(lid ? Color.green : Color.secondary)
                    .help(lid ? "请放在通风处，不要放进包里" : "当前没有开启合盖，合盖后会正常睡眠")
            } else if !model.active, !model.isBlocked, model.phase == .off, !model.flagsText.isEmpty {
                Text(model.flagsText).font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
    private var dotColor: Color {
        switch model.phase {
        case .on: return .green
        case .off: return model.isBlocked ? .orange : Color.primary.opacity(0.25)
        case .confirming: return .orange
        case .recovery: return .red
        }
    }
    @ViewBuilder private var headline: some View {
        let size: CGFloat = compact ? 34 : 42
        if model.phase == .recovery || model.phase == .confirming || model.isBlocked {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.statusTitle).font(.system(size: compact ? 17 : 20, weight: .medium))
                    .foregroundStyle(model.phase == .recovery ? Color.red : Color.orange)
                if model.phase == .recovery, !model.statusDetail.isEmpty {
                    Text(model.statusDetail).font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        } else if model.active && model.unlimitedSession {
            // Only the view ticks; the model publishes nothing for an unchanged unlimited session.
            TimelineView(.periodic(from: .now, by: 1)) { _ in BigNumber(parts: SessionText.parts(model.elapsedSeconds ?? 0), size: size) }
        } else if model.active {
            BigNumber(parts: SessionText.parts(model.remaining), size: size)
        } else if let planned = model.plannedSeconds {
            BigNumber(parts: SessionText.parts(planned, seconds: false), size: size).foregroundStyle(.primary.opacity(0.85))
        } else {
            Text("不限时").font(.system(size: size * 0.8, weight: .light)).foregroundStyle(.primary.opacity(0.85))
        }
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    var warning = false
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon).font(.system(size: 10.5)).foregroundStyle(.tertiary).frame(width: 15)
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).multilineTextAlignment(.trailing).foregroundStyle(warning ? Color.orange : Color.primary).monospacedDigit()
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
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.mini).tint(AwakeStyle.switchTint)
        }
        .accessibilityElement(children: .combine)
    }
}

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary).textCase(nil).padding(.leading, 2)
    }
}
