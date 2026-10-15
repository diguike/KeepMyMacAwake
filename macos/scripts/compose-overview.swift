import AppKit

// Composes the README overview image from ScreenshotTests renders: a desktop with a menu bar,
// the control window and the menu bar panel.
// Usage: swift macos/scripts/compose-overview.swift <control.png> <menubar.png> <output.png> light|dark
// Shadow offsets are in device space (y up), so negative heights fall downward.
let args = CommandLine.arguments
let control = NSImage(contentsOfFile: args[1])!
let panel = NSImage(contentsOfFile: args[2])!
let output = URL(fileURLWithPath: args[3])
let dark = args[4] == "dark"
let W = 1680, H = 1335
let scale: CGFloat = 0.75

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

let cg = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                   space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
cg.translateBy(x: 0, y: CGFloat(H)); cg.scaleBy(x: 1, y: -1)
let ns = NSGraphicsContext(cgContext: cg, flipped: true)
NSGraphicsContext.current = ns

// Desktop: warm cream (light) or warm near-black (dark), with a faint orange glow behind the window.
let bounds = NSRect(x: 0, y: 0, width: W, height: H)
NSGradient(starting: dark ? rgb(0x1E1814) : rgb(0xFFF7EE), ending: dark ? rgb(0x0E0B09) : rgb(0xF5E4D4))!.draw(in: bounds, angle: -60)
NSGradient(colors: [rgb(0xFF6A2B, dark ? 0.16 : 0.14), rgb(0xFF6A2B, 0)])!
    .draw(fromCenter: NSPoint(x: 460, y: 700), radius: 0, toCenter: NSPoint(x: 460, y: 700), radius: 760, options: [])

// Menu bar.
let barH: CGFloat = 38
(dark ? rgb(0x000000, 0.35) : rgb(0xFFFFFF, 0.6)).setFill()
NSRect(x: 0, y: 0, width: CGFloat(W), height: barH).fill()
let ink = dark ? rgb(0xFFFFFF, 0.92) : rgb(0x000000, 0.86)
func symbol(_ name: String, _ size: CGFloat, _ color: NSColor, at point: NSPoint, weight: NSFont.Weight = .regular) {
    let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight).applying(NSImage.SymbolConfiguration(paletteColors: [color]))
    let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)!.withSymbolConfiguration(config)!
    image.draw(in: NSRect(x: point.x, y: point.y - image.size.height / 2, width: image.size.width, height: image.size.height),
               from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
}
func text(_ string: String, _ font: NSFont, _ color: NSColor, at point: NSPoint, centerY: Bool = true) -> CGFloat {
    let attributed = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
    let size = attributed.size()
    attributed.draw(at: NSPoint(x: point.x, y: centerY ? point.y - size.height / 2 : point.y))
    return size.width
}
symbol("apple.logo", 19, ink, at: NSPoint(x: 30, y: barH / 2))
_ = text("KeepMyMacAwake", .systemFont(ofSize: 19, weight: .semibold), ink, at: NSPoint(x: 75, y: barH / 2))
// Status item with the active highlight.
let pill = NSRect(x: 1206, y: 5, width: 126, height: 28)
(dark ? rgb(0xFFFFFF, 0.18) : rgb(0x000000, 0.08)).setFill()
NSBezierPath(roundedRect: pill, xRadius: 6, yRadius: 6).fill()
symbol("cup.and.saucer.fill", 17, ink, at: NSPoint(x: pill.minX + 12, y: barH / 2))
_ = text("6h28m", .monospacedDigitSystemFont(ofSize: 19, weight: .semibold), ink, at: NSPoint(x: pill.minX + 47, y: barH / 2))
symbol("wifi", 18, ink, at: NSPoint(x: 1372, y: barH / 2))
symbol("battery.100percent.bolt", 18, ink, at: NSPoint(x: 1424, y: barH / 2))
_ = text("10月16日 周五 00:42", .systemFont(ofSize: 19, weight: .regular), ink, at: NSPoint(x: 1490, y: barH / 2))

// Control window: a title bar with traffic lights above the rendered page.
let titleH: CGFloat = 46
let content = NSSize(width: control.size.width * scale, height: control.size.height * scale)
let window = NSRect(x: 113, y: 90, width: content.width, height: titleH + content.height)
let windowPath = NSBezierPath(roundedRect: window, xRadius: 22, yRadius: 22)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = rgb(dark ? 0x000000 : 0x5A3214, dark ? 0.55 : 0.18)
shadow.shadowBlurRadius = 46; shadow.shadowOffset = NSSize(width: 0, height: -22)
shadow.set()
(dark ? rgb(0x17130F) : rgb(0xFFFAF4)).setFill()
windowPath.fill()
NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.saveGraphicsState()
windowPath.addClip()
control.draw(in: NSRect(x: window.minX, y: window.minY + titleH, width: content.width, height: content.height),
             from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
NSGraphicsContext.restoreGraphicsState()
(dark ? rgb(0xFFFFFF, 0.14) : rgb(0x000000, 0.10)).setStroke()
windowPath.lineWidth = 1; windowPath.stroke()
for (index, color) in [0xFF5F57, 0xFEBC2E, 0x28C840].enumerated() {
    rgb(UInt32(color)).setFill()
    NSBezierPath(ovalIn: NSRect(x: window.minX + 20 + CGFloat(index) * 30, y: window.minY + 15, width: 16, height: 16)).fill()
}

// Menu bar panel under the status item, then a caption.
let panelSize = NSSize(width: panel.size.width * scale, height: panel.size.height * scale)
let panelRect = NSRect(x: 1027, y: 55, width: panelSize.width, height: panelSize.height)
NSGraphicsContext.saveGraphicsState()
let panelShadow = NSShadow()
panelShadow.shadowColor = rgb(dark ? 0x000000 : 0x5A3214, dark ? 0.5 : 0.16)
panelShadow.shadowBlurRadius = 30; panelShadow.shadowOffset = NSSize(width: 0, height: -14)
panelShadow.set()
panel.draw(in: panelRect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
NSGraphicsContext.restoreGraphicsState()
let caption = dark ? rgb(0xFFFFFF, 0.62) : rgb(0x4A2A12, 0.72)
let font = NSFont.systemFont(ofSize: 22, weight: .semibold)
_ = text("点菜单栏杯子图标，", font, caption, at: NSPoint(x: 1025, y: panelRect.maxY + 52), centerY: false)
_ = text("随时查看剩余时间和运行状态", font, caption, at: NSPoint(x: 1025, y: panelRect.maxY + 90), centerY: false)

let rep = NSBitmapImageRep(cgImage: cg.makeImage()!)
try rep.representation(using: .png, properties: [:])!.write(to: output)
