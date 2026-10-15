import SwiftUI
import AppKit
import AwakeCore

/// Shared look for the control window and the menu bar panel. Orange from the author's avatar marks the
/// main action, selection and the session meter; a light tinted status card carries the rest.
enum AwakeStyle {
    private static func dynamic(_ name: String, light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: NSColor.Name(name)) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light })
    }
    static func rgb(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
    /// Avatar orange, and the amber the session meter starts from.
    static let orangeNS = rgb(0xFF6A2B)
    static let amberNS = rgb(0xFFA940)
    static let orange = Color(nsColor: orangeNS)
    /// Selection: an orange tile with a white glyph.
    static let ink = orange
    static let onInk = Color.white
    /// Warning text; deeper in light mode so small text stays legible on white.
    static let warning = dynamic("AwakeWarning", light: rgb(0xC94A12), dark: rgb(0xFF8A50))
    /// Warm cream page and white cards (warm browns in dark mode), after the Color Hunt palette
    /// FCECDD FFC288 FEA82F FF6701 that pairs cream and apricot with a vivid orange.
    static let page = dynamic("AwakePage", light: rgb(0xFFFAF4), dark: rgb(0x17130F))
    static let card = dynamic("AwakeCard", light: .white, dark: rgb(0x231D18))
    static let raised = dynamic("AwakeRaised", light: .white, dark: rgb(0x3D342D))
    /// Status card: apricot in light mode, deep amber brown in dark mode, with dark brown or cream numbers.
    static let heroTop = dynamic("AwakeHeroTop", light: rgb(0xFFF4E2), dark: rgb(0x3A2716))
    static let heroBottom = dynamic("AwakeHeroBottom", light: rgb(0xFFE3C7), dark: rgb(0x2A1D12))
    static let heroInk = dynamic("AwakeHeroInk", light: rgb(0x4A2A12), dark: rgb(0xFFF4EA))
    static let heroEdge = dynamic("AwakeHeroEdge", light: rgb(0xFF6A2B, alpha: 0.18), dark: rgb(0xFFFFFF, alpha: 0.08))
    static let heroShadow = Color(nsColor: rgb(0xC2571C))
    static let well = Color.primary.opacity(0.045)
    static let selectedCard = dynamic("AwakeSelectedCard", light: rgb(0xFFF6F0), dark: rgb(0x2E231C))
    static let chip = dynamic("AwakeChip", light: rgb(0xFFFFFF, alpha: 0.7), dark: rgb(0xFFFFFF, alpha: 0.08))
    static let hairline = Color.primary.opacity(0.08)
    static let switchTint = orange
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

    /// Tinted status card with a soft colored shadow.
    func awakeHero(padding: CGFloat = 14, radius: CGFloat = 16) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self.padding(padding)
            .background(LinearGradient(colors: [AwakeStyle.heroTop, AwakeStyle.heroBottom], startPoint: .topLeading, endPoint: .bottomTrailing), in: shape)
            .overlay(shape.strokeBorder(AwakeStyle.heroEdge, lineWidth: 0.75))
            // A shadow spreads about three times its radius; offset it so it does not spill above into the scroll clip.
            .shadow(color: AwakeStyle.heroShadow.opacity(0.10), radius: 4, y: 8)
    }
}

/// Small rounded mark that echoes the app icon without relying on the bundle.
struct AppMark: View {
    var size: CGFloat = 38
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(LinearGradient(colors: [Color(nsColor: AwakeStyle.rgb(0xFF8A4C)), Color(nsColor: AwakeStyle.rgb(0xF2541B))],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: size * 0.27, style: .continuous).stroke(Color.black.opacity(0.06), lineWidth: 0.5))
            .overlay(Image(systemName: "cup.and.saucer.fill").font(.system(size: size * 0.44, weight: .regular))
                .foregroundStyle(Color.white, Color.white.opacity(0.75)))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Segmented tick bar for the remaining share of a session; fine ticks sized to the width, amber to orange.
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
                        .fill(index < filled ? Self.color(at: CGFloat(index) / CGFloat(max(1, count - 1))) : Color.primary.opacity(0.1))
                        .frame(width: width)
                }
            }
        }
        .frame(height: height).accessibilityHidden(true)
    }
    private static func color(at fraction: CGFloat) -> Color {
        Color(nsColor: AwakeStyle.amberNS.blended(withFraction: fraction, of: AwakeStyle.orangeNS) ?? AwakeStyle.orangeNS)
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
        let shape = RoundedRectangle(cornerRadius: compact ? 8 : 9, style: .continuous)
        return configuration.label
            .font(.system(size: compact ? 13 : 13.5, weight: kind == .primary ? .semibold : .medium))
            .foregroundStyle(kind == .primary ? Color.white : Color.primary)
            .padding(.horizontal, 14).frame(height: compact ? 32 : 38)
            .background(background, in: shape)
            // A lit top edge on the orange button; a hairline on the card-colored one.
            .overlay(shape.strokeBorder(kind == .primary
                ? AnyShapeStyle(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0)], startPoint: .top, endPoint: .center))
                : AnyShapeStyle(kind == .secondary ? AwakeStyle.hairline : .clear), lineWidth: 0.75))
            .shadow(color: kind == .primary ? AwakeStyle.orange.opacity(0.32) : .clear, radius: 6, y: 2)
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: 9))
    }
    private var background: AnyShapeStyle {
        switch kind {
        case .primary:
            return AnyShapeStyle(LinearGradient(colors: [Color(nsColor: NSColor(srgbRed: 1, green: 0.48, blue: 0.24, alpha: 1)),
                                                         Color(nsColor: NSColor(srgbRed: 0.93, green: 0.34, blue: 0.10, alpha: 1))],
                                                startPoint: .top, endPoint: .bottom))
        case .neutral: return AnyShapeStyle(Color.primary.opacity(0.07))
        case .secondary: return AnyShapeStyle(AwakeStyle.card)
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
                    .shadow(color: model.phase == .on ? AwakeStyle.orange.opacity(0.8) : .clear, radius: 3)
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
                    .font(.system(size: 11.5)).foregroundStyle(lid ? AwakeStyle.heroInk : Color.secondary)
                    .help(lid ? "请放在通风处，不要放进包里" : "当前没有开启合盖，合盖后会正常睡眠")
            } else if !model.active, !model.isBlocked, model.phase == .off, !model.flagsText.isEmpty {
                Text(model.flagsText).font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
    private var dotColor: Color {
        switch model.phase {
        case .on: return AwakeStyle.orange
        case .off: return model.isBlocked ? AwakeStyle.warning : Color.primary.opacity(0.25)
        case .confirming: return AwakeStyle.warning
        case .recovery: return .red
        }
    }
    @ViewBuilder private var headline: some View {
        let size: CGFloat = compact ? 34 : 42
        if model.phase == .recovery || model.phase == .confirming || model.isBlocked {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.statusTitle).font(.system(size: compact ? 17 : 20, weight: .medium))
                    .foregroundStyle(model.phase == .recovery ? Color.red : AwakeStyle.warning)
                if model.phase == .recovery, !model.statusDetail.isEmpty {
                    Text(model.statusDetail).font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        } else if model.active && model.unlimitedSession {
            // Only the view ticks; the model publishes nothing for an unchanged unlimited session.
            TimelineView(.periodic(from: .now, by: 1)) { _ in BigNumber(parts: SessionText.parts(model.elapsedSeconds ?? 0), size: size).foregroundStyle(AwakeStyle.heroInk) }
        } else if model.active {
            BigNumber(parts: SessionText.parts(model.remaining), size: size).foregroundStyle(AwakeStyle.heroInk)
        } else if let planned = model.plannedSeconds {
            BigNumber(parts: SessionText.parts(planned, seconds: false), size: size).foregroundStyle(AwakeStyle.heroInk)
        } else {
            Text("不限时").font(.system(size: size * 0.8, weight: .light)).foregroundStyle(AwakeStyle.heroInk)
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
            Text(value).multilineTextAlignment(.trailing).foregroundStyle(warning ? AwakeStyle.warning : Color.primary).monospacedDigit()
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
