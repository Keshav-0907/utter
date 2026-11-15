// Renders Resources/AppIcon.icns. Usage: swift scripts/make-icon.swift [preview.png]
import AppKit

let size: CGFloat = 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha
    )
}

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let context = NSGraphicsContext.current!.cgContext

let plate = NSRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: plate, xRadius: 186, yRadius: 186)

// Soft drop shadow under the plate.
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.28).cgColor)
color(0x0B0B14).setFill()
shape.fill()
context.restoreGState()

context.saveGState()
shape.addClip()

// One confident colour with a slight top-to-bottom shade. No glows.
NSGradient(colors: [color(0x3D8BFF), color(0x0B5CE0)])!.draw(in: plate, angle: -90)

// Voice bars.
let heights: [CGFloat] = [150, 300, 460, 250, 380, 190, 110]
let barWidth: CGFloat = 54
let gap: CGFloat = 34
let total = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * gap
var x = (size - total) / 2
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0x06307A, 0.35).cgColor)
context.beginTransparencyLayer(auxiliaryInfo: nil)
for height in heights {
    let bar = NSRect(x: x, y: (size - height) / 2, width: barWidth, height: height)
    let path = NSBezierPath(roundedRect: bar, xRadius: barWidth / 2, yRadius: barWidth / 2)
    NSGradient(colors: [color(0xFFFFFF), color(0xF1F6FF)])!.draw(in: path, angle: -90)
    x += barWidth + gap
}
context.endTransparencyLayer()
context.restoreGState()

context.restoreGState()

// Thin bright rim, strongest at the top.
context.saveGState()
context.addPath(CGPath(roundedRect: plate.insetBy(dx: 3, dy: 3), cornerWidth: 183, cornerHeight: 183, transform: nil))
context.setLineWidth(6)
context.replacePathWithStrokedPath()
context.clip()
NSGradient(colors: [color(0xFFFFFF, 0.35), color(0xFFFFFF, 0.0)])!.draw(in: plate, angle: -90)
context.restoreGState()
image.unlockFocus()
let final = image

func png(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    final.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

if CommandLine.arguments.count > 1 {
    try png(512).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
}

let fm = FileManager.default
let iconset = fm.temporaryDirectory.appendingPathComponent("Utter-\(UUID().uuidString).iconset")
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try png(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try png(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try task.run()
task.waitUntilExit()
try? fm.removeItem(at: iconset)
print(task.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
