## Matcha 1.3.0

A minimalist macOS keep-awake app that also prevents the screen saver and lock
screen, with first-class automation for scripts and AI agents.

### Highlights

- Keeps the Mac awake and the display unlocked for a chosen duration or until stopped
- A soft matcha wash fills the main window while a session is active
- Typed durations (`8`, `2.5h`, `1d`, `2h 30m`), presets, and a resizable floating indicator
- Optional live countdown (or infinity) beside the menu bar icon
- Global hotkeys: `Ctrl-Opt-Cmd-M` toggles, `Ctrl-Opt-Cmd-1` starts one hour
- Five-minute ending warning with **Add 1 Hour** / **Stop**; auto-extends 30 minutes while a build is still running
- Auto-keep-awake for real build/encode tools, plus a low battery guard
- Sessions survive crashes and force-quits; an intentional Quit ends them
- CLI, `matcha://` URL scheme, and a status plist for agents
- Agent kit for Claude Code, opencode, Codex CLI, Gemini CLI, Cursor, Windsurf, Aider, and any shell-capable agent

### Install

```sh
curl -fL https://github.com/jakeantelis/Matcha/releases/latest/download/Matcha.zip -o /tmp/Matcha.zip
unzip -qo /tmp/Matcha.zip -d /Applications
xattr -dr com.apple.quarantine /Applications/Matcha.app 2>/dev/null || true
open /Applications/Matcha.app
```

The app is ad-hoc signed, not notarized. If Gatekeeper blocks the first launch,
right-click the app and choose **Open**, or allow it under
**System Settings > Privacy & Security > Open Anyway**. Building from source
avoids the warning entirely.

### Agent kit

```sh
curl -fsSL https://raw.githubusercontent.com/jakeantelis/Matcha/main/Tools/install-agent-kit.sh | sh
```

Installs the `matcha-keep-awake` skill for Claude Code and opencode. For Codex
CLI, Gemini CLI, Cursor, Windsurf, Aider, or any other agent, copy the snippet
from `Agent/AGENTS.md`. Agents start a session before long work and stop it
afterwards, leaving sessions you started yourself untouched.

### Requirements

- macOS 11 or later
- Universal binary: Apple silicon and Intel
