# Matcha

A minimalist macOS menu bar / desktop app that keeps your Mac awake — no triggers to fiddle with, just click and go.

- **Start / Stop** with one click
- **Presets** — 2h, 4h, 8h, ∞ (until you stop)
- **Type a duration** — "8", "2.5h", "1d", "2h 30m" all work (bare numbers are treated as hours)
- **Floating indicator** — a draggable, translucent circle showing the remaining time; right-click (or click) it for quick control: stop, +1h / +4h, set duration
- **Optional menu bar icon** with the same controls
- **Auto-keep awake for code** — watches for real build/encode tools (`xcodebuild`, `swiftc`, `clang`, `make`, `cmake`, `ninja`, `cargo`, `rustc`, `go`, `zig`, `ffmpeg`, …) and sustained high CPU; if you step away (3+ min idle) while something is running, it offers to keep the Mac awake via a notification. Idle AI-assistant apps are deliberately ignored; agents should report long jobs via `matchactl on <duration>`.
- Keep display on and prevent the screen saver / lock screen (in addition to preventing system sleep)
- Launch at login, light/dark/system appearance
- **Automation** — CLI + `matcha://` URL scheme so scripts or AI agents can query and control it

## Automation

Any script or AI agent can drive Matcha:

```sh
matchactl on            # until stopped
matchactl on 2          # 2 hours
matchactl extend 1      # add an hour
matchactl off
matchactl toggle
matchactl status        # -> on (3598s left) / coding activity: true
```

The CLI lives inside the bundle:

```sh
/Applications/Matcha.app/Contents/Resources/matchactl status
```

Or use the URL scheme directly:

```sh
open -g "matcha://on?hours=2"
open -g "matcha://on?minutes=45"
open -g "matcha://extend?hours=1"
open -g "matcha://off"
open -g "matcha://toggle"
```

`-g` keeps Matcha in the background. Status is published to
`~/Library/Application Support/Matcha/status.plist` for tooling.

## Requirements

- macOS 11.0+
- Xcode Command Line Tools (`swiftc`)

## Build & install

```sh
./build.sh install
```

This compiles the Swift sources, bundles `AppIcon.icns`, ad-hoc codesigns, and installs to `/Applications/Matcha.app`.

Other modes:

```sh
./build.sh build      # build only, into build/Matcha.app
./build.sh package    # build + create dist/Matcha.zip
```

## Generate the app icon

```sh
swift Tools/make-icon.swift ./Resources
iconutil -c icns ./Resources/AppIcon.iconset -o ./Resources/AppIcon.icns
```

## Preview render (for screenshots)

```sh
build/Matcha.app/Contents/MacOS/Matcha --render panel-idle.png --idle
build/Matcha.app/Contents/MacOS/Matcha --render panel-active.png
build/Matcha.app/Contents/MacOS/Matcha --render-badge badge.png --active
```

## License

[MIT](LICENSE)