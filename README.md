# Matcha

A minimalist macOS menu bar / desktop app that keeps your Mac awake — no triggers to fiddle with, just click and go.

- **Start / Stop** with one click
- **Presets** — 2h, 4h, 8h, ∞ (until you stop)
- **Type a duration** — "8", "2.5h", "1d", "2h 30m" all work (bare numbers are treated as hours)
- **Floating indicator** — a draggable, translucent circle showing the remaining time; right-click (or click) it for quick control: stop, +1h / +4h, set duration
- **Optional menu bar icon** with the same controls
- Keep display on (in addition to preventing system sleep)
- Launch at login, light/dark/system appearance

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