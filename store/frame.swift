// Draws store screenshot frames in the app's light style: soft lavender background,
// navy headline and subtitle, and the device screenshot in a navy bezel. The "hero"
// frame adds the brand mark, a checklist and the student illustration.
// CoreText handles Arabic, Devanagari and CJK.
//
// Usage: swift store/frame.swift jobs.json
// jobs.json: [{"raw", "out", "width", "height", "title", "subtitle", "rtl",
//              "style": "hero"|"standard", "bullets": [..], "mark": png, "illustration": png}]
import AppKit
import Foundation

struct Job: Decodable {
    let raw: String
    let out: String
    let width: Int
    let height: Int
    let title: String
    let subtitle: String?
    let rtl: Bool
    let style: String
    let bullets: [String]?
    let mark: String?
    let illustration: String?
}

let navy = NSColor(srgbRed: 28/255, green: 36/255, blue: 64/255, alpha: 1)
let slate = NSColor(srgbRed: 100/255, green: 116/255, blue: 139/255, alpha: 1)
let mint = NSColor(srgbRed: 44/255, green: 203/255, blue: 140/255, alpha: 1)

func roundedFont(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
    return NSFont(descriptor: descriptor, size: size) ?? base
}

/// Draws wrapped text centred in `width` with its top at `top` (AppKit origin is bottom-left).
/// Returns the height used.
@discardableResult
func drawText(_ text: String, font: NSFont, color: NSColor, x: CGFloat, top: CGFloat, width: CGFloat,
              rtl: Bool, alignment: NSTextAlignment = .center, lineHeight: CGFloat = 1.05) -> CGFloat {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.baseWritingDirection = rtl ? .rightToLeft : .leftToRight
    paragraph.lineHeightMultiple = lineHeight
    let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
    let height = ceil(string.boundingRect(with: NSSize(width: width, height: .greatestFiniteMagnitude),
                                          options: [.usesLineFragmentOrigin, .usesFontLeading]).height)
    string.draw(with: NSRect(x: x, y: top - height, width: width, height: height),
                options: [.usesLineFragmentOrigin, .usesFontLeading])
    return height
}

func drawBackground(_ w: CGFloat, _ h: CGFloat) {
    NSGradient(colors: [
        NSColor(srgbRed: 236/255, green: 239/255, blue: 255/255, alpha: 1),
        NSColor(srgbRed: 247/255, green: 249/255, blue: 252/255, alpha: 1)
    ])!.draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: -90)
    // Soft colour blobs for depth.
    let blobs: [(CGFloat, CGFloat, CGFloat, NSColor)] = [
        (0.88, 0.86, 0.42, NSColor(srgbRed: 185/255, green: 198/255, blue: 255/255, alpha: 0.35)),
        (0.08, 0.30, 0.38, NSColor(srgbRed: 183/255, green: 230/255, blue: 211/255, alpha: 0.30))
    ]
    for (cx, cy, r, color) in blobs {
        let radius = w * r
        let rect = NSRect(x: w * cx - radius, y: h * cy - radius, width: radius * 2, height: radius * 2)
        NSGradient(colors: [color, color.withAlphaComponent(0)])!.draw(in: NSBezierPath(ovalIn: rect), relativeCenterPosition: .zero)
    }
}

/// The device screenshot inside a navy bezel with a soft shadow.
func drawDevice(_ shot: NSImage, in screen: NSRect, scale: CGFloat) {
    let bezel = 20 * scale
    let outer = screen.insetBy(dx: -bezel, dy: -bezel)
    let outerPath = NSBezierPath(roundedRect: outer, xRadius: 92 * scale, yRadius: 92 * scale)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(srgbRed: 28/255, green: 36/255, blue: 64/255, alpha: 0.28)
    shadow.shadowOffset = NSSize(width: 0, height: -36 * scale)
    shadow.shadowBlurRadius = 80 * scale
    shadow.set()
    navy.setFill()
    outerPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    let inner = NSBezierPath(roundedRect: screen, xRadius: 72 * scale, yRadius: 72 * scale)
    NSGraphicsContext.saveGraphicsState()
    inner.addClip()
    shot.draw(in: screen)
    NSGraphicsContext.restoreGraphicsState()
}

func render(_ job: Job) throws {
    guard let shot = NSImage(contentsOfFile: job.raw) else {
        throw NSError(domain: "frame", code: 1, userInfo: [NSLocalizedDescriptionKey: "cannot read \(job.raw)"])
    }
    let w = CGFloat(job.width), h = CGFloat(job.height)
    let scale = w / 1320

    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: job.width, pixelsHigh: job.height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { throw NSError(domain: "frame", code: 2) }
    rep.size = NSSize(width: w, height: h)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    drawBackground(w, h)
    let aspect = shot.size.height / shot.size.width
    let padX = 90 * scale

    if job.style == "hero" {
        var cursor = h - 150 * scale
        // Brand mark + wordmark on one row.
        if let markPath = job.mark, let mark = NSImage(contentsOfFile: markPath) {
            let size = 132 * scale
            let word = NSAttributedString(string: "Examly", attributes: [.font: roundedFont(118 * scale, .bold), .foregroundColor: navy])
            let wordSize = word.size()
            let total = size + 28 * scale + wordSize.width
            let x = (w - total) / 2
            let markRect = NSRect(x: x, y: cursor - size, width: size, height: size)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: markRect, xRadius: 30 * scale, yRadius: 30 * scale).addClip()
            mark.draw(in: markRect)
            NSGraphicsContext.restoreGraphicsState()
            word.draw(at: NSPoint(x: x + size + 28 * scale, y: cursor - size + (size - wordSize.height) / 2))
            cursor -= size + 60 * scale
        }
        cursor -= drawText(job.title, font: roundedFont(104 * scale, .heavy), color: navy,
                           x: padX, top: cursor, width: w - padX * 2, rtl: job.rtl)
        cursor -= 56 * scale

        // Checklist, left-aligned block centred on the page.
        if let bullets = job.bullets, !bullets.isEmpty {
            let font = NSFont.systemFont(ofSize: 50 * scale, weight: .medium)
            let blockWidth = 900 * scale
            let blockX = (w - blockWidth) / 2
            for bullet in bullets {
                let dot = 54 * scale
                let rowHeight = max(dot, ceil(font.ascender - font.descender + font.leading))
                let dotX = job.rtl ? blockX + blockWidth - dot : blockX
                let dotRect = NSRect(x: dotX, y: cursor - rowHeight + (rowHeight - dot) / 2, width: dot, height: dot)
                mint.setFill()
                NSBezierPath(ovalIn: dotRect).fill()
                let check = NSBezierPath()
                check.move(to: NSPoint(x: dotRect.minX + dot * 0.27, y: dotRect.midY))
                check.line(to: NSPoint(x: dotRect.minX + dot * 0.44, y: dotRect.midY - dot * 0.17))
                check.line(to: NSPoint(x: dotRect.minX + dot * 0.74, y: dotRect.midY + dot * 0.17))
                check.lineWidth = 7 * scale
                check.lineCapStyle = .round
                check.lineJoinStyle = .round
                NSColor.white.setStroke()
                check.stroke()
                let textX = job.rtl ? blockX : blockX + dot + 26 * scale
                drawText(bullet, font: font, color: slate, x: textX, top: cursor - (rowHeight - font.pointSize * 1.2) / 2,
                         width: blockWidth - dot - 26 * scale, rtl: job.rtl, alignment: job.rtl ? .right : .left)
                cursor -= rowHeight + 30 * scale
            }
        }

        // Device rises from (and runs past) the bottom edge on the right; the student stands
        // in front of it on the left.
        let deviceWidth = w * 0.66
        let deviceHeight = deviceWidth * aspect
        let deviceTop = cursor - 30 * scale
        let deviceX = job.rtl ? 70 * scale : w - deviceWidth - 70 * scale
        drawDevice(shot, in: NSRect(x: deviceX, y: deviceTop - deviceHeight, width: deviceWidth, height: deviceHeight), scale: scale)

        if let path = job.illustration, let student = NSImage(contentsOfFile: path) {
            let width = w * 0.48
            let height = width * student.size.height / student.size.width
            let x = job.rtl ? w - width - 10 * scale : 10 * scale
            student.draw(in: NSRect(x: x, y: 0, width: width, height: height))
        }
    } else {
        var cursor = h - 160 * scale
        cursor -= drawText(job.title, font: roundedFont(96 * scale, .heavy), color: navy,
                           x: padX, top: cursor, width: w - padX * 2, rtl: job.rtl)
        if let subtitle = job.subtitle, !subtitle.isEmpty {
            cursor -= 28 * scale
            cursor -= drawText(subtitle, font: NSFont.systemFont(ofSize: 48 * scale, weight: .medium), color: slate,
                               x: padX, top: cursor, width: w - padX * 2, rtl: job.rtl, lineHeight: 1.1)
        }
        let deviceTop = cursor - 100 * scale
        let deviceWidth = min(w * 0.76, (deviceTop - 90 * scale) / aspect)
        let deviceHeight = deviceWidth * aspect
        drawDevice(shot, in: NSRect(x: (w - deviceWidth) / 2, y: deviceTop - deviceHeight, width: deviceWidth, height: deviceHeight), scale: scale)
    }

    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "frame", code: 3)
    }
    let url = URL(fileURLWithPath: job.out)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try png.write(to: url)
}

let jobs = try JSONDecoder().decode([Job].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
for job in jobs {
    try render(job)
}
print("\(jobs.count) framed screenshots")
