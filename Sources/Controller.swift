import AppKit
import Carbon.HIToolbox
import IOKit.pwr_mgt
import ServiceManagement
import UserNotifications

final class Controller: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation, UNUserNotificationCenterDelegate {

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var window: NSWindow?
    private var windowTint: TintView?
    private var popoverPanel: PanelView?
    private var windowPanel: PanelView?
    private var badge: FloatingBadge?
    private let triggers = TriggerMonitor()
    private let hotKeys = HotKeyManager()
    private var triggerBusy = false
    private var pendingShowWorkItem: DispatchWorkItem?

    private var active = false
    private var endDate: Date?
    private var duration: TimeInterval?
    private var ticker: Timer?
    private var assertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0
    private var displayKeepAlive: Timer?
    private var caffeinateProcess: Process?
    private var batteryTimer: Timer?
    private var hotKeysRegistered = false
    private var warnedEnding = false
    private var agentTimer: Timer?

    private func startAgentDetection() {
        agentTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkAgents()
        }
        RunLoop.main.add(agentTimer!, forMode: .common)
        checkAgents()
    }

    private func checkAgents() {
        guard !active else { return }
        let procs = ["claude", "codex", "opencode", "aider", "roo", "cline", "continue", "copilot", "gemini"]
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let task = Process()
            task.launchPath = "/bin/ps"
            task.arguments = ["-axo", "comm="]
            let pipe = Pipe()
            task.standardOutput = pipe
            do {
                try task.run()
                task.waitUntilExit()
            } catch {
                return
            }
            guard task.terminationStatus == 0,
                  let data = try? pipe.fileHandleForReading.readToEnd(),
                  let out = String(data: data, encoding: .utf8) else { return }
            let lower = out.lowercased()
            var running = false
            for p in procs {
                if lower.contains("/\(p)") || lower.hasSuffix(p) || lower.contains(" \(p)") {
                    running = true
                    break
                }
            }
            guard running else { return }
            DispatchQueue.main.async {
                guard let self = self, !self.active else { return }
                let key = "lastAgentPrompt"
                let last = UserDefaults.standard.double(forKey: key)
                if Date().timeIntervalSince1970 - last > 1800 {
                    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key)
                    self.offerKeepAwakeAgent()
                }
            }
        }
    }

    private func offerKeepAwakeAgent() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                let content = UNMutableNotificationContent()
                content.title = "Keep your Mac awake?"
                content.body = "An AI coding agent is running. Matcha can prevent sleep while it works."
                content.categoryIdentifier = "AWAY"
                content.sound = .default
                center.add(UNNotificationRequest(identifier: "matcha.agent.\(UUID().uuidString)", content: content, trigger: nil))
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clearPersistedSession()
        stopBatteryGuard()
        releaseAssertions()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Pref.registerDefaults()
        NSApp.setActivationPolicy(.regular)
        buildMainMenu()

        let panel = PanelView()
        wire(panel)
        popoverPanel = panel
        let vc = NSViewController()
        vc.view = panel
        vc.preferredContentSize = panel.frame.size
        popover.behavior = .transient
        popover.contentViewController = vc

        badge = FloatingBadge(size: FloatingBadge.size(for: UserDefaults.standard.string(forKey: Pref.badgeSize) ?? "medium"))
        badge?.onClick = { [weak self] in self?.presentBadgeMenu() }
        badge?.onRightClick = { [weak self] in self?.presentBadgeMenu() }
        badge?.onQuickAdd = { [weak self] seconds in self?.extend(by: seconds) }
        badge?.onStop = { [weak self] in self?.stop() }
        badge?.onMoved = { origin in
            UserDefaults.standard.set("\(origin.x),\(origin.y)", forKey: Pref.badgeOrigin)
        }

        triggers.onBusyChanged = { [weak self] busy in
            self?.triggerBusy = busy
            self?.refreshAll()
        }
        triggers.onAwayWhileBusy = { [weak self] in self?.offerKeepAwake() }
        setupNotifications()
        registerHotKeys()

        createWindow()
        applyPreferences()
        restoreSession()
        applyTriggers()
        startAgentDetection()
        refreshAll()

        let show = DispatchWorkItem { [weak self] in
            self?.showWindow()
            NSApp.activate(ignoringOtherApps: true)
        }
        pendingShowWorkItem = show
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: show)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        pendingShowWorkItem?.cancel()
        pendingShowWorkItem = nil
        urls.forEach(handle)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showWindow() }
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    // MARK: - Automation (URL scheme + CLI)

    private func handle(_ url: URL) {
        guard url.scheme?.lowercased() == "matcha" else { return }
        let command = url.host?.lowercased() ?? ""
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        func requestedTime() -> TimeInterval? {
            func value(_ name: String) -> Double? {
                items.first(where: { $0.name == name })?.value.flatMap(Double.init)
            }
            if let hours = value("hours") { return hours * 3600 }
            if let minutes = value("minutes") { return minutes * 60 }
            if let seconds = value("seconds") { return seconds }
            if let raw = items.first(where: { $0.name == "duration" })?.value {
                return Fmt.parseDuration(raw)
            }
            return nil
        }

        switch command {
        case "on":
            start(duration: requestedTime())
        case "off":
            stop()
        case "toggle":
            toggleActive()
        case "extend":
            let seconds = requestedTime() ?? 3600
            extend(by: seconds)
        default:
            break
        }
    }

    // MARK: - Notifications

    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let keep = UNNotificationAction(identifier: "KEEP_AWAKE", title: "Keep Awake", options: [.foreground])
        let skip = UNNotificationAction(identifier: "NOT_NOW", title: "Not Now", options: [])
        let category = UNNotificationCategory(
            identifier: "AWAY",
            actions: [keep, skip],
            intentIdentifiers: [],
            options: []
        )
        let addHour = UNNotificationAction(identifier: "ADD_HOUR", title: "Add 1 Hour", options: [])
        let stopSession = UNNotificationAction(identifier: "STOP_SESSION", title: "Stop", options: [])
        let ending = UNNotificationCategory(
            identifier: "ENDING",
            actions: [addHour, stopSession],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category, ending])
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func registerHotKeys() {
        let modifiers = UInt32(controlKey | optionKey | cmdKey)
        let toggleOK = hotKeys.register(keyCode: UInt32(kVK_ANSI_M), modifiers: modifiers) { [weak self] in
            self?.toggleActive()
        }
        let startOK = hotKeys.register(keyCode: UInt32(kVK_ANSI_1), modifiers: modifiers) { [weak self] in
            self?.start(duration: 3600)
        }
        hotKeysRegistered = toggleOK && startOK
    }

    private func offerKeepAwake() {
        guard !active else { return }
        let content = UNMutableNotificationContent()
        content.title = "Still working?"
        content.body = "A build or coding task is running and you've stepped away. Keep your Mac awake?"
        content.categoryIdentifier = "AWAY"
        content.sound = .default
        let request = UNNotificationRequest(identifier: "matcha.away", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == "KEEP_AWAKE" {
            start(duration: nil)
            NSApp.activate(ignoringOtherApps: true)
            showWindow()
        } else if response.actionIdentifier == "ADD_HOUR" {
            if active, endDate != nil {
                extend(by: 3600)
            } else {
                start(duration: 3600)
            }
        } else if response.actionIdentifier == "STOP_SESSION" {
            stop()
        } else if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            if response.notification.request.content.categoryIdentifier == "AWAY" {
                start(duration: nil)
            }
            NSApp.activate(ignoringOtherApps: true)
            showWindow()
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    private func applyTriggers() {
        if UserDefaults.standard.bool(forKey: Pref.autoTriggers) {
            triggers.start()
        } else {
            triggers.stop()
            triggerBusy = false
        }
    }

    @objc private func toggleAutoTriggers(_ sender: NSMenuItem) {
        let value = !UserDefaults.standard.bool(forKey: Pref.autoTriggers)
        UserDefaults.standard.set(value, forKey: Pref.autoTriggers)
        applyTriggers()
    }

    @objc private func toggleBatteryGuard(_ sender: NSMenuItem) {
        let value = !UserDefaults.standard.bool(forKey: Pref.batteryGuard)
        UserDefaults.standard.set(value, forKey: Pref.batteryGuard)
    }

    // MARK: - Status file (read by the matchactl CLI)

    private func writeStatus() {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Matcha", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let status: [String: Any] = [
            "active": active,
            "remaining": endDate.map { max(0, Int($0.timeIntervalSinceNow.rounded())) } ?? -1,
            "duration": duration.map { Int($0) } ?? -1,
            "trigger": triggerBusy,
            "hotkeys": hotKeysRegistered,
        ]

        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: status,
            format: .xml,
            options: 0
        ) else { return }
        try? data.write(to: directory.appendingPathComponent("status.plist"))
    }

    private func wire(_ panel: PanelView) {
        panel.onToggle = { [weak self] in self?.toggleActive() }
        panel.onPreset = { [weak self] seconds in self?.start(duration: seconds) }
        panel.onCustomMinutes = { [weak self] minutes in
            self?.start(duration: TimeInterval(minutes))
        }
        panel.onMenu = { [weak self] view in self?.presentMenu(from: view) }
    }

    private func buildMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "About Matcha",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        let updates = NSMenuItem(
            title: "Check for Updates\u{2026}",
            action: #selector(checkForUpdates(_:)),
            keyEquivalent: ""
        )
        updates.target = self
        appMenu.addItem(updates)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Matcha", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Matcha", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        NSApp.mainMenu = main
    }

    private func createWindow() {
        let panel = PanelView()
        panel.setTintEnabled(false)
        wire(panel)
        windowPanel = panel

        let panelSize = panel.frame.size
        let topInset: CGFloat = 34
        let side: CGFloat = 20
        let bottom: CGFloat = 16
        let contentSize = NSSize(
            width: panelSize.width + side * 2,
            height: panelSize.height + topInset + bottom
        )

        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        w.title = "Matcha"
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isMovableByWindowBackground = true
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.center()

        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        w.contentView = effect

        let tint = TintView()
        tint.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(tint)
        NSLayoutConstraint.activate([
            tint.topAnchor.constraint(equalTo: effect.topAnchor),
            tint.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            tint.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
        windowTint = tint

        panel.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: effect.centerXAnchor),
            panel.topAnchor.constraint(equalTo: effect.topAnchor, constant: topInset),
            panel.widthAnchor.constraint(equalToConstant: panelSize.width),
            panel.heightAnchor.constraint(equalToConstant: panelSize.height),
        ])

        window = w
    }

    @objc func showWindow() {
        if window == nil { createWindow() }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Status item

    private func applyPreferences() {
        let showMenuBar = UserDefaults.standard.bool(forKey: Pref.showMenuBarIcon)
        if showMenuBar && statusItem == nil {
            createStatusItem()
        } else if !showMenuBar, let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
        applyAppearance()
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = symbolImage(["cup.and.saucer.fill", "cup.and.saucer", "mug.fill", "mug"])
            button.imagePosition = .imageLeading
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            button.action = #selector(statusClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Matcha"
        }
        statusItem = item
    }

    @objc private func statusClicked() {
        if let event = NSApp.currentEvent,
           event.type == .rightMouseUp || event.modifierFlags.contains(.option),
           let button = statusItem?.button {
            presentMenu(from: button)
        } else if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func applyAppearance() {
        let appearance: NSAppearance?
        switch UserDefaults.standard.string(forKey: Pref.appearance) ?? "system" {
        case "dark": appearance = NSAppearance(named: .darkAqua)
        case "light": appearance = NSAppearance(named: .aqua)
        default: appearance = nil
        }
        popover.appearance = appearance
        window?.appearance = appearance
    }

    // MARK: - Settings menu

    private func presentMenu(from view: NSView) {
        buildSettingsMenu().popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: view.bounds.height + 6),
            in: view
        )
    }

    private func presentBadgeMenu() {
        guard let badge, let view = badge.contentView else { return }
        let mouse = NSEvent.mouseLocation
        let location = NSPoint(x: mouse.x - badge.frame.origin.x, y: mouse.y - badge.frame.origin.y)
        buildSettingsMenu().popUp(positioning: nil, at: location, in: view)
    }

    private func buildSettingsMenu() -> NSMenu {
        let menu = NSMenu()

        let power = NSMenuItem(
            title: active ? "Stop Matcha" : "Start Matcha",
            action: #selector(togglePower(_:)),
            keyEquivalent: ""
        )
        power.target = self
        menu.addItem(power)

        menu.addItem(timeItem("+15 Min", seconds: 900))
        menu.addItem(timeItem("+30 Min", seconds: 1800))
        menu.addItem(timeItem("+1 Hour", seconds: 3600))
        menu.addItem(timeItem("+4 Hours", seconds: 14400))

        let setItem = NSMenuItem(title: "Set Duration", action: nil, keyEquivalent: "")
        let setMenu = NSMenu()

        func durationItem(_ title: String, seconds: TimeInterval?, tag: Int) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: #selector(setDurationFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.tag = tag
            item.representedObject = seconds
            return item
        }

        setMenu.addItem(durationItem("2 Hours", seconds: 7200, tag: 0))
        setMenu.addItem(durationItem("4 Hours", seconds: 14400, tag: 0))
        setMenu.addItem(durationItem("8 Hours", seconds: 28800, tag: 0))
        setMenu.addItem(durationItem("Until I Stop", seconds: nil, tag: 1))
        setMenu.addItem(.separator())
        setMenu.addItem(durationItem("Other…", seconds: nil, tag: 2))
        setItem.submenu = setMenu
        menu.addItem(setItem)

        menu.addItem(.separator())

        func toggleItem(_ title: String, _ key: String, _ action: Selector) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            item.state = UserDefaults.standard.bool(forKey: key) ? .on : .off
            return item
        }

        menu.addItem(toggleItem("Keep Display On & Unlocked", Pref.keepDisplayOn, #selector(toggleKeepDisplay(_:))))
        menu.addItem(toggleItem("Auto-Keep Awake for Code", Pref.autoTriggers, #selector(toggleAutoTriggers(_:))))
        if Battery.hasBattery {
            menu.addItem(toggleItem("Low Battery Guard", Pref.batteryGuard, #selector(toggleBatteryGuard(_:))))
        }
        menu.addItem(toggleItem("Show in Menu Bar", Pref.showMenuBarIcon, #selector(toggleMenuBarIcon(_:))))
        menu.addItem(toggleItem("Show Time in Menu Bar", Pref.menuBarCountdown, #selector(toggleMenuBarCountdown(_:))))
        menu.addItem(toggleItem("Show Floating Indicator", Pref.showFloatingIndicator, #selector(toggleFloatingIndicator(_:))))
        menu.addItem(toggleItem("Translucent Indicator", Pref.translucentIndicator, #selector(toggleTranslucent(_:))))

        let sizeItem = NSMenuItem(title: "Indicator Size", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        let sizes: [(String, String)] = [("Small", "small"), ("Medium", "medium"), ("Large", "large")]
        let currentSize = UserDefaults.standard.string(forKey: Pref.badgeSize) ?? "medium"
        for (index, option) in sizes.enumerated() {
            let item = NSMenuItem(title: option.0, action: #selector(setIndicatorSize(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.state = option.1 == currentSize ? .on : .off
            sizeMenu.addItem(item)
        }
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        if #available(macOS 13.0, *) {
            let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
            login.target = self
            login.state = launchAtLoginEnabled() ? .on : .off
            menu.addItem(login)
        }

        menu.addItem(.separator())

        let appearanceItem = NSMenuItem(title: "Appearance", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let modes: [(String, String)] = [("Match System", "system"), ("Light", "light"), ("Dark", "dark")]
        let current = UserDefaults.standard.string(forKey: Pref.appearance) ?? "system"
        for (index, mode) in modes.enumerated() {
            let item = NSMenuItem(title: mode.0, action: #selector(setAppearanceMode(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.state = mode.1 == current ? .on : .off
            submenu.addItem(item)
        }
        appearanceItem.submenu = submenu
        menu.addItem(appearanceItem)

        menu.addItem(.separator())

        let hint = NSMenuItem(
            title: "Hotkeys: \u{2303}\u{2325}\u{2318}M toggle \u{00B7} \u{2303}\u{2325}\u{2318}1 one hour",
            action: nil,
            keyEquivalent: ""
        )
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(.separator())

        let openItem = NSMenuItem(title: "Open Window", action: #selector(showWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(
            NSMenuItem(title: "Quit Matcha", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        )
        return menu
    }

    private struct ReleaseInfo: Decodable {
        let tag_name: String
        let html_url: String
    }

    @objc private func checkForUpdates(_ sender: Any?) {
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        guard let url = URL(string: "https://api.github.com/repos/jakeantelis/Matcha/releases/latest") else { return }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)

                if let data, let release = try? JSONDecoder().decode(ReleaseInfo.self, from: data) {
                    let latest = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                    if Self.isVersion(latest, newerThan: current) {
                        let alert = NSAlert()
                        alert.messageText = "Matcha \(latest) is available"
                        alert.informativeText = "You have \(current). Rerun the install command to update, or download the new version."
                        alert.addButton(withTitle: "Download")
                        alert.addButton(withTitle: "Later")
                        if alert.runModal() == .alertFirstButtonReturn,
                           let page = URL(string: release.html_url) {
                            NSWorkspace.shared.open(page)
                        }
                    } else {
                        let alert = NSAlert()
                        alert.messageText = "You\u{2019}re up to date"
                        alert.informativeText = "Matcha \(current) is the latest version."
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                } else {
                    let alert = NSAlert()
                    alert.messageText = "Couldn\u{2019}t check for updates"
                    alert.informativeText = error?.localizedDescription ?? "Check your connection and try again."
                    alert.addButton(withTitle: "Open Releases")
                    alert.addButton(withTitle: "OK")
                    if alert.runModal() == .alertFirstButtonReturn {
                        NSWorkspace.shared.open(URL(string: "https://github.com/jakeantelis/Matcha/releases")!)
                    }
                }
            }
        }.resume()
    }

    private static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0.prefix(while: { $0.isNumber })) ?? 0 }
        let b = current.split(separator: ".").map { Int($0.prefix(while: { $0.isNumber })) ?? 0 }
        for index in 0..<max(a.count, b.count) {
            let left = index < a.count ? a[index] : 0
            let right = index < b.count ? b[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    private func timeItem(_ title: String, seconds: TimeInterval) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(addTime(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = seconds
        return item
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(addTime(_:)) {
            return active ? endDate != nil : true
        }
        return true
    }

    @objc private func togglePower(_ sender: NSMenuItem) {
        toggleActive()
    }

    @objc private func addTime(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? TimeInterval else { return }
        extend(by: seconds)
    }

    private func extend(by seconds: TimeInterval) {
        guard active, endDate != nil else {
            start(duration: seconds)
            return
        }
        endDate = endDate!.addingTimeInterval(seconds)
        duration = duration.map { $0 + seconds }
        warnedEnding = false
        persistSession()
        refreshAll()
    }

    @objc private func setDurationFromMenu(_ sender: NSMenuItem) {
        switch sender.tag {
        case 0:
            if let seconds = sender.representedObject as? TimeInterval {
                start(duration: seconds)
            }
        case 1:
            start(duration: nil)
        default:
            showWindow()
        }
    }

    @objc private func toggleKeepDisplay(_ sender: NSMenuItem) {
        let value = !UserDefaults.standard.bool(forKey: Pref.keepDisplayOn)
        UserDefaults.standard.set(value, forKey: Pref.keepDisplayOn)
        if active {
            releaseAssertions()
            createAssertions()
        }
    }

    @objc private func toggleMenuBarIcon(_ sender: NSMenuItem) {
        let value = !UserDefaults.standard.bool(forKey: Pref.showMenuBarIcon)
        UserDefaults.standard.set(value, forKey: Pref.showMenuBarIcon)
        applyPreferences()
    }

    @objc private func toggleMenuBarCountdown(_ sender: NSMenuItem) {
        let value = !UserDefaults.standard.bool(forKey: Pref.menuBarCountdown)
        UserDefaults.standard.set(value, forKey: Pref.menuBarCountdown)
        updateStatusItem()
    }

    @objc private func toggleFloatingIndicator(_ sender: NSMenuItem) {
        let value = !UserDefaults.standard.bool(forKey: Pref.showFloatingIndicator)
        UserDefaults.standard.set(value, forKey: Pref.showFloatingIndicator)
        refreshAll()
    }

    @objc private func toggleTranslucent(_ sender: NSMenuItem) {
        let value = !UserDefaults.standard.bool(forKey: Pref.translucentIndicator)
        UserDefaults.standard.set(value, forKey: Pref.translucentIndicator)
        refreshAll()
    }

    @objc private func setIndicatorSize(_ sender: NSMenuItem) {
        let names = ["small", "medium", "large"]
        guard sender.tag >= 0, sender.tag < names.count else { return }
        let name = names[sender.tag]
        UserDefaults.standard.set(name, forKey: Pref.badgeSize)
        guard let badge else { return }
        badge.resize(to: FloatingBadge.size(for: name))
        clampBadgeToScreen()
    }

    private func clampBadgeToScreen() {
        guard let badge else { return }
        let center = NSPoint(x: badge.frame.midX, y: badge.frame.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        var origin = badge.frame.origin
        origin.x = min(max(visible.minX + 8, origin.x), visible.maxX - badge.frame.width - 8)
        origin.y = min(max(visible.minY + 8, origin.y), visible.maxY - badge.frame.height - 8)
        badge.setFrameOrigin(origin)
        UserDefaults.standard.set("\(origin.x),\(origin.y)", forKey: Pref.badgeOrigin)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSSound.beep()
        }
    }

    private func launchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    @objc private func setAppearanceMode(_ sender: NSMenuItem) {
        let modes = ["system", "light", "dark"]
        UserDefaults.standard.set(modes[sender.tag], forKey: Pref.appearance)
        applyAppearance()
    }

    // MARK: - State

    private func toggleActive() {
        if active {
            stop()
        } else {
            start(duration: nil)
        }
    }

    private var sessionStartedAt: Date?

    private func start(duration seconds: TimeInterval?) {
        if !active {
            createAssertions()
            guard assertionID != 0 else {
                NSSound.beep()
                return
            }
            active = true
            sessionStartedAt = Date()
        }
        duration = seconds
        endDate = seconds.map { Date().addingTimeInterval($0) }
        warnedEnding = false
        startTicker()
        startBatteryGuard()
        persistSession()
        refreshAll()
    }

    private func stop() {
        if active {
            releaseAssertions()
            active = false
        }
        ticker?.invalidate()
        ticker = nil
        endDate = nil
        duration = nil
        warnedEnding = false
        stopBatteryGuard()
        clearPersistedSession()
        if let started = sessionStartedAt {
            let mins = Int(Date().timeIntervalSince(started) / 60)
            if mins >= 5 {
                let content = UNMutableNotificationContent()
                content.title = "Session complete"
                content.body = "Kept your Mac awake for \(mins) min"
                content.sound = .default
                UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "matcha.summary.\(UUID().uuidString)", content: content, trigger: nil))
            }
            sessionStartedAt = nil
        }
        refreshAll()
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard active, let end = endDate else { return }
        let remaining = end.timeIntervalSinceNow
        if remaining <= 0 {
            stop()
            NSSound.beep()
            return
        }
        if remaining <= 300, !warnedEnding {
            warnedEnding = true
            warnSessionEnding()
        }
        refreshAll()
    }

    private func warnSessionEnding() {
        if triggerBusy {
            endDate = endDate?.addingTimeInterval(1800)
            duration = duration.map { $0 + 1800 }
            warnedEnding = false
            persistSession()
            let content = UNMutableNotificationContent()
            content.title = "Still working — extended 30 minutes"
            content.body = "A build is still running, so Matcha is keeping your Mac awake."
            content.sound = .default
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "matcha.extended", content: content, trigger: nil)
            )
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Matcha stops in 5 minutes"
        content.body = "Add an hour or stop now."
        content.categoryIdentifier = "ENDING"
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "matcha.ending", content: content, trigger: nil)
        )
    }

    // MARK: - Session persistence

    private func persistSession() {
        let defaults = UserDefaults.standard
        defaults.set(active, forKey: Pref.sessionActive)
        defaults.set(endDate?.timeIntervalSince1970 ?? 0, forKey: Pref.sessionEnd)
        defaults.set(duration ?? 0, forKey: Pref.sessionDuration)
    }

    private func clearPersistedSession() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: Pref.sessionActive)
        defaults.set(0.0, forKey: Pref.sessionEnd)
        defaults.set(0.0, forKey: Pref.sessionDuration)
    }

    private func restoreSession() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: Pref.sessionActive) else { return }

        let stamp = defaults.double(forKey: Pref.sessionEnd)
        let savedDuration = defaults.double(forKey: Pref.sessionDuration)
        if stamp > 0 {
            let end = Date(timeIntervalSince1970: stamp)
            guard end.timeIntervalSinceNow > 0 else {
                clearPersistedSession()
                return
            }
            endDate = end
            duration = savedDuration > 0 ? savedDuration : end.timeIntervalSinceNow
        } else {
            endDate = nil
            duration = nil
        }

        createAssertions()
        guard assertionID != 0 else {
            endDate = nil
            duration = nil
            clearPersistedSession()
            return
        }
        active = true
        startTicker()
        startBatteryGuard()
    }

    // MARK: - Battery guard

    private func startBatteryGuard() {
        guard Battery.hasBattery, batteryTimer == nil else { return }
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkBattery()
        }
        RunLoop.main.add(timer, forMode: .common)
        batteryTimer = timer
    }

    private func stopBatteryGuard() {
        batteryTimer?.invalidate()
        batteryTimer = nil
    }

    private func checkBattery() {
        guard active,
              UserDefaults.standard.bool(forKey: Pref.batteryGuard),
              let status = Battery.status(),
              status.onBattery,
              status.percent > 0,
              status.percent <= 20
        else { return }

        stop()
        let content = UNMutableNotificationContent()
        content.title = "Matcha stopped to save battery"
        content.body = "Battery is at \(status.percent)%. Plug in and start a session when you're ready."
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "matcha.battery", content: content, trigger: nil)
        )
    }

    private func createAssertions() {
        let reason = "User chose to keep this Mac awake" as CFString
        var id: IOPMAssertionID = 0
        if IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &id
        ) == kIOReturnSuccess {
            assertionID = id
        }
        if UserDefaults.standard.bool(forKey: Pref.keepDisplayOn) {
            startDisplayKeepAlive()
        }
    }

    private func startDisplayKeepAlive() {
        guard displayKeepAlive == nil else { return }
        renewDisplayKeepAlive()

        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.renewDisplayKeepAlive()
        }
        RunLoop.main.add(timer, forMode: .common)
        displayKeepAlive = timer
    }

    private func renewDisplayKeepAlive() {
        caffeinateProcess?.terminate()
        caffeinateProcess = nil

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = ["-d", "-u", "-t", "40"]
        do {
            try process.run()
            caffeinateProcess = process
        } catch {
            guard displayAssertionID == 0 else { return }
            var displayID: IOPMAssertionID = 0
            if IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "User chose to keep this Mac awake" as CFString,
                &displayID
            ) == kIOReturnSuccess {
                displayAssertionID = displayID
            }
        }
    }

    private func stopDisplayKeepAlive() {
        displayKeepAlive?.invalidate()
        displayKeepAlive = nil
        caffeinateProcess?.terminate()
        caffeinateProcess = nil
        if displayAssertionID != 0 {
            IOPMAssertionRelease(displayAssertionID)
            displayAssertionID = 0
        }
    }

    private func releaseAssertions() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
        stopDisplayKeepAlive()
    }

    private func refreshAll() {
        let state = MatchaState(
            active: active,
            endDate: endDate,
            duration: duration,
            triggerBusy: triggerBusy
        )
        popoverPanel?.apply(state: state)
        windowPanel?.apply(state: state)
        windowTint?.setActive(active)
        badge?.translucent = UserDefaults.standard.bool(forKey: Pref.translucentIndicator)
        badge?.update(state: state)

        let showBadge = UserDefaults.standard.bool(forKey: Pref.showFloatingIndicator) && active
        if showBadge {
            showBadgeIfNeeded()
        } else {
            badge?.orderOut(nil)
        }

        updateStatusItem()
        writeStatus()
    }

    private func showBadgeIfNeeded() {
        guard let badge else { return }
        if !badge.isVisible {
            badge.setFrameOrigin(savedBadgeOrigin() ?? defaultBadgeOrigin())
            badge.orderFrontRegardless()
        }
    }

    private func savedBadgeOrigin() -> NSPoint? {
        guard let raw = UserDefaults.standard.string(forKey: Pref.badgeOrigin) else { return nil }
        let parts = raw.split(separator: ",")
        guard parts.count == 2, let x = Double(parts[0]), let y = Double(parts[1]) else { return nil }
        return NSPoint(x: x, y: y)
    }

    private func defaultBadgeOrigin() -> NSPoint {
        guard let screen = NSScreen.main else { return NSPoint(x: 200, y: 200) }
        let frame = screen.visibleFrame
        let size = badge?.frame.width ?? 78
        return NSPoint(x: frame.maxX - size - 24, y: frame.minY + 24)
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        button.image = symbolImage(
            active
                ? ["cup.and.saucer.fill", "cup.and.saucer", "mug.fill", "mug"]
                : ["cup.and.saucer", "mug"]
        )
        button.contentTintColor = active ? Matcha.green : nil
        let showTime = UserDefaults.standard.bool(forKey: Pref.menuBarCountdown)
        if active, showTime {
            button.title = endDate.map { " " + Fmt.clock($0.timeIntervalSinceNow) } ?? " \u{221E}"
        } else {
            button.title = ""
        }
    }
}
