# Matcha

**Keep your Mac awake for builds, exports, and AI coding agents.**

> **100% Free & Open Source (MIT)** · No accounts, no subscriptions, no tracking, and zero bloat. Built natively in Swift for macOS.

[![Release](https://img.shields.io/github/v/release/jakeantelis/Matcha)](https://github.com/jakeantelis/Matcha/releases)
[![License](https://img.shields.io/github/license/jakeantelis/Matcha)](LICENSE)
[![Platform](https://img.shields.io/badge/macOS-11%2B-2f6f4f)]()
[![Built with Swift](https://img.shields.io/badge/Swift-AppKit-F05138)]()

<p align="center">
  <img src="docs/demo.gif" width="420" alt="Matcha toggling from sleep-allowed to awake — the ring fills green and the cup steams">
</p>

<p align="center"><b>Works with</b> · Claude Code · Codex · Cursor · opencode · Aider · Gemini CLI · Windsurf · <i>and 44+ more</i></p>

Matcha is a tiny macOS menu-bar utility that keeps your display on and lock screen away while builds, exports, or AI coding agents run. See what's new in [`RELEASE_NOTES.md`](RELEASE_NOTES.md).

## Install

**Recommended: one command.** Open **Terminal** (*Applications → Utilities → Terminal*), paste this, and press **Return**:

```sh
curl -fsSL https://raw.githubusercontent.com/jakeantelis/Matcha/main/Tools/install.sh | sh
```

The installer downloads the latest release, verifies its SHA-256 checksum, installs Matcha to `/Applications`, launches it, and configures supported coding agents. Rerun it anytime to update; skip agent setup with `| sh -s -- --no-agents`.

> **Signing status:** Matcha is signed with an Apple Developer ID certificate and notarized by Apple, so Gatekeeper opens it without workarounds.

**Prefer to download?** Grab either from the [releases page](https://github.com/jakeantelis/Matcha/releases):

- **Disk image (easiest, GUI):** open `Matcha.dmg` and drag **Matcha** into the **Applications** folder.
- **Homebrew:** `brew install --cask matcha` (via the tap — see [Homebrew](#homebrew) below).
- **Zip (manual):** unzip `Matcha.zip` and move **Matcha.app** to **Applications**.

**Mac App Store:** Exploring native Mac App Store distribution for the future — watch the [releases page](https://github.com/jakeantelis/Matcha/releases) for announcements.

*Requires macOS 11+ (universal — Apple Silicon & Intel). Allow notifications for session ending warnings and agent prompts.*

## Features

- **One-click sessions** — presets (`2h` / `4h` / ∞), natural language (`8h`, `90m`, `2.5h`, `8 hours`), or clock time (`until 6pm`).
- **Tea-fill timer** — a matcha-green ring fills and steam rises while a session runs, with the live countdown in the ring, menu bar, and floating badge, plus elapsed run time in the window and menu-bar tooltip.
- **Display + lock screen** — prevents the screen saver *and* lock screen, not just idle sleep (`caffeinate -d -u` + IOPM assertions).
- **Floating indicator** — a draggable desktop badge with quick actions (double-click +30m, Option-click stop; translucent by default).
- **Agent-aware** — detects 44+ coding agents and lists the active ones: *“opencode · Claude Code are running.”*
- **CLI & scripting** — `matcha run -- <cmd>` stays awake for exactly as long as the command runs.
- **Crash-safe** — timed sessions resume after a crash or force-quit; a normal Quit ends them.
- **Battery guard** — stops at user-adjustable threshold (default 20%) on battery.
- **Watch-lists, schedules & templates** — stay awake while an app runs, at scheduled days/times, or with saved one-click session templates.
- **Idle auto-stop** — automatically stops if your Mac has been idle for a configured number of minutes.
- **Shortcuts & App Intents** — full Siri and Shortcuts support for starting, stopping, toggling, extending, and checking status.
- **xbar plugin** — integration for xbar / BitBar menu bar monitoring and control.
- **Network & Clamshell Guard** — Optional network sleep prevention (`NetworkClientActive`) and clamshell/lid-closed wake support when connected to power/display.
- **Quick Command Palette** — Spotlight-style instant launcher (`⌃⌥⌘K`) to type durations, templates, or commands.
- **Post-Session Actions** — Optionally play a sound or put your Mac to sleep when a session finishes.
- **Menu Bar Icon Customization** — Choose between the matcha cup, a minimal leaf, or a status dot icon.
- **Custom Agent Manager** — Easily add custom agent process names via Settings without manual file edits.
- **Export & Webhooks** — Export session history to JSON/CSV and dispatch webhooks on session completion.

## Control it your way

| Way | How |
| --- | --- |
| **Menu bar** | Click the cup icon → popover, or `⌘,` for the Settings window |
| **Floating badge** | Drag it anywhere; click for controls, right-click for quick actions |
| **Hotkeys** | `⌃⌥⌘M` toggle · `⌃⌥⌘1` start 1 hour · `⌃⌥⌘N` show/hide window · `⌃⌥⌘K` command palette |
| **CLI** | `matcha on 2h` · `matcha off` · `matcha run -- ./build.sh` · `matcha watch` |
| **URL / AppleScript** | `open -g "matcha://on?hours=2"` |

Whichever you choose — visual floater, menu bar, hotkeys, or pure CLI — Matcha has you covered.

## How it compares

| Feature / Capability | **Matcha** | Amphetamine | Caffeinate (CLI) |
| :--- | :---: | :---: | :---: |
| **Prevents System Sleep** | ✅ | ✅ | ✅ |
| **Keeps Screen + Lock Screen Awake** | ✅ | ✅ | ⚠️ *(Requires `-d -u` flags)* |
| **Detects AI Coding Agents** (44+ built-in) | ✅ | ❌ | ❌ |
| **Agent CLI (`matcha run -- <cmd>`)** | ✅ | ❌ | ⚠️ *(Manual wrapping)* |
| **Tea-Fill Visual Timer & Floating Badge** | ✅ | ❌ *(Menu bar only)* | ❌ *(Terminal only)* |
| **Schedules & Watch-Lists** | ✅ | ✅ | ❌ |
| **Saved Session Templates** | ✅ | ❌ | ❌ |
| **Idle Auto-Stop & Battery Guard** | ✅ | ⚠️ *(Battery limit only)* | ❌ |
| **Network & Clamshell Guards** | ✅ | ❌ | ❌ |
| **Quick Command Palette (`⌃⌥⌘K`)** | ✅ | ❌ | ❌ |
| **Post-Session Actions** (Sound / Sleep) | ✅ | ❌ | ❌ |
| **Tabbed Local Analytics & Stats** | ✅ | ❌ | ❌ |
| **Shortcuts, Apple Intents & xbar** | ✅ | ✅ | ❌ |
| **App Architecture** | Zero-deps Native Swift | Native AppKit | Built-in Terminal Tool |
| **Price & License** | Free · OSS · MIT | Free + Paid Tier | Free · OSS |

## Coding agents

Matcha ships skills/instructions for Claude Code, opencode, Codex, Gemini, Windsurf, Cursor, and Aider, and detects **44 built-in agents** plus anything you add.

**How detection works — you pick the level:**

| Mode | Behavior |
| --- | --- |
| **Detect & prompt** *(default)* | When an agent is running, Matcha sends a notification: *"Keep your Mac awake?"* — tap **Keep Awake** to start. Never turns on by itself. |
| **Auto-start** | Settings → **Auto-Start for Coding Agents** — Matcha starts the moment an agent appears and stops when the last one quits (waits a few minutes after a manual stop so it doesn't fight you). |
| **Self-serve** | Agents use `matcha run -- <cmd>` to stay awake for exactly the duration of the command. |

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

Needs only the Xcode Command Line Tools (`swiftc`).

### Homebrew

The official cask is in review at [homebrew-cask#296800](https://github.com/Homebrew/homebrew-cask/pull/296800). Until it merges, use the tap:

```sh
brew tap jakeantelis/matcha
brew trust jakeantelis/matcha
brew install --cask matcha
```

The cask formula lives in [`Casks/matcha.rb`](Casks/matcha.rb).

## License

[MIT](LICENSE) — free to use, fork, and ship.