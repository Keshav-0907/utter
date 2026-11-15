// Draws the installer window background. Usage: swift scripts/make-dmg-background.swift
// Writes Resources/dmg-background.tiff holding a normal and a Retina version.
// The layout must match scripts/dmg-settings.py: a 660 x 400 window with the app icon
// centred at (170, 185) and the Applications shortcut at (490, 185), measured from the top left.
import AppKit

let width: CGFloat = 660
let height: CGFloat = 400

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha
    )
}

func render(scale: CGFloat) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Same quiet ground as the website.
    color(0xF6F7F8).setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()

    // A thin arrow from the app to the Applications folder. Drawing is bottom-up, so y = 400 - 185.
    let y = height - 185
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 272, y: y))
    arrow.line(to: NSPoint(x: 388, y: y))
    arrow.move(to: NSPoint(x: 376, y: y + 11))
    arrow.line(to: NSPoint(x: 388, y: y))
    arrow.line(to: NSPoint(x: 376, y: y - 11))
    arrow.lineWidth = 1.5
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    color(0x101113, 0.32).setStroke()
    arrow.stroke()

    // One line of instruction, and a hairline above it.
    color(0x101113, 0.10).setFill()
    NSRect(x: 40, y: height - 300, width: width - 80, height: 1).fill()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let title = NSAttributedString(string: "Drag Utter onto Applications to install", attributes: [
        .font: NSFont.systemFont(ofSize: 14, weight: .medium),
        .foregroundColor: color(0x101113, 0.82),
        .paragraphStyle: paragraph,
        .kern: -0.1,
    ])
    title.draw(in: NSRect(x: 0, y: height - 338, width: width, height: 20))
    let note = NSAttributedString(string: "Then open it from Applications or Spotlight.", attributes: [
        .font: NSFont.systemFont(ofSize: 12, weight: .regular),
        .foregroundColor: color(0x101113, 0.5),
        .paragraphStyle: paragraph,
    ])
    note.draw(in: NSRect(x: 0, y: height - 360, width: width, height: 18))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let temp = FileManager.default.temporaryDirectory
let one = temp.appendingPathComponent("utter-dmg-bg.png")
let two = temp.appendingPathComponent("utter-dmg-bg@2x.png")
try render(scale: 1).write(to: one)
try render(scale: 2).write(to: two)

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil")
task.arguments = ["-cathidpicheck", one.path, two.path, "-out", "Resources/dmg-background.tiff"]
try task.run()
task.waitUntilExit()
print(task.terminationStatus == 0 ? "Wrote Resources/dmg-background.tiff" : "tiffutil failed")
