import AppKit

final class FloatingBadge: NSPanel {
    var onClick: (() -> Void)?
    var onRightClick: (() -> Void)?
    var onMoved: ((NSPoint) -> Void)?
    var onQuickAdd: ((TimeInterval) -> Void)?
    var onStop: (() -> Void)?

    private let badgeView = BadgeView()
    private(set) var side: CGFloat

    static func size(for name: String) -> CGFloat {
        switch name {
        case "small": return 76
        case "large": return 128
        default: return 96
        }
    }

    init(size: CGFloat = 96) {
        side = size
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        becomesKeyOnlyIfNeeded = true

        badgeView.frame = NSRect(x: 0, y: 0, width: side, height: side)
        badgeView.autoresizingMask = [.width, .height]
        badgeView.toolTip = "Click for timer and settings \u{00B7} Right-click for quick actions \u{00B7} Drag to move"
        badgeView.onClick = { [weak self] in self?.onClick?() }
        badgeView.onRightClick = { [weak self] in self?.onRightClick?() }
        badgeView.onMoved = { [weak self] origin in self?.setFrameOrigin(origin) }
        badgeView.onDragEnded = { [weak self] in
            guard let self else { return }
            self.onMoved?(self.frame.origin)
        }
        badgeView.onQuickAdd = { [weak self] seconds in self?.onQuickAdd?(seconds) }
        badgeView.onStop = { [weak self] in self?.onStop?() }
        contentView = badgeView
    }

    var translucent: Bool = true {
        didSet { badgeView.translucent = translucent }
    }

    func resize(to newSide: CGFloat) {
        guard newSide != side else { return }
        let center = NSPoint(x: frame.midX, y: frame.midY)
        side = newSide
        var newFrame = frame
        newFrame.size = NSSize(width: newSide, height: newSide)
        newFrame.origin = NSPoint(x: center.x - newSide / 2, y: center.y - newSide / 2)
        setFrame(newFrame, display: true)
        badgeView.needsDisplay = true
    }

    func update(state: MatchaState) {
        badgeView.apply(state: state)
    }
}

final class BadgeView: NSView {
    var onClick: (() -> Void)?
    var onRightClick: (() -> Void)?
    var onMoved: ((NSPoint) -> Void)?
    var onDragEnded: (() -> Void)?
    var onQuickAdd: ((TimeInterval) -> Void)?
    var onStop: (() -> Void)?

    var translucent: Bool = true { didSet { needsDisplay = true } }

    private var active = false
    private var timed = false
    private var text = ""
    private var progress: CGFloat = 0
    private var dragOffset: NSPoint?
    private var movedDuringDrag = false
    private var hovering = false
    private var tracking: NSTrackingArea?
    private var animTimer: Timer?
    private var phase: CGFloat = 0

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
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

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let scale = max(0.5, bounds.width / 96)
        let diameter = min(bounds.width, bounds.height)
        let base = NSRect(
            x: (bounds.width - diameter) / 2,
            y: (bounds.height - diameter) / 2,
            width: diameter,
            height: diameter
        )
        let circle = base.insetBy(dx: 6 * scale, dy: 6 * scale)

        let fillAlpha: CGFloat = (translucent ? 0.55 : 0.97) + (hovering ? 0.08 : 0)
        let path = NSBezierPath(ovalIn: circle)

        NSGraphicsContext.current?.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
        shadow.shadowBlurRadius = 8 * scale
        shadow.shadowOffset = NSSize(width: 0, height: -3 * scale)
        shadow.set()
        NSColor.controlBackgroundColor.withAlphaComponent(fillAlpha).setFill()
        path.fill()
        NSGraphicsContext.current?.restoreGraphicsState()

        // Active breathing glow, matching the main window's warm halo
        if active {
            let wave = 0.5 + 0.5 * sin(phase * 2 * .pi)
            let glowRect = NSInsetRect(circle, -3 * scale, -3 * scale)
            if let ctx = NSGraphicsContext.current {
                ctx.saveGraphicsState()
                NSBezierPath(ovalIn: glowRect).addClip()
                let g = NSGradient(colors: [
                    Matcha.green.withAlphaComponent(0.12 + 0.10 * wave),
                    Matcha.green.withAlphaComponent(0),
                ])
                g?.draw(in: glowRect, angle: -90)
                ctx.restoreGraphicsState()
            }
        }

        if hovering {
            let glowRect = NSInsetRect(circle, -2 * scale, -2 * scale)
            if let ctx = NSGraphicsContext.current {
                ctx.saveGraphicsState()
                NSBezierPath(ovalIn: glowRect).addClip()
                let g = NSGradient(colors: [
                    (active ? Matcha.green : NSColor.controlAccentColor).withAlphaComponent(0.16),
                    (active ? Matcha.green : NSColor.controlAccentColor).withAlphaComponent(0)
                ])
                g?.draw(in: glowRect, angle: -90)
                ctx.restoreGraphicsState()
            }
        }

        let borderColor: NSColor
        if active {
            borderColor = Matcha.green.withAlphaComponent(hovering ? 0.9 : 0.65)
        } else {
            borderColor = hovering ? NSColor.tertiaryLabelColor : NSColor.separatorColor
        }
        borderColor.setStroke()
        path.lineWidth = max(1, scale)
        path.stroke()

        if active {
            let lineWidth: CGFloat = 3.5 * scale
            let radius = circle.width / 2 - lineWidth / 2 - 1.5 * scale
            let arc = NSBezierPath()
            let start: CGFloat = 90
            let end = start - 360 * max(0.02, min(1, progress))
            arc.appendArc(
                withCenter: NSPoint(x: bounds.midX, y: bounds.midY),
                radius: radius,
                startAngle: start,
                endAngle: end,
                clockwise: true
            )
            arc.lineWidth = lineWidth
            arc.lineCapStyle = .round
            Matcha.green.setStroke()
            arc.stroke()
        }

        if active, timed {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 14 * scale, weight: .semibold),
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
        } else {
        if !active {
            let cupConfig = NSImage.SymbolConfiguration(pointSize: 24 * scale, weight: .regular)
            if let cup = NSImage(systemSymbolName: "cup.and.saucer", accessibilityDescription: nil)?
                .withSymbolConfiguration(cupConfig) {
                tinted(cup, hovering ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor).draw(in: NSRect(
                    x: bounds.midX - cup.size.width / 2,
                    y: bounds.midY - cup.size.height / 2,
                    width: cup.size.width,
                    height: cup.size.height
                ))
            }
            return
        }
            let names = active
                ? ["cup.and.saucer.fill", "cup.and.saucer", "mug.fill", "mug"]
                : ["cup.and.saucer", "mug"]
            guard let base = symbolImage(names),
                  let sized = base.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 24 * scale, weight: .medium))
            else { return }
            let color = active ? Matcha.green : NSColor.secondaryLabelColor
            let image = tinted(sized, color)
            let size = image.size
            image.draw(in: NSRect(
                x: bounds.midX - size.width / 2,
                y: bounds.midY - size.height / 2,
                width: size.width,
                height: size.height
            ))
        }
    }

    func apply(state: MatchaState) {
        active = state.active
        if state.active, let end = state.endDate, let total = state.duration, total > 0 {
            timed = true
            text = Fmt.clock(end.timeIntervalSinceNow)
            progress = CGFloat(max(0, min(1, end.timeIntervalSinceNow / total)))
        } else {
            timed = false
            text = ""
            progress = state.active ? 1 : 0
        }
        needsDisplay = true
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?()
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.option), active {
            onStop?()
            return
        }
        if event.clickCount == 2, active {
            onQuickAdd?(1800)
            return
        }
        // Let the panel handle dragging when movable
        super.mouseDown(with: event)
        dragOffset = event.locationInWindow
        movedDuringDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let offset = dragOffset else { return }
        movedDuringDrag = true
        let mouse = NSEvent.mouseLocation
        onMoved?(NSPoint(x: mouse.x - offset.x, y: mouse.y - offset.y))
    }

    override func mouseUp(with event: NSEvent) {
        if movedDuringDrag {
            onDragEnded?()
        } else {
            onClick?()
        }
        dragOffset = nil
    }
}
