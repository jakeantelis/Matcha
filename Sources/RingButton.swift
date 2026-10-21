import AppKit

final class RingButton: NSView {
    var active = false { didSet { needsDisplay = true } }
    var progress: CGFloat = 0 { didSet { needsDisplay = true } }
    var accent: NSColor = .controlAccentColor { didSet { needsDisplay = true } }
    var onClick: (() -> Void)?

    private var hovering = false
    private var tracking: NSTrackingArea?

    override var intrinsicContentSize: NSSize { NSSize(width: 128, height: 128) }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = tracking { removeTrackingArea(t) }
        let t = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(t)
        tracking = t
    }

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        needsDisplay = true
        NSCursor.pointingHand.push()
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        needsDisplay = true
        NSCursor.pop()
    }

    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) {
            onClick?()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let lineWidth: CGFloat = 8
        let ringRect = bounds.insetBy(dx: lineWidth / 2 + 1, dy: lineWidth / 2 + 1)

        let track = NSBezierPath(ovalIn: ringRect)
        track.lineWidth = lineWidth
        if active {
            accent.withAlphaComponent(0.16).setStroke()
        } else {
            (hovering ? NSColor.tertiaryLabelColor : NSColor.quaternaryLabelColor).setStroke()
        }
        track.stroke()

        if active {
            let arc = NSBezierPath()
            let start: CGFloat = 90
            let end = start - 360 * max(0.02, min(1, progress))
            arc.appendArc(
                withCenter: NSPoint(x: bounds.midX, y: bounds.midY),
                radius: ringRect.width / 2,
                startAngle: start,
                endAngle: end,
                clockwise: true
            )
            arc.lineWidth = lineWidth
            arc.lineCapStyle = .round
            accent.setStroke()
            arc.stroke()
        }

        let names = active
            ? ["cup.and.saucer.fill", "cup.and.saucer", "mug.fill", "mug"]
            : ["cup.and.saucer", "mug"]
        guard let base = symbolImage(names),
              let sized = base.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 38, weight: .medium))
        else { return }

        let color = active ? accent : (hovering ? NSColor.labelColor : NSColor.secondaryLabelColor)
        let image = tinted(sized, color)
        let size = image.size
        let rect = NSRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        image.draw(in: rect)
    }
}
