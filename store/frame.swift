// Draws store screenshot frames: gradient background, localized headline,
// rounded device screenshot. CoreText handles Arabic, Devanagari and CJK.
//
// Usage: swift store/frame.swift jobs.json
// jobs.json: [{"raw", "out", "width", "height", "caption", "rtl"}]
import AppKit
import Foundation

struct Job: Decodable {
    let raw: String
    let out: String
    let width: Int
    let height: Int
    let caption: String
    let rtl: Bool
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

    // Background gradient (primary -> indigo -> purple), top-left to bottom-right.
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 59/255, green: 108/255, blue: 246/255, alpha: 1),
        NSColor(srgbRed: 92/255, green: 92/255, blue: 246/255, alpha: 1),
        NSColor(srgbRed: 139/255, green: 92/255, blue: 246/255, alpha: 1)
    ])!
    gradient.draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: -70)

    // Headline, centered, wrapped within side padding. AppKit's origin is bottom-left.
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.baseWritingDirection = job.rtl ? .rightToLeft : .leftToRight
    paragraph.lineHeightMultiple = 1.05
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 92 * scale, weight: .heavy),
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph
    ]
    let caption = NSAttributedString(string: job.caption, attributes: attributes)
    let padX = 90 * scale, top = 150 * scale
    let textWidth = w - padX * 2
    let textHeight = ceil(caption.boundingRect(
        with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading]
    ).height)
    caption.draw(with: NSRect(x: padX, y: h - top - textHeight, width: textWidth, height: textHeight),
                 options: [.usesLineFragmentOrigin, .usesFontLeading])

    // Device screenshot below the headline, scaled to 78% of the width.
    // Fit inside both 78% of the width and the space left under the headline.
    let deviceTop = h - top - textHeight - 90 * scale
    let aspect = shot.size.height / shot.size.width
    let deviceWidth = min(w * 0.78, (deviceTop - 60 * scale) / aspect)
    let deviceHeight = deviceWidth * aspect
    let deviceRect = NSRect(x: (w - deviceWidth) / 2, y: deviceTop - deviceHeight, width: deviceWidth, height: deviceHeight)
    let radius = 70 * scale
    let path = NSBezierPath(roundedRect: deviceRect, xRadius: radius, yRadius: radius)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(srgbRed: 15/255, green: 23/255, blue: 42/255, alpha: 0.35)
    shadow.shadowOffset = NSSize(width: 0, height: -40 * scale)
    shadow.shadowBlurRadius = 90 * scale
    shadow.set()
    NSColor.white.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    shot.draw(in: deviceRect)
    NSGraphicsContext.restoreGraphicsState()

    NSColor(white: 1, alpha: 0.55).setStroke()
    path.lineWidth = 6 * scale
    path.stroke()

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
