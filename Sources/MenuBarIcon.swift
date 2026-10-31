import AppKit

enum MenuBarIcon {
    static func cup(steaming: Bool, color: NSColor? = nil) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            (color ?? NSColor.black).set()
            let body = NSBezierPath()
            body.move(to: NSPoint(x: 1.8, y: 10.2))
            body.line(to: NSPoint(x: 16.2, y: 10.2))
            body.line(to: NSPoint(x: 13.9, y: 3.4))
            body.curve(to: NSPoint(x: 12.1, y: 1.9), controlPoint1: NSPoint(x: 13.6, y: 2.4), controlPoint2: NSPoint(x: 12.9, y: 1.9))
            body.line(to: NSPoint(x: 5.9, y: 1.9))
            body.curve(to: NSPoint(x: 4.1, y: 3.4), controlPoint1: NSPoint(x: 5.1, y: 1.9), controlPoint2: NSPoint(x: 4.4, y: 2.4))
            body.close()
            body.fill()
            NSBezierPath(ovalIn: NSRect(x: 1.8, y: 8.5, width: 14.4, height: 3.4)).fill()
            if steaming {
                for x in [6.2, 11.8] as [CGFloat] {
                    let curl = NSBezierPath()
                    curl.lineWidth = 1.5
                    curl.lineCapStyle = .round
                    curl.move(to: NSPoint(x: x, y: 12.4))
                    curl.curve(to: NSPoint(x: x, y: 16.9), controlPoint1: NSPoint(x: x + 2.4, y: 13.6), controlPoint2: NSPoint(x: x - 2.4, y: 15.6))
                    curl.stroke()
                }
            }
            return true
        }
        image.isTemplate = color == nil
        image.accessibilityDescription = "Matcha"
        return image
    }
}
