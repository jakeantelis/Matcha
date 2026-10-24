import AppKit
import ServiceManagement

final class PreferencesWindowController: NSObject {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?
    private let todayLabel = NSTextField(labelWithString: "")
    private let totalLabel = NSTextField(labelWithString: "")
    private let historyLabel = NSTextField(labelWithString: "")

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
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 560))

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
        checkbox("Auto-Start for Coding Agents", Pref.autoStartAgents)
        checkbox("Network / Wi-Fi Guard", Pref.networkGuard)
        checkbox("Clamshell / Lid-Closed Support", Pref.clamshellMode)
        if Battery.hasBattery {
            checkbox("Low Battery Guard", Pref.batteryGuard)

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

        checkbox("Idle Auto-Stop", Pref.idleAutoStop)

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

        header("Menu Bar & Floater")
        checkbox("Show in Menu Bar", Pref.showMenuBarIcon)
        checkbox("Show Time in Menu Bar", Pref.menuBarCountdown)
        checkbox("Show in Dock", Pref.showInDock)
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
        watchField.widthAnchor.constraint(equalToConstant: 280).isActive = true
        stack.addArrangedSubview(watchField)

        header("Session Templates")

        let templates = TemplateStore.all
        let templateField = NSTextField()
        templateField.placeholderString = "Template name (e.g. Morning Build)"
        templateField.translatesAutoresizingMaskIntoConstraints = false
        templateField.widthAnchor.constraint(equalToConstant: 280).isActive = true
        templateField.identifier = NSUserInterfaceItemIdentifier("templateName")
        stack.addArrangedSubview(templateField)

        let durationRow = NSStackView()
        durationRow.orientation = .horizontal
        durationRow.alignment = .centerY
        durationRow.spacing = 6
        durationRow.widthAnchor.constraint(equalToConstant: 280).isActive = true

        let templateDuration = NSTextField()
        templateDuration.placeholderString = "e.g. 4h, 90m"
        templateDuration.translatesAutoresizingMaskIntoConstraints = false
        templateDuration.identifier = NSUserInterfaceItemIdentifier("templateDuration")
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
        templateLabel.cell?.truncatesLastVisibleLine = false
        templateLabel.widthAnchor.constraint(equalToConstant: 280).isActive = true
        templateLabel.identifier = NSUserInterfaceItemIdentifier("templateList")
        stack.addArrangedSubview(templateLabel)

        let deleteTemplate = NSButton(title: "Remove Template", target: self, action: #selector(deleteTemplate(_:)))
        deleteTemplate.bezelStyle = .rounded
        stack.addArrangedSubview(deleteTemplate)

        header("Schedules")

        let schedNameField = NSTextField()
        schedNameField.placeholderString = "Schedule name (e.g. Morning Build)"
        schedNameField.translatesAutoresizingMaskIntoConstraints = false
        schedNameField.widthAnchor.constraint(equalToConstant: 280).isActive = true
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
        dayRow.widthAnchor.constraint(equalToConstant: 280).isActive = true
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
        timeRow.widthAnchor.constraint(equalToConstant: 280).isActive = true

        let timeLabel = NSTextField(labelWithString: "At:")
        timeLabel.font = NSFont.systemFont(ofSize: 11)
        timeLabel.textColor = .secondaryLabelColor
        timeRow.addArrangedSubview(timeLabel)

        let timeField = NSTextField()
        timeField.placeholderString = "9:00"
        timeField.translatesAutoresizingMaskIntoConstraints = false
        timeField.identifier = NSUserInterfaceItemIdentifier("scheduleTime")
        timeField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        timeRow.addArrangedSubview(timeField)

        let durLabel = NSTextField(labelWithString: "Duration:")
        durLabel.font = NSFont.systemFont(ofSize: 11)
        durLabel.textColor = .secondaryLabelColor
        timeRow.addArrangedSubview(durLabel)

        let schedDurField = NSTextField()
        schedDurField.placeholderString = "4h"
        schedDurField.translatesAutoresizingMaskIntoConstraints = false
        schedDurField.identifier = NSUserInterfaceItemIdentifier("scheduleDuration")
        schedDurField.widthAnchor.constraint(equalToConstant: 50).isActive = true
        timeRow.addArrangedSubview(schedDurField)

        let schedEndless = NSButton(checkboxWithTitle: "Endless", target: self, action: #selector(toggled(_:)))
        schedEndless.identifier = NSUserInterfaceItemIdentifier("scheduleEndless")
        timeRow.addArrangedSubview(schedEndless)

        stack.addArrangedSubview(timeRow)

        let saveSchedule = NSButton(title: "Save Schedule", target: self, action: #selector(saveSchedule(_:)))
        saveSchedule.bezelStyle = .rounded
        stack.addArrangedSubview(saveSchedule)

        let scheduleLabel = NSTextField(labelWithString: ScheduleStore.all.isEmpty ? "No schedules set" : ScheduleStore.all.map { s in
            let days = s.weekdays.map { dayNames[$0] }.joined(separator: ",")
            let dur = s.isEndless ? "until stopped" : Fmt.clockShort(s.durationSeconds)
            return "\(s.name) · \(days) @ \(String(format: "%d:%02d", s.hour, s.minute)) · \(dur)"
        }.joined(separator: "\n"))
        scheduleLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        scheduleLabel.textColor = .secondaryLabelColor
        scheduleLabel.maximumNumberOfLines = 0
        scheduleLabel.cell?.truncatesLastVisibleLine = false
        scheduleLabel.widthAnchor.constraint(equalToConstant: 280).isActive = true
        scheduleLabel.identifier = NSUserInterfaceItemIdentifier("scheduleList")
        stack.addArrangedSubview(scheduleLabel)

        let deleteSchedule = NSButton(title: "Remove Schedule", target: self, action: #selector(deleteSchedule(_:)))
        deleteSchedule.bezelStyle = .rounded
        stack.addArrangedSubview(deleteSchedule)

        header("Usage")
        todayLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        totalLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        stack.addArrangedSubview(todayLabel)
        stack.addArrangedSubview(totalLabel)

        header("Recent Sessions")
        historyLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        historyLabel.textColor = .secondaryLabelColor
        historyLabel.maximumNumberOfLines = 0
        historyLabel.cell?.truncatesLastVisibleLine = false
        historyLabel.widthAnchor.constraint(equalToConstant: 280).isActive = true
        stack.addArrangedSubview(historyLabel)

        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
        ])

        content.addSubview(stack)
        content.frame = NSRect(x: 0, y: 0, width: 340, height: stack.fittingSize.height + 40)
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
        historyLabel.stringValue = formatHistory()
    }

    private func format(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private func formatHistory() -> String {
        let entries = SessionHistory.all.suffix(5).reversed()
        if entries.isEmpty { return "No sessions yet" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        var lines: [String] = []
        for entry in entries {
            let dur = format(entry.duration)
            let when = formatter.string(from: entry.startedAt)
            lines.append("\(when) · \(dur) · \(entry.source)")
        }
        return lines.joined(separator: "\n")
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

    @objc private func saveTemplate(_ sender: NSButton) {
        guard let contentView = window?.contentView else { return }
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
        refreshTemplateList()
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
        refreshTemplateList()
    }

    private func refreshTemplateList() {
        guard let contentView = window?.contentView else { return }
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
        guard let contentView = window?.contentView else { return }
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
        refreshScheduleList()
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
        refreshScheduleList()
    }

    private func refreshScheduleList() {
        guard let contentView = window?.contentView else { return }
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