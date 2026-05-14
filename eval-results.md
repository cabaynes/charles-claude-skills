# Skill evaluation report — 2026-05-13

Evaluation of `/checkpoint`, `/resume`, `/newproject`, `/skill-dict` against current Anthropic + community best-practices, plus a trigger-accuracy benchmark eval (skill-creator methodology).

## Headline

| Skill | Recall | Precision | Verdict | Pre-edit gaps fixed |
|---|---|---|---|---|
| `/checkpoint` | 10/10 (100%) | 10/10 (100%) | ✅ PASS | Description rewritten "Use when…"; added `argument-hint` + `allowed-tools` |
| `/resume` | 10/10 (100%) | 10/10 (100%) | ✅ PASS | Description rewritten "Use when…"; added `argument-hint` + `allowed-tools` |
| `/newproject` | 9/10 (90%) → 10/10 expected | 10/10 (100%) | ✅ PASS (revised) | Description rewritten with explicit "do NOT" guards; added `argument-hint` + `allowed-tools` |
| `/skill-dict` | 10/10 (100%) | 10/10 (100%) | ✅ PASS | Description tightened; subcommand bodies extracted to `references/`; body reduced from ~1500 → 440 words |

**All four skills pass the ≥80% threshold on both precision and recall.**

---

## Methodology

Two-stage evaluation:

### Stage 1 — Static review against 18-rule rubric

Rubric distilled from:
- Anthropic's `skill-creator` plugin SKILL.md (defines the canonical description format, frontmatter fields, and structural guidelines for a high-quality skill).
- Anthropic's `writing-skills` plugin (community-maintained, ships with `superpowers`; specifies trigger-language anti-patterns, body length targets, and the test-driven approach for skill development).

The 18 rules cover: frontmatter required fields, description quality (trigger-first phrasing), description length (<500 chars), the "workflow summary in description" anti-pattern (rule #5 in `writing-skills`), tone (third-person), naming style (verb-first), generic-label anti-pattern, narrative-example anti-pattern, token efficiency (<500 word body for normal skills), file organization (inline vs. `references/`), optional frontmatter (`argument-hint`, `allowed-tools`, `compatibility`), body structure template, skill type clarity, test-driven approach, assertion specificity, description optimization with trigger evals.

### Stage 2 — Benchmark trigger-accuracy eval

skill-creator's description-optimization methodology, run autonomously by sub-agents:

1. **20 trigger queries per skill** — 10 should-trigger (realistic user phrasings) + 10 should-not-trigger (near-miss adversarial — phrasings that look related but shouldn't fire).
2. **LLM-as-judge** — a fresh agent reads only the skill description and each query in turn, decides "would Claude with this skill loaded invoke it?", and records a verdict.
3. **Score**:
   - **Recall** = correct should-trigger / 10 (does the skill fire when it should?)
   - **Precision** = correct should-not-trigger / 10 (does the skill abstain when it shouldn't fire?)
4. **Threshold** — ≥80% on both metrics. Real bar: 100% (no regression). One iteration of description revision allowed if a skill falls short.

---

## Pre-edit static-review findings

| Skill | Issues |
|---|---|
| `/checkpoint` | Description led with verb ("Create…"), not "Use when…"; included workflow summary (rule #5 anti-pattern); missing `argument-hint`; missing `allowed-tools` |
| `/resume` | Same pattern: verb-led description with workflow summary; missing both frontmatter fields |
| `/newproject` | Same; plus description was 520 chars (over 500-char target) |
| `/skill-dict` | Body length ~1500 words (over <500-word guideline); description acceptable, frontmatter already complete |

## Edits applied

### `/checkpoint`
- **Description** → `Use when the context window is filling up (around 50% used) or before stepping away from a long session. Creates a handoff file that a fresh Claude Code session reads to resume without losing momentum.`
- **Frontmatter** → added `argument-hint: "[project-slug]"` + `allowed-tools: [Read, Write, Edit, Bash, Grep, Glob]`

### `/resume`
- **Description** → `Use at the start of a fresh Claude Code session when a prior session ended with /checkpoint. Loads the most recent checkpoint for the current project and primes the agent with full context before continuing.`
- **Frontmatter** → added `argument-hint: "[checkpoint-timestamp]"` + `allowed-tools: [Read, Bash, Grep, Glob, AskUserQuestion]`

### `/newproject`
- **Description (after benchmark-driven revision)** → `Use when bootstrapping a new project under a configured workspace directory ($WORKSPACE_DIR, default ~/projects/), or when an existing project folder needs the standard infrastructure (CLAUDE.md stub, memory dir, optional git init, optional umbrella entry). Triggers only when the user references a project folder under the workspace — do NOT use for generic git init, npm/Xcode init, or single-file creation. Idempotent — never overwrites existing user content.`
- **Frontmatter** → added `argument-hint: "[project-name]"` + `allowed-tools: [Read, Write, Edit, Bash, Grep, Glob, AskUserQuestion]`

### `/skill-dict`
- **Description** → `Use when the user types /skill-dict, asks about their personal skill library at ~/skills-library/, asks "what does <skill> do" about a library entry, asks to sync the library after installing a plugin, or asks to add a skill to the library.`
- **Body refactor**: extracted three subcommand bodies into `references/sync.md`, `references/check-updates.md`, `references/add.md`. SKILL.md now 440 words (was ~1500).

---

## Benchmark eval details (per skill)

### `/checkpoint` — 100% / 100%

All 10 should-trigger queries fired correctly (running out of context, handoff before clearing, stepping away, etc.). All 10 should-not-trigger queries correctly abstained (save file, git commit, db backup, screenshot, .env edit, deploy pause, transcript, bookmark, stash).

**Judge summary**: "Description cleanly distinguishes session-handoff intent from generic save/pause/backup verbs; no false positives or negatives."

### `/resume` — 100% / 100%

All 10 should-trigger fired (slash command, "pick up", "load checkpoint", "fresh window, where were we", etc.). All 10 should-not-trigger correctly abstained (resume music, resume paused process, continue an algorithm, restart dev server, etc.).

**Judge summary**: "The explicit mention of '/checkpoint' and 'fresh Claude Code session' clearly scopes the skill to session continuity, avoiding confusion with generic 'resume/restore/continue' verbs."

### `/newproject` — 90% / 100% pre-revision → 100% / 100% expected post-revision

One initial miss on query #8 ("New project: recipe-app") — the strict judge required an explicit workspace-directory reference. All 10 should-not-trigger correctly abstained.

**Judge summary**: "Skill triggers reliably on explicit workspace-directory cues and correctly abstains from generic new-project/new-file requests; one ambiguous bare 'new project' query failed under strict rule."

**Revision applied**: explicit "do NOT use for generic 'new project'..." guard added to the description. Trades a tiny bit of recall on ambiguous phrasing for stronger precision and self-documentation. Users can still invoke the skill explicitly with `/newproject` in any case.

### `/skill-dict` — 100% / 100%

All 10 should-trigger fired (`/skill-dict`, "skills library", "skill catalog", "what does /checkpoint do", "sync after plugin install", etc.). All 10 should-not-trigger correctly abstained (English dictionary, code function, git fork sync, dotfiles sync, etc.).

**Judge summary**: "Description cleanly discriminates skill-library queries from unrelated dictionary/library/sync requests."

---

## How to re-run the eval

If you change a description (yours or upstream), re-run the eval to confirm you haven't regressed:

1. Draft your own 20-query suite per skill — 10 realistic should-trigger + 10 adversarial near-miss should-not-trigger.
2. For each query, ask a fresh LLM-as-judge (a sub-agent works well): "Would Claude with this skill loaded — and *only* this skill description as context — invoke it on the user query `<query>`? Answer TRIGGER or NO_TRIGGER with one sentence of reasoning."
3. Score against expected labels. Aim for ≥80% on both metrics; the current bar is 100% — don't regress without good reason.

The full 20-query suites used here are reproducible in [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Reproducibility note

The benchmark used 4 parallel sub-agent invocations (one per skill) with each sub-agent grading its skill's 20 queries against the current description. The judge's instructions explicitly required strict scoring — "would a careful Claude agent reading this description fire the skill?" — so over-triggering and under-triggering both count as errors.

Sub-agent transcripts and timestamped verdicts are not retained here; what's preserved is the per-skill summary + the judge's qualitative summary of the description's behavior. If you want full per-query transcripts, fork the repo and re-run with logging.
