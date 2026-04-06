import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "NativeMacApp/Assets/LoquorIcon.png"
let outputURL = URL(fileURLWithPath: outputPath)
let size = CGSize(width: 1024, height: 1024)
let rect = CGRect(origin: .zero, size: size)

let image = NSImage(size: size)
image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    fputs("Could not create graphics context.\n", stderr)
    exit(1)
}

context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)
context.interpolationQuality = .high

let backgroundRect = rect.insetBy(dx: 92, dy: 92)
let backgroundPath = NSBezierPath(roundedRect: backgroundRect, xRadius: 220, yRadius: 220)
context.saveGState()
backgroundPath.addClip()

let backgroundGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.09, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.16, alpha: 1.0).cgColor,
    ] as CFArray,
    locations: [0.0, 1.0]
)!
context.drawLinearGradient(
    backgroundGradient,
    start: CGPoint(x: 160, y: 900),
    end: CGPoint(x: 864, y: 124),
    options: []
)

let haloGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        NSColor(calibratedRed: 1.0, green: 0.73, blue: 0.33, alpha: 0.18).cgColor,
        NSColor(calibratedRed: 1.0, green: 0.73, blue: 0.33, alpha: 0.0).cgColor,
    ] as CFArray,
    locations: [0.0, 1.0]
)!
context.drawRadialGradient(
    haloGradient,
    startCenter: CGPoint(x: 512, y: 565),
    startRadius: 0,
    endCenter: CGPoint(x: 512, y: 565),
    endRadius: 310,
    options: []
)
context.restoreGState()

backgroundPath.lineWidth = 2
NSColor(calibratedWhite: 1.0, alpha: 0.06).setStroke()
backgroundPath.stroke()

let barWidth: CGFloat = 108
let barSpacing: CGFloat = 54
let cornerRadius: CGFloat = 54
let barBottom: CGFloat = 318
let heights: [CGFloat] = [278, 404, 338]
let colors: [(NSColor, NSColor)] = [
    (
        NSColor(calibratedRed: 1.00, green: 0.47, blue: 0.35, alpha: 1.0),
        NSColor(calibratedRed: 1.00, green: 0.71, blue: 0.36, alpha: 1.0)
    ),
    (
        NSColor(calibratedRed: 1.00, green: 0.54, blue: 0.33, alpha: 1.0),
        NSColor(calibratedRed: 1.00, green: 0.84, blue: 0.40, alpha: 1.0)
    ),
    (
        NSColor(calibratedRed: 1.00, green: 0.49, blue: 0.35, alpha: 1.0),
        NSColor(calibratedRed: 1.00, green: 0.78, blue: 0.38, alpha: 1.0)
    ),
]

let totalWidth = (barWidth * 3) + (barSpacing * 2)
let startX = (size.width - totalWidth) / 2

for index in 0..<3 {
    let barRect = CGRect(
        x: startX + CGFloat(index) * (barWidth + barSpacing),
        y: barBottom,
        width: barWidth,
        height: heights[index]
    )

    let glowRect = barRect.insetBy(dx: -32, dy: -28)
    let glowPath = NSBezierPath(roundedRect: glowRect, xRadius: 78, yRadius: 78)
    context.saveGState()
    glowPath.addClip()
    let glowGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            colors[index].1.withAlphaComponent(0.22).cgColor,
            colors[index].0.withAlphaComponent(0.0).cgColor,
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    context.drawRadialGradient(
        glowGradient,
        startCenter: CGPoint(x: glowRect.midX, y: glowRect.midY + 12),
        startRadius: 0,
        endCenter: CGPoint(x: glowRect.midX, y: glowRect.midY + 12),
        endRadius: max(glowRect.width, glowRect.height) * 0.72,
        options: []
    )
    context.restoreGState()

    let path = NSBezierPath(roundedRect: barRect, xRadius: cornerRadius, yRadius: cornerRadius)
    context.saveGState()
    path.addClip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [colors[index].0.cgColor, colors[index].1.cgColor] as CFArray,
        locations: [0.0, 1.0]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: barRect.minX, y: barRect.minY),
        end: CGPoint(x: barRect.maxX, y: barRect.maxY),
        options: []
    )

    let sheenGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(calibratedWhite: 1.0, alpha: 0.28).cgColor,
            NSColor(calibratedWhite: 1.0, alpha: 0.0).cgColor,
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    context.drawLinearGradient(
        sheenGradient,
        start: CGPoint(x: barRect.midX, y: barRect.maxY),
        end: CGPoint(x: barRect.midX, y: barRect.minY + 42),
        options: []
    )
    context.restoreGState()

    path.lineWidth = 1.5
    NSColor(calibratedWhite: 1.0, alpha: 0.16).setStroke()
    path.stroke()
}

image.unlockFocus()

guard
    let tiffData = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiffData),
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Could not encode icon as PNG.\n", stderr)
    exit(1)
}

try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try pngData.write(to: outputURL)
print(outputURL.path)
