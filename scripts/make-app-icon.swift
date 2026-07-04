import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsetURL = root.appendingPathComponent("assets/AppIcon.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let sizes: [(name: String, points: CGFloat, scale: CGFloat)] = [
    ("icon_16x16.png", 16, 1),
    ("icon_16x16@2x.png", 16, 2),
    ("icon_32x32.png", 32, 1),
    ("icon_32x32@2x.png", 32, 2),
    ("icon_128x128.png", 128, 1),
    ("icon_128x128@2x.png", 128, 2),
    ("icon_256x256.png", 256, 1),
    ("icon_256x256@2x.png", 256, 2),
    ("icon_512x512.png", 512, 1),
    ("icon_512x512@2x.png", 512, 2)
]

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

func stroke(_ path: NSBezierPath, width: CGFloat, color: NSColor) {
    color.setStroke()
    path.lineWidth = width
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
}

func makeIcon(pixelSize: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: pixelSize, height: pixelSize))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
    let radius = pixelSize * 0.205
    let background = NSBezierPath(roundedRect: rect.insetBy(dx: pixelSize * 0.012, dy: pixelSize * 0.012), xRadius: radius, yRadius: radius)
    color(0x070B13).setFill()
    background.fill()

    let glow = NSShadow()
    glow.shadowBlurRadius = pixelSize * 0.028
    glow.shadowColor = color(0x20E7FF, alpha: 0.35)
    glow.shadowOffset = .zero
    NSGraphicsContext.current?.saveGraphicsState()
    glow.set()

    let lineWidth = pixelSize * 0.035
    let cyan = color(0x27EAF2)
    let blue = color(0x4B8DFF)
    let violet = color(0x8E55FF)

    let folder = NSBezierPath()
    folder.move(to: NSPoint(x: pixelSize * 0.24, y: pixelSize * 0.30))
    folder.line(to: NSPoint(x: pixelSize * 0.24, y: pixelSize * 0.72))
    folder.curve(to: NSPoint(x: pixelSize * 0.29, y: pixelSize * 0.77), controlPoint1: NSPoint(x: pixelSize * 0.24, y: pixelSize * 0.75), controlPoint2: NSPoint(x: pixelSize * 0.26, y: pixelSize * 0.77))
    folder.line(to: NSPoint(x: pixelSize * 0.45, y: pixelSize * 0.77))
    folder.line(to: NSPoint(x: pixelSize * 0.51, y: pixelSize * 0.70))
    folder.line(to: NSPoint(x: pixelSize * 0.76, y: pixelSize * 0.70))
    folder.curve(to: NSPoint(x: pixelSize * 0.80, y: pixelSize * 0.66), controlPoint1: NSPoint(x: pixelSize * 0.79, y: pixelSize * 0.70), controlPoint2: NSPoint(x: pixelSize * 0.80, y: pixelSize * 0.68))
    folder.line(to: NSPoint(x: pixelSize * 0.80, y: pixelSize * 0.30))
    folder.curve(to: NSPoint(x: pixelSize * 0.76, y: pixelSize * 0.26), controlPoint1: NSPoint(x: pixelSize * 0.80, y: pixelSize * 0.28), controlPoint2: NSPoint(x: pixelSize * 0.78, y: pixelSize * 0.26))
    folder.line(to: NSPoint(x: pixelSize * 0.42, y: pixelSize * 0.26))
    stroke(folder, width: lineWidth, color: blue)

    let lensRect = NSRect(x: pixelSize * 0.32, y: pixelSize * 0.30, width: pixelSize * 0.38, height: pixelSize * 0.38)
    let lens = NSBezierPath(ovalIn: lensRect)
    stroke(lens, width: lineWidth, color: cyan)

    let handle = NSBezierPath()
    handle.move(to: NSPoint(x: pixelSize * 0.66, y: pixelSize * 0.34))
    handle.line(to: NSPoint(x: pixelSize * 0.79, y: pixelSize * 0.21))
    stroke(handle, width: lineWidth * 1.18, color: violet)

    for index in 0..<2 {
        let y = pixelSize * (0.55 - CGFloat(index) * 0.10)
        let bullet = NSBezierPath(roundedRect: NSRect(x: pixelSize * 0.42, y: y - pixelSize * 0.018, width: pixelSize * 0.038, height: pixelSize * 0.038), xRadius: pixelSize * 0.008, yRadius: pixelSize * 0.008)
        stroke(bullet, width: lineWidth * 0.55, color: cyan)
        let row = NSBezierPath()
        row.move(to: NSPoint(x: pixelSize * 0.51, y: y))
        row.line(to: NSPoint(x: pixelSize * 0.61, y: y))
        stroke(row, width: lineWidth * 0.55, color: blue)
    }

    NSGraphicsContext.current?.restoreGraphicsState()
    image.unlockFocus()
    return image
}

for item in sizes {
    let pixels = item.points * item.scale
    let image = makeIcon(pixelSize: pixels)
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not render \(item.name)")
    }
    try png.write(to: iconsetURL.appendingPathComponent(item.name))
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetURL.path, "-o", root.appendingPathComponent("assets/MacEverything.icns").path]
try task.run()
task.waitUntilExit()
if task.terminationStatus != 0 {
    fatalError("iconutil failed")
}
print("Generated assets/MacEverything.icns")
