import Foundation

// Simple assertion helper
func assertEqual<T: Equatable>(_ lhs: T, _ rhs: T, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    if lhs != rhs {
        print("❌ FAIL: \(message) (Expected \(rhs), got \(lhs)) at \(file):\(line)")
        exit(1)
    } else {
        print("✅ PASS: \(message)")
    }
}

// Test duration parsing (Fmt.parseDuration simulation or direct test)
func parseDuration(_ text: String) -> TimeInterval? {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    let s = trimmed.lowercased()
    var total: TimeInterval = 0
    var pos = s.startIndex

    while pos < s.endIndex {
        while pos < s.endIndex && s[pos].isWhitespace {
            pos = s.index(after: pos)
        }
        guard pos < s.endIndex else { break }

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

print("--- Running Matcha Unit Tests ---")
assertEqual(parseDuration("2h"), 7200, "2 hours")
assertEqual(parseDuration("90m"), 5400, "90 minutes")
assertEqual(parseDuration("2.5h"), 9000, "2.5 hours")
assertEqual(parseDuration("1d"), 86400, "1 day")
assertEqual(parseDuration("8 hours"), 28800, "8 hours with space")
assertEqual(parseDuration("45"), 162000, "bare number defaults to hours")
print("All duration tests passed successfully!")
