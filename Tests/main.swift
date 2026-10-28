import Foundation

var failures = 0

func check<T: Equatable>(_ label: String, _ got: T, _ expected: T) {
    if got == expected {
        print("PASS  \(label)")
    } else {
        failures += 1
        print("FAIL  \(label) — expected \(expected), got \(got)")
    }
}

// --- Fmt.parseDuration ---
check("2h", Fmt.parseDuration("2h"), 7200)
check("90m", Fmt.parseDuration("90m"), 5400)
check("2.5h", Fmt.parseDuration("2.5h"), 9000)
check("1d", Fmt.parseDuration("1d"), 86400)
check("8 hours (space)", Fmt.parseDuration("8 hours"), 28800)
check("2h 30m (compound)", Fmt.parseDuration("2h 30m"), 9000)
check("bare number = hours", Fmt.parseDuration("45"), 162000)
check("empty is nil", Fmt.parseDuration(""), nil)
check("garbage is nil", Fmt.parseDuration("banana"), nil)
check("zero is nil", Fmt.parseDuration("0h"), nil)

// --- Fmt.parseClockTime ---
if let d = Fmt.parseClockTime("6pm") { let c = Calendar.current; check("6pm hour", c.component(.hour, from: d), 18) } else { failures += 1; print("FAIL  6pm parsed nil") }
if let d = Fmt.parseClockTime("18:30") { let c = Calendar.current; check("18:30 minute", c.component(.minute, from: d), 30) } else { failures += 1; print("FAIL  18:30 parsed nil") }
check("garbage time is nil", Fmt.parseClockTime("notatime"), nil)

// --- AgentRegistry ---
check("normalize lowercases", AgentRegistry.normalize("OpenCode"), "opencode")
check("normalize trims", AgentRegistry.normalize("  h@x "), "")
check("label for builtin", AgentRegistry.label(for: "opencode"), "opencode")
check("label for unknown falls back", AgentRegistry.label(for: "my-agent"), "my-agent")
check("builtin count >= 40", AgentRegistry.builtIn.count >= 40, true)
check("label for antigravity", AgentRegistry.label(for: "antigravity"), "Antigravity")

// --- Fmt.clockShort ---
check("clockShort 2.5h", Fmt.clockShort(9000), "2h30m")
check("clockShort 9m", Fmt.clockShort(540), "9:00")
check("clockShort 0", Fmt.clockShort(0), "0:00")
check("clockShort 1h", Fmt.clockShort(3600), "1h00m")

// --- SessionHistory ---
SessionHistory.clear()
check("history empty after clear", SessionHistory.all.count, 0)
SessionHistory.add(startedAt: Date(), duration: 1800, source: "manual")
check("history has 1 entry", SessionHistory.all.count, 1)
check("history duration", SessionHistory.all[0].duration, 1800)
check("history source", SessionHistory.all[0].source, "manual")
SessionHistory.clear()
check("history empty after clear 2", SessionHistory.all.count, 0)

// --- SessionTemplate & Schedule ---
let template = SessionTemplate(name: "Test", durationSeconds: 3600, isEndless: false)
check("template name", template.name, "Test")
check("template duration", template.durationSeconds, 3600)

let schedule = Schedule(name: "Build", weekdays: [1, 2, 3, 4, 5], hour: 9, minute: 0, durationSeconds: 7200, isEndless: false)
check("schedule name", schedule.name, "Build")
check("schedule hour", schedule.hour, 9)

print(failures == 0 ? "ALL TESTS PASSED" : "\(failures) TEST(S) FAILED")
exit(failures == 0 ? 0 : 1)