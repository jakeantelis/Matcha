import AppKit

let app = NSApplication.shared

let arguments = CommandLine.arguments
if let index = arguments.firstIndex(of: "--render"), index + 1 < arguments.count {
    var agents: [String] = []
    if let ai = arguments.firstIndex(of: "--agents"), ai + 1 < arguments.count {
        agents = arguments[ai + 1].split(separator: ",").map(String.init)
    }
    Render.panel(
        to: arguments[index + 1],
        dark: arguments.contains("--dark"),
        active: !arguments.contains("--idle"),
        agents: agents,
        card: arguments.contains("--card")
    )
    exit(0)
}
if let index = arguments.firstIndex(of: "--render-badge"), index + 1 < arguments.count {
    Render.badge(
        to: arguments[index + 1],
        dark: arguments.contains("--dark"),
        active: !arguments.contains("--idle"),
        translucent: !arguments.contains("--opaque")
    )
    exit(0)
}

let controller = Controller()
app.delegate = controller
app.run()
