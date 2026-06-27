import AppKit

let outputRoot = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".build/generated-icons")
let iconsetURL = outputRoot.appendingPathComponent("ClipKeyIcon.iconset", isDirectory: true)
let menuBarURL = outputRoot.appendingPathComponent("MenuBarIcon.png")

try? FileManager.default.removeItem(at: outputRoot)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let iconSizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (fileName, size) in iconSizes {
    try writePNG(makeIcon(size: size, isMenuBar: false), to: iconsetURL.appendingPathComponent(fileName))
}

try writePNG(makeIcon(size: 64, isMenuBar: true), to: menuBarURL)

func makeIcon(size: CGFloat, isMenuBar: Bool) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high

    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    bounds.fill()

    let scale = size / 1024
    let inset = isMenuBar ? size * 0.08 : size * 0.055
    let cornerRadius = isMenuBar ? size * 0.24 : size * 0.22
    let tileRect = bounds.insetBy(dx: inset, dy: inset)
    let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: cornerRadius, yRadius: cornerRadius)

    NSGraphicsContext.saveGraphicsState()
    if !isMenuBar {
        let shadow = NSShadow()
        shadow.shadowOffset = NSSize(width: 0, height: -18 * scale)
        shadow.shadowBlurRadius = 32 * scale
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
        shadow.set()
    }
    NSGradient(colors: [
        NSColor(calibratedRed: 0.07, green: 0.46, blue: 0.92, alpha: 1),
        NSColor(calibratedRed: 0.17, green: 0.78, blue: 0.70, alpha: 1),
        NSColor(calibratedRed: 0.98, green: 0.60, blue: 0.24, alpha: 1)
    ])?.draw(in: tilePath, angle: 135)
    NSGraphicsContext.restoreGraphicsState()

    NSColor.white.withAlphaComponent(0.22).setStroke()
    tilePath.lineWidth = max(1, 18 * scale)
    tilePath.stroke()

    drawCard(
        in: NSRect(x: size * 0.24, y: size * 0.25, width: size * 0.48, height: size * 0.47),
        radius: 64 * scale,
        rotation: -8,
        alpha: 0.42,
        scale: scale
    )
    drawCard(
        in: NSRect(x: size * 0.31, y: size * 0.31, width: size * 0.48, height: size * 0.47),
        radius: 64 * scale,
        rotation: 7,
        alpha: 0.66,
        scale: scale
    )

    let frontRect = NSRect(x: size * 0.28, y: size * 0.22, width: size * 0.46, height: size * 0.55)
    let frontPath = NSBezierPath(roundedRect: frontRect, xRadius: 70 * scale, yRadius: 70 * scale)
    NSColor.white.withAlphaComponent(0.94).setFill()
    frontPath.fill()
    NSColor(calibratedRed: 0.06, green: 0.20, blue: 0.34, alpha: 0.16).setStroke()
    frontPath.lineWidth = max(1, 10 * scale)
    frontPath.stroke()

    let clipRect = NSRect(x: size * 0.39, y: size * 0.70, width: size * 0.24, height: size * 0.12)
    let clipPath = NSBezierPath(roundedRect: clipRect, xRadius: 42 * scale, yRadius: 42 * scale)
    NSColor(calibratedRed: 0.09, green: 0.42, blue: 0.86, alpha: 1).setFill()
    clipPath.fill()

    drawLine(y: 0.60, width: 0.28, color: NSColor(calibratedRed: 0.09, green: 0.42, blue: 0.86, alpha: 1), size: size)
    drawLine(y: 0.50, width: 0.34, color: NSColor(calibratedRed: 0.14, green: 0.67, blue: 0.59, alpha: 1), size: size)
    drawLine(y: 0.40, width: 0.24, color: NSColor(calibratedRed: 0.94, green: 0.48, blue: 0.18, alpha: 1), size: size)

    image.unlockFocus()
    return image
}

func drawCard(in rect: NSRect, radius: CGFloat, rotation: CGFloat, alpha: CGFloat, scale: CGFloat) {
    let transform = NSAffineTransform()
    transform.translateX(by: rect.midX, yBy: rect.midY)
    transform.rotate(byDegrees: rotation)
    transform.translateX(by: -rect.midX, yBy: -rect.midY)

    NSGraphicsContext.saveGraphicsState()
    transform.concat()
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    NSColor.white.withAlphaComponent(alpha).setFill()
    path.fill()
    NSColor.white.withAlphaComponent(0.18).setStroke()
    path.lineWidth = max(1, 8 * scale)
    path.stroke()
    NSGraphicsContext.restoreGraphicsState()
}

func drawLine(y: CGFloat, width: CGFloat, color: NSColor, size: CGFloat) {
    let rect = NSRect(x: size * 0.37, y: size * y, width: size * width, height: max(3, size * 0.035))
    let path = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
    color.setFill()
    path.fill()
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "ClipKeyIcon", code: 1)
    }

    try pngData.write(to: url, options: .atomic)
}
