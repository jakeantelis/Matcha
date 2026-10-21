import AppKit

final class PillButton: NSButton {
    var fillColor: NSColor = .controlAccentColor { didSet { needsDisplay = true } }
    var hoverColor: NSColor? { didSet { needsDisplay = true } }
    var textColor: NSColor = .white { didSet { needsDisplay = true } }
    var textFont: NSFont = .systemFont(ofSize: 12, weight: .medium) { didSet { needsDisplay = true } }

    private var hovering = false
    private var tracking: NSTrackingArea?

    init(title: String, target: AnyObject?, action: Selector?) {
        super.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        self.isBordered = false
        self.focusRingType = .none
    }

    required init?(coder: NSCoder) { fatalError() }

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

    override func mouseEntered(with event: NSEvent) { hovering = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovering = false; needsDisplay = true }

    override func draw(_ dirtyRect: NSRect) {
        let radius = min(bounds.height, bounds.width) / 2
        (hovering ? (hoverColor ?? fillColor) : fillColor).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: textColor,
            .paragraphStyle: style,
        ]
        let text = NSAttributedString(string: title, attributes: attributes)
        let height = text.size().height
        text.draw(in: NSRect(x: 4, y: (bounds.height - height) / 2 - 0.5, width: bounds.width - 8, height: height))
    }
}
