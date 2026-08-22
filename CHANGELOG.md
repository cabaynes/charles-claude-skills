# Changelog

All notable changes to this project will be documented here. Format roughly follows [Keep a Changelog](https://keepachangelog.com/).

## [0.6.0] — 2026-08-22

### Added

- **`/takenotes` Step 3.5 — superseded-fact sweep.** The reconcile pass discovered its targets through the `MEMORY.md` index hooks, which left a blind spot: when a session changes a previously-true fact (a location, an employer, a vendor), the memory that *owns* the topic gets corrected, but a file that merely *mentions* the old fact — under a one-line hook that says nothing about it — never gets opened, so the stale claim survives every reconcile. Found in the author's own store, where a wedding-venue change was corrected in the owning project's memory the day it happened yet sat wrong in the shared user profile for 19 days. Step 3.5 closes the gap: grep for the **old** term (not the topic — the topic also matches the freshly-corrected files) across the project's memory and, where one exists, the shared canonical store, then reconcile every hit. Historical mentions explicitly recorded as superseded are kept; only the old fact asserted as *current* is stale.

## [0.5.0] — 2026-08-03

### Added

- **`/takenotes`** — a third skill in `skills/session-continuity/`, optional and independent of the `/putdown` + `/pickup` pair. Where a putdown carries *session state* forward (and goes stale the moment you act on it), `/takenotes` writes what a session *learned* into permanent storage: typed memory, `CLAUDE.md`, or a `docs/` file. Three passes — **harvest** the session, **reconcile** what's already stored against what this session established, **route** each finding to where it belongs. The reconcile pass is the part nothing else does: a memory saying *"do not add a webhook receiver, the vendor cannot call out"* doesn't just sit there being outdated, it argues a future session out of work you already shipped. It also guards `CLAUDE.md` — anything over ~15 lines becomes a `docs/` spoke with a descriptive pointer, regardless of the file's current length, because a block that fits under any cap still costs context on every session start.

### Changed

- **`/putdown` now chains to `/takenotes` when it's installed.** Its Steps 2–3 invoke `/takenotes` instead of doing memory updates inline, so a single `/putdown` gets the full harvest-and-reconcile before the handoff is written — and the commit in Step 4.5 sweeps up whatever it wrote. A new **Step 0** announces both skills and their order before any work starts, and Step 5 reports `/takenotes`' result on its own labelled line (explicitly saying so when nothing durable was found, since a silent absence looks like a skipped step).
- **`/putdown` degrades gracefully without `/takenotes`.** If the skill isn't installed it falls back to a reduced inline memory step — no reconcile pass, but functional. Neither skill hard-depends on the other, and `/takenotes` can be installed or removed later without touching `/putdown`.
- **`/putdown`'s description no longer omits the memory step.** It previously described only the handoff and the commit/push, which risked an agent following the description and skipping Steps 2–3 entirely — the exact failure mode Anthropic's skill-authoring guidance warns about when a description summarises the workflow.

### Notes

- `/takenotes` passed the same 20-query trigger-accuracy benchmark as the other four skills — 100% precision, 100% recall — and was additionally validated behaviourally against a poisoned-memory sandbox. Both are documented in [eval-results.md](eval-results.md).
- The public `/takenotes` is a **parameterised fork**, hand-maintained like `/newproject` rather than auto-snapshotted. The author's local copy is coupled to a specific shared-memory layout (a canonical store with symlinks fanned into each project); the public version treats that as an optional pattern it detects rather than a requirement.

## [0.4.0] — 2026-06-13

### Changed (breaking: storage path)

- **Handoff files moved from `.checkpoints/` → `.putdowns/` and the word "checkpoint" is retired.** The 0.3.0 rename freed the command names but left the files still called "checkpoints," which kept the old term in play and risked the same confusion with the built-in `/checkpoint`/`/rewind` feature. The handoff files a session produces are now called **putdowns**, stored in `~/.claude/putdowns/<project>/` locally and `.putdowns/` inside a repo. The file format is unchanged. To migrate an existing install: `mv ~/.claude/checkpoints ~/.claude/putdowns` (local store), and in any repo that has committed handoffs, `git mv .checkpoints .putdowns`. The skills still read a stray `.checkpoints/` folder if they encounter one, so nothing breaks if you migrate gradually.

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
