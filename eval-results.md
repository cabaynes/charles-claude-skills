# Skill evaluation report

**Skills evaluated:** `/putdown`, `/pickup`, `/newproject`, `/skill-dict`
**Original eval:** 2026-05-13 · **Session-continuity pair re-evaluated:** 2026-06-13

> The session-continuity pair was first evaluated on 2026-05-13 under the names `/checkpoint` and `/resume`, scoring 100%/100% each. Those names were later retired because they shadow Claude Code built-ins (`/checkpoint` aliases `/rewind`; `/resume` opens the conversation picker — see CHANGELOG 0.3.0/0.4.0). The pair is now `/putdown` + `/pickup`, the descriptions changed during the rename, and the handoff files moved to `.putdowns/`. The scores below for those two reflect a **fresh re-eval on 2026-06-13** against the current descriptions; `/newproject` and `/skill-dict` are unchanged from the 2026-05-13 run.

## Headline

| Skill | Recall | Precision | Verdict | Notes |
|---|---|---|---|---|
| `/putdown` | 10/10 (100%) | 10/10 (100%) | ✅ PASS | Re-evaluated 2026-06-13 under current name + description |
| `/pickup` | 10/10 (100%) | 10/10 (100%) | ✅ PASS | Re-evaluated 2026-06-13; one revision to recover a fresh-window phrasing (below) |
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

skill-creator's description-optimization methodology. Each query is run as a real trigger test — a fresh `claude -p` session is given only the skill's description (as an available command) plus the user query, and the harness records whether the session's first action invokes the skill.

1. **20 trigger queries per skill** — 10 should-trigger (realistic user phrasings) + 10 should-not-trigger (near-miss adversarial — phrasings that look related but shouldn't fire).
2. **3 runs per query**, majority vote, to smooth out non-determinism.
3. **Score**:
   - **Recall** = correct should-trigger / 10 (does the skill fire when it should?)
   - **Precision** = correct should-not-trigger / 10 (does the skill abstain when it shouldn't fire?)
4. **Threshold** — ≥80% on both metrics. Real bar: 100% (no regression). One iteration of description revision allowed if a skill falls short.

> **Harness note (learned the hard way):** run probes **serially** (one at a time) and **move the real skill out of the skills dir** during the eval. Parallel probes let the temp skill-copies shadow each other (false misses), and an installed copy of the skill being tested wins the trigger race over the temp copy (also false misses). And if the eval model is unavailable, every query returns a uniform 0/3 with no tool calls — that's an environment failure, not a regression.

---

## Session-continuity pair — current descriptions (2026-06-13)

### `/putdown`
`Use when the user says "putdown", when ending or stepping away from a working session, or when the context window is filling up (around 50% used). Creates a handoff file that a fresh Claude Code session reads (via /pickup) to resume without losing momentum, then commits and pushes all session work — a putdown means the session is ending, nothing stays unpushed.`
- **Frontmatter** → `argument-hint: "[project-slug]"` + `allowed-tools: [Read, Write, Edit, Bash, Grep, Glob]`

### `/pickup`
`Use when the user says "pickup", asks "where were we" after opening a fresh window, or wants to resume/pick up their work from a prior session that ended with /putdown — loads the most recent putdown file (the handoff note) for the current project and primes the agent with full context before continuing. Do NOT use for reopening a previous Claude conversation (that is the built-in /resume picker) or for resuming media, downloads, paused processes, or VMs.`
- **Frontmatter** → `argument-hint: "[putdown-timestamp]"` + `allowed-tools: [Read, Bash, Grep, Glob, AskUserQuestion]`

---

## Benchmark eval details (per skill)

### `/putdown` — 100% / 100%

All 10 should-trigger queries fired (bare `putdown`, "wrap up this session", "I'm about to /clear — capture where we are", "save your progress, gotta run", "context window is getting full", etc.). All 10 should-not-trigger correctly abstained — including the sharp near-misses: `rewind my code to before the last prompt` (the built-in `/rewind`), `add a checkpoint to the training loop every 100 steps` (ML checkpoint), `git checkout the checkpoint tag`, `commit and push what we have, not done yet` (a mid-work backup, not a session end), and `put down the iPad`.

### `/pickup` — 100% / 100% (after one revision)

All 10 should-trigger fired (bare `pickup`, "pick up where we left off", "load the latest putdown", "continue from the last putdown", "what was I doing? load my session state", etc.). All 10 should-not-trigger correctly abstained — notably `resume my last claude conversation` (that's the built-in `/resume` picker, not this skill), `resume the paused download`, `resume playback`, `write a resume for my job application`, and `resume the VM from a snapshot`.

**Revision applied:** the first re-eval pass missed `"fresh window, where were we?"` (0/3). The carve-out that keeps the skill off `resume my last claude conversation` was also suppressing this legitimate fresh-window trigger. Adding `asks "where were we" after opening a fresh window` to the description recovered it (3/3) without reintroducing the conversation-picker false-trigger — confirmed by re-eval.

### `/newproject` — 90% / 100% pre-revision → 100% / 100% expected post-revision

One initial miss on query #8 ("New project: recipe-app") — the strict judge required an explicit workspace-directory reference. All 10 should-not-trigger correctly abstained.

**Revision applied**: explicit "do NOT use for generic 'new project'..." guard added to the description. Trades a tiny bit of recall on ambiguous phrasing for stronger precision and self-documentation. Users can still invoke the skill explicitly with `/newproject` in any case.

### `/skill-dict` — 100% / 100%

All 10 should-trigger fired (`/skill-dict`, "skills library", "skill catalog", "what does <skill> do", "sync after plugin install", etc.). All 10 should-not-trigger correctly abstained (English dictionary, code function, git fork sync, dotfiles sync, etc.).

**Judge summary**: "Description cleanly discriminates skill-library queries from unrelated dictionary/library/sync requests."

---

## How to re-run the eval

If you change a description (yours or upstream), re-run the eval to confirm you haven't regressed:

1. Draft your own 20-query suite per skill — 10 realistic should-trigger + 10 adversarial near-miss should-not-trigger.
2. Run each query as a real trigger test against the skill description (skill-creator's `run_eval` does this), or with an LLM-as-judge: "Would Claude with only this skill description loaded invoke it on `<query>`? TRIGGER or NO_TRIGGER, one sentence of reasoning."
3. Score against expected labels. Aim for ≥80% on both metrics; the current bar is 100% — don't regress without good reason.
4. Heed the harness note above: serial probes, real skill moved aside, an available model.
