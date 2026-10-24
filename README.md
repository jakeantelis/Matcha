# Matcha

**Keep your Mac awake for builds, exports, and AI coding agents.**

[![Release](https://img.shields.io/github/v/release/jakeantelis/Matcha)](https://github.com/jakeantelis/Matcha/releases)
[![License](https://img.shields.io/github/license/jakeantelis/Matcha)](LICENSE)
[![Platform](https://img.shields.io/badge/macOS-11%2B-2f6f4f)]()
[![Built with Swift](https://img.shields.io/badge/Swift-AppKit-F05138)]()

<p align="center">
  <img src="docs/shot-idle-card2.png" width="260" alt="Matcha idle — sleep allowed">
  <img src="docs/shot-active-card2.png" width="260" alt="Matcha active — awake">
</p>

<p align="center"><b>Works with</b> · Claude Code · Codex · Cursor · opencode · Aider · Gemini CLI · Windsurf · <i>and 44+ more</i></p>

Matcha is a tiny macOS menu-bar utility that keeps your display on and lock screen away while builds, exports, or AI coding agents run. See what's new in [`RELEASE_NOTES.md`](RELEASE_NOTES.md).

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/jakeantelis/Matcha/main/Tools/install.sh | sh
```

Installs to `/Applications`, launches, and configures your coding agents. Rerun to update; skip agent setup with `| sh -s -- --no-agents`.

*Requires macOS 11+ (universal — Apple Silicon & Intel). Allow notifications for the ending warning and agent prompts.*

> **Signing:** Matcha is ad-hoc signed and **not notarized by Apple**. The installer
> strips quarantine automatically, so the one-liner just works. Manual downloads
> need right-click → **Open** (or System Settings → Privacy & Security → Open Anyway)
> the first time. Notarization will come once a paid Apple Developer ID is available.

<details>
<summary>Manual install</summary>

```sh
curl -fL https://github.com/jakeantelis/Matcha/releases/latest/download/Matcha.zip -o /tmp/Matcha.zip
unzip -qo /tmp/Matcha.zip -d /Applications
xattr -dr com.apple.quarantine /Applications/Matcha.app 2>/dev/null || true
open /Applications/Matcha.app
```

The app is ad-hoc signed, not notarized. The installer strips quarantine automatically; for manual downloads use right-click → Open.

</details>

## Features

- **One-click sessions** — presets (`2h` / `4h` / ∞), natural language (`8h`, `90m`, `2.5h`, `8 hours`), or clock time (`until 6pm`).
- **Tea-fill timer** — a matcha-green ring fills and steam rises while a session runs, with the live countdown in the ring, menu bar, and floating badge.
- **Display + lock screen** — prevents the screen saver *and* lock screen, not just idle sleep (`caffeinate -d -u` + IOPM assertions).
- **Floating indicator** — a draggable desktop badge with quick actions (double-click +30m, Option-click stop; translucent by default).
- **Agent-aware** — detects 44+ coding agents and lists the active ones: *“opencode · Claude Code are running.”*
- **CLI & scripting** — `matcha run -- <cmd>` stays awake for exactly as long as the command runs.
- **Crash-safe** — timed sessions resume after a crash or force-quit; a normal Quit ends them.
- **Battery guard** — stops at 20% on battery.
- **Watch-lists & schedules** — stay awake while an app (e.g. Blender, Logic Pro) is running, or until a set clock time.
- **In-app updates** — checks on launch + daily; one-click install & restart keeps your session and mode.

## Control it your way

| Way | How |
| --- | --- |
| **Menu bar** | Click the cup icon → popover, or `⌘,` for the Settings window |
| **Floating badge** | Drag it anywhere; click for controls, right-click for quick actions |
| **Hotkeys** | `⌃⌥⌘M` toggle · `⌃⌥⌘1` start 1 hour |
| **CLI** | `matcha on 2h` · `matcha off` · `matcha run -- ./build.sh` · `matcha watch` |
| **URL / AppleScript** | `open -g "matcha://on?hours=2"` |

Whichever you choose — visual floater, menu bar, hotkeys, or pure CLI — Matcha has you covered.

## Why not Amphetamine or Caffeinate?

| | **Matcha** | Amphetamine | Caffeinate |
|---|:---:|:---:|:---:|
| Keeps screen + lock screen awake | ✅ | ✅ | ⚠️ |
| **Detects your coding agents** | ✅ | — | — |
| **Agent CLI (`matcha run`)** | ✅ | — | — |
| **Floating badge / tea timer** | ✅ | — | — |
| Schedules + watch-lists | ✅ | ✅ | — |
| Shortcuts / AppleScript | ✅ | ✅ | — |
| Price | Free · OSS · MIT | Free + paid tier | Free · OSS |

## Coding agents

Matcha ships skills/instructions for Claude Code, opencode, Codex, Gemini, Windsurf, Cursor, and Aider, and detects **44 built-in agents** plus anything you add. Agents start sessions before long work and stop them afterwards — your own sessions stay untouched.

Missing one? Settings → **Add Coding Agent…**, or add names to `~/Library/Application Support/Matcha/agents.txt`.

## Raycast & Alfred

<details>
<summary>Raycast script commands</summary>

The [`Raycast/`](Raycast) folder contains ready-to-use commands — `matcha-toggle`, `matcha-on`, `matcha-off`, `matcha-status`. Point Raycast at the folder as a **Script Command Directory**.

</details>

<details>
<summary>Alfred workflow</summary>

1. **Keyword** trigger: `matcha` (argument optional)
2. **Run Script** (`/bin/zsh`):

```zsh
/Applications/Matcha.app/Contents/Resources/matchactl {query}
```

Type `matcha on 2h`, `matcha off`, or `matcha status` from Alfred.

</details>

## Privacy

No accounts, analytics, or telemetry. The only network calls are updating and the install you asked for.

## Build from source

```sh
./build.sh install   # build → /Applications/Matcha.app
./build.sh package   # build + dist/Matcha.zip
./Tools/release.sh   # universal arm64+x86_64 + checksums
```

Needs only the Xcode Command Line Tools (`swiftc`). A Homebrew cask is provided in [`Casks/matcha.rb`](Casks/matcha.rb) (submit to `homebrew-cask` once notarized).

## License

[MIT](LICENSE) — free to use, fork, and ship.