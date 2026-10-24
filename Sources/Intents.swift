import AppKit
import AppIntents

@available(macOS 13.0, *)
struct MatchaStartIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Matcha"
    static var description = IntentDescription("Keep your Mac awake. Optional duration like 2h, 90m, or 8 hours.")

    @Parameter(title: "Duration", description: "e.g. 2h, 90m, 8 hours. Empty = until stopped.")
    var duration: String?

    func perform() async throws -> some IntentResult {
        let matcha = "/Applications/Matcha.app"
        let matchactl = "\(matcha)/Contents/Resources/matchactl"
        let dur = (duration ?? "").isEmpty ? nil : duration
        let task = Process()
        task.executableURL = URL(fileURLWithPath: matchactl)
        task.arguments = ["on"] + (dur.map { [$0] } ?? [])
        try? task.run()
        task.waitUntilExit()
        return .result()
    }
}

@available(macOS 13.0, *)
struct MatchaStopIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Matcha"
    static var description = IntentDescription("Stop the active Matcha keep-awake session.")

    func perform() async throws -> some IntentResult {
        let matchactl = "/Applications/Matcha.app/Contents/Resources/matchactl"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: matchactl)
        task.arguments = ["off"]
        try? task.run()
        task.waitUntilExit()
        return .result()
    }
}

@available(macOS 13.0, *)
struct MatchaToggleIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Matcha"
    static var description = IntentDescription("Start or stop Matcha depending on current state.")

    func perform() async throws -> some IntentResult {
        let matchactl = "/Applications/Matcha.app/Contents/Resources/matchactl"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: matchactl)
        task.arguments = ["toggle"]
        try? task.run()
        task.waitUntilExit()
        return .result()
    }
}

@available(macOS 13.0, *)
struct MatchaExtendIntent: AppIntent {
    static var title: LocalizedStringResource = "Extend Matcha"
    static var description = IntentDescription("Add time to the active session.")

    @Parameter(title: "Duration", description: "e.g. 30m, 1h")
    var duration: String

    func perform() async throws -> some IntentResult {
        let matchactl = "/Applications/Matcha.app/Contents/Resources/matchactl"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: matchactl)
        task.arguments = ["extend", duration]
        try? task.run()
        task.waitUntilExit()
        return .result()
    }
}

@available(macOS 13.0, *)
struct MatchaStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Matcha Status"
    static var description = IntentDescription("Get the current Matcha session status.")

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let matchactl = "/Applications/Matcha.app/Contents/Resources/matchactl"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: matchactl)
        task.arguments = ["status"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let status = String(data: data, encoding: .utf8) ?? "unknown"
        return .result(value: status.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

@available(macOS 13.0, *)
struct MatchaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: MatchaStartIntent(), phrases: [
            "start \(.applicationName)",
            "keep awake with \(.applicationName)",
        ], shortTitle: "Start", systemImageName: "cup.and.saucer.fill")
        AppShortcut(intent: MatchaStopIntent(), phrases: [
            "stop \(.applicationName)",
        ], shortTitle: "Stop", systemImageName: "leaf")
        AppShortcut(intent: MatchaToggleIntent(), phrases: [
            "toggle \(.applicationName)",
        ], shortTitle: "Toggle", systemImageName: "arrow.triangle.2.circlepath")
        AppShortcut(intent: MatchaStatusIntent(), phrases: [
            "\(.applicationName) status",
        ], shortTitle: "Status", systemImageName: "info.circle")
    }
}
