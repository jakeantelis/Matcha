import AppKit
import IOKit.ps

extension NSView {
    func findSubview(withIdentifier id: NSUserInterfaceItemIdentifier) -> NSView? {
        if identifier == id { return self }
        for sub in subviews {
            if let found = sub.findSubview(withIdentifier: id) { return found }
        }
        return nil
    }
}

extension Notification.Name {
    static let matchaPrefsChanged = Notification.Name("matchaPrefsChanged")
}

enum Battery {
    struct Status {
        let onBattery: Bool
        let percent: Int
    }

    private static func internalBattery() -> [String: Any]? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any]
            else { continue }
            if let type = info[kIOPSTypeKey] as? String, type == kIOPSInternalBatteryType {
                return info
            }
        }
        return nil
    }

    static var hasBattery: Bool {
        internalBattery() != nil
    }

    static func status() -> Status? {
        guard let info = internalBattery() else { return nil }
        let state = info[kIOPSPowerSourceStateKey] as? String ?? ""
        let current = info[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maximum = info[kIOPSMaxCapacityKey] as? Int ?? 100
        let percent = maximum > 0 ? Int((Double(current) / Double(maximum)) * 100) : current
        return Status(
            onBattery: state == kIOPSBatteryPowerValue,
            percent: min(100, max(0, percent))
        )
    }
}

struct MatchaState {
    var active: Bool = false
    var endDate: Date?
    var duration: TimeInterval?
    var triggerBusy: Bool = false
    var agentRunning: Bool = false
    var agentNames: [String] = []
}

enum Matcha {
    static let green = NSColor(
        calibratedRed: 0.26,
        green: 0.60,
        blue: 0.30,
        alpha: 1
    )
}

enum Pref {
    static let showMenuBarIcon = "showMenuBarIcon"
    static let menuBarCountdown = "menuBarCountdown"
    static let showFloatingIndicator = "showFloatingIndicator"
    static let translucentIndicator = "translucentIndicator"
    static let keepDisplayOn = "keepDisplayOn"
    static let appearance = "appearance"
    static let badgeOrigin = "badgeOrigin"
    static let badgeSize = "badgeSize"
    static let batteryGuard = "batteryGuard"
    static let sessionActive = "sessionActive"
    static let sessionEnd = "sessionEnd"
    static let sessionDuration = "sessionDuration"
    static let autoTriggers = "autoTriggers"
    static let customAgents = "customAgents"
    static let showTips = "showTips"
    static let animations = "animations"
    static let firstRunHintShown = "firstRunHintShown"
    static let autoStartAgents = "autoStartAgents"
    static let watchApps = "watchApps"
    static let awakeTotal = "awakeTotal"
    static let awakeToday = "awakeToday"
    static let awakeTodayDate = "awakeTodayDate"
    static let showInDock = "showInDock"
    static let sessionHistory = "sessionHistory"
    static let batteryThreshold = "batteryThreshold"
    static let idleAutoStop = "idleAutoStop"
    static let idleAutoStopMinutes = "idleAutoStopMinutes"
    static let sessionTemplates = "sessionTemplates"
    static let schedules = "schedules"
    static let networkGuard = "networkGuard"
    static let clamshellMode = "clamshellMode"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            showMenuBarIcon: true,
            menuBarCountdown: true,
            showFloatingIndicator: true,
            translucentIndicator: true,
            keepDisplayOn: true,
            appearance: "system",
            autoTriggers: true,
            badgeSize: "medium",
            batteryGuard: true,
            showTips: false,
            animations: true,
            firstRunHintShown: false,
            autoStartAgents: false,
            showInDock: true,
            batteryThreshold: 20,
            idleAutoStop: false,
            idleAutoStopMinutes: 10,
            networkGuard: false,
            clamshellMode: false,
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

            // parse optional unit word (allow a space after the number)
            while pos < s.endIndex && s[pos].isWhitespace {
                pos = s.index(after: pos)
            }
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

    static func parseClockTime(_ text: String) -> Date? {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "a.m.", with: "am")
            .replacingOccurrences(of: "p.m.", with: "pm")
        guard !cleaned.isEmpty else { return nil }

        var body = cleaned
        var isPM = false
        if body.hasSuffix("pm") { isPM = true; body.removeLast(2) }
        else if body.hasSuffix("am") { body.removeLast(2) }

        let parts = body.split(separator: ":").map(String.init)
        var hour: Int
        var minute = 0
        if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) {
            hour = h; minute = m
        } else if parts.count == 1, let h = Int(parts[0]) {
            hour = h
        } else {
            return nil
        }
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }

        if isPM, hour < 12 { hour += 12 }
        if !isPM, hour == 12 { hour = 0 }

        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        guard var date = cal.date(from: comps) else { return nil }
        if date <= Date() { date = date.addingTimeInterval(86400) }
        return date
    }

    static func remainingText(_ state: MatchaState) -> String {
        guard let end = state.endDate else { return "Until you stop" }
        return "\(clock(end.timeIntervalSinceNow)) left \u{00B7} ends \(clockTime.string(from: end))"
    }

    static func remainingShort(_ state: MatchaState) -> String {
        guard let end = state.endDate else { return "On" }
        return clock(end.timeIntervalSinceNow)
    }

    static func clockShort(_ interval: TimeInterval) -> String {
        let seconds = Int(max(0, interval.rounded()))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return "\(hours)h\(String(format: "%02d", minutes))m"
        }
        return String(format: "%d:%02d", minutes, secs)
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

func animationsEnabled() -> Bool {
    UserDefaults.standard.bool(forKey: Pref.animations)
        && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
}

func matchaMark(size: CGFloat, active: Bool = true) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let r = size * 0.24
    let bg = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size), xRadius: r, yRadius: r)
    let grad = NSGradient(colors: active
        ? [NSColor(srgbRed: 0.42, green: 0.74, blue: 0.52, alpha: 1),
           NSColor(srgbRed: 0.22, green: 0.55, blue: 0.36, alpha: 1)]
        : [NSColor(srgbRed: 0.72, green: 0.76, blue: 0.80, alpha: 1),
           NSColor(srgbRed: 0.60, green: 0.65, blue: 0.69, alpha: 1)]
    )
    grad?.draw(in: bg, angle: -90)
    if let cup = symbolImage(["cup.and.saucer.fill", "mug.fill", "mug"])?
        .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: size * 0.50, weight: .semibold)) {
        let white = tinted(cup, active ? .white : NSColor(srgbRed: 0.94, green: 0.95, blue: 0.96, alpha: 1))
        white.draw(in: NSRect(x: (size - white.size.width) / 2, y: (size - white.size.height) / 2, width: white.size.width, height: white.size.height))
    }
    image.unlockFocus()
    image.isTemplate = false
    return image
}


enum AgentRegistry {
    static let builtIn: [(name: String, label: String)] = [
        ("claude", "Claude Code"),
        ("codex", "Codex"),
        ("opencode", "opencode"),
        ("aider", "Aider"),
        ("cursor", "Cursor"),
        ("gemini", "Gemini CLI"),
        ("windsurf", "Windsurf"),
        ("continue", "Continue"),
        ("copilot", "Copilot"),
        ("cline", "Cline"),
        ("roo", "Roo Code"),
        ("augment", "Augment"),
        ("crush", "Crush"),
        ("amp", "Amp"),
        ("goose", "Goose"),
        ("ollama", "Ollama"),
        ("devin", "Devin"),
        ("openhands", "OpenHands"),
        ("swe-agent", "SWE-agent"),
        ("qwen", "Qwen Code"),
        ("kimi", "Kimi CLI"),
        ("kiro", "Kiro"),
        ("junie", "Junie"),
        ("amazon-q", "Amazon Q"),
        ("cody", "Cody"),
        ("tabnine", "Tabnine"),
        ("tabby", "Tabby"),
        ("kilo", "Kilo Code"),
        ("plandex", "Plandex"),
        ("codebuff", "Codebuff"),
        ("forgecode", "Forge"),
        ("open-interpreter", "Open Interpreter"),
        ("gpt-engineer", "GPT Engineer"),
        ("autogpt", "AutoGPT"),
        ("letta", "Letta"),
        ("agent-zero", "Agent Zero"),
        ("devika", "Devika"),
        ("trae", "Trae"),
        ("replit", "Replit Agent"),
        ("deepseek", "DeepSeek"),
        ("gptme", "gptme"),
        ("ra-aid", "RA.Aid"),
        ("kodu", "Kodu"),
        ("openchamber", "OpenChamber"),
    ]

    static var builtInNames: Set<String> { Set(builtIn.map(\.name)) }

    static var builtInLabels: [String: String] {
        Dictionary(uniqueKeysWithValues: builtIn.map { ($0.name, $0.label) })
    }

    static var customNames: [String] {
        var names = (UserDefaults.standard.stringArray(forKey: Pref.customAgents) ?? [])
            .map { normalize($0) }
            .filter { !$0.isEmpty }
        if let text = try? String(contentsOf: agentsFile, encoding: .utf8) {
            for line in text.split(separator: "\n") {
                let value = normalize(String(line))
                if !value.isEmpty { names.append(value) }
            }
        }
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
    }

    static var allNames: Set<String> { builtInNames.union(customNames) }

    static var agentsFile: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Matcha", isDirectory: true)
            .appendingPathComponent("agents.txt")
    }

    static func label(for name: String) -> String {
        builtInLabels[name] ?? name
    }

    @discardableResult
    static func addCustom(_ raw: String) -> Bool {
        let name = normalize(raw)
        guard !name.isEmpty, !builtInNames.contains(name) else { return false }
        var names = UserDefaults.standard.stringArray(forKey: Pref.customAgents) ?? []
        guard !names.contains(name) else { return false }
        names.append(name)
        UserDefaults.standard.set(names, forKey: Pref.customAgents)
        return true
    }

    static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard !trimmed.isEmpty else { return "" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return "" }
        return trimmed.lowercased()
    }
}

enum SessionHistory {
    struct Entry: Codable {
        let startedAt: Date
        let duration: TimeInterval
        let source: String
    }

    static let maxEntries = 20

    static func add(startedAt: Date, duration: TimeInterval, source: String) {
        var entries = all
        entries.append(Entry(startedAt: startedAt, duration: duration, source: source))
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Pref.sessionHistory)
        }
    }

    static var all: [Entry] {
        guard let data = UserDefaults.standard.data(forKey: Pref.sessionHistory),
              let entries = try? JSONDecoder().decode([Entry].self, from: data)
        else { return [] }
        return entries
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: Pref.sessionHistory)
    }
}

struct SessionTemplate: Codable, Equatable {
    let name: String
    let durationSeconds: TimeInterval
    let isEndless: Bool
}

enum TemplateStore {
    static var all: [SessionTemplate] {
        guard let data = UserDefaults.standard.data(forKey: Pref.sessionTemplates),
              let templates = try? JSONDecoder().decode([SessionTemplate].self, from: data)
        else { return [] }
        return templates
    }

    static func save(_ templates: [SessionTemplate]) {
        if let data = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(data, forKey: Pref.sessionTemplates)
        }
    }

    static func add(_ template: SessionTemplate) {
        var templates = all
        if let idx = templates.firstIndex(where: { $0.name == template.name }) {
            templates[idx] = template
        } else {
            templates.append(template)
        }
        save(templates)
    }

    static func remove(named name: String) {
        save(all.filter { $0.name != name })
    }
}

struct Schedule: Codable, Equatable {
    let name: String
    let weekdays: [Int]
    let hour: Int
    let minute: Int
    let durationSeconds: TimeInterval
    let isEndless: Bool

    func appliesTo(date: Date) -> Bool {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date) - 1
        guard weekdays.contains(weekday) else { return false }
        return cal.component(.hour, from: date) == hour && cal.component(.minute, from: date) == minute
    }
}

enum ScheduleStore {
    static var all: [Schedule] {
        guard let data = UserDefaults.standard.data(forKey: Pref.schedules),
              let schedules = try? JSONDecoder().decode([Schedule].self, from: data)
        else { return [] }
        return schedules
    }

    static func save(_ schedules: [Schedule]) {
        if let data = try? JSONEncoder().encode(schedules) {
            UserDefaults.standard.set(data, forKey: Pref.schedules)
        }
    }

    static func add(_ schedule: Schedule) {
        var schedules = all
        if let idx = schedules.firstIndex(where: { $0.name == schedule.name }) {
            schedules[idx] = schedule
        } else {
            schedules.append(schedule)
        }
        save(schedules)
    }

    static func remove(named name: String) {
        save(all.filter { $0.name != name })
    }
}
