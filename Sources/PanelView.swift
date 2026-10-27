import AppKit

private let brightGreen = NSColor(calibratedRed: 0.30, green: 0.90, blue: 0.45, alpha: 1)

final class PanelView: NSView {
    var onToggle: (() -> Void)?
    var onPreset: ((TimeInterval?) -> Void)?
    var onCustomMinutes: ((Int) -> Void)?
    var onMenu: ((NSView) -> Void)?
    var onResize: (() -> Void)?

    private let ring = RingButton()
    private let cupIcon = NSImageView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "Matcha")
    private let gear = NSButton()
    private let durationInput = DurationInputView()
    private let activityLabel = NSTextField(labelWithString: "")
    private let activityRow = NSStackView()
    private let separator = NSView()
    private var presetChips: [PillButton] = []
    private let tint = TintView()
    private var activityPulseTimer: Timer?
    private var marqueeTimer: Timer?
    private var marqueeBase = ""
    private var marqueeOffset = 0
    private var marqueeCap = 0
    private var marqueeColor = NSColor.secondaryLabelColor
    private var marqueeGlow = false
    private var footerText = ""
    private var footerActive = false
    private var cursorOn = false
    private let stack = NSStackView()

    private let panelWidth: CGFloat = 320
    private let pad: CGFloat = 20

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    func apply(state: MatchaState) {
        let busy = state.triggerBusy || state.agentRunning
        let activeBusy = state.active && busy
        tint.setActive(state.active)
        ring.active = state.active
        ring.accent = Matcha.green
        ring.setAccessibilityLabel(state.active ? "Matcha active, tap to stop" : "Matcha idle, tap to start")

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

        footerText = activityText
        footerActive = activeBusy

        let cap = 34
        if activityText.count > cap, animationsEnabled(), state.agentNames.count > 2 {
            marqueeBase = activityText
            marqueeCap = cap
            marqueeColor = activityColor
            marqueeGlow = activeBusy
            marqueeOffset = marqueeBase.count - 1
            stopActivityPulse()
            renderMarqueeTick()
            startMarquee()
        } else {
            stopMarquee()
            if activeBusy { startActivityPulse() } else { stopActivityPulse() }
            renderFooter()
        }

        activityRow.layer?.backgroundColor = activeBusy
            ? NSColor(calibratedRed: 0.05, green: 0.09, blue: 0.07, alpha: 0.92).cgColor
            : NSColor.quaternaryLabelColor.withAlphaComponent(0.5).cgColor

        statusLabel.stringValue = state.active ? "Awake · display unlocked" : "Sleep allowed"
        if state.active {
            detailLabel.stringValue = state.endDate != nil ? Fmt.remainingText(state) : "Until you stop"
        } else {
            detailLabel.stringValue = " "
        }
        detailLabel.isHidden = false
        cupIcon.image = matchaMark(size: 18, active: state.active)
        syncFrame()
    }

    private func syncFrame() {
        layoutSubtreeIfNeeded()
        let height = stack.fittingSize.height + pad * 2
        if abs(height - frame.height) > 0.5 {
            frame = NSRect(x: 0, y: 0, width: panelWidth, height: height)
            onResize?()
        }
    }

    @objc private func gearClicked() { onMenu?(gear) }

    private func activityAttributed(_ text: String, color: NSColor, glow: Bool, centered: Bool) -> NSAttributedString {
        var attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Menlo-Regular", size: 11) ?? NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: color,
        ]
        if centered {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            attrs[.paragraphStyle] = paragraph
        }
        if glow {
            let shadow = NSShadow()
            shadow.shadowColor = brightGreen.withAlphaComponent(0.9)
            shadow.shadowBlurRadius = 2.5
            shadow.shadowOffset = .zero
            attrs[.shadow] = shadow
        }
        return NSAttributedString(string: text, attributes: attrs)
    }

    private func startMarquee() {
        guard marqueeTimer == nil else { return }
        let timer = Timer(timeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.renderMarqueeTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        marqueeTimer = timer
    }

    private func stopMarquee() {
        marqueeTimer?.invalidate()
        marqueeTimer = nil
    }

    private func renderMarqueeTick() {
        guard marqueeBase.count > 0, marqueeCap > 0 else { return }
        marqueeOffset = (marqueeOffset + 1) % marqueeBase.count
        let doubled = marqueeBase + "   " + marqueeBase
        let start = doubled.index(doubled.startIndex, offsetBy: marqueeOffset)
        let end = doubled.index(start, offsetBy: marqueeCap)
        var window = String(doubled[start..<end])
        while window.count < marqueeCap { window += " " }
        activityLabel.attributedStringValue = activityAttributed(window, color: marqueeColor, glow: marqueeGlow, centered: false)
    }

    private func renderFooter() {
        var text = footerText
        if footerActive {
            text += cursorOn ? "\u{258B}" : " "
        }
        activityLabel.attributedStringValue = activityAttributed(
            text,
            color: footerActive ? brightGreen : NSColor.secondaryLabelColor,
            glow: footerActive,
            centered: true
        )
    }

    private func startActivityPulse() {
        guard activityPulseTimer == nil, animationsEnabled() else { return }
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard animationsEnabled() else { self.stopActivityPulse(); return }
            self.cursorOn.toggle()
            self.renderFooter()
        }
        RunLoop.main.add(timer, forMode: .common)
        activityPulseTimer = timer
    }

    private func stopActivityPulse() {
        activityPulseTimer?.invalidate()
        activityPulseTimer = nil
        cursorOn = false
        renderFooter()
    }

    deinit {
        activityPulseTimer?.invalidate()
        marqueeTimer?.invalidate()
    }

    func setTintEnabled(_ enabled: Bool) {
        tint.isHidden = !enabled
    }

    func showOnboardingHintIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Pref.firstRunHintShown) else { return }
        UserDefaults.standard.set(true, forKey: Pref.firstRunHintShown)
        detailLabel.isHidden = false
        detailLabel.alphaValue = 1
        detailLabel.stringValue = "Tap the ring to start"
        detailLabel.textColor = .tertiaryLabelColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup({ _ in
                self.detailLabel.animator().alphaValue = 0
            }, completionHandler: {
                self.detailLabel.stringValue = " "
                self.detailLabel.alphaValue = 1
                self.detailLabel.textColor = .secondaryLabelColor
            })
        }
    }

    override func cancelOperation(_ sender: Any?) {
        window?.performClose(sender)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:
            onPreset?(nil)
        case 49:
            onToggle?()
        default:
            super.keyDown(with: event)
        }
    }

    @objc private func chipClicked(_ sender: NSButton) {
        if sender.tag == 9999 {
            durationInput.isHidden = false
            durationInput.focus()
            return
        }
        durationInput.clear()
        durationInput.isHidden = true
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
        gear.setAccessibilityRole(.button)
        gear.setAccessibilityLabel("Settings")
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
        statusLabel.setAccessibilityRole(.staticText)
        statusLabel.setAccessibilityLabel("Status")

        detailLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.alignment = .center
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.widthAnchor.constraint(equalToConstant: inner).isActive = true
        detailLabel.setAccessibilityRole(.staticText)
        detailLabel.setAccessibilityLabel("Time remaining")

        let chipSpecs: [(String, Int)] = [
            ("2h", 7200), ("4h", 14400), ("\u{221E}", 0), ("Custom", 9999),
        ]
        presetChips = chipSpecs.map { chip($0.0, tag: $0.1) }
        presetChips[0].setAccessibilityLabel("Start 2 hour session")
        presetChips[1].setAccessibilityLabel("Start 4 hour session")
        presetChips[2].setAccessibilityLabel("Start until stopped")
        presetChips[3].setAccessibilityLabel("Custom duration")
        let chips = NSStackView(views: presetChips)
        chips.orientation = .horizontal
        chips.distribution = .fillEqually
        chips.spacing = 8
        chips.widthAnchor.constraint(equalToConstant: inner).isActive = true

        activityLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        activityLabel.textColor = .tertiaryLabelColor
        activityLabel.lineBreakMode = .byTruncatingTail
        activityLabel.usesSingleLineMode = true

        activityRow.orientation = .horizontal
        activityRow.alignment = .centerY
        activityRow.spacing = 5
        activityRow.edgeInsets = NSEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        activityRow.addArrangedSubview(activityLabel)
        activityRow.wantsLayer = true
        activityRow.layer?.cornerRadius = 10
        activityRow.layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.5).cgColor

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
