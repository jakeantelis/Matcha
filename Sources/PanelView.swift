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
    private let activityDot = NSImageView()
    private let activityLabel = NSTextField(labelWithString: "")
    private var presetChips: [PillButton] = []
    private let tint = TintView()

    private let panelWidth: CGFloat = 280
    private let pad: CGFloat = 16

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    func apply(state: MatchaState) {
        tint.setActive(state.active)
        ring.active = state.active
        ring.accent = Matcha.green

        var timed = false
        if state.active, let end = state.endDate, let total = state.duration, total > 0 {
            timed = true
            ring.progress = CGFloat(max(0, min(1, end.timeIntervalSinceNow / total)))
            ring.timeText = Fmt.clock(end.timeIntervalSinceNow)
        } else {
            ring.progress = state.active ? 1 : 0
            ring.timeText = nil
        }
        ring.pulsing = state.active && !timed

        let activeTag: Int = {
            guard state.active else { return -1 }
            guard timed, let total = state.duration else { return 0 }
            return Int(total.rounded())
        }()
        for chip in presetChips {
            let selected = chip.tag == activeTag
            chip.fillColor = selected ? Matcha.green : .quaternaryLabelColor
            chip.hoverColor = selected ? Matcha.green.withAlphaComponent(0.85) : .tertiaryLabelColor
            chip.textColor = selected ? .white : .labelColor
        }

        activityDot.contentTintColor = state.triggerBusy ? Matcha.green : .tertiaryLabelColor
        activityLabel.stringValue = state.triggerBusy ? "Build/activity detected" : "No build activity"
        activityLabel.textColor = state.triggerBusy ? .secondaryLabelColor : .tertiaryLabelColor

        statusLabel.stringValue = state.active ? "Awake — display unlocked" : "Sleep allowed"
        detailLabel.stringValue = state.active ? (state.endDate != nil ? Fmt.remainingText(state) : "Until you stop") : "Your Mac can sleep normally"
        cupIcon.contentTintColor = state.active ? Matcha.green : .secondaryLabelColor
    }

    @objc private func gearClicked() { onMenu?(gear) }

    func setTintEnabled(_ enabled: Bool) {
        tint.isHidden = !enabled
    }

    override func cancelOperation(_ sender: Any?) {
        window?.performClose(sender)
    }

    @objc private func chipClicked(_ sender: NSButton) {
        onPreset?(sender.tag == 0 ? nil : TimeInterval(sender.tag))
    }

    private func handleDuration(_ text: String) {
        let seconds = Fmt.parseDuration(text)
        if let seconds, seconds > 0 {
            durationInput.clear()
            onCustomMinutes?(Int(seconds))
        } else {
            durationInput.showError()
            NSSound.beep()
        }
    }

    private func build() {
        let inner = panelWidth - pad * 2

        tint.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tint)
        NSLayoutConstraint.activate([
            tint.topAnchor.constraint(equalTo: topAnchor),
            tint.leadingAnchor.constraint(equalTo: leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: trailingAnchor),
            tint.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

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
        ring.toolTip = "Start or stop Matcha"
        ring.setAccessibilityRole(.button)
        ring.setAccessibilityLabel("Start or stop Matcha")
        ring.translatesAutoresizingMaskIntoConstraints = false
        ring.widthAnchor.constraint(equalToConstant: 128).isActive = true
        ring.heightAnchor.constraint(equalToConstant: 128).isActive = true

        statusLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        statusLabel.alignment = .center
        statusLabel.widthAnchor.constraint(equalToConstant: inner).isActive = true

        detailLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .regular)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.alignment = .center
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.widthAnchor.constraint(equalToConstant: inner).isActive = true

        let chipSpecs: [(String, Int)] = [
            ("2h", 7200), ("4h", 14400), ("8h", 28800), ("\u{221E}", 0),
        ]
        presetChips = chipSpecs.map { chip($0.0, tag: $0.1) }
        let chips = NSStackView(views: presetChips)
        chips.orientation = .horizontal
        chips.distribution = .fillEqually
        chips.spacing = 6
        chips.widthAnchor.constraint(equalToConstant: inner).isActive = true

        activityDot.image = symbolImage(["circle.fill"])?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 6, weight: .regular))
        activityDot.contentTintColor = .tertiaryLabelColor
        activityDot.translatesAutoresizingMaskIntoConstraints = false
        activityDot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        activityDot.heightAnchor.constraint(equalToConstant: 8).isActive = true

        activityLabel.font = NSFont.systemFont(ofSize: 10.5)
        activityLabel.textColor = .tertiaryLabelColor

        let activityRow = NSStackView(views: [activityDot, activityLabel])
        activityRow.orientation = .horizontal
        activityRow.alignment = .centerY
        activityRow.spacing = 5

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
        [header, ring, statusLabel, detailLabel, activityRow, chips, durationInput].forEach { stack.addArrangedSubview($0) }
        stack.setCustomSpacing(14, after: header)
        stack.setCustomSpacing(12, after: ring)
        stack.setCustomSpacing(3, after: statusLabel)
        stack.setCustomSpacing(6, after: detailLabel)
        stack.setCustomSpacing(12, after: activityRow)
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
        switch tag {
        case 0: button.toolTip = "Keep awake until stopped"
        case 7200: button.toolTip = "Keep awake for 2 hours"
        case 14400: button.toolTip = "Keep awake for 4 hours"
        case 28800: button.toolTip = "Keep awake for 8 hours"
        default: break
        }
        return button
    }
}

final class TintView: NSView {
    private let gradient = CAGradientLayer()
    private var active = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        build()
    }

    private func build() {
        wantsLayer = true
        gradient.frame = bounds
        gradient.opacity = 0
        layer?.addSublayer(gradient)
        updateColors()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = NSRect(origin: .zero, size: newSize)
        CATransaction.commit()
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func setActive(_ value: Bool) {
        guard value != active else { return }
        active = value
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.28)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        gradient.opacity = value ? 1 : 0
        CATransaction.commit()
    }

    private func updateColors() {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        gradient.colors = [
            Matcha.green.withAlphaComponent(dark ? 0.20 : 0.16).cgColor,
            Matcha.green.withAlphaComponent(dark ? 0.06 : 0.04).cgColor,
        ]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }
}
