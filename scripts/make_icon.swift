import AppKit
import Foundation

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let root = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let iconset = root.appendingPathComponent(".build/AppIcon.iconset", isDirectory: true)
let output = root.appendingPathComponent(".build/AppIcon.icns")

try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(_ size: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "icon", code: 1)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.shouldAntialias = true

    let s = CGFloat(size)
    let bounds = NSRect(x: s * 0.025, y: s * 0.025, width: s * 0.95, height: s * 0.95)
    let radius = s * 0.212
    let background = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)

    let gradient = NSGradient(
        starting: NSColor(srgbRed: 0.17, green: 0.17, blue: 0.17, alpha: 1),
        ending: NSColor(srgbRed: 0.045, green: 0.045, blue: 0.045, alpha: 1)
    )
    gradient?.draw(in: background, angle: -90)

    NSColor.white.withAlphaComponent(0.07).setStroke()
    background.lineWidth = max(1, s * 0.0025)
    background.stroke()

    NSColor(srgbRed: 0.95, green: 0.95, blue: 0.93, alpha: 1).setStroke()

    let shaft = NSBezierPath()
    shaft.move(to: NSPoint(x: s * 0.5, y: s * 0.70))
    shaft.line(to: NSPoint(x: s * 0.5, y: s * 0.32))
    shaft.lineWidth = s * 0.072
    shaft.lineCapStyle = .round
    shaft.stroke()

    let chevron = NSBezierPath()
    chevron.move(to: NSPoint(x: s * 0.345, y: s * 0.465))
    chevron.line(to: NSPoint(x: s * 0.5, y: s * 0.30))
    chevron.line(to: NSPoint(x: s * 0.655, y: s * 0.465))
    chevron.lineWidth = s * 0.072
    chevron.lineCapStyle = .round
    chevron.lineJoinStyle = .round
    chevron.stroke()

    let baseline = NSBezierPath()
    baseline.move(to: NSPoint(x: s * 0.34, y: s * 0.175))
    baseline.line(to: NSPoint(x: s * 0.66, y: s * 0.175))
    baseline.lineWidth = s * 0.036
    baseline.lineCapStyle = .round
    baseline.stroke()

    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon", code: 2)
    }
    return data
}

let variants: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, size) in variants {
    try render(size).write(to: iconset.appendingPathComponent(name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(domain: "iconutil", code: Int(process.terminationStatus))
}

print(output.path)
