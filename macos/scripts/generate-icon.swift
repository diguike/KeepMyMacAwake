import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let sizes = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
for (size, scale) in sizes {
    let pixels = size * scale
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    let background = NSBezierPath(roundedRect: NSRect(x: 56, y: 56, width: 912, height: 912), xRadius: 210, yRadius: 210)
    // Avatar orange with a white cup, white steam and a cream moon.
    func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor { NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1) }
    NSGradient(starting: rgb(0xEE, 0x4F, 0x16), ending: rgb(0xFF, 0x8C, 0x4E))!.draw(in: background, angle: 75)
    NSColor(white: 1, alpha: 0.18).setStroke(); background.lineWidth = 3; background.stroke()
    let moonColor = rgb(0xFF, 0xF1, 0xD6)
    let steamColor = NSColor(white: 1, alpha: 0.85)
    // Crescent: a disc with an offset disc clipped out.
    NSGraphicsContext.saveGraphicsState()
    let cutout = NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024))
    cutout.appendOval(in: NSRect(x: 712, y: 690, width: 132, height: 132)); cutout.windingRule = .evenOdd; cutout.addClip()
    moonColor.setFill(); NSBezierPath(ovalIn: NSRect(x: 676, y: 660, width: 140, height: 140)).fill()
    NSGraphicsContext.restoreGraphicsState()
    let handle = NSBezierPath(ovalIn: NSRect(x: 635, y: 370, width: 130, height: 155)); handle.lineWidth = 36
    NSColor(white: 0.98, alpha: 1).setStroke()
    handle.stroke()
    NSColor(white: 0.98, alpha: 1).setFill()
    let cup = NSBezierPath(); cup.move(to: NSPoint(x: 282, y: 580)); cup.line(to: NSPoint(x: 677, y: 580))
    cup.line(to: NSPoint(x: 652, y: 384)); cup.curve(to: NSPoint(x: 310, y: 384), controlPoint1: NSPoint(x: 635, y: 270), controlPoint2: NSPoint(x: 322, y: 270)); cup.close(); cup.fill()
    NSColor(white: 0.98, alpha: 0.9).setStroke()
    let saucer = NSBezierPath(); saucer.move(to: NSPoint(x: 248, y: 278)); saucer.line(to: NSPoint(x: 712, y: 278)); saucer.lineWidth = 30; saucer.lineCapStyle = .round; saucer.stroke()
    steamColor.setStroke()
    for x in [390.0, 510.0] {
        let steam = NSBezierPath(); steam.move(to: NSPoint(x: x, y: 644))
        steam.curve(to: NSPoint(x: x + 12, y: 797), controlPoint1: NSPoint(x: x + 70, y: 700), controlPoint2: NSPoint(x: x - 50, y: 735))
        steam.lineWidth = 22; steam.lineCapStyle = .round; steam.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()
    let name = "icon_\(size)x\(size)" + (scale == 2 ? "@2x" : "") + ".png"
    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
}
