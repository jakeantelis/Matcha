import AppKit

private let brightGreen = NSColor(calibratedRed: 0.30, green: 0.90, blue: 0.45, alpha: 1)

final class PanelView: NSView {
    var onToggle: (() -> Void)?
    var onPreset: ((TimeInterval?) -> Void)?
    var onCustomMinutes: ((Int) -> Void)?
    var onMenu: ((NSView) -> Void)?

    private let ring = RingButton()
    private let cupIcon = NSImageView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "Matcha")
    private let gear = NSButton()
    private let durationInput = DurationInputView()
    private let activityDot = NSImageView()
    private let activityLabel = NSTextField(labelWithString: "")
    private let cursorLabel = NSTextField(labelWithString: "\u{2588}")
    private let activityRow = NSStackView()
    private var presetChips: [PillButton] = []
    private let tint = TintView()
    private var activityPulseTimer: Timer?

    private let panelWidth: CGFloat = 320
    private let pad: CGFloat = 20

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    func apply(state: MatchaState) {
        let busy = state.triggerBusy || state.agentRunning
        let activeBusy = state.active && busy
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

        activityDot.contentTintColor = activeBusy ? brightGreen : .tertiaryLabelColor
        let activityText: String
        if state.triggerBusy {
            activityText = "build or export activity"
        } else if !state.agentNames.isEmpty {
            activityText = state.agentNames.count == 1
                ? "\(state.agentNames[0]) is running"
                : "\(state.agentNames.joined(separator: " · ")) are running"
        } else if state.agentRunning {
            activityText = "an AI coding agent is running"
        } else {
            activityText = "no build or agent activity"
        }
        let activityColor = activeBusy ? brightGreen : NSColor.secondaryLabelColor
        var activityAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Menlo-Regular", size: 11) ?? NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: activityColor,
            .kern: 0.5,
        ]
        if activeBusy {
            let shadow = NSShadow()
            shadow.shadowColor = brightGreen.withAlphaComponent(0.9)
            shadow.shadowBlurRadius = 5
            shadow.shadowOffset = .zero
            activityAttrs[.shadow] = shadow
        }
        activityLabel.attributedStringValue = NSAttributedString(string: activityText, attributes: activityAttrs)
        activityRow.layer?.backgroundColor = activeBusy
            ? NSColor(calibratedRed: 0.05, green: 0.09, blue: 0.07, alpha: 0.92).cgColor
            : NSColor.quaternaryLabelColor.withAlphaComponent(0.5).cgColor
        cursorLabel.textColor = brightGreen

        if activeBusy {
            startActivityPulse()
        } else {
            stopActivityPulse()
        }

        statusLabel.stringValue = state.active ? "Steeping · display unlocked" : "Sleep allowed"
        if state.active {
            detailLabel.stringValue = state.endDate != nil ? Fmt.remainingText(state) : "Until you stop"
        } else {
            detailLabel.stringValue = "Your Mac can sleep normally"
        }
        cupIcon.image = matchaMark(size: 18, active: state.active)
    }

    @objc private func gearClicked() { onMenu?(gear) }

    private func startActivityPulse() {
        guard activityPulseTimer == nil, animationsEnabled() else { return }
        cursorLabel.alphaValue = 1
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard animationsEnabled() else { self.stopActivityPulse(); return }
            self.cursorLabel.alphaValue = self.cursorLabel.alphaValue > 0.5 ? 0 : 1
        }
        RunLoop.main.add(timer, forMode: .common)
        activityPulseTimer = timer
    }

    private func stopActivityPulse() {
        activityPulseTimer?.invalidate()
        activityPulseTimer = nil
        cursorLabel.alphaValue = 0
        activityLabel.alphaValue = 1
    }

    deinit {
        activityPulseTimer?.invalidate()
    }

    func setTintEnabled(_ enabled: Bool) {
        tint.isHidden = !enabled
    }

    override func cancelOperation(_ sender: Any?) {
        window?.performClose(sender)
    }

    @objc private func chipClicked(_ sender: NSButton) {
        if sender.tag == 9999 {
            durationInput.isHidden = false
            durationInput.focus()
            return
        }
        onPreset?(sender.tag == 0 ? nil : TimeInterval(sender.tag))
    }

    private func handleDuration(_ text: String) {
        let seconds = Fmt.parseDuration(text)
        if let seconds, seconds > 0 {
            durationInput.clear()
            durationInput.isHidden = true
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

        cupIcon.image = matchaMark(size: 18)
        cupIcon.translatesAutoresizingMaskIntoConstraints = false
        cupIcon.widthAnchor.constraint(equalToConstant: 18).isActive = true
        cupIcon.heightAnchor.constraint(equalToConstant: 18).isActive = true

        titleLabel.font = NSFont.systemFont(ofSize: 13.5, weight: .bold)

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
        ring.widthAnchor.constraint(equalToConstant: 124).isActive = true
        ring.heightAnchor.constraint(equalToConstant: 124).isActive = true

        statusLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        statusLabel.alignment = .center
        statusLabel.widthAnchor.constraint(equalToConstant: inner).isActive = true

        detailLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.alignment = .center
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.widthAnchor.constraint(equalToConstant: inner).isActive = true

        let chipSpecs: [(String, Int)] = [
            ("2h", 7200), ("4h", 14400), ("\u{221E}", 0), ("Custom", 9999),
        ]
        presetChips = chipSpecs.map { chip($0.0, tag: $0.1) }
        let chips = NSStackView(views: presetChips)
        chips.orientation = .horizontal
        chips.distribution = .fillEqually
        chips.spacing = 8
        chips.widthAnchor.constraint(equalToConstant: inner).isActive = true

        activityDot.image = symbolImage(["circle.fill"])?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 6, weight: .regular))
        activityDot.contentTintColor = .tertiaryLabelColor
        activityDot.translatesAutoresizingMaskIntoConstraints = false
        activityDot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        activityDot.heightAnchor.constraint(equalToConstant: 8).isActive = true

        activityLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        activityLabel.textColor = .tertiaryLabelColor
        activityLabel.lineBreakMode = .byTruncatingTail

        cursorLabel.font = NSFont(name: "Menlo-Regular", size: 11) ?? NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        cursorLabel.textColor = brightGreen
        cursorLabel.alphaValue = 0

        activityRow.orientation = .horizontal
        activityRow.alignment = .centerY
        activityRow.spacing = 5
        activityRow.edgeInsets = NSEdgeInsets(top: 4, left: 9, bottom: 4, right: 10)
        activityRow.addArrangedSubview(activityDot)
        activityRow.addArrangedSubview(activityLabel)
        activityRow.addArrangedSubview(cursorLabel)
        activityRow.wantsLayer = true
        activityRow.layer?.cornerRadius = 10
        activityRow.layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.5).cgColor

        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.6).cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.widthAnchor.constraint(equalToConstant: inner).isActive = true
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true

        durationInput.onSubmit = { [weak self] text in
            self?.handleDuration(text)
        }
        durationInput.heightAnchor.constraint(equalToConstant: 30).isActive = true
        durationInput.widthAnchor.constraint(equalToConstant: inner).isActive = true
        durationInput.isHidden = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        [header, ring, statusLabel, detailLabel, chips, durationInput, separator, activityRow].forEach { stack.addArrangedSubview($0) }
        stack.setCustomSpacing(16, after: header)
        stack.setCustomSpacing(16, after: ring)
        stack.setCustomSpacing(5, after: statusLabel)
        stack.setCustomSpacing(16, after: detailLabel)
        stack.setCustomSpacing(28, after: chips)
        stack.setCustomSpacing(14, after: durationInput)
        stack.setCustomSpacing(12, after: separator)

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
        button.textFont = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        switch tag {
        case 0: button.toolTip = "Keep awake until stopped"
        case 7200: button.toolTip = "Keep awake for 2 hours"
        case 14400: button.toolTip = "Keep awake for 4 hours"
        case 9999: button.toolTip = "Type a custom duration"
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
        gradient.opacity = 1
        layer?.addSublayer(gradient)
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
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
        updateColors(animated: true)
    }

    private func palette() -> [CGColor] {
        if active {
            let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let top = NSColor(calibratedRed: 0.22, green: 0.56, blue: 0.34, alpha: dark ? 0.36 : 0.28)
            let bottom = NSColor(calibratedRed: 0.19, green: 0.53, blue: 0.44, alpha: dark ? 0.14 : 0.10)
            return [top.cgColor, bottom.cgColor]
        } else {
            let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let top = NSColor(calibratedRed: 0.52, green: 0.62, blue: 0.74, alpha: dark ? 0.14 : 0.10)
            let bottom = NSColor(calibratedRed: 0.52, green: 0.62, blue: 0.74, alpha: dark ? 0.03 : 0.02)
            return [top.cgColor, bottom.cgColor]
        }
    }

    private func updateColors(animated: Bool = false) {
        let colors = palette()
        if animated {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.3)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
            gradient.colors = colors
            CATransaction.commit()
        } else {
            CATransaction.setDisableActions(true)
            gradient.colors = colors
            CATransaction.setDisableActions(false)
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }
}
