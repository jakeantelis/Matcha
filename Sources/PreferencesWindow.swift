import AppKit
import ServiceManagement

final class PreferencesWindowController: NSObject {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?
    private let todayLabel = NSTextField(labelWithString: "")
    private let totalLabel = NSTextField(labelWithString: "")

    func show() {
        if window == nil {
            window = makeWindow()
        }
        reloadStats()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow() -> NSWindow {
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 560))

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        func header(_ text: String) {
            let label = NSTextField(labelWithString: text)
            label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
            label.textColor = .secondaryLabelColor
            stack.addArrangedSubview(label)
            stack.setCustomSpacing(2, after: label)
        }

        func checkbox(_ title: String, _ key: String) {
            let button = NSButton(checkboxWithTitle: title, target: self, action: #selector(toggled(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(key)
            button.state = UserDefaults.standard.bool(forKey: key) ? .on : .off
            stack.addArrangedSubview(button)
        }

        header("Behavior")
        checkbox("Keep Display On & Unlocked", Pref.keepDisplayOn)
        checkbox("Auto-Keep Awake for Code", Pref.autoTriggers)
        if Battery.hasBattery {
            checkbox("Low Battery Guard", Pref.batteryGuard)
        }

        header("Menu Bar & Floater")
        checkbox("Show in Menu Bar", Pref.showMenuBarIcon)
        checkbox("Show Time in Menu Bar", Pref.menuBarCountdown)
        checkbox("Show Floating Indicator", Pref.showFloatingIndicator)
        checkbox("Translucent Indicator", Pref.translucentIndicator)
        checkbox("Animations", Pref.animations)

        header("Appearance")
        let appearance = NSPopUpButton(frame: .zero, pullsDown: false)
        appearance.addItems(withTitles: ["Match System", "Light", "Dark"])
        let currentAppearance = UserDefaults.standard.string(forKey: Pref.appearance) ?? "system"
        appearance.selectItem(at: ["system", "light", "dark"].firstIndex(of: currentAppearance) ?? 0)
        appearance.target = self
        appearance.action = #selector(appearanceChanged(_:))
        stack.addArrangedSubview(appearance)

        let size = NSPopUpButton(frame: .zero, pullsDown: false)
        size.addItems(withTitles: ["Small", "Medium", "Large"])
        let currentSize = UserDefaults.standard.string(forKey: Pref.badgeSize) ?? "medium"
        size.selectItem(at: ["small", "medium", "large"].firstIndex(of: currentSize) ?? 1)
        size.target = self
        size.action = #selector(sizeChanged(_:))
        stack.addArrangedSubview(size)

        if #available(macOS 13.0, *) {
            let login = NSButton(checkboxWithTitle: "Launch at Login", target: self, action: #selector(loginToggled(_:)))
            login.state = SMAppService.mainApp.status == .enabled ? .on : .off
            stack.addArrangedSubview(login)
        }

        header("Agents & Automation")
        checkbox("Show Tips", Pref.showTips)

        let watchLabel = NSTextField(labelWithString: "Keep awake while these apps run (comma separated):")
        watchLabel.font = NSFont.systemFont(ofSize: 11)
        watchLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(watchLabel)

        let watchField = NSTextField()
        watchField.placeholderString = "e.g. Logic Pro, Final Cut Pro, Blender"
        watchField.stringValue = (UserDefaults.standard.stringArray(forKey: Pref.watchApps) ?? []).joined(separator: ", ")
        watchField.target = self
        watchField.action = #selector(watchAppsChanged(_:))
        watchField.translatesAutoresizingMaskIntoConstraints = false
        watchField.widthAnchor.constraint(equalToConstant: 340).isActive = true
        stack.addArrangedSubview(watchField)

        header("Usage")
        todayLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        totalLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        stack.addArrangedSubview(todayLabel)
        stack.addArrangedSubview(totalLabel)

        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
        ])

        content.addSubview(stack)
        content.frame = NSRect(x: 0, y: 0, width: 380, height: stack.fittingSize.height + 40)
        stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20).isActive = true

        let window = NSWindow(
            contentRect: content.frame,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Matcha Settings"
        window.contentView = content
        window.isReleasedWhenClosed = false
        return window
    }

    private func reloadStats() {
        let defaults = UserDefaults.standard
        todayLabel.stringValue = "Today: \(format(defaults.double(forKey: Pref.awakeToday)))"
        totalLabel.stringValue = "All time: \(format(defaults.double(forKey: Pref.awakeTotal)))"
    }

    private func format(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    @objc private func toggled(_ sender: NSButton) {
        guard let key = sender.identifier?.rawValue else { return }
        UserDefaults.standard.set(sender.state == .on, forKey: key)
        NotificationCenter.default.post(name: .matchaPrefsChanged, object: nil)
    }

    @objc private func appearanceChanged(_ sender: NSPopUpButton) {
        let values = ["system", "light", "dark"]
        UserDefaults.standard.set(values[sender.indexOfSelectedItem], forKey: Pref.appearance)
        NotificationCenter.default.post(name: .matchaPrefsChanged, object: nil)
    }

    @objc private func sizeChanged(_ sender: NSPopUpButton) {
        let values = ["small", "medium", "large"]
        UserDefaults.standard.set(values[sender.indexOfSelectedItem], forKey: Pref.badgeSize)
        NotificationCenter.default.post(name: .matchaPrefsChanged, object: nil)
    }

    @objc private func loginToggled(_ sender: NSButton) {
        if #available(macOS 13.0, *) {
            if sender.state == .on {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }

    @objc private func watchAppsChanged(_ sender: NSTextField) {
        let names = sender.stringValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        UserDefaults.standard.set(names, forKey: Pref.watchApps)
        NotificationCenter.default.post(name: .matchaPrefsChanged, object: nil)
    }
}