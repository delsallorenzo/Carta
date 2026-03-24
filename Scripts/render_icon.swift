import AppKit

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    fputs("usage: swift Scripts/render_icon.swift <output-png>\n", stderr)
    exit(1)
}

let outputPath = arguments[1]
let width = 1024
let height = 1024

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("failed to allocate bitmap\n", stderr)
    exit(1)
}

guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("failed to create graphics context\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

let canvas = NSRect(x: 0, y: 0, width: width, height: height)
NSColor(calibratedWhite: 0.98, alpha: 1.0).setFill()
NSBezierPath(rect: canvas).fill()

for _ in 0..<220_000 {
    let x = CGFloat.random(in: 0..<CGFloat(width))
    let y = CGFloat.random(in: 0..<CGFloat(height))
    let alpha = CGFloat.random(in: 0.02...0.10)
    NSColor(calibratedWhite: CGFloat.random(in: 0.68...0.9), alpha: alpha).setFill()
    NSBezierPath(rect: NSRect(x: x, y: y, width: 1, height: 1)).fill()
}

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center

let font = NSFont(name: "HelveticaNeue-Bold", size: 720)
    ?? NSFont.systemFont(ofSize: 720, weight: .black)

let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.black,
    .paragraphStyle: paragraph
]

let text = NSString(string: "C")
let textSize = text.size(withAttributes: attributes)
let textRect = NSRect(
    x: (CGFloat(width) - textSize.width) / 2,
    y: (CGFloat(height) - textSize.height) / 2 - 24,
    width: textSize.width,
    height: textSize.height
)
text.draw(in: textRect, withAttributes: attributes)

NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("failed to encode icon png\n", stderr)
    exit(1)
}

do {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
} catch {
    fputs("failed to write png: \(error)\n", stderr)
    exit(1)
}
