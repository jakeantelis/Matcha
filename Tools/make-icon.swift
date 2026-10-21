import AppKit

func renderIcon(side: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: side, height: side))
    image.lockFocus()

    let canvas = NSRect(x: 0, y: 0, width: side, height: side)

    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.55, green: 0.85, blue: 0.62, alpha: 1),
        NSColor(srgbRed: 0.35, green: 0.70, blue: 0.44, alpha: 1),
        NSColor(srgbRed: 0.20, green: 0.50, blue: 0.32, alpha: 1),
    ])
    gradient?.draw(in: canvas, relativeCenterPosition: NSPoint(x: 0, y: 0.22))

    let cx = side / 2

    // -- saucer --
    let saucer = NSBezierPath(ovalIn: NSRect(x: cx - side * 0.30, y: side * 0.10, width: side * 0.60, height: side * 0.14))
    NSColor(srgbRed: 0.12, green: 0.38, blue: 0.24, alpha: 0.30).setFill()
    saucer.fill()

    // -- cup body --
    let cupTop = side * 0.56
    let cupBottom = side * 0.18
    let cupHalfTop = side * 0.22
    let cupHalfBottom = side * 0.16

    let cup = NSBezierPath()
    cup.move(to: NSPoint(x: cx - cupHalfTop, y: cupTop))
    cup.line(to: NSPoint(x: cx - cupHalfBottom, y: cupBottom))
    cup.curve(
        to: NSPoint(x: cx + cupHalfBottom, y: cupBottom),
        controlPoint1: NSPoint(x: cx - cupHalfBottom, y: cupBottom - side * 0.06),
        controlPoint2: NSPoint(x: cx + cupHalfBottom, y: cupBottom - side * 0.06)
    )
    cup.line(to: NSPoint(x: cx + cupHalfTop, y: cupTop))
    cup.close()

    let cupColor = NSColor(srgbRed: 1.00, green: 0.97, blue: 0.91, alpha: 1)
    cupColor.setFill()
    cup.fill()

    // -- tea surface (ellipse across the brim) --
    let tea = NSBezierPath(ovalIn: NSRect(x: cx - cupHalfTop, y: cupTop - side * 0.055, width: side * 0.44, height: side * 0.11))
    NSColor(srgbRed: 0.45, green: 0.74, blue: 0.40, alpha: 0.95).setFill()
    tea.fill()

    // -- steam --
    let steamColor = NSColor.white.withAlphaComponent(0.80)
    steamColor.setStroke()
    for offset in [-side * 0.05, side * 0.05] {
        let steam = NSBezierPath()
        let baseY = cupTop + side * 0.05
        steam.move(to: NSPoint(x: cx + offset, y: baseY))
        steam.curve(
            to: NSPoint(x: cx + offset, y: baseY + side * 0.14),
            controlPoint1: NSPoint(x: cx + offset - side * 0.04, y: baseY + side * 0.04),
            controlPoint2: NSPoint(x: cx + offset + side * 0.04, y: baseY + side * 0.10)
        )
        steam.lineWidth = side * 0.03
        steam.lineCapStyle = .round
        steam.stroke()
    }

    image.unlockFocus()
    return image
}

let outputDirectory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let iconset = "\(outputDirectory)/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

let master = renderIcon(side: 1024)

let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (pixels, name) in sizes {
    let target = NSImage(size: NSSize(width: pixels, height: pixels))
    target.lockFocus()
    master.draw(
        in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
        from: NSRect(x: 0, y: 0, width: 1024, height: 1024),
        operation: .copy,
        fraction: 1
    )
    target.unlockFocus()

    guard let tiff = target.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { continue }
    rep.size = NSSize(width: pixels, height: pixels)
    try? rep.representation(using: .png, properties: [:])?
        .write(to: URL(fileURLWithPath: "\(iconset)/\(name)"))
}

print("wrote \(iconset)")