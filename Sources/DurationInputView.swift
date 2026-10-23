import AppKit

final class DurationInputView: NSView, NSTextFieldDelegate {
    var onSubmit: ((String) -> Void)?

    private let field = NSTextField()
    private let clockIcon = NSImageView()
    private let hintIcon = NSImageView()
    private var focused = false
    private var invalid = false

    private static let placeholder = "Duration \u{2014} 90m, 2h, 1d"
    private static let invalidPlaceholder = "Try 90m, 2h, or 1:30"

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    func clear() {
        field.stringValue = ""
        setInvalid(false)
    }

    func showError() {
        setInvalid(true)
    }

    private func setInvalid(_ value: Bool) {
        invalid = value
        field.placeholderString = value ? Self.invalidPlaceholder : Self.placeholder
        clockIcon.contentTintColor = value ? .systemRed : .secondaryLabelColor
        needsDisplay = true
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
        field.placeholderString = Self.placeholder
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

        if invalid {
            NSColor.systemRed.withAlphaComponent(0.12).setFill()
        } else if focused {
            Matcha.green.withAlphaComponent(0.14).setFill()
        } else {
            NSColor.quaternaryLabelColor.setFill()
        }
        path.fill()

        let strokeColor = invalid
            ? NSColor.systemRed
            : (focused ? Matcha.green : NSColor.separatorColor)
        strokeColor.setStroke()
        path.lineWidth = (focused || invalid) ? 1.5 : 1
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

    func controlTextDidChange(_ obj: Notification) {
        if invalid { setInvalid(false) }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        focused = false
        needsDisplay = true
    }

    @objc private func submit() {
        onSubmit?(field.stringValue)
    }
}
