// Draws the Google Play feature graphic (1024x500) in the app icon's night-blue style.
// Usage: swift store/feature_graphic.swift <icon.png> <out.png> <title> <subtitle>
import AppKit

let args = CommandLine.arguments
let w: CGFloat = 1024, h: CGFloat = 500
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w), pixelsHigh: Int(h), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

NSGradient(colors: [NSColor(srgbRed: 0.16, green: 0.20, blue: 0.38, alpha: 1),
                    NSColor(srgbRed: 0.07, green: 0.09, blue: 0.18, alpha: 1)])!
    .draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: -60)
// Soft indigo glow behind the icon.
let glow = NSColor(srgbRed: 0.36, green: 0.36, blue: 0.96, alpha: 0.45)
NSGradient(colors: [glow, glow.withAlphaComponent(0)])!
    .draw(in: NSBezierPath(ovalIn: NSRect(x: 40, y: 20, width: 460, height: 460)), relativeCenterPosition: .zero)
// A few stars.
for (x, y, r) in [(560.0, 420.0, 3.0), (900.0, 450.0, 2.0), (980.0, 120.0, 3.0), (620.0, 70.0, 2.0), (760.0, 455.0, 2.5)] {
    NSColor.white.withAlphaComponent(0.7).setFill()
    NSBezierPath(ovalIn: NSRect(x: x - r, y: y - r, width: r * 2, height: r * 2)).fill()
}

if let icon = NSImage(contentsOfFile: args[1]) {
    let rect = NSRect(x: 110, y: 110, width: 280, height: 280)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.shadowBlurRadius = 40
    shadow.set()
    NSBezierPath(roundedRect: rect, xRadius: 64, yRadius: 64).addClip()
    icon.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()
}

func rounded(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    return base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? base
}
let paragraph = NSMutableParagraphStyle()
paragraph.lineHeightMultiple = 0.95
NSAttributedString(string: args[3], attributes: [.font: rounded(84, .heavy), .foregroundColor: NSColor.white])
    .draw(at: NSPoint(x: 450, y: 250))
NSAttributedString(string: args[4], attributes: [
    .font: NSFont.systemFont(ofSize: 34, weight: .semibold),
    .foregroundColor: NSColor(srgbRed: 0.80, green: 0.84, blue: 1, alpha: 1),
    .paragraphStyle: paragraph
]).draw(in: NSRect(x: 452, y: 130, width: 540, height: 110))

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
