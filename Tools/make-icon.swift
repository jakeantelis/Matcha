import AppKit

func renderIcon(side: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: side, height: side))
    image.lockFocus()

    let canvas = NSRect(x: 0, y: 0, width: side, height: side)

    // Squircle background (Big Sur style)
    let bg = NSBezierPath(
        roundedRect: canvas.insetBy(dx: side * 0.01, dy: side * 0.01),
        xRadius: side * 0.18,
        yRadius: side * 0.18
    )
    NSGraphicsContext.current?.saveGraphicsState()
    bg.addClip()

    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.52, green: 0.84, blue: 0.62, alpha: 1),
        NSColor(srgbRed: 0.30, green: 0.68, blue: 0.44, alpha: 1),
        NSColor(srgbRed: 0.14, green: 0.47, blue: 0.30, alpha: 1),
    ])
    gradient?.draw(in: canvas, relativeCenterPosition: NSPoint(x: 0, y: 0.32))

    let depth = NSGradient(colors: [
        NSColor(srgbRed: 0.08, green: 0.36, blue: 0.22, alpha: 0.40),
        NSColor(srgbRed: 0.08, green: 0.36, blue: 0.22, alpha: 0.0),
    ])
    depth?.draw(in: canvas, relativeCenterPosition: NSPoint(x: -0.55, y: -0.60))

    NSGraphicsContext.current?.restoreGraphicsState()

    let cx = side / 2

    // Saucer
    let saucer = NSBezierPath(ovalIn: NSRect(x: cx - side * 0.29, y: side * 0.085, width: side * 0.58, height: side * 0.125))
    NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.18).setFill()
    saucer.fill()

    // Cup
    let cupTop = side * 0.60
    let cupBottom = side * 0.23
    let cupHalfTop = side * 0.205
    let cupHalfBottom = side * 0.14

    let cup = NSBezierPath()
    cup.move(to: NSPoint(x: cx - cupHalfTop, y: cupTop))
    cup.line(to: NSPoint(x: cx - cupHalfBottom, y: cupBottom + side * 0.05))
    cup.curve(
        to: NSPoint(x: cx + cupHalfBottom, y: cupBottom + side * 0.05),
        controlPoint1: NSPoint(x: cx - cupHalfBottom, y: cupBottom - side * 0.05),
        controlPoint2: NSPoint(x: cx + cupHalfBottom, y: cupBottom - side * 0.05)
    )
    cup.line(to: NSPoint(x: cx + cupHalfTop, y: cupTop))
    cup.close()

    NSColor(srgbRed: 1.00, green: 0.985, blue: 0.93, alpha: 1).setFill()
    cup.fill()

    // Left highlight for a glass feel
    let shine = NSBezierPath()
    shine.move(to: NSPoint(x: cx - cupHalfTop + side * 0.055, y: cupTop - side * 0.045))
    shine.line(to: NSPoint(x: cx - cupHalfBottom + side * 0.02, y: cupBottom + side * 0.055))
    shine.lineWidth = side * 0.035
    shine.lineCapStyle = .round
    NSColor.white.withAlphaComponent(0.7).setStroke()
    shine.stroke()

    // Tea surface across the brim
    let tea = NSBezierPath(ovalIn: NSRect(x: cx - cupHalfTop, y: cupTop - side * 0.055, width: side * 0.41, height: side * 0.105))
    NSColor(srgbRed: 0.28, green: 0.64, blue: 0.39, alpha: 1).setFill()
    tea.fill()

    // Steam
    let steamColor = NSColor.white.withAlphaComponent(0.85)
    steamColor.setStroke()
    for offset in [-side * 0.045, side * 0.045] {
        let steam = NSBezierPath()
        let baseY = cupTop + side * 0.05
        steam.move(to: NSPoint(x: cx + offset, y: baseY))
        steam.curve(
            to: NSPoint(x: cx + offset, y: baseY + side * 0.14),
            controlPoint1: NSPoint(x: cx + offset - side * 0.035, y: baseY + side * 0.045),
            controlPoint2: NSPoint(x: cx + offset + side * 0.035, y: baseY + side * 0.10)
        )
        steam.lineWidth = side * 0.026
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