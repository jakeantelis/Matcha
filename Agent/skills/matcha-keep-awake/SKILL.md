---
name: matcha-keep-awake
description: Keep a Mac awake during long builds, test suites, downloads, or agent tasks with Matcha's matchactl CLI, then stop the session afterwards. Use on macOS before any command likely to run longer than a few minutes.
---

# Matcha keep-awake

Use Matcha when a long-running command could be interrupted by the Mac sleeping
or locking. It prevents idle sleep, display sleep, and the screen saver.

## Command

```sh
MATCHA="$(command -v matchactl || echo /Applications/Matcha.app/Contents/Resources/matchactl)"
```

Run `"$MATCHA" status` first. It prints `on (Ns left)` or `off`.

## When to use

Use it before work expected to take more than ~5 minutes:

- builds, test suites, lint/type-check runs on large projects
- long downloads, uploads, model training, video encoding
- multi-step migrations or scripts you will walk away from

Skip it for quick commands (< 1 minute). Never use it for interactive work
where you are at the keyboard.

## Rules

1. If `status` says `off`, start a session sized to the work:
   - up to 1 hour: `"$MATCHA" on 1`
   - up to 4 hours: `"$MATCHA" on 4`
   - unknown or longer: `"$MATCHA" on 4`, then `"$MATCHA" extend 1` as needed
2. If it is already `on`, leave it alone. Do not extend or stop a session the
   user started.
3. When the work finishes and you started the session, run `"$MATCHA" off`.
   If the user might still be working, only do this when you started it.
4. If Matcha is not installed (the command fails), continue without it. Never
   block or fail a task because keep-awake is unavailable.
5. Do not use `sudo`. Do not modify Matcha preferences.

## Examples

```sh
MATCHA="$(command -v matchactl || echo /Applications/Matcha.app/Contents/Resources/matchactl)"

# before a long build
"$MATCHA" on 2
swift build 2>&1 | tail -20
"$MATCHA" off

# check state
"$MATCHA" status
```
