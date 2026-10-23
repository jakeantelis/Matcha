## Matcha 1.3.1

A minimalist macOS keep-awake app that also prevents the screen saver and lock
screen, with first-class automation for scripts and AI agents.

### Highlights

- Keeps the Mac awake and the display unlocked for a chosen duration or until stopped
- A soft matcha wash fills the main window while a session is active
- Typed durations (`8`, `2.5h`, `1d`, `2h 30m`), presets, and a resizable floating indicator
- One-command install and update, with checksum verification and automatic agent setup
- **Check for Updates…** in the app menu
- Friendly uninstall script that also removes agent instructions
- Optional live countdown (or infinity) beside the menu bar icon
- Global hotkeys: `Ctrl-Opt-Cmd-M` toggles, `Ctrl-Opt-Cmd-1` starts one hour
- Five-minute ending warning with **Add 1 Hour** / **Stop**; auto-extends 30 minutes while a build is still running
- Auto-keep-awake for real build/encode tools, plus a low battery guard
- Sessions survive crashes and force-quits; an intentional Quit ends them
- CLI, `matcha://` URL scheme, and a status plist for agents
- Agent kit auto-configures Claude Code, opencode, Codex CLI, Gemini CLI, and Windsurf; project rules for Cursor and Aider
- No accounts, analytics, or telemetry

### Install

```sh
curl -fsSL https://raw.githubusercontent.com/jakeantelis/Matcha/main/Tools/install.sh | sh
```

Downloads the latest release, verifies its SHA-256, installs it, opens the app,
and configures detected coding agents. Rerun the same command to update; add
`-s -- --no-agents` to skip agent setup.

The app is ad-hoc signed, not notarized. If Gatekeeper blocks a manual install,
right-click the app and choose **Open**, or allow it under
**System Settings > Privacy & Security > Open Anyway**. The installer avoids
that prompt automatically.

### Agent kit

The installer configures Claude Code and opencode skills, plus instructions for
Codex CLI, Gemini CLI, and Windsurf when those tools are present. Cursor and
Aider use project rules:

```sh
curl -fsSL https://raw.githubusercontent.com/jakeantelis/Matcha/main/Tools/install-agent-kit.sh | sh -s -- --project
```

Agents start a session before long work and stop it afterwards, leaving sessions
you started yourself untouched.

### Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/jakeantelis/Matcha/main/Tools/uninstall.sh | sh
```

Add `-s -- --yes --purge` to remove preferences and session data as well.

### Requirements

- macOS 11 or later
- Universal binary: Apple silicon and Intel
