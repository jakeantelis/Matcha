# Matcha 1.4.0

A quiet, green keep-awake timer for builds, exports, and AI coding agents.
Same install path, a lot more polish.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/jakeantelis/Matcha/main/Tools/install.sh | sh
```

Requires macOS 11+ (universal). Ad-hoc signed, not notarized — the installer
strips quarantine automatically.

## Highlights

### New features
- **Matcha "steeping" timer** — a green tea-fill ring + rising steam while active
- **Agent detection for 43+ tools** — the footer lists them: *"opencode · Claude Code are running"*, scrolling when there are many
- **Settings window** (`⌘,`) replacing the long menu — behavior, menu bar & floater, appearance, agents, usage
- **Usage stats** — today & all-time "kept awake" time (local only)
- **Watch an app** — stay awake while e.g. Logic Pro or Blender is running
- **Until a time** — `until 6pm` in Set Duration
- **In-app updater** — checks on launch + daily, installs & restarts in one click, keeps your session
- **Add your own agents** — Settings → Add Coding Agent…, or `agents.txt`

### CLI
- `matchactl on 2h` / `90m` / `2.5h` / `until`
- `matcha run -- <cmd>` — awake exactly while a command runs
- `matcha watch`, `matchactl status --json`, `matchactl version`
- Shortcuts (`matcha://` URL) and AppleScript support

### Polish
- Green only when on; calm grey idle with a dotted ring
- Floating badge breathing glow; left-click opens the window, right-click quick menu
- Animations toggle (honors Reduce Motion), Tips default off
- Friendlier copy, refreshed screenshots and README

## Docs
- [`README.md`](README.md) — full overview + comparison
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — add an agent or fix a bug

## Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/jakeantelis/Matcha/main/Tools/uninstall.sh | sh
```

Add `-s -- --yes --purge` to remove preferences and session data too.