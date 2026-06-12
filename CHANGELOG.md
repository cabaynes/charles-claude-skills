# Changelog

All notable changes to this project will be documented here. Format roughly follows [Keep a Changelog](https://keepachangelog.com/).

## [0.3.0] — 2026-06-12

### Changed (breaking: skill names)

- **Session-continuity pair renamed: `/checkpoint` → `/putdown` and `/resume` → `/pickup`.** The old names collide with Claude Code **built-in** commands for every user: `/resume` is the built-in conversation-resume picker, and `/checkpoint` is a built-in alias for `/rewind`. Custom skills currently shadow those built-ins (locking you out of them), and updates to Claude Code can silently flip that precedence ([anthropics/claude-code#33080](https://github.com/anthropics/claude-code/issues/33080)). The handoff FILES are unchanged — still timestamped markdown in `~/.claude/checkpoints/<project>/` — so existing checkpoints keep working after the rename. To migrate an existing install: `mv ~/.claude/skills/checkpoint ~/.claude/skills/putdown && mv ~/.claude/skills/resume ~/.claude/skills/pickup` then re-copy the SKILL.md files from this release.
- **`/putdown` now ends the session cleanly: it commits and pushes all session work.** After writing the handoff file it reviews the changed-file list (with a secrets gate — `.env*`, keys, and credential files are never staged), commits everything with a descriptive message, and pushes if a remote exists, reporting the pushed SHA or a prominent warning on failure. In private repos it also copies the handoff into the repo's `.checkpoints/` folder so cloud sessions (Claude Code on the web) can read it; public and Pages-served repos skip the in-repo copy so session notes are never published.
- **`/pickup` is now cross-surface aware.** It starts with `git fetch` and flags when origin is ahead (work pushed from another surface, e.g. Claude Code on the web), and searches both `~/.claude/checkpoints/<project>/` and the repo's `.checkpoints/`, deduplicating by timestamp.

## [0.2.0] — 2026-06-08

### Changed

- **`/checkpoint`**: the post-save "free the context window" reminder is now surface-aware. It detects the running surface via `CLAUDE_CODE_ENTRYPOINT` and gives the correct instruction: in the **terminal CLI** (standalone or VSCode's integrated terminal) `/clear` genuinely frees context, so it now recommends `/clear` → `/resume` instead of closing the window; the window-closing dance is reserved for the **VSCode visual-editor panel** and other GUI surfaces where `/clear` doesn't reliably reset context. Previously the skill told every user to close the window, which was only correct for the visual editor. The MCP-servers-added-this-session exception (full process restart required) is preserved for the CLI path.

## [0.1.0] — 2026-05-13

### Added

- **Session-continuity pair**: `/checkpoint` + `/resume` (must install together — they read/write the same handoff files). Lives in `skills/session-continuity/` so the pair stays together structurally.
- **`/newproject`** (parameterized for general use): bootstrap a workspace project under `$WORKSPACE_DIR` (default `~/projects/`). Optional fan-out memory integration; optional umbrella file update.
- **`/skill-dict`**: manage a personal catalog of installed Claude Code skills. Five subcommands: `list`, `show <name>`, `sync`, `add <name>`, `check-updates`. Subcommand details live in `skills/skill-dict/references/`.
- Evaluated against Anthropic's `writing-skills` + `skill-creator` rubric:
  - 18-rule static review (description quality, frontmatter, length, structure, anti-patterns).
  - skill-creator's description-optimization benchmark eval: 20 trigger queries per skill, LLM-as-judge scoring.
  - Results: 100% precision and 100% recall on all four skills. Full report in `eval-results.md`.
- Resume-builder docs: top-level `README.md`, per-skill `README.md`s, `INSTALL.md`, `CONTRIBUTING.md`, MIT `LICENSE` (root + per-skill).
- `MAINTAINING.md` — release workflow documentation (how to push edits, add a new skill, run the eval, verify sanitization).
- `scripts/snapshot.sh` — release helper that copies the canonical local skills into this repo with personal-path sanitization.

### Notes

- The repo is a **one-way snapshot** of the maintainer's local skills at `~/.claude/skills/<name>/`. Local versions are canonical; the snapshot script refreshes the repo copies for each release.
- `/newproject` is the only skill that diverges between local and public — the local version is hard-coded to the `~/CLAUDE/` workspace convention; the public version is parameterized.
