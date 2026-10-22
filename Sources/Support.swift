import AppKit

struct MatchaState {
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
    static let autoTriggers = "autoTriggers"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            showMenuBarIcon: true,
            showFloatingIndicator: true,
            translucentIndicator: true,
            keepDisplayOn: false,
            appearance: "system",
            autoTriggers: true,
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
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let s = trimmed.lowercased()
        var total: TimeInterval = 0
        var pos = s.startIndex

        while pos < s.endIndex {
            // skip whitespace between tokens
            while pos < s.endIndex && s[pos].isWhitespace {
                pos = s.index(after: pos)
            }
            guard pos < s.endIndex else { break }

            // parse a number
            let numberStart = pos
            var sawDot = false
            while pos < s.endIndex {
                let c = s[pos]
                if c.isNumber {
                    pos = s.index(after: pos)
                } else if c == "." && !sawDot {
                    sawDot = true
                    pos = s.index(after: pos)
                } else {
                    break
                }
            }
            guard numberStart != pos, let value = Double(s[numberStart..<pos]) else {
                return nil
            }

            // parse optional unit word
            let unitStart = pos
            while pos < s.endIndex && s[pos].isLetter {
                pos = s.index(after: pos)
            }
            let unit = String(s[unitStart..<pos])

            switch unit {
            case "d", "day", "days":
                total += value * 86400
            case "h", "hr", "hrs", "hour", "hours":
                total += value * 3600
            case "m", "min", "mins", "minute", "minutes":
                total += value * 60
            case "s", "sec", "secs", "second", "seconds":
                total += value
            case "":
                total += value * 3600
            default:
                return nil
            }
        }

        return total > 0 ? total : nil
    }

    static func remainingText(_ state: MatchaState) -> String {
        guard let end = state.endDate else { return "Until you stop" }
        return "\(clock(end.timeIntervalSinceNow)) left \u{00B7} ends \(clockTime.string(from: end))"
    }

    static func remainingShort(_ state: MatchaState) -> String {
        guard let end = state.endDate else { return "On" }
        return clock(end.timeIntervalSinceNow)
    }
}

func symbolImage(_ names: [String]) -> NSImage? {
    for name in names {
        if let image = NSImage(systemSymbolName: name, accessibilityDescription: "Matcha") {
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
