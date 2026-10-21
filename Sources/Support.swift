import AppKit

struct CaffeinateState {
    var active: Bool = false
    var endDate: Date?
    var duration: TimeInterval?
}

enum Matcha {
    static let green = NSColor(
        calibratedRed: 0.28,
        green: 0.62,
        blue: 0.36,
        alpha: 1
    )
}

enum Pref {
    static let showMenuBarIcon = "showMenuBarIcon"
    static let showFloatingIndicator = "showFloatingIndicator"
    static let translucentIndicator = "translucentIndicator"
    static let keepDisplayOn = "keepDisplayOn"
    static let appearance = "appearance"
    static let badgeOrigin = "badgeOrigin"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            showMenuBarIcon: true,
            showFloatingIndicator: true,
            translucentIndicator: true,
            keepDisplayOn: false,
            appearance: "system",
        ])
    }
}

enum Fmt {
    static let clockTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    static func clock(_ interval: TimeInterval) -> String {
        let seconds = Int(max(0, interval.rounded()))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    static func parseDuration(_ text: String) -> TimeInterval? {
        var total: TimeInterval = 0
        let lower = text.lowercased()
        let scanner = Scanner(string: lower)
        while !scanner.isAtEnd {
            if let num = scanner.scanDouble() {
                if scanner.scanString("d") != nil || scanner.scanString("day") != nil || scanner.scanString("days") != nil {
                    total += num * 86400
                } else if scanner.scanString("h") != nil || scanner.scanString("hr") != nil || scanner.scanString("hrs") != nil || scanner.scanString("hour") != nil || scanner.scanString("hours") != nil {
                    total += num * 3600
                } else if scanner.scanString("m") != nil || scanner.scanString("min") != nil || scanner.scanString("mins") != nil || scanner.scanString("minute") != nil || scanner.scanString("minutes") != nil {
                    total += num * 60
                } else if scanner.scanString("s") != nil || scanner.scanString("sec") != nil || scanner.scanString("secs") != nil || scanner.scanString("second") != nil || scanner.scanString("seconds") != nil {
                    total += num
                } else {
                    total += num * 3600
                }
                continue
            }
            _ = scanner.scanCharacter()
        }
        return total > 0 ? total : nil
    }

    static func remainingText(_ state: CaffeinateState) -> String {
        guard let end = state.endDate else { return "Until you stop" }
        return "\(clock(end.timeIntervalSinceNow)) left \u{00B7} ends \(clockTime.string(from: end))"
    }

    static func remainingShort(_ state: CaffeinateState) -> String {
        guard let end = state.endDate else { return "On" }
        return clock(end.timeIntervalSinceNow)
    }
}

func symbolImage(_ names: [String]) -> NSImage? {
    for name in names {
        if let image = NSImage(systemSymbolName: name, accessibilityDescription: "Caffeinate") {
            return image
        }
    }
    return nil
}

func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
    let result = NSImage(size: image.size)
    result.lockFocus()
    let rect = NSRect(origin: .zero, size: image.size)
    image.draw(in: rect)
    color.set()
    rect.fill(using: .sourceAtop)
    result.unlockFocus()
    result.isTemplate = false
    return result
}
