import AppKit

// Vector-drawn clock + play mark. Generate every native macOS icon resolution.
let output = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
for (name, size) in [("icon_16x16",16),("icon_16x16@2x",32),("icon_32x32",32),("icon_32x32@2x",64),("icon_128x128",128),("icon_128x128@2x",256),("icon_256x256",256),("icon_256x256@2x",512),("icon_512x512",512),("icon_512x512@2x",1024)] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let transform = AffineTransform(scale: CGFloat(size) / 1024)
    (transform as NSAffineTransform).concat()
    let tile = NSBezierPath(roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880), xRadius: 200, yRadius: 200)
    NSGradient(starting: NSColor(calibratedRed: 0.12, green: 0.25, blue: 0.72, alpha: 1), ending: NSColor(calibratedRed: 0.12, green: 0.65, blue: 0.94, alpha: 1))!.draw(in: tile, angle: 60)
    let ring = NSBezierPath()
    ring.appendArc(withCenter: NSPoint(x: 512, y: 512), radius: 276, startAngle: 45, endAngle: 405, clockwise: false)
    ring.lineWidth = 48
    NSColor.white.withAlphaComponent(0.95).setStroke()
    ring.stroke()
    let hand = NSBezierPath()
    hand.move(to: NSPoint(x: 512, y: 716))
    hand.line(to: NSPoint(x: 512, y: 512))
    hand.line(to: NSPoint(x: 401, y: 438))
    hand.lineWidth = 44
    hand.lineCapStyle = .round
    hand.lineJoinStyle = .round
    hand.stroke()
    let badge = NSBezierPath(ovalIn: NSRect(x: 614, y: 192, width: 244, height: 244))
    NSColor(calibratedRed: 0.10, green: 0.25, blue: 0.64, alpha: 1).setFill()
    badge.fill()
    let play = NSBezierPath()
    play.move(to: NSPoint(x: 706, y: 380))
    play.line(to: NSPoint(x: 706, y: 248))
    play.line(to: NSPoint(x: 805, y: 314))
    play.close()
    NSColor(calibratedRed: 0.55, green: 1, blue: 0.89, alpha: 1).setFill()
    play.fill()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output).appendingPathComponent(name + ".png"))
}
