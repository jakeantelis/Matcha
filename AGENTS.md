# AGENTS.md

Matcha is a macOS keep-awake app for builds, exports, and AI coding agents.
Written in Swift (AppKit). ~3.7k LOC, single target, no Xcode project —
compiled with `swiftc` directly.

## Build & test

```sh
./build.sh            # build → build/Matcha.app
./build.sh package    # + zip dist/Matcha.zip
./build.sh install    # + install to /Applications
./Tools/run-tests.sh  # run unit tests (parses, formats, agent registry)
```

**Run `./Tools/run-tests.sh` after changes to `Sources/` or `Tools/`.**
Tests compile `Tests/main.swift` + `Sources/Support.swift` and exit non-zero on failure.

## Layout

| Path | What |
| --- | --- |
| `Sources/` | All Swift sources. `main.swift` is the entry point, `Controller.swift` is the app delegate + most logic. |
| `Tests/main.swift` | Unit tests (pure, no test framework — plain `check()` helper). |
| `Resources/` | `Info.plist`, app icon. Version lives in `CFBundleShortVersionString`. |
| `Tools/` | CLI binaries (`matcha`, `matchactl`), `release.sh`, `install.sh`, `run-tests.sh`. |
| `Casks/matcha.rb` | Homebrew cask (version + SHA must match release). |
| `Raycast/` | Raycast script commands. |
| `Agent/` | Agent-facing keep-awake skill + installer (not app code). |
| `build.sh` | Compile, package, install. |

## Code style

- **No comments** unless strictly necessary.
- AppKit/Swift conventions; match the existing style in surrounding code.
- `Support.swift` holds `Fmt` (duration/clock parsing), `AgentRegistry` (detection), and shared utilities — pure functions that tests can exercise without a GUI.
- Keep the Apple-like, minimalist aesthetic (no `moon`/`dots` emoji).

## Adding a coding agent to detection

Edit `AgentRegistry.builtIn` in `Sources/Support.swift` — each entry is
`(process-name, label)`. Process name is what appears in `ps`/Activity Monitor.
Add a test to `Tests/main.swift` if adding to the built-in list.

## Release

- **PUBLICATION ON HOLD:** Matcha 1.5.0 is built, signed, notarized, and stapled
  locally but must **not** be pushed, tagged, released, or published to Homebrew
  until the developer-account name review is resolved. Read
  `docs/NOTARIZATION-TODO.md` before any release action.
- `Tools/release.sh` — build universal binary, sign with the verified Apple
  Developer ID certificate, notarize, staple, and zip. It refuses `--publish`
  unless signing and notarization both succeed.
- After a release: update `Casks/matcha.rb` version + SHA-256.
- See `docs/NOTARIZATION-TODO.md` for the current handoff and release hold.

## Notes

- Target: macOS 11+ (universal arm64 + x86_64).
- **Context economy:** The user pays for model tokens and wants lean sessions.
  Read `Sources/` files in targeted chunks (grep first, then narrow reads), do not
  re-read a file you have already seen, avoid restating code or history, and keep
  replies short. Prefer `git status`/`git diff --stat` over full diffs.
- No external dependencies — only system frameworks (AppKit, Carbon, IOKit, ServiceManagement, UserNotifications).
- Git: `main` branch, squash or linear history, push when tests pass and no release hold is active.
