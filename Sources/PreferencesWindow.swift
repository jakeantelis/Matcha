import AppKit
import ServiceManagement

final class PreferencesWindowController: NSObject {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?
    private let todayLabel = NSTextField(labelWithString: "")
    private let totalLabel = NSTextField(labelWithString: "")
    private let historyLabel = NSTextField(labelWithString: "")
    private let statsCardLabel = NSTextField(labelWithString: "")

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
        let panel = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Matcha Settings"
        panel.titlebarAppearsTransparent = false

        let tabView = NSTabView(frame: NSRect(x: 0, y: 0, width: 460, height: 520))
        tabView.translatesAutoresizingMaskIntoConstraints = false

        let t1 = NSTabViewItem(identifier: "general")
        t1.label = "General"
        let t2 = NSTabViewItem(identifier: "power")
        t2.label = "Power & Behavior"
        let t3 = NSTabViewItem(identifier: "automation")
        t3.label = "Automation"
        let t4 = NSTabViewItem(identifier: "analytics")
        t4.label = "Analytics"

        tabView.addTabViewItem(t1)
        tabView.addTabViewItem(t2)
        tabView.addTabViewItem(t3)
        tabView.addTabViewItem(t4)

        populateGeneralTab(t1)
        populatePowerTab(t2)
        populateAutomationTab(t3)
        populateAnalyticsTab(t4)

        let footer = makeFooter()

        panel.contentView?.addSubview(tabView)
        panel.contentView?.addSubview(footer)
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: panel.contentView!.topAnchor),
            tabView.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor),
            tabView.bottomAnchor.constraint(equalTo: footer.topAnchor),
            footer.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: panel.contentView!.bottomAnchor),
            footer.heightAnchor.constraint(equalToConstant: 34)
        ])

        return panel
    }

    private func makeFooter() -> NSView {
        let bar = NSView()
        bar.translatesAutoresizingMaskIntoConstraints = false

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let label = NSTextField(labelWithString: version.isEmpty ? "Matcha" : "Matcha \(version)")
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false

        let button = NSButton(title: "Check for Updates", target: NSApp.delegate, action: Selector(("checkForUpdates:")))
        button.bezelStyle = .inline
        button.controlSize = .small
        button.font = NSFont.systemFont(ofSize: 11)
        button.translatesAutoresizingMaskIntoConstraints = false

        bar.addSubview(label)
        bar.addSubview(button)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            button.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -12),
            button.centerYAnchor.constraint(equalTo: bar.centerYAnchor)
        ])
        return bar
    }

    private func makeScrollView(with stack: NSStackView) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.documentView = stack
        return scroll
    }

    private func makeStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 28, bottom: 24, right: 28)
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func header(_ text: String, in stack: NSStackView) {
        let label = NSTextField(labelWithString: text.uppercased())
        label.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        label.textColor = .tertiaryLabelColor
        stack.addArrangedSubview(label)
        stack.setCustomSpacing(4, after: label)
    }

    private func checkbox(_ title: String, _ key: String, in stack: NSStackView) {
        let button = NSButton(checkboxWithTitle: title, target: self, action: #selector(toggled(_:)))
        button.identifier = NSUserInterfaceItemIdentifier(key)
        button.state = UserDefaults.standard.bool(forKey: key) ? .on : .off
        stack.addArrangedSubview(button)
    }

    private func populateGeneralTab(_ item: NSTabViewItem) {
        let stack = makeStack()

        header("Display & UI", in: stack)
        checkbox("Show in Menu Bar", Pref.showMenuBarIcon, in: stack)
        checkbox("Show Time in Menu Bar", Pref.menuBarCountdown, in: stack)
        checkbox("Show in Dock", Pref.showInDock, in: stack)
        checkbox("Show Floating Indicator", Pref.showFloatingIndicator, in: stack)
        checkbox("Translucent Indicator", Pref.translucentIndicator, in: stack)
        checkbox("Animations", Pref.animations, in: stack)
        checkbox("Show Tips", Pref.showTips, in: stack)

        header("Menu Bar Icon Style", in: stack)
        let iconStyle = NSPopUpButton(frame: .zero, pullsDown: false)
        iconStyle.addItems(withTitles: ["Matcha Cup", "Minimal Leaf", "Status Dot"])
        let currentStyle = UserDefaults.standard.string(forKey: Pref.menuBarStyle) ?? "cup"
        iconStyle.selectItem(at: ["cup", "leaf", "dot"].firstIndex(of: currentStyle) ?? 0)
        iconStyle.target = self
        iconStyle.action = #selector(iconStyleChanged(_:))
        stack.addArrangedSubview(iconStyle)

        header("Appearance", in: stack)
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
            header("System Integration", in: stack)
            let login = NSButton(checkboxWithTitle: "Launch at Login", target: self, action: #selector(loginToggled(_:)))
            login.state = SMAppService.mainApp.status == .enabled ? .on : .off
            stack.addArrangedSubview(login)
        }

        item.view = makeScrollView(with: stack)
    }

    private func populatePowerTab(_ item: NSTabViewItem) {
        let stack = makeStack()

        header("Power & Sleep Guards", in: stack)
        checkbox("Keep Display On & Unlocked", Pref.keepDisplayOn, in: stack)
        checkbox("Network / Wi-Fi Guard", Pref.networkGuard, in: stack)
        checkbox("Clamshell / Lid-Closed Support", Pref.clamshellMode, in: stack)

        if Battery.hasBattery {
            checkbox("Low Battery Guard", Pref.batteryGuard, in: stack)

            let batteryRow = NSStackView()
            batteryRow.orientation = .horizontal
            batteryRow.alignment = .centerY
            batteryRow.spacing = 8

            let batteryLabel = NSTextField(labelWithString: "Stop at")
            batteryLabel.font = NSFont.systemFont(ofSize: 11)
            batteryLabel.textColor = .secondaryLabelColor
            batteryRow.addArrangedSubview(batteryLabel)

            let batterySlider = NSSlider(frame: .zero)
            batterySlider.minValue = 5
            batterySlider.maxValue = 50
            batterySlider.intValue = Int32(UserDefaults.standard.integer(forKey: Pref.batteryThreshold))
            batterySlider.target = self
            batterySlider.action = #selector(batteryThresholdChanged(_:))
            batteryRow.addArrangedSubview(batterySlider)

            let batteryValue = NSTextField(labelWithString: "\(UserDefaults.standard.integer(forKey: Pref.batteryThreshold))%")
            batteryValue.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            batteryValue.identifier = NSUserInterfaceItemIdentifier("batteryValue")
            batteryValue.widthAnchor.constraint(equalToConstant: 32).isActive = true
            batteryRow.addArrangedSubview(batteryValue)

            stack.addArrangedSubview(batteryRow)
        }

        checkbox("Idle Auto-Stop", Pref.idleAutoStop, in: stack)

        let idleRow = NSStackView()
        idleRow.orientation = .horizontal
        idleRow.alignment = .centerY
        idleRow.spacing = 8

        let idleLabel = NSTextField(labelWithString: "Stop after")
        idleLabel.font = NSFont.systemFont(ofSize: 11)
        idleLabel.textColor = .secondaryLabelColor
        idleRow.addArrangedSubview(idleLabel)

        let idleSlider = NSSlider(frame: .zero)
        idleSlider.minValue = 1
        idleSlider.maxValue = 60
        idleSlider.intValue = Int32(UserDefaults.standard.integer(forKey: Pref.idleAutoStopMinutes))
        idleSlider.target = self
        idleSlider.action = #selector(idleMinutesChanged(_:))
        idleRow.addArrangedSubview(idleSlider)

        let idleValue = NSTextField(labelWithString: "\(UserDefaults.standard.integer(forKey: Pref.idleAutoStopMinutes)) min")
        idleValue.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        idleValue.identifier = NSUserInterfaceItemIdentifier("idleValue")
        idleValue.widthAnchor.constraint(equalToConstant: 48).isActive = true
        idleRow.addArrangedSubview(idleValue)

        stack.addArrangedSubview(idleRow)

        header("Post-Session Action", in: stack)
        let postAction = NSPopUpButton(frame: .zero, pullsDown: false)
        postAction.addItems(withTitles: ["None", "Play Sound", "Sleep Mac"])
        let currentPost = UserDefaults.standard.string(forKey: Pref.postSessionAction) ?? "none"
        postAction.selectItem(at: ["none", "sound", "sleep"].firstIndex(of: currentPost) ?? 0)
        postAction.target = self
        postAction.action = #selector(postActionChanged(_:))
        stack.addArrangedSubview(postAction)

        header("Webhook on Finish", in: stack)
        let webhookField = NSTextField()
        webhookField.placeholderString = "https://your-webhook-url.com"
        webhookField.stringValue = UserDefaults.standard.string(forKey: Pref.webhookURL) ?? ""
        webhookField.translatesAutoresizingMaskIntoConstraints = false
        webhookField.widthAnchor.constraint(equalToConstant: 380).isActive = true
        webhookField.target = self
        webhookField.action = #selector(webhookChanged(_:))
        stack.addArrangedSubview(webhookField)

        item.view = makeScrollView(with: stack)
    }

    private func populateAutomationTab(_ item: NSTabViewItem) {
        let stack = makeStack()

        header("Coding Agents", in: stack)
        checkbox("Auto-Keep Awake for Code", Pref.autoTriggers, in: stack)
        checkbox("Auto-Start for Coding Agents", Pref.autoStartAgents, in: stack)

        let agentRow = NSStackView()
        agentRow.orientation = .horizontal
        agentRow.alignment = .centerY
        agentRow.spacing = 8

        let agentField = NSTextField()
        agentField.placeholderString = "Add custom agent process (e.g. cursor)"
        agentField.translatesAutoresizingMaskIntoConstraints = false
        agentField.widthAnchor.constraint(equalToConstant: 300).isActive = true
        agentField.identifier = NSUserInterfaceItemIdentifier("customAgentField")
        agentRow.addArrangedSubview(agentField)

        let addAgentBtn = NSButton(title: "Add", target: self, action: #selector(addCustomAgent(_:)))
        addAgentBtn.bezelStyle = .rounded
        agentRow.addArrangedSubview(addAgentBtn)
        stack.addArrangedSubview(agentRow)

        let customList = (UserDefaults.standard.stringArray(forKey: Pref.customAgents) ?? []).joined(separator: ", ")
        let agentListLabel = NSTextField(labelWithString: customList.isEmpty ? "Custom agents: none" : "Custom: \(customList)")
        agentListLabel.font = NSFont.systemFont(ofSize: 11)
        agentListLabel.textColor = .secondaryLabelColor
        agentListLabel.identifier = NSUserInterfaceItemIdentifier("customAgentList")
        stack.addArrangedSubview(agentListLabel)

        header("Watch Apps", in: stack)
        let watchLabel = NSTextField(labelWithString: "Keep awake while these apps run (comma separated):")
        watchLabel.font = NSFont.systemFont(ofSize: 11)
        watchLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(watchLabel)

        let watchField = NSTextField()
        watchField.placeholderString = "e.g. Logic Pro, Final Cut Pro, Blender"
        watchField.stringValue = (UserDefaults.standard.stringArray(forKey: Pref.watchApps) ?? []).joined(separator: ", ")
        watchField.translatesAutoresizingMaskIntoConstraints = false
        watchField.widthAnchor.constraint(equalToConstant: 380).isActive = true
        watchField.target = self
        watchField.action = #selector(watchAppsChanged(_:))
        stack.addArrangedSubview(watchField)

        header("Session Templates", in: stack)
        let templates = TemplateStore.all
        let templateField = NSTextField()
        templateField.placeholderString = "Template name (e.g. Morning Build)"
        templateField.translatesAutoresizingMaskIntoConstraints = false
        templateField.widthAnchor.constraint(equalToConstant: 380).isActive = true
        templateField.identifier = NSUserInterfaceItemIdentifier("templateName")
        stack.addArrangedSubview(templateField)

        let durationRow = NSStackView()
        durationRow.orientation = .horizontal
        durationRow.alignment = .centerY
        durationRow.spacing = 6

        let templateDuration = NSTextField()
        templateDuration.placeholderString = "e.g. 4h, 90m"
        templateDuration.translatesAutoresizingMaskIntoConstraints = false
        templateDuration.identifier = NSUserInterfaceItemIdentifier("templateDuration")
        templateDuration.widthAnchor.constraint(equalToConstant: 170).isActive = true
        durationRow.addArrangedSubview(templateDuration)

        let endlessCheck = NSButton(checkboxWithTitle: "Endless", target: self, action: #selector(toggled(_:)))
        endlessCheck.identifier = NSUserInterfaceItemIdentifier("templateEndless")
        durationRow.addArrangedSubview(endlessCheck)

        let saveTemplate = NSButton(title: "Save", target: self, action: #selector(saveTemplate(_:)))
        saveTemplate.bezelStyle = .rounded
        durationRow.addArrangedSubview(saveTemplate)

        stack.addArrangedSubview(durationRow)

        let templateLabel = NSTextField(labelWithString: templates.isEmpty ? "No templates saved" : templates.map { t in
            t.isEndless ? "\(t.name) (until stopped)" : "\(t.name) (\(Fmt.clockShort(t.durationSeconds)))"
        }.joined(separator: "\n"))
        templateLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        templateLabel.textColor = .secondaryLabelColor
        templateLabel.maximumNumberOfLines = 0
        templateLabel.widthAnchor.constraint(equalToConstant: 380).isActive = true
        templateLabel.identifier = NSUserInterfaceItemIdentifier("templateList")
        stack.addArrangedSubview(templateLabel)

        let deleteTemplate = NSButton(title: "Remove Template", target: self, action: #selector(deleteTemplate(_:)))
        deleteTemplate.bezelStyle = .rounded
        stack.addArrangedSubview(deleteTemplate)

        header("Schedules", in: stack)
        let schedNameField = NSTextField()
        schedNameField.placeholderString = "Schedule name (e.g. Morning Build)"
        schedNameField.translatesAutoresizingMaskIntoConstraints = false
        schedNameField.widthAnchor.constraint(equalToConstant: 380).isActive = true
        schedNameField.identifier = NSUserInterfaceItemIdentifier("scheduleName")
        stack.addArrangedSubview(schedNameField)

        let weekdayLabel = NSTextField(labelWithString: "Days:")
        weekdayLabel.font = NSFont.systemFont(ofSize: 11)
        weekdayLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(weekdayLabel)

        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let dayRow = NSStackView()
        dayRow.orientation = .horizontal
        dayRow.spacing = 4
        for (i, day) in dayNames.enumerated() {
            let btn = NSButton(checkboxWithTitle: day, target: self, action: #selector(scheduleDayToggled(_:)))
            btn.identifier = NSUserInterfaceItemIdentifier("day\(i)")
            dayRow.addArrangedSubview(btn)
        }
        stack.addArrangedSubview(dayRow)

        let timeRow = NSStackView()
        timeRow.orientation = .horizontal
        timeRow.alignment = .centerY
        timeRow.spacing = 8

        let timeField = NSTextField()
        timeField.placeholderString = "9:00"
        timeField.translatesAutoresizingMaskIntoConstraints = false
        timeField.identifier = NSUserInterfaceItemIdentifier("scheduleTime")
        timeField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        timeRow.addArrangedSubview(timeField)

        let schedDurField = NSTextField()
        schedDurField.placeholderString = "4h"
        schedDurField.translatesAutoresizingMaskIntoConstraints = false
        schedDurField.identifier = NSUserInterfaceItemIdentifier("scheduleDuration")
        schedDurField.widthAnchor.constraint(equalToConstant: 50).isActive = true
        timeRow.addArrangedSubview(schedDurField)

        let schedEndless = NSButton(checkboxWithTitle: "Endless", target: self, action: #selector(toggled(_:)))
        schedEndless.identifier = NSUserInterfaceItemIdentifier("scheduleEndless")
        timeRow.addArrangedSubview(schedEndless)

        let saveSchedule = NSButton(title: "Save Schedule", target: self, action: #selector(saveSchedule(_:)))
        saveSchedule.bezelStyle = .rounded
        timeRow.addArrangedSubview(saveSchedule)

        stack.addArrangedSubview(timeRow)

        let scheduleLabel = NSTextField(labelWithString: ScheduleStore.all.isEmpty ? "No schedules set" : ScheduleStore.all.map { s in
            let days = s.weekdays.map { dayNames[$0] }.joined(separator: ",")
            let dur = s.isEndless ? "until stopped" : Fmt.clockShort(s.durationSeconds)
            return "\(s.name) · \(days) @ \(String(format: "%d:%02d", s.hour, s.minute)) · \(dur)"
        }.joined(separator: "\n"))
        scheduleLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        scheduleLabel.textColor = .secondaryLabelColor
        scheduleLabel.maximumNumberOfLines = 0
        scheduleLabel.widthAnchor.constraint(equalToConstant: 380).isActive = true
        scheduleLabel.identifier = NSUserInterfaceItemIdentifier("scheduleList")
        stack.addArrangedSubview(scheduleLabel)

        let deleteSchedule = NSButton(title: "Remove Schedule", target: self, action: #selector(deleteSchedule(_:)))
        deleteSchedule.bezelStyle = .rounded
        stack.addArrangedSubview(deleteSchedule)

        item.view = makeScrollView(with: stack)
    }

    private func populateAnalyticsTab(_ item: NSTabViewItem) {
        let stack = makeStack()

        header("Usage Summary", in: stack)
        todayLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        totalLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        statsCardLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        statsCardLabel.textColor = .secondaryLabelColor
        statsCardLabel.maximumNumberOfLines = 0

        stack.addArrangedSubview(todayLabel)
        stack.addArrangedSubview(totalLabel)
        stack.addArrangedSubview(statsCardLabel)

        header("Recent Sessions", in: stack)
        historyLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        historyLabel.textColor = .secondaryLabelColor
        historyLabel.maximumNumberOfLines = 10
        historyLabel.widthAnchor.constraint(equalToConstant: 380).isActive = true
        stack.addArrangedSubview(historyLabel)

        let exportRow = NSStackView()
        exportRow.orientation = .horizontal
        exportRow.spacing = 8

        let exportJSONBtn = NSButton(title: "Export JSON", target: self, action: #selector(exportJSON(_:)))
        exportJSONBtn.bezelStyle = .rounded
        exportRow.addArrangedSubview(exportJSONBtn)

        let exportCSVBtn = NSButton(title: "Export CSV", target: self, action: #selector(exportCSV(_:)))
        exportCSVBtn.bezelStyle = .rounded
        exportRow.addArrangedSubview(exportCSVBtn)

        let clearHistory = NSButton(title: "Clear History", target: self, action: #selector(clearHistory(_:)))
        clearHistory.bezelStyle = .rounded
        exportRow.addArrangedSubview(clearHistory)

        stack.addArrangedSubview(exportRow)

        item.view = makeScrollView(with: stack)
    }

    func reloadStats() {
        let today = UserDefaults.standard.double(forKey: Pref.awakeToday)
        let total = UserDefaults.standard.double(forKey: Pref.awakeTotal)
        todayLabel.stringValue = "Today: \(Fmt.clockShort(today))"
        totalLabel.stringValue = "Total: \(Fmt.clockShort(total))"

        let history = SessionHistory.all
        let totalSessions = history.count
        let avgDuration = totalSessions > 0 ? history.reduce(0) { $0 + $1.duration } / Double(totalSessions) : 0
        statsCardLabel.stringValue = "Stats: \(totalSessions) total sessions logged · Avg: \(Fmt.clockShort(avgDuration))"

        if history.isEmpty {
            historyLabel.stringValue = "No sessions recorded yet"
        } else {
            let df = DateFormatter()
            df.dateStyle = .short
            df.timeStyle = .short
            historyLabel.stringValue = history.suffix(8).reversed().map { h in
                "\(df.string(from: h.startedAt)) · \(Fmt.clockShort(h.duration)) (\(h.source))"
            }.joined(separator: "\n")
        }
    }

    @objc private func toggled(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }
        UserDefaults.standard.set(sender.state == .on, forKey: id)
        NotificationCenter.default.post(name: .matchaPrefsChanged, object: nil)
    }

    @objc private func appearanceChanged(_ sender: NSPopUpButton) {
        let modes = ["system", "light", "dark"]
        let mode = modes[sender.indexOfSelectedItem]
        UserDefaults.standard.set(mode, forKey: Pref.appearance)
        NotificationCenter.default.post(name: .matchaPrefsChanged, object: nil)
    }

    @objc private func sizeChanged(_ sender: NSPopUpButton) {
        let sizes = ["small", "medium", "large"]
        let sz = sizes[sender.indexOfSelectedItem]
        UserDefaults.standard.set(sz, forKey: Pref.badgeSize)
        NotificationCenter.default.post(name: .matchaPrefsChanged, object: nil)
    }

    @objc private func iconStyleChanged(_ sender: NSPopUpButton) {
        let styles = ["cup", "leaf", "dot"]
        let style = styles[sender.indexOfSelectedItem]
        UserDefaults.standard.set(style, forKey: Pref.menuBarStyle)
        NotificationCenter.default.post(name: .matchaPrefsChanged, object: nil)
    }

    @objc private func postActionChanged(_ sender: NSPopUpButton) {
        let actions = ["none", "sound", "sleep"]
        let action = actions[sender.indexOfSelectedItem]
        UserDefaults.standard.set(action, forKey: Pref.postSessionAction)
        NotificationCenter.default.post(name: .matchaPrefsChanged, object: nil)
    }

    @objc private func webhookChanged(_ sender: NSTextField) {
        UserDefaults.standard.set(sender.stringValue.trimmingCharacters(in: .whitespaces), forKey: Pref.webhookURL)
    }

    @objc private func addCustomAgent(_ sender: NSButton) {
        guard let contentView = sender.superview else { return }
        guard let field = contentView.findSubview(withIdentifier: NSUserInterfaceItemIdentifier("customAgentField")) as? NSTextField else { return }
        let text = field.stringValue
        if AgentRegistry.addCustom(text) {
            field.stringValue = ""
            if let label = contentView.findSubview(withIdentifier: NSUserInterfaceItemIdentifier("customAgentList")) as? NSTextField {
                let customList = (UserDefaults.standard.stringArray(forKey: Pref.customAgents) ?? []).joined(separator: ", ")
                label.stringValue = customList.isEmpty ? "Custom agents: none" : "Custom: \(customList)"
            }
        } else {
            NSSound.beep()
        }
    }

    @objc private func exportJSON(_ sender: NSButton) {
        guard let json = SessionHistory.exportJSON() else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "matcha-history.json"
        if panel.runModal() == .OK, let url = panel.url {
            try? json.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    @objc private func exportCSV(_ sender: NSButton) {
        let csv = SessionHistory.exportCSV()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "matcha-history.csv"
        if panel.runModal() == .OK, let url = panel.url {
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    @objc private func loginToggled(_ sender: NSButton) {
        if #available(macOS 13.0, *) {
            do {
                if sender.state == .on {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {}
        }
    }

    @objc private func batteryThresholdChanged(_ sender: NSSlider) {
        UserDefaults.standard.set(Int(sender.intValue), forKey: Pref.batteryThreshold)
        if let label = window?.contentView?.findSubview(withIdentifier: NSUserInterfaceItemIdentifier("batteryValue")) as? NSTextField {
            label.stringValue = "\(Int(sender.intValue))%"
        }
    }

    @objc private func idleMinutesChanged(_ sender: NSSlider) {
        let value = Int(sender.intValue)
        UserDefaults.standard.set(value, forKey: Pref.idleAutoStopMinutes)
        if let label = window?.contentView?.findSubview(withIdentifier: NSUserInterfaceItemIdentifier("idleValue")) as? NSTextField {
            label.stringValue = "\(value) min"
        }
    }

    @objc private func clearHistory(_ sender: NSButton) {
        SessionHistory.clear()
        reloadStats()
    }

    @objc private func watchAppsChanged(_ sender: NSTextField) {
        let names = sender.stringValue.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        UserDefaults.standard.set(names, forKey: Pref.watchApps)
        NotificationCenter.default.post(name: .matchaPrefsChanged, object: nil)
    }

    @objc private func saveTemplate(_ sender: NSButton) {
        guard let contentView = sender.superview?.superview else { return }
        guard let nameField = contentView.findSubview(withIdentifier: NSUserInterfaceItemIdentifier("templateName")) as? NSTextField else { return }
        let name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { NSSound.beep(); return }

        let endlessField = contentView.findSubview(withIdentifier: NSUserInterfaceItemIdentifier("templateEndless")) as? NSButton
        let isEndless = endlessField?.state == .on

        let duration: TimeInterval
        if isEndless {
            duration = 0
        } else {
            guard let durField = contentView.findSubview(withIdentifier: NSUserInterfaceItemIdentifier("templateDuration")) as? NSTextField,
                  let parsed = Fmt.parseDuration(durField.stringValue), parsed > 0 else {
                NSSound.beep()
                return
            }
            duration = parsed
        }

        TemplateStore.add(SessionTemplate(name: name, durationSeconds: duration, isEndless: isEndless))
        nameField.stringValue = ""
        if let durField = contentView.findSubview(withIdentifier: NSUserInterfaceItemIdentifier("templateDuration")) as? NSTextField {
            durField.stringValue = ""
        }
        endlessField?.state = .off
        refreshTemplateList(in: contentView)
    }

    @objc private func deleteTemplate(_ sender: NSButton) {
        let templates = TemplateStore.all
        guard !templates.isEmpty else { return }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Remove which template?"
        templates.forEach { alert.addButton(withTitle: $0.name) }
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        let index = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        guard index >= 0 && index < templates.count else { return }
        TemplateStore.remove(named: templates[index].name)
        if let contentView = sender.superview {
            refreshTemplateList(in: contentView)
        }
    }

    private func refreshTemplateList(in contentView: NSView) {
        guard let label = contentView.findSubview(withIdentifier: NSUserInterfaceItemIdentifier("templateList")) as? NSTextField else { return }
        let templates = TemplateStore.all
        label.stringValue = templates.isEmpty ? "No templates saved" : templates.map { t in
            t.isEndless ? "\(t.name) (until stopped)" : "\(t.name) (\(Fmt.clockShort(t.durationSeconds)))"
        }.joined(separator: "\n")
    }

    private var selectedDays: Set<Int> = []

    @objc private func scheduleDayToggled(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue,
              id.hasPrefix("day"),
              let day = Int(id.dropFirst(3)) else { return }
        if sender.state == .on {
            selectedDays.insert(day)
        } else {
            selectedDays.remove(day)
        }
    }

    @objc private func saveSchedule(_ sender: NSButton) {
        guard let contentView = sender.superview?.superview else { return }
        guard let nameField = contentView.findSubview(withIdentifier: NSUserInterfaceItemIdentifier("scheduleName")) as? NSTextField else { return }
        let name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { NSSound.beep(); return }
        guard !selectedDays.isEmpty else { NSSound.beep(); return }

        guard let timeField = contentView.findSubview(withIdentifier: NSUserInterfaceItemIdentifier("scheduleTime")) as? NSTextField else { return }
        let timeParts = timeField.stringValue.split(separator: ":")
        guard timeParts.count == 2, let hour = Int(timeParts[0]), let minute = Int(timeParts[1]),
              (0...23).contains(hour), (0...59).contains(minute) else { NSSound.beep(); return }

        let endlessField = contentView.findSubview(withIdentifier: NSUserInterfaceItemIdentifier("scheduleEndless")) as? NSButton
        let isEndless = endlessField?.state == .on

        let duration: TimeInterval
        if isEndless {
            duration = 0
        } else {
            guard let durField = contentView.findSubview(withIdentifier: NSUserInterfaceItemIdentifier("scheduleDuration")) as? NSTextField,
                  let parsed = Fmt.parseDuration(durField.stringValue), parsed > 0 else {
                NSSound.beep()
                return
            }
            duration = parsed
        }

        ScheduleStore.add(Schedule(name: name, weekdays: selectedDays.sorted(), hour: hour, minute: minute, durationSeconds: duration, isEndless: isEndless))
        nameField.stringValue = ""
        timeField.stringValue = ""
        if let durField = contentView.findSubview(withIdentifier: NSUserInterfaceItemIdentifier("scheduleDuration")) as? NSTextField {
            durField.stringValue = ""
        }
        endlessField?.state = .off
        for i in 0..<7 {
            if let btn = contentView.findSubview(withIdentifier: NSUserInterfaceItemIdentifier("day\(i)")) as? NSButton {
                btn.state = .off
            }
        }
        selectedDays.removeAll()
        refreshScheduleList(in: contentView)
    }

    @objc private func deleteSchedule(_ sender: NSButton) {
        let schedules = ScheduleStore.all
        guard !schedules.isEmpty else { return }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Remove which schedule?"
        schedules.forEach { alert.addButton(withTitle: $0.name) }
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        let index = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        guard index >= 0 && index < schedules.count else { return }
        ScheduleStore.remove(named: schedules[index].name)
        if let contentView = sender.superview {
            refreshScheduleList(in: contentView)
        }
    }

    private func refreshScheduleList(in contentView: NSView) {
        guard let label = contentView.findSubview(withIdentifier: NSUserInterfaceItemIdentifier("scheduleList")) as? NSTextField else { return }
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let schedules = ScheduleStore.all
        label.stringValue = schedules.isEmpty ? "No schedules set" : schedules.map { s in
            let days = s.weekdays.map { dayNames[$0] }.joined(separator: ",")
            let dur = s.isEndless ? "until stopped" : Fmt.clockShort(s.durationSeconds)
            return "\(s.name) · \(days) @ \(String(format: "%d:%02d", s.hour, s.minute)) · \(dur)"
        }.joined(separator: "\n")
    }
}
