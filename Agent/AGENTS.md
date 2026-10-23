# Matcha keep-awake

Paste this into any agent instructions file: `AGENTS.md` (Codex CLI),
`GEMINI.md` (Gemini CLI), `CONVENTIONS.md` (Aider), Cursor/Windsurf project
rules, or a system prompt.

```md
## Keep the Mac awake for long work

Before a build, test suite, download, model run, or any task likely to take more
than a few minutes, start Matcha:

    matchactl on 2

Use `on 1`, `on 4`, or `on 8` to match the expected duration. If `matchactl
status` says it is already on, leave it alone and do not extend a session the
user started.

When the work finishes and you started the session:

    matchactl off

If `matchactl` is not on PATH, use
`/Applications/Matcha.app/Contents/Resources/matchactl`. If Matcha is not
installed, continue the task without it; never block on keep-awake.
```
