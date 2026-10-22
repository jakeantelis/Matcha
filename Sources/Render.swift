import AppKit

enum Render {
    static func panel(to path: String, dark: Bool, active: Bool) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)

        let panel = PanelView()
        var state = MatchaState()
        state.active = active
        if active {
            state.duration = 7200
            state.endDate = Date().addingTimeInterval(4530)
        }
        panel.apply(state: state)
        panel.layoutSubtreeIfNeeded()

        let pad: CGFloat = 16
        let size = NSSize(width: panel.frame.width + pad * 2, height: panel.frame.height + pad * 2)

        let image = NSImage(size: size)
        image.lockFocus()

        let card = NSBezierPath(
            roundedRect: NSRect(origin: .zero, size: size),
            xRadius: 20,
            yRadius: 20
        )
        NSColor.windowBackgroundColor.setFill()
        card.fill()

        let rep = panel.bitmapImageRepForCachingDisplay(in: panel.bounds)!
        panel.cacheDisplay(in: panel.bounds, to: rep)
        rep.draw(in: NSRect(x: pad, y: pad, width: panel.frame.width, height: panel.frame.height))

        image.unlockFocus()

        let out = NSBitmapImageRep(data: image.tiffRepresentation!)!
        try? out.representation(using: .png, properties: [:])?
            .write(to: URL(fileURLWithPath: path))
    }

    static func badge(to path: String, dark: Bool, active: Bool, translucent: Bool) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)

        let side: CGFloat = 78
        let badge = BadgeView(frame: NSRect(x: 0, y: 0, width: side, height: side))
        badge.translucent = translucent
        var state = MatchaState()
        state.active = active
        if active {
            state.duration = 7200
            state.endDate = Date().addingTimeInterval(4530)
        }
        badge.apply(state: state)

        let pad: CGFloat = 22
        let total = side + pad * 2
        let image = NSImage(size: NSSize(width: total, height: total))
        image.lockFocus()

        let colors = [NSColor.systemTeal, NSColor.systemIndigo]
        NSGradient(colors: colors)?.draw(in: NSRect(x: 0, y: 0, width: total, height: total), angle: -45)

        let rep = badge.bitmapImageRepForCachingDisplay(in: badge.bounds)!
        badge.cacheDisplay(in: badge.bounds, to: rep)
        rep.draw(in: NSRect(x: pad, y: pad, width: side, height: side))

        image.unlockFocus()

        let out = NSBitmapImageRep(data: image.tiffRepresentation!)!
        try? out.representation(using: .png, properties: [:])?
            .write(to: URL(fileURLWithPath: path))
    }
}
