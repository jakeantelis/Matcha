# Contributing to Matcha

Thanks for helping out. Matcha is a small macOS keep-awake app written in Swift,
with a special focus on build/export jobs and AI coding agents.

## Ways to contribute

- **Report a bug or request a feature**: open an
  [issue](https://github.com/jakeantelis/Matcha/issues).
- **Add a coding agent to detection**: edit the `AgentRegistry.builtIn` list in
  [`Sources/Support.swift`](Sources/Support.swift) and open a pull request.
- **Improve docs**: the agent skill, CLI docs, and README all accept PRs.
- **Fix something you found**: small, focused PRs are easiest to review.

## Getting started

Requires macOS and Apple's Swift toolchain (Xcode or Command Line Tools).

```sh
git clone https://github.com/jakeantelis/Matcha.git
cd Matcha
./build.sh            # build    → build/Matcha.app
./build.sh package    # + zip dist/Matcha.zip
./build.sh install    # + install to /Applications
```

## Building the app

- `./build.sh`, compile and produce `build/Matcha.app`.
- `./Tools/release.sh`, build a universal (arm64 + x86_64) binary and zip.
- `./Tools/release.sh --publish`, create a GitHub release.

## Adding a coding agent

Agent detection lives in [`AgentRegistry.builtIn`](Sources/Support.swift). Each
entry is a `(process-name, label)` pair:

```swift
("opencode", "opencode"),
("mycli", "My CLI"),
```

The process name is what appears in Activity Monitor. Detection is local (it
reads `ps`) and never uploads anything.

Submit the change as a PR and it ships for everyone.

## Code style

- Match the existing style, no added comments unless necessary, AppKit/Swift
  conventions, and keep the `moon/dots`-free, Apple-like aesthetic.
- Verify with `./build.sh` before pushing.