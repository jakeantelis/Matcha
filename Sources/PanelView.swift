import AppKit

final class PanelView: NSView {
    var onToggle: (() -> Void)?
    var onPreset: ((TimeInterval?) -> Void)?
    var onCustomMinutes: ((Int) -> Void)?
    var onMenu: ((NSView) -> Void)?

    private let ring = RingButton()
    private let cupIcon = NSImageView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let gear = NSButton()
    private let durationInput = DurationInputView()

    private let panelWidth: CGFloat = 280
    private let pad: CGFloat = 16

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    func apply(state: CaffeinateState) {
        ring.active = state.active
        ring.accent = state.active ? Matcha.green : .controlAccentColor
        if state.active, let end = state.endDate, let total = state.duration, total > 0 {
            ring.progress = CGFloat(max(0, min(1, end.timeIntervalSinceNow / total)))
        } else {
            ring.progress = state.active ? 1 : 0
        }

        statusLabel.stringValue = state.active ? "Keeping awake" : "Sleep is allowed"
        if state.active {
            detailLabel.stringValue = state.endDate != nil ? Fmt.remainingText(state) : "Until you stop"
        } else {
            detailLabel.stringValue = "Click the cup to start"
        }
        cupIcon.contentTintColor = state.active ? Matcha.green : .secondaryLabelColor
    }

    @objc private func gearClicked() { onMenu?(gear) }

    @objc private func chipClicked(_ sender: NSButton) {
        onPreset?(sender.tag == 0 ? nil : TimeInterval(sender.tag))
    }

    private func handleDuration(_ text: String) {
        let seconds = Fmt.parseDuration(text)
        if let seconds, seconds > 0 {
            durationInput.clear()
            onCustomMinutes?(Int(seconds))
        } else {
            NSSound.beep()
        }
    }

    private func build() {
        let inner = panelWidth - pad * 2

        cupIcon.image = symbolImage(["cup.and.saucer", "mug"])?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold))
        cupIcon.contentTintColor = .secondaryLabelColor
        cupIcon.translatesAutoresizingMaskIntoConstraints = false
        cupIcon.widthAnchor.constraint(equalToConstant: 16).isActive = true
        cupIcon.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let titleLabel = NSTextField(labelWithString: "Matcha")
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)

        gear.image = symbolImage(["gearshape", "gear"])
        gear.isBordered = false
        gear.imagePosition = .imageOnly
        gear.contentTintColor = .tertiaryLabelColor
        gear.target = self
        gear.action = #selector(gearClicked)
        gear.toolTip = "Settings"
        gear.translatesAutoresizingMaskIntoConstraints = false
        gear.widthAnchor.constraint(equalToConstant: 20).isActive = true
        gear.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let spacer = NSView()
        spacer.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)

        let header = NSStackView(views: [cupIcon, titleLabel, spacer, gear])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 7
        header.widthAnchor.constraint(equalToConstant: inner).isActive = true

        ring.onClick = { [weak self] in self?.onToggle?() }
        ring.translatesAutoresizingMaskIntoConstraints = false
        ring.widthAnchor.constraint(equalToConstant: 128).isActive = true
        ring.heightAnchor.constraint(equalToConstant: 128).isActive = true

        statusLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        statusLabel.alignment = .center
        statusLabel.widthAnchor.constraint(equalToConstant: inner).isActive = true

        detailLabel.font = NSFont.systemFont(ofSize: 11.5)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.alignment = .center
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.widthAnchor.constraint(equalToConstant: inner).isActive = true

        let chipSpecs: [(String, Int)] = [
            ("2h", 7200), ("4h", 14400), ("8h", 28800), ("\u{221E}", 0),
        ]
        let chips = NSStackView(views: chipSpecs.map { chip($0.0, tag: $0.1) })
        chips.orientation = .horizontal
        chips.distribution = .fillEqually
        chips.spacing = 6
        chips.widthAnchor.constraint(equalToConstant: inner).isActive = true

        durationInput.onSubmit = { [weak self] text in
            self?.handleDuration(text)
        }
        durationInput.heightAnchor.constraint(equalToConstant: 30).isActive = true
        durationInput.widthAnchor.constraint(equalToConstant: inner).isActive = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        [header, ring, statusLabel, detailLabel, chips, durationInput].forEach { stack.addArrangedSubview($0) }
        stack.setCustomSpacing(14, after: header)
        stack.setCustomSpacing(12, after: ring)
        stack.setCustomSpacing(3, after: statusLabel)
        stack.setCustomSpacing(14, after: detailLabel)
        stack.setCustomSpacing(8, after: chips)

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: pad),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: pad),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -pad),
        ])

        layoutSubtreeIfNeeded()
        let height = stack.fittingSize.height + pad * 2
        frame = NSRect(x: 0, y: 0, width: panelWidth, height: height)
        layoutSubtreeIfNeeded()
    }

    private func chip(_ title: String, tag: Int) -> PillButton {
        let button = PillButton(title: title, target: self, action: #selector(chipClicked(_:)))
        button.tag = tag
        button.fillColor = .quaternaryLabelColor
        button.hoverColor = .tertiaryLabelColor
        button.textColor = .labelColor
        button.textFont = NSFont.systemFont(ofSize: 11, weight: .medium)
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        if tag == 0 { button.toolTip = "Keep awake until stopped" }
        return button
    }
}
