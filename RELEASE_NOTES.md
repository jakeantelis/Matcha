## Matcha 1.1.0

A minimalist macOS keep-awake app that also prevents the screen saver and lock
screen, with first-class automation for scripts and AI agents.

### Highlights

- Keeps the Mac awake and the display unlocked for a chosen duration or until stopped
- Typed durations (`8`, `2.5h`, `1d`, `2h 30m`), presets, and a floating indicator you can resize
- Auto-keep-awake for real build/encode tools
- Low battery guard (laptops only)
- Sessions survive crashes and force-quits; an intentional Quit ends them
- CLI, `matcha://` URL scheme, and a status plist for agents
- Agent skill for Claude Code and opencode

### Install

```sh
curl -fL https://github.com/jakeantelis/Matcha/releases/latest/download/Matcha.zip -o /tmp/Matcha.zip
unzip -qo /tmp/Matcha.zip -d /Applications
xattr -dr com.apple.quarantine /Applications/Matcha.app 2>/dev/null || true
open /Applications/Matcha.app
```

The app is ad-hoc signed, not notarized. If Gatekeeper blocks the first launch,
right-click the app and choose **Open**, or allow it under
**System Settings → Privacy & Security → Open Anyway**. Building from source
avoids the warning entirely.

### Agent kit

```sh
curl -fsSL https://raw.githubusercontent.com/jakeantelis/Matcha/main/Tools/install-agent-kit.sh | sh
```

Installs the `matcha-keep-awake` skill for Claude Code and opencode. Agents will
call `matchactl on <hours>` before long builds and stop the session afterwards.

### Requirements

- macOS 11 or later
- Universal binary: Apple silicon and Intel
