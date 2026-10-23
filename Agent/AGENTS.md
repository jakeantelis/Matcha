# Matcha agent instructions

The small, agent-agnostic snippet is in [`instructions.md`](instructions.md).
It tells an agent to run `matchactl on <hours>` before long work and
`matchactl off` afterwards, while leaving sessions the user started alone.

The installer adds it automatically where a stable instructions file exists:

| Agent | Target |
| --- | --- |
| Claude Code | `~/.claude/skills/matcha-keep-awake/SKILL.md` |
| opencode | `~/.config/opencode/skills/matcha-keep-awake/SKILL.md` |
| Codex CLI | `~/.codex/AGENTS.md` |
| Gemini CLI | `~/.gemini/GEMINI.md` |
| Windsurf | `~/.codeium/windsurf/memories/global_rules.md` |

Cursor and Aider load rules per project, so run the installer inside the repo:

```sh
curl -fsSL https://raw.githubusercontent.com/jakeantelis/Matcha/main/Tools/install-agent-kit.sh | sh -s -- --project
```

That writes `.cursor/rules/matcha-keep-awake.mdc` and appends the snippet to
`CONVENTIONS.md`. For Zed or any other agent, paste `instructions.md` into its
instructions or system prompt.
