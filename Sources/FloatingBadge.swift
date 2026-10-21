import AppKit

final class FloatingBadge: NSPanel {
    var onClick: (() -> Void)?
    var onRightClick: (() -> Void)?
    var onMoved: ((NSPoint) -> Void)?

    private let badgeView = BadgeView()
    private static let size: CGFloat = 96

    init() {
        let side = Self.size
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: side, height: side),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        becomesKeyOnlyIfNeeded = true

        badgeView.frame = NSRect(x: 0, y: 0, width: side, height: side)
        badgeView.autoresizingMask = [.width, .height]
        badgeView.onClick = { [weak self] in self?.onClick?() }
        badgeView.onRightClick = { [weak self] in self?.onRightClick?() }
        badgeView.onMoved = { [weak self] origin in self?.setFrameOrigin(origin) }
        badgeView.onDragEnded = { [weak self] in
            guard let self else { return }
            self.setFrameOrigin(NSPoint(x: self.frame.origin.x.rounded(), y: self.frame.origin.y.rounded()))
            self.onMoved?(self.frame.origin)
        }
        contentView = badgeView
    }

    var translucent: Bool = true {
        didSet { badgeView.translucent = translucent }
    }

    func update(state: CaffeinateState) {
        badgeView.apply(state: state)
    }
}

final class BadgeView: NSView {
    var onClick: (() -> Void)?
    var onRightClick: (() -> Void)?
    var onMoved: ((NSPoint) -> Void)?
    var onDragEnded: (() -> Void)?

    var translucent: Bool = true { didSet { needsDisplay = true } }

    private var active = false
    private var timed = false
    private var text = ""
    private var progress: CGFloat = 0
    private var dragOffset: NSPoint?
    private var movedDuringDrag = false

    override func draw(_ dirtyRect: NSRect) {
        let diameter = min(bounds.width, bounds.height)
        let base = NSRect(
            x: (bounds.width - diameter) / 2,
            y: (bounds.height - diameter) / 2,
            width: diameter,
            height: diameter
        )
        let circle = base.insetBy(dx: 2, dy: 2)

        let fillAlpha: CGFloat = translucent ? 0.55 : 0.97
        let path = NSBezierPath(ovalIn: circle)
        NSColor.controlBackgroundColor.withAlphaComponent(fillAlpha).setFill()
        path.fill()

        (active ? NSColor.controlAccentColor.withAlphaComponent(0.6) : NSColor.separatorColor).setStroke()
        path.lineWidth = 1
        path.stroke()

        if active {
            let lineWidth: CGFloat = 3.5
            let radius = circle.width / 2 - lineWidth / 2 - 1.5
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
            (timed ? Matcha.green : NSColor.controlAccentColor).setStroke()
            arc.stroke()
        }

        if active, timed {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold),
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
            let names = active
                ? ["cup.and.saucer.fill", "cup.and.saucer", "mug.fill", "mug"]
                : ["cup.and.saucer", "mug"]
            guard let base = symbolImage(names),
                  let sized = base.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 24, weight: .medium))
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

    func apply(state: CaffeinateState) {
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
