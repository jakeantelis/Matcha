import AppKit

final class CommandPaletteWindowController: NSWindowController {
    private var searchField: NSTextField!
    private var resultLabel: NSTextField!

    convenience init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 160),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .windowBackgroundColor
        panel.titlebarAppearsTransparent = true
        panel.title = ""
        panel.center()

        self.init(window: panel)
        setupUI(in: panel)
    }

    private func setupUI(in panel: NSPanel) {
        let contentView = panel.contentView!

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])

        let titleLabel = NSTextField(labelWithString: "Matcha Command Palette")
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        stack.addArrangedSubview(titleLabel)

        searchField = NSTextField()
        searchField.placeholderString = "Type duration (2h, 90m), template name, or 'off'..."
        searchField.font = NSFont.systemFont(ofSize: 14)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.widthAnchor.constraint(equalToConstant: 400).isActive = true
        searchField.target = self
        searchField.action = #selector(submitted(_:))
        stack.addArrangedSubview(searchField)

        resultLabel = NSTextField(labelWithString: "Press Return to run · Esc to close")
        resultLabel.font = NSFont.systemFont(ofSize: 11)
        resultLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(resultLabel)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(sender)
        if let searchField {
            window?.makeFirstResponder(searchField)
        }
    }

    @objc private func submitted(_ sender: NSTextField) {
        let text = sender.stringValue.trimmingCharacters(in: .whitespaces)
        let lower = text.lowercased()

        if lower == "off" || lower == "stop" {
            NotificationCenter.default.post(name: Notification.Name("MatchaPaletteStop"), object: nil)
            close()
            return
        }

        if lower == "status" {
            NotificationCenter.default.post(name: Notification.Name("MatchaPaletteStatus"), object: nil)
            close()
            return
        }

        if let template = TemplateStore.all.first(where: { $0.name.lowercased() == lower }) {
            NotificationCenter.default.post(name: Notification.Name("MatchaPaletteStartTemplate"), object: template.name)
            close()
            return
        }

        if let duration = Fmt.parseDuration(text), duration > 0 {
            NotificationCenter.default.post(name: Notification.Name("MatchaPaletteStartDuration"), object: duration)
            close()
            return
        }

        if text.isEmpty {
            NotificationCenter.default.post(name: Notification.Name("MatchaPaletteStartEndless"), object: nil)
            close()
            return
        }

        resultLabel.stringValue = "Unknown command or duration. Try '2h', 'off', or a template name."
        NSSound.beep()
    }

    override func cancelOperation(_ sender: Any?) {
        close()
    }
}
