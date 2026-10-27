# Matcha 1.5.0

A quiet, green keep-awake timer for builds, exports, and AI coding agents.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/jakeantelis/Matcha/main/Tools/install.sh | sh
```

Requires macOS 11+ (universal). **Signed with a Developer ID and notarized by
Apple**, so Gatekeeper opens it without workarounds.

Or install with Homebrew (tap until the official cask merges):

```sh
brew tap jakeantelis/matcha
brew trust jakeantelis/matcha
brew install --cask matcha
```

## Highlights

### Notarized
Matcha is now signed with an Apple Developer ID certificate and notarized.
No more "unidentified developer" dialogs, and no quarantine-stripping needed.

### New in 1.5.0
- **Command Palette** (`⌃⌥⌘K`) — Spotlight-style launcher for durations, templates, and commands
- **Schedules & templates** — start sessions on selected days/times, or save one-click presets
- **Idle auto-stop** — stop automatically after a configurable idle period
- **Network & clamshell guards** — optional network-sleep prevention and lid-closed wake support
- **App Intents & Shortcuts** — start, stop, toggle, extend, and check status from Siri or Shortcuts
- **xbar plugin** — monitor and control Matcha from xbar / BitBar
- **Post-session actions** — play a sound or sleep the Mac when a session ends
- **Menu bar styles** — matcha cup, minimal leaf, or status dot
- **Custom agent manager** — add agent process names in Settings, no file editing
- **Export & webhooks** — session history to JSON/CSV, webhook on completion
- **Tabbed settings** — reorganized into Behavior, Menu Bar, Appearance, Agents, Usage
- **Elapsed run time** — the window and menu-bar tooltip show how long the session has been running

### Fixes
- The custom duration field now hides when you pick a preset (`2h`, `4h`, `∞`)

## Docs
- [`README.md`](README.md) — overview, comparison, integrations
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — add an agent or fix a bug

## Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/jakeantelis/Matcha/main/Tools/uninstall.sh | sh
```

Add `-s -- --yes --purge` to remove preferences and session data too.
