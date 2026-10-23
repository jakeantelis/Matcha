import AppKit

final class RingButton: NSView {
    var active = false { didSet { needsDisplay = true } }
    var progress: CGFloat = 0 { didSet { needsDisplay = true } }
    var accent: NSColor = .controlAccentColor { didSet { needsDisplay = true } }
    var timeText: String? { didSet { if timeText != oldValue { needsDisplay = true } } }
    var pulsing = false {
        didSet {
            guard pulsing != oldValue else { return }
            pulsing ? startPulse() : stopPulse()
        }
    }
    var onClick: (() -> Void)?

    private var hovering = false
    private var tracking: NSTrackingArea?
    private var cursorPushed = false
    private var pulseTimer: Timer?
    private var pulsePhase: CGFloat = 0

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
        if !cursorPushed {
            NSCursor.pointingHand.push()
            cursorPushed = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        needsDisplay = true
        if cursorPushed {
            NSCursor.pop()
            cursorPushed = false
        }
    }

    deinit {
        if cursorPushed { NSCursor.pop() }
        pulseTimer?.invalidate()
    }

    private func startPulse() {
        guard pulseTimer == nil,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        else { return }

        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.pulsePhase += 0.035
            if self.pulsePhase > 1 { self.pulsePhase -= 1 }
            self.needsDisplay = true
        }
        RunLoop.main.add(timer, forMode: .common)
        pulseTimer = timer
    }

    private func stopPulse() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        pulsePhase = 0
        needsDisplay = true
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
            if pulsing {
                let wave = 0.5 + 0.5 * sin(pulsePhase * 2 * .pi)
                accent.withAlphaComponent(0.5 + 0.5 * wave).setStroke()
            } else {
                accent.setStroke()
            }
            arc.stroke()
        }

        if let text = timeText {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 19, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
            ]
            let string = NSAttributedString(string: text, attributes: attributes)
            let size = string.size()
            string.draw(in: NSRect(
                x: bounds.midX - size.width / 2,
                y: bounds.midY - size.height / 2,
                width: size.width,
                height: size.height
            ))
            return
        }

        if !active {
            let cupConfig = NSImage.SymbolConfiguration(pointSize: 38, weight: .medium)
            if let cup = NSImage(systemSymbolName: "cup.and.saucer", accessibilityDescription: nil)?
                .withSymbolConfiguration(cupConfig) {
                tinted(cup, hovering ? NSColor.labelColor : NSColor.secondaryLabelColor).draw(in: NSRect(x: bounds.midX - cup.size.width / 2, y: bounds.midY - cup.size.height / 2, width: cup.size.width, height: cup.size.height))
            }
            NSColor.tertiaryLabelColor.setFill()
            let d1 = NSBezierPath(ovalIn: NSRect(x: bounds.midX + 18, y: bounds.midY - 14, width: 4, height: 4))
            d1.fill()
            let d2 = NSBezierPath(ovalIn: NSRect(x: bounds.midX + 25, y: bounds.midY - 19, width: 5, height: 5))
            d2.fill()
            let d3 = NSBezierPath(ovalIn: NSRect(x: bounds.midX + 33, y: bounds.midY - 25, width: 6, height: 6))
            d3.fill()
            return
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
