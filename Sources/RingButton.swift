import AppKit

final class RingButton: NSView {
    var active = false {
        didSet {
            guard active != oldValue else { return }
            active ? startAnim() : stopAnim()
            needsDisplay = true
        }
    }
    var progress: CGFloat = 0 { didSet { needsDisplay = true } }
    var accent: NSColor = .controlAccentColor { didSet { needsDisplay = true } }
    var timeText: String? { didSet { if timeText != oldValue { needsDisplay = true } } }
    var pulsing = false { didSet { needsDisplay = true } }
    var onClick: (() -> Void)?

    private var hovering = false
    private var tracking: NSTrackingArea?
    private var cursorPushed = false
    private var animTimer: Timer?
    private var phase: CGFloat = 0

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
        animTimer?.invalidate()
    }

    private func startAnim() {
        guard animTimer == nil, animationsEnabled() else { return }

        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard animationsEnabled() else { self.stopAnim(); return }
            self.phase += 0.02
            if self.phase > 1 { self.phase -= 1 }
            self.needsDisplay = true
        }
        RunLoop.main.add(timer, forMode: .common)
        animTimer = timer
    }

    private func stopAnim() {
        animTimer?.invalidate()
        animTimer = nil
        phase = 0
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
        let innerCircle = ringRect.insetBy(dx: lineWidth, dy: lineWidth)

        // Warm glow behind the active arc
        if active {
            let haloRadius = ringRect.width / 2
            let halo = NSBezierPath()
            halo.appendArc(
                withCenter: NSPoint(x: bounds.midX, y: bounds.midY),
                radius: haloRadius,
                startAngle: 90,
                endAngle: 90 - 360 * max(0.02, min(1, progress)),
                clockwise: true
            )
            halo.lineWidth = lineWidth + 12
            halo.lineCapStyle = .round
            accent.withAlphaComponent(0.12).setStroke()
            halo.stroke()
        }

        let track = NSBezierPath(ovalIn: ringRect)
        track.lineWidth = lineWidth
        if active {
            accent.withAlphaComponent(0.16).setStroke()
        } else if hovering {
            accent.withAlphaComponent(0.35).setStroke()
        } else {
            NSColor.tertiaryLabelColor.setStroke()
            var dash: [CGFloat] = [1.5, 5]
            track.setLineDash(&dash, count: dash.count, phase: 0)
        }
        track.stroke()

        // Tea fill — liquid level reflects time remaining
        if active {
            NSGraphicsContext.current?.saveGraphicsState()
            NSBezierPath(ovalIn: innerCircle).addClip()

            var level = max(0, min(1, progress))
            if pulsing {
                level = 0.4 + 0.18 * sin(phase * 2 * .pi)
            }
            let fillHeight = max(0, innerCircle.height * level)
            let fillRect = NSRect(
                x: innerCircle.minX,
                y: innerCircle.minY,
                width: innerCircle.width,
                height: fillHeight
            )
            let fillGradient = NSGradient(colors: [
                accent.withAlphaComponent(0.45),
                accent.withAlphaComponent(0.18),
            ])
            fillGradient?.draw(in: fillRect, angle: 90)
            NSGraphicsContext.current?.restoreGraphicsState()
        }

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
                let wave = 0.5 + 0.5 * sin(phase * 2 * .pi)
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

            if active {
                drawSteam(innerCircle: innerCircle)
            }
            return
        }

        if !active {
            let cupConfig = NSImage.SymbolConfiguration(pointSize: 38, weight: .regular)
            if let cup = NSImage(systemSymbolName: "cup.and.saucer", accessibilityDescription: nil)?
                .withSymbolConfiguration(cupConfig) {
                tinted(cup, hovering ? accent : NSColor.tertiaryLabelColor).draw(in: NSRect(x: bounds.midX - cup.size.width / 2, y: bounds.midY - cup.size.height / 2, width: cup.size.width, height: cup.size.height))
            }
            return
        }

        let names = ["cup.and.saucer.fill", "cup.and.saucer", "mug.fill", "mug"]
        guard let base = symbolImage(names),
              let sized = base.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 38, weight: .medium))
        else { return }

        let image = tinted(sized, accent)
        let size = image.size
        let rect = NSRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        image.draw(in: rect)
        drawSteam(innerCircle: innerCircle)
    }

    private func drawSteam(innerCircle: NSRect) {
        let base = innerCircle.midY + 12
        for (i, offset) in [-9.0, 9.0].enumerated() {
            let wobble = sin(phase * 2 * .pi + CGFloat(i) * 1.6) * 2
            let alpha = 0.25 + 0.2 * sin(phase * 2 * .pi + CGFloat(i))
            let path = NSBezierPath()
            let x0 = innerCircle.midX + offset + wobble
            path.move(to: NSPoint(x: x0, y: base))
            path.curve(
                to: NSPoint(x: x0 + wobble * 2, y: base + 10),
                controlPoint1: NSPoint(x: x0 - 3, y: base + 4),
                controlPoint2: NSPoint(x: x0 + 3, y: base + 7)
            )
            path.lineWidth = 2
            path.lineCapStyle = .round
            accent.withAlphaComponent(max(0, alpha)).setStroke()
            path.stroke()
        }
    }
}