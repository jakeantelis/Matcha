import AppKit
import IOKit.pwr_mgt
import ServiceManagement

final class Controller: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation {

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var window: NSWindow?
    private var popoverPanel: PanelView?
    private var windowPanel: PanelView?
    private var badge: FloatingBadge?

    private var active = false
    private var endDate: Date?
    private var duration: TimeInterval?
    private var ticker: Timer?
    private var assertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0

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

        badge = FloatingBadge()
        badge?.onClick = { [weak self] in self?.presentBadgeMenu() }
        badge?.onRightClick = { [weak self] in self?.presentBadgeMenu() }
        badge?.onMoved = { origin in
            UserDefaults.standard.set("\(origin.x),\(origin.y)", forKey: Pref.badgeOrigin)
        }

        createWindow()
        applyPreferences()
        refreshAll()
        showWindow()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showWindow() }
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

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
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Matcha", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Matcha", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        NSApp.mainMenu = main
    }

    private func createWindow() {
        let panel = PanelView()
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
            button.image = symbolImage(["mug", "cup.and.saucer"])
            button.action = #selector(statusClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
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

        menu.addItem(toggleItem("Keep Display On", Pref.keepDisplayOn, #selector(toggleKeepDisplay(_:))))
        menu.addItem(toggleItem("Show in Menu Bar", Pref.showMenuBarIcon, #selector(toggleMenuBarIcon(_:))))
        menu.addItem(toggleItem("Show Floating Indicator", Pref.showFloatingIndicator, #selector(toggleFloatingIndicator(_:))))
        menu.addItem(toggleItem("Translucent Indicator", Pref.translucentIndicator, #selector(toggleTranslucent(_:))))

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

        let openItem = NSMenuItem(title: "Open Window", action: #selector(showWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(
            NSMenuItem(title: "Quit Matcha", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        )
        return menu
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
        if active, endDate != nil {
            endDate = endDate!.addingTimeInterval(seconds)
            duration = duration.map { $0 + seconds }
            refreshAll()
        } else {
            start(duration: seconds)
        }
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

    private func start(duration seconds: TimeInterval?) {
        if !active {
            createAssertions()
            guard assertionID != 0 else {
                NSSound.beep()
                return
            }
            active = true
        }
        duration = seconds
        endDate = seconds.map { Date().addingTimeInterval($0) }
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
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
        refreshAll()
    }

    private func tick() {
        guard active, let end = endDate else { return }
        if end.timeIntervalSinceNow <= 0 {
            stop()
            NSSound.beep()
            return
        }
        refreshAll()
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
            var displayID: IOPMAssertionID = 0
            if IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &displayID
            ) == kIOReturnSuccess {
                displayAssertionID = displayID
            }
        }
    }

    private func releaseAssertions() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
        if displayAssertionID != 0 {
            IOPMAssertionRelease(displayAssertionID)
            displayAssertionID = 0
        }
    }

    private func refreshAll() {
        let state = CaffeinateState(active: active, endDate: endDate, duration: duration)
        popoverPanel?.apply(state: state)
        windowPanel?.apply(state: state)
        badge?.translucent = UserDefaults.standard.bool(forKey: Pref.translucentIndicator)
        badge?.update(state: state)

        let showBadge = UserDefaults.standard.bool(forKey: Pref.showFloatingIndicator) && active
        if showBadge {
            showBadgeIfNeeded()
        } else {
            badge?.orderOut(nil)
        }

        updateStatusItem()
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
        button.contentTintColor = active ? .controlAccentColor : nil
        if active, let end = endDate {
            button.title = " " + Fmt.clock(end.timeIntervalSinceNow)
        } else {
            button.title = ""
        }
    }
}
