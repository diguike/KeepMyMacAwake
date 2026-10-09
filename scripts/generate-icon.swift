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
    NSGradient(starting: NSColor(red: 0.18, green: 0.20, blue: 0.24, alpha: 1),
               ending: NSColor(red: 0.08, green: 0.10, blue: 0.13, alpha: 1))!.draw(in: background, angle: 75)
    NSColor(red: 0.95, green: 0.70, blue: 0.37, alpha: 1).setStroke()
    let moon = NSBezierPath(); moon.move(to: NSPoint(x: 690, y: 790))
    moon.curve(to: NSPoint(x: 825, y: 665), controlPoint1: NSPoint(x: 630, y: 660), controlPoint2: NSPoint(x: 710, y: 590))
    moon.lineWidth = 25; moon.lineCapStyle = .round; moon.stroke()
    let handle = NSBezierPath(ovalIn: NSRect(x: 635, y: 370, width: 130, height: 155)); handle.lineWidth = 36; handle.stroke()
    NSColor(red: 1, green: 0.93, blue: 0.80, alpha: 1).setFill()
    let cup = NSBezierPath(); cup.move(to: NSPoint(x: 282, y: 580)); cup.line(to: NSPoint(x: 677, y: 580))
    cup.line(to: NSPoint(x: 652, y: 384)); cup.curve(to: NSPoint(x: 310, y: 384), controlPoint1: NSPoint(x: 635, y: 270), controlPoint2: NSPoint(x: 322, y: 270)); cup.close(); cup.fill()
    NSColor(red: 0.95, green: 0.70, blue: 0.37, alpha: 1).setStroke()
    let saucer = NSBezierPath(); saucer.move(to: NSPoint(x: 248, y: 278)); saucer.line(to: NSPoint(x: 712, y: 278)); saucer.lineWidth = 30; saucer.lineCapStyle = .round; saucer.stroke()
    for x in [390.0, 510.0] {
        let steam = NSBezierPath(); steam.move(to: NSPoint(x: x, y: 644))
        steam.curve(to: NSPoint(x: x + 12, y: 797), controlPoint1: NSPoint(x: x + 70, y: 700), controlPoint2: NSPoint(x: x - 50, y: 735))
        steam.lineWidth = 22; steam.lineCapStyle = .round; steam.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()
    let name = "icon_\(size)x\(size)" + (scale == 2 ? "@2x" : "") + ".png"
    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
}
