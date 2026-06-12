# charles-claude-skills

Production-quality slash-command skills for [Claude Code](https://claude.com/claude-code), evaluated against Anthropic's `writing-skills` + `skill-creator` rubric. **100% trigger accuracy** on a 20-query precision/recall benchmark per skill.

![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)
![Trigger accuracy](https://img.shields.io/badge/trigger%20accuracy-100%25-brightgreen)
![Claude Code](https://img.shields.io/badge/Claude%20Code-skills-purple)

## Skills in this repo

**Session-continuity pair (always install together — they share a folder):**

| Skill | What it does |
|---|---|
| `/putdown` | Distills session state into a handoff file before you clear context |
| `/pickup` | Loads the most recent checkpoint in a fresh session |

Pair docs: [skills/session-continuity/README.md](skills/session-continuity/README.md)

**Standalone utilities:**

| Skill | What it does | Docs |
|---|---|---|
| `/newproject` | Bootstrap a configurable workspace project (idempotent) | [skills/newproject/README.md](skills/newproject/README.md) |
| `/skill-dict` | Manage a personal catalog of installed Claude Code skills | [skills/skill-dict/README.md](skills/skill-dict/README.md) |

## Install (quick)

```bash
git clone https://github.com/cabaynes/charles-claude-skills.git
# Session-continuity pair (one command, both halves):
cp -r charles-claude-skills/skills/session-continuity/{putdown,pickup} ~/.claude/skills/
# Standalone, opt-in:
cp -r charles-claude-skills/skills/{newproject,skill-dict} ~/.claude/skills/
```

Then **close your Claude Code window and open a fresh one** so the new skills register. (`Cmd+Shift+P → Developer: Reload Window` does NOT free Claude Code's context memory — only a fresh window does.)

Full instructions, symlink-vs-copy trade-offs, and troubleshooting in [INSTALL.md](INSTALL.md).

## How these were evaluated

These aren't just "skills I wrote" — each was scored against an 18-rule rubric distilled from Anthropic's `writing-skills` and `skill-creator` reference docs, then run through skill-creator's description-optimization benchmark eval:

- **20 trigger queries per skill** (10 should-trigger + 10 should-not-trigger, near-miss adversarial)
- **LLM-as-judge scoring** against the skill description
- **Threshold**: ≥80% precision and recall to pass

**Results (2026-05-13):**

| Skill | Recall | Precision |
|---|---|---|
| `/putdown` | 10/10 | 10/10 |
| `/pickup` | 10/10 | 10/10 |
| `/newproject` | 10/10 (post-revision) | 10/10 |
| `/skill-dict` | 10/10 | 10/10 |

Full methodology, per-query verdicts, and revision rationale in [eval-results.md](eval-results.md).

## Maintaining this repo

If you're forking or contributing, see [MAINTAINING.md](MAINTAINING.md) for the release workflow — how to refresh skills from a canonical source, run the eval, bump the CHANGELOG, and verify sanitization before pushing.

## License

[MIT](LICENSE) — copyright 2026 Charles Baynes. Per-skill `LICENSE` files are also included in each skill folder so the folder is self-contained when copied alone.
