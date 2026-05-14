# Changelog

All notable changes to this project will be documented here. Format roughly follows [Keep a Changelog](https://keepachangelog.com/).

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
- `scripts/snapshot.sh` — release helper that copies the canonical local skills into this repo with personal-path sanitization.

### Notes

- The repo is a **one-way snapshot** of the maintainer's local skills at `~/.claude/skills/<name>/`. Local versions are canonical; the snapshot script refreshes the repo copies for each release.
- `/newproject` is the only skill that diverges between local and public — the local version is hard-coded to the `~/CLAUDE/` workspace convention; the public version is parameterized.
