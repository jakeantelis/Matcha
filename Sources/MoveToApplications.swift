import AppKit

enum MoveToApplications {
    private static let askedKey = "moveToApplicationsAsked"
    private static let destination = URL(fileURLWithPath: "/Applications/Matcha.app")

    static func offerIfNeeded() -> Bool {
        let path = Bundle.main.bundlePath
        guard InstallLocation.shouldOffer(path: path), !UserDefaults.standard.bool(forKey: askedKey) else { return false }
        UserDefaults.standard.set(true, forKey: askedKey)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Move Matcha to your Applications folder?"
        alert.informativeText = "Matcha will live there from now on, so it is easy to find and keeps working after you eject the disk image."
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Not now")
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        return move(from: URL(fileURLWithPath: path))
    }

    private static func move(from source: URL) -> Bool {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) {
            let replace = NSAlert()
            replace.messageText = "Replace the Matcha already in Applications?"
            replace.informativeText = "The older copy will be moved to the Trash."
            replace.addButton(withTitle: "Replace")
            replace.addButton(withTitle: "Cancel")
            guard replace.runModal() == .alertFirstButtonReturn else { return false }
            NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
                .filter { $0 != NSRunningApplication.current }.forEach { $0.terminate() }
            do { try fm.trashItem(at: destination, resultingItemURL: nil) } catch { return failed() }
        }
        do { try fm.copyItem(at: source, to: destination) } catch { return failed() }

        var script = "sleep 0.8; /usr/bin/open -n '\(destination.path)'"
        if source.path.hasPrefix("/Volumes/") {
            let volume = source.pathComponents.prefix(3).joined(separator: "/").replacingOccurrences(of: "//", with: "/")
            script += "; sleep 2; /usr/sbin/diskutil eject '\(volume)' >/dev/null 2>&1"
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        try? process.run()
        NSApp.terminate(nil)
        return true
    }

    private static func failed() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Matcha could not be moved"
        alert.informativeText = "That is fine. You can drag Matcha into the Applications folder yourself, or just keep using it from here."
        alert.runModal()
        return false
    }
}
