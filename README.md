# Matcha

A minimalist macOS menu bar / desktop app that keeps your Mac awake — no triggers to fiddle with, just click and go.

- **Start / Stop** with one click
- **Presets** — 2h, 4h, 8h, ∞ (until you stop)
- **Type a duration** — "8", "2.5h", "1d", "2h 30m" all work (bare numbers are treated as hours)
- **Floating indicator** — a draggable, translucent circle showing the remaining time, adjustable size (Small / Medium / Large); right-click (or click) it for quick control: stop, +1h / +4h, set duration
- **Optional menu bar icon** with the same controls, plus an optional live countdown (or ∞) beside it
- **Global hotkeys** — `⌃⌥⌘M` toggles, `⌃⌥⌘1` starts one hour
- **Graceful ending** — a 5-minute warning with *Add 1 Hour* / *Stop*; auto-extends 30 minutes while a build is still running
- **Auto-keep awake for code** — watches for real build/encode tools (`xcodebuild`, `swiftc`, `clang`, `make`, `cmake`, `ninja`, `cargo`, `rustc`, `go`, `zig`, `ffmpeg`, …) and sustained high CPU; if you step away (3+ min idle) while something is running, it offers to keep the Mac awake via a notification. Idle AI-assistant apps are deliberately ignored; agents should report long jobs via `matchactl on <duration>`.
- Keep display on and prevent the screen saver / lock screen (in addition to preventing system sleep)
- **Session restore** — if Matcha crashes or is force-quit, a timed session resumes with its remaining time on next launch (an intentional Quit ends it)
- **Low battery guard** — stops a session at 20% while on battery and tells you; laptops only, hidden on Macs without a battery
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

## Agent kit

Matcha ships a skill that teaches Claude Code and opencode when to keep the Mac
awake during long work:

```sh
curl -fsSL https://raw.githubusercontent.com/jakeantelis/Matcha/main/Tools/install-agent-kit.sh | sh
```

From a checkout, run `./Tools/install-agent-kit.sh`. It installs to
`~/.claude/skills/matcha-keep-awake` and `~/.config/opencode/skills/matcha-keep-awake`;
the source is [`Agent/skills/matcha-keep-awake/SKILL.md`](Agent/skills/matcha-keep-awake/SKILL.md).
Agents start a session before long builds and stop it afterwards, leaving any
session you started yourself untouched.

If your agent has no skill support, add this to its instructions:

> Before any build, test suite, or task likely to run longer than a few minutes,
> run `matchactl on 2` (or `/Applications/Matcha.app/Contents/Resources/matchactl on 2`).
> Run `matchactl off` when it finishes. If `matchactl status` says it is already
> on, leave it alone.

## Install a release

```sh
curl -fL https://github.com/jakeantelis/Matcha/releases/latest/download/Matcha.zip -o /tmp/Matcha.zip
unzip -qo /tmp/Matcha.zip -d /Applications
xattr -dr com.apple.quarantine /Applications/Matcha.app 2>/dev/null || true
open /Applications/Matcha.app
```

Releases are universal binaries (Apple silicon + Intel).

## Requirements

- macOS 11.0+
- Xcode Command Line Tools (`swiftc`)

## Build & install

```sh
./build.sh install
```

This compiles the Swift sources, bundles `AppIcon.icns`, ad-hoc codesigns, and installs to `/Applications/Matcha.app`.
Works on laptops, Mac mini and iMac alike; battery-specific UI only appears on Macs that have a battery.

Built locally, the app is not quarantined and launches normally. A zip downloaded
from GitHub is unsigned (no paid Apple Developer ID), so Gatekeeper will warn on
first launch. Either right-click the app and choose **Open**, approve it under
**System Settings → Privacy & Security → Open Anyway**, or build it yourself with
the command above.

Other modes:

```sh
./build.sh build      # build only, into build/Matcha.app
./build.sh package    # build + create dist/Matcha.zip
```

## Release (maintainers)

```sh
./Tools/release.sh            # universal build, dist/Matcha.zip + checksum
./Tools/release.sh --publish  # same, then create the GitHub release
```

`--publish` requires the `gh` CLI and a pushed commit. Bump
`CFBundleShortVersionString` in `Resources/Info.plist` first.

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