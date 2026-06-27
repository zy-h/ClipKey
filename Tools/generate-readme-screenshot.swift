import AppKit

let outputPath = CommandLine.arguments.dropFirst().first ?? "docs/screenshot.png"
let outputURL = URL(fileURLWithPath: outputPath)
try? FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

let width: CGFloat = 1280
let height: CGFloat = 820
let image = NSImage(size: NSSize(width: width, height: height))

image.lockFocus()
NSGraphicsContext.current?.imageInterpolation = .high

NSColor(calibratedRed: 0.94, green: 0.96, blue: 0.98, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()

drawRoundedRect(
    NSRect(x: 190, y: 110, width: 900, height: 600),
    radius: 26,
    fill: NSColor.white,
    stroke: NSColor(calibratedWhite: 0.78, alpha: 1),
    lineWidth: 1
)

drawText("ClipKey", at: NSPoint(x: 238, y: 646), size: 28, weight: .semibold)
drawText("Lightweight clipboard history for macOS", at: NSPoint(x: 238, y: 616), size: 15, color: secondaryTextColor)

drawSearchBar()
drawRows()
drawSettingsPanel()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "ClipKeyScreenshot", code: 1)
}

try png.write(to: outputURL, options: .atomic)

func drawSearchBar() {
    drawRoundedRect(
        NSRect(x: 238, y: 552, width: 520, height: 46),
        radius: 12,
        fill: NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.99, alpha: 1),
        stroke: NSColor(calibratedWhite: 0.84, alpha: 1),
        lineWidth: 1
    )
    drawText("Search clipboard", at: NSPoint(x: 284, y: 566), size: 16, color: secondaryTextColor)
    drawMagnifier(center: NSPoint(x: 262, y: 575))
}

func drawRows() {
    drawText("Latest items", at: NSPoint(x: 238, y: 512), size: 14, weight: .medium, color: secondaryTextColor)

    drawRow(y: 434, accent: NSColor(calibratedRed: 0.09, green: 0.48, blue: 0.92, alpha: 1)) {
        drawText("Text", at: NSPoint(x: 332, y: 472), size: 15, weight: .semibold)
        drawText("轻量、快速、简洁、免费", at: NSPoint(x: 332, y: 446), size: 20, weight: .medium)
        drawText("Rich text / HTML format can be restored when supported", at: NSPoint(x: 332, y: 422), size: 13, color: secondaryTextColor)
        drawTextIcon("T", rect: NSRect(x: 260, y: 442, width: 46, height: 46), color: NSColor(calibratedRed: 0.09, green: 0.48, blue: 0.92, alpha: 1))
    }

    drawRow(y: 322, accent: NSColor(calibratedRed: 0.14, green: 0.68, blue: 0.58, alpha: 1)) {
        drawImagePreview(rect: NSRect(x: 250, y: 338, width: 72, height: 58))
        drawText("Image", at: NSPoint(x: 346, y: 374), size: 17, weight: .semibold)
        drawText("PNG · 245 KB · 1280 x 720", at: NSPoint(x: 346, y: 346), size: 14, color: secondaryTextColor)
    }

    drawRow(y: 210, accent: NSColor(calibratedRed: 0.96, green: 0.53, blue: 0.20, alpha: 1)) {
        drawTextIcon("⌘", rect: NSRect(x: 260, y: 218, width: 46, height: 46), color: NSColor(calibratedRed: 0.96, green: 0.53, blue: 0.20, alpha: 1))
        drawText("Hotkey", at: NSPoint(x: 332, y: 252), size: 17, weight: .semibold)
        drawText("Command + Shift + V", at: NSPoint(x: 332, y: 224), size: 15, color: secondaryTextColor)
    }
}

func drawSettingsPanel() {
    drawRoundedRect(
        NSRect(x: 785, y: 250, width: 245, height: 348),
        radius: 18,
        fill: NSColor(calibratedRed: 0.98, green: 0.99, blue: 1, alpha: 1),
        stroke: NSColor(calibratedWhite: 0.82, alpha: 1),
        lineWidth: 1
    )
    drawText("Settings / 设置", at: NSPoint(x: 820, y: 548), size: 18, weight: .semibold)
    drawText("Language", at: NSPoint(x: 820, y: 500), size: 13, color: secondaryTextColor)
    drawSegmentedControl()
    drawToggle(label: "Show in Menu Bar", y: 404, enabled: true)
    drawToggle(label: "Pause Recording", y: 350, enabled: false)
    drawText("Keep Last", at: NSPoint(x: 820, y: 292), size: 13, color: secondaryTextColor)
    drawText("20   30   50   100", at: NSPoint(x: 820, y: 265), size: 16, weight: .medium)
}

func drawRow(y: CGFloat, accent: NSColor, content: () -> Void) {
    drawRoundedRect(
        NSRect(x: 238, y: y, width: 520, height: 92),
        radius: 16,
        fill: NSColor(calibratedRed: 0.985, green: 0.99, blue: 1, alpha: 1),
        stroke: NSColor(calibratedWhite: 0.86, alpha: 1),
        lineWidth: 1
    )
    accent.setFill()
    NSBezierPath(
        roundedRect: NSRect(x: 238, y: y, width: 5, height: 92),
        xRadius: 2.5,
        yRadius: 2.5
    ).fill()
    content()
}

func drawSegmentedControl() {
    drawRoundedRect(
        NSRect(x: 820, y: 456, width: 176, height: 34),
        radius: 10,
        fill: NSColor(calibratedWhite: 0.92, alpha: 1),
        stroke: NSColor(calibratedWhite: 0.82, alpha: 1),
        lineWidth: 1
    )
    drawRoundedRect(
        NSRect(x: 823, y: 459, width: 82, height: 28),
        radius: 8,
        fill: NSColor.white,
        stroke: NSColor.clear,
        lineWidth: 0
    )
    drawText("English", at: NSPoint(x: 840, y: 465), size: 12, weight: .medium)
    drawText("中文", at: NSPoint(x: 934, y: 465), size: 12, color: secondaryTextColor)
}

func drawToggle(label: String, y: CGFloat, enabled: Bool) {
    drawText(label, at: NSPoint(x: 820, y: y + 4), size: 14)
    let trackColor = enabled
        ? NSColor(calibratedRed: 0.14, green: 0.68, blue: 0.58, alpha: 1)
        : NSColor(calibratedWhite: 0.82, alpha: 1)
    drawRoundedRect(
        NSRect(x: 950, y: y, width: 46, height: 26),
        radius: 13,
        fill: trackColor,
        stroke: NSColor.clear,
        lineWidth: 0
    )
    let knobX: CGFloat = enabled ? 972 : 954
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: knobX, y: y + 3, width: 20, height: 20)).fill()
}

func drawImagePreview(rect: NSRect) {
    drawRoundedRect(
        rect,
        radius: 10,
        fill: NSColor(calibratedRed: 0.12, green: 0.66, blue: 0.74, alpha: 1),
        stroke: NSColor(calibratedWhite: 0.80, alpha: 1),
        lineWidth: 1
    )
    NSColor(calibratedRed: 0.98, green: 0.65, blue: 0.20, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: rect.minX + 45, y: rect.minY + 34, width: 14, height: 14)).fill()
    NSColor.white.withAlphaComponent(0.86).setFill()
    let mountain = NSBezierPath()
    mountain.move(to: NSPoint(x: rect.minX + 8, y: rect.minY + 12))
    mountain.line(to: NSPoint(x: rect.minX + 28, y: rect.minY + 34))
    mountain.line(to: NSPoint(x: rect.minX + 42, y: rect.minY + 22))
    mountain.line(to: NSPoint(x: rect.minX + 62, y: rect.minY + 44))
    mountain.line(to: NSPoint(x: rect.minX + 64, y: rect.minY + 12))
    mountain.close()
    mountain.fill()
}

func drawTextIcon(_ text: String, rect: NSRect, color: NSColor) {
    drawRoundedRect(rect, radius: 12, fill: color.withAlphaComponent(0.13), stroke: color.withAlphaComponent(0.35), lineWidth: 1)
    drawText(text, at: NSPoint(x: rect.midX - 8, y: rect.minY + 12), size: 20, weight: .bold, color: color)
}

func drawMagnifier(center: NSPoint) {
    secondaryTextColor.setStroke()
    let circle = NSBezierPath(ovalIn: NSRect(x: center.x - 8, y: center.y - 6, width: 13, height: 13))
    circle.lineWidth = 2
    circle.stroke()
    let handle = NSBezierPath()
    handle.move(to: NSPoint(x: center.x + 3, y: center.y - 8))
    handle.line(to: NSPoint(x: center.x + 10, y: center.y - 15))
    handle.lineWidth = 2
    handle.stroke()
}

func drawRoundedRect(_ rect: NSRect, radius: CGFloat, fill: NSColor, stroke: NSColor, lineWidth: CGFloat) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    if lineWidth > 0 {
        stroke.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }
}

func drawText(
    _ string: String,
    at point: NSPoint,
    size: CGFloat,
    weight: NSFont.Weight = .regular,
    color: NSColor = primaryTextColor
) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color
    ]
    string.draw(at: point, withAttributes: attributes)
}

let primaryTextColor = NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.14, alpha: 1)
let secondaryTextColor = NSColor(calibratedRed: 0.38, green: 0.43, blue: 0.50, alpha: 1)
