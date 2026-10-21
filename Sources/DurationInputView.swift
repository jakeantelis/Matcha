import AppKit

final class DurationInputView: NSView, NSTextFieldDelegate {
    var onSubmit: ((String) -> Void)?

    private let field = NSTextField()
    private let clockIcon = NSImageView()
    private let hintIcon = NSImageView()
    private var focused = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    func clear() {
        field.stringValue = ""
    }

    private func build() {
        translatesAutoresizingMaskIntoConstraints = false

        clockIcon.image = symbolImage(["clock"])?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 12, weight: .regular))
        clockIcon.contentTintColor = .secondaryLabelColor
        clockIcon.translatesAutoresizingMaskIntoConstraints = false

        field.isBordered = false
        field.isBezeled = false
        field.isEditable = true
        field.backgroundColor = .clear
        field.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        field.placeholderString = "How many hours?"
        field.lineBreakMode = .byTruncatingTail
        field.target = self
        field.action = #selector(submit)
        field.delegate = self
        field.translatesAutoresizingMaskIntoConstraints = false

        hintIcon.image = symbolImage(["return", "arrow.turn.down.left"])?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 9, weight: .regular))
        hintIcon.contentTintColor = .tertiaryLabelColor
        hintIcon.translatesAutoresizingMaskIntoConstraints = false

        addSubview(clockIcon)
        addSubview(field)
        addSubview(hintIcon)

        NSLayoutConstraint.activate([
            clockIcon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            clockIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            clockIcon.widthAnchor.constraint(equalToConstant: 14),
            clockIcon.heightAnchor.constraint(equalToConstant: 14),

            field.leadingAnchor.constraint(equalTo: clockIcon.trailingAnchor, constant: 6),
            field.centerYAnchor.constraint(equalTo: centerYAnchor),
            field.trailingAnchor.constraint(equalTo: hintIcon.leadingAnchor, constant: -8),

            hintIcon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            hintIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            hintIcon.widthAnchor.constraint(equalToConstant: 13),
            hintIcon.heightAnchor.constraint(equalToConstant: 13),
        ])
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let radius = rect.height / 2
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

        if focused {
            NSColor.controlAccentColor.withAlphaComponent(0.14).setFill()
        } else {
            NSColor.quaternaryLabelColor.setFill()
        }
        path.fill()

        (focused ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = focused ? 1.5 : 1
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(field)
        super.mouseDown(with: event)
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        focused = true
        needsDisplay = true
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        focused = false
        needsDisplay = true
    }

    @objc private func submit() {
        onSubmit?(field.stringValue)
    }
}
