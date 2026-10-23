# Matcha

**Keep your Mac awake for builds, exports, and AI coding agents — with a cup of calm.**

[![Release](https://img.shields.io/github/v/release/jakeantelis/Matcha)](https://github.com/jakeantelis/Matcha/releases)
[![License](https://img.shields.io/github/license/jakeantelis/Matcha)](LICENSE)
[![Platform](https://img.shields.io/badge/macOS-11%2B-2f6f4f)]()
[![Built with Swift](https://img.shields.io/badge/Swift-AppKit-F05138)]()

<p align="center">
  <img src="docs/shot-idle-card2.png" width="260" alt="Matcha idle — sleep allowed">
  <img src="docs/shot-active-card2.png" width="260" alt="Matcha active — steeping">
</p>

<p align="center"><b>Works with</b> · Claude Code · Codex · Cursor · opencode · Aider · Gemini CLI · Windsurf · <i>and 43+ more</i></p>

Matcha is a tiny menu-bar utility that keeps your display on and lock screen away while builds, exports, or AI coding agents run. It looks like a tea timer, but it’s engineered for developers and operators who leave machines working overnight.

---

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/jakeantelis/Matcha/main/Tools/install.sh | sh
```

One command installs Matcha to `/Applications`, launches it, and configures your coding agents. Rerun to update. Skip agent setup with `| sh -s -- --no-agents`.

*Requires macOS 11+ (universal: Apple Silicon & Intel).*

---

## What's New in v1.4.0

- **Tea-fill Timer & Steam** — A rich green liquid fills the ring as time counts down, accompanied by gentle animated steam wisps.
- **Matrix Agent Footer** — When active agents run, a terminal-style glowing green pill with a blinking cursor lists them: *“OpenChamber · Claude Code are running”* (with slow marquee scrolling for 3+ agents).
- **Settings Window (`⌘,`)** — A full preferences window replacing cluttered menus: configure behavior, menu bar, floater, appearance, size, login items, custom agents, and view local awake usage stats.
- **App-Store-Like Updates** — Auto-checks on launch and daily; one-click **Install & Restart** preserves your active session and mode seamlessly.
- **Smart Scheduling** — Set sessions via preset chips (`2h`, `4h`, `∞`), natural language (`8h`, `90m`, `2.5h`), or clock time (`until 6pm`).
- **App Watchlist** — Automatically keep awake while custom apps run (e.g., Logic Pro, Final Cut, Blender).
- **Clean Off-Mode** — Muted grey idle state with a dotted ring track and hidden footer.

---

## Features & Quick Tour

| Feature | Description |
| :--- | :--- |
| **Display & Lock Screen** | Blocks screen saver and lock screen (`caffeinate -d -u` + IOPM assertions). |
| **Floating Indicator** | Draggable badge with quick actions (double-click +30m, Option-click stop, translucent default). |
| **CLI & Automation** | `matchactl on 2h`, `matchactl extend 30m`, `matcha status --json`, `matcha run -- <cmd>`. |
| **Global Hotkeys** | `⌃⌥⌘M` (toggle), `⌃⌥⌘1` (start 1 hour). |
| **Battery Guard** | Pauses automatically at 20% on battery. |
| **Crash-Safe** | Timed sessions resume after crashes or force-quits. |
| **Shortcuts & AppleScript** | Scriptable via `matcha://` URL scheme. |

---

## Why Matcha vs Others?

| | **Matcha** | Amphetamine | Caffeinate |
|---|:---:|:---:|:---:|
| Keeps screen + lock screen awake | ✅ | ✅ | ⚠️ |
| **Detects 43+ AI coding agents** | ✅ | — | — |
| **Agent skill + CLI (`matcha run`)** | ✅ | — | — |
| **Tea-fill timer & animated badge** | ✅ | — | — |
| Schedules (Until-Time & App Watch) | ✅ | ✅ | — |
| Shortcuts / AppleScript | ✅ | ✅ | — |
| Price | Free · OSS · MIT | Free + paid tier | Free · OSS |

---

## Coding Agents

Matcha detects **43 built-in agents** (Claude Code, opencode, Codex, Cursor, Aider, OpenChamber, etc.) plus any custom process names you add in Settings → **Add Coding Agent…** or `~/Library/Application Support/Matcha/agents.txt`.

Agents start sessions before long tasks and stop them afterward, leaving your manually started sessions untouched.

---

## Privacy & Build

- **100% Local & Private** — No accounts, analytics, or telemetry. Network calls only occur when you check for updates or install.
- **Build from Source** — `./build.sh install` builds locally using Xcode Command Line Tools (`swiftc`).

## License

[MIT](LICENSE)
