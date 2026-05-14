# `/checkpoint` + `/resume` — the session-continuity pair

> Install both, not one. They're a single feature split across two slash commands.

## What

Two skills that work as a pair to preserve work across Claude Code context resets:

- **`/checkpoint`** — at the end of a session (or whenever your context window is filling up), writes a structured handoff file that captures what you accomplished, what's still in flight, file paths you were mid-edit on, decisions you made and why, blockers waiting on you, and (critically) approaches you ruled out so the next session doesn't redo them.
- **`/resume`** — at the start of a fresh session, finds the most recent handoff for the current project, reads it, and primes the new agent with full context. Asks you to confirm before continuing.

`/resume` reads files that `/checkpoint` writes. Without `/checkpoint`, `/resume` has nothing to load. Without `/resume`, `/checkpoint`'s handoff sits unused.

## Why the pair exists

Claude Code's context window is finite. As a session grows, you hit limits. Three things people try:

1. **`/clear` and hope.** Loses every bit of judgment from the prior session — what you tried, what didn't work, why you took the third option instead of the obvious one.
2. **Auto-compaction.** Lossy and unstructured. Compresses recent history but doesn't differentiate "this was a dead end, don't redo" from "this is the next step."
3. **"Reload Window" in VSCode.** This doesn't actually free Claude Code's context-window memory. It feels like it should, but it doesn't. Only closing the Claude Code window with `Cmd+W` and opening a new one starts a fresh agent process.

`/checkpoint` solves all three by writing a structured markdown file with sections specifically designed for re-entering work: **Where we are right now**, **What's in progress (resume here)**, **Immediate next steps**, **Blockers**, **Key decisions made & why**, and **What NOT to redo**. The file lives at `~/.claude/checkpoints/<project-slug>/<timestamp>.md`.

`/resume` then loads it in a fresh session and confirms with you before picking up the work.

## Benefits — how each saves context

| Skill | Token cost saved |
|---|---|
| `/checkpoint` | Distills ~10k tokens of session state into a ~1k-token structured handoff |
| `/resume` | Restores full context in ~30s vs. 5–10 minutes of manual scroll-back-and-paste |

The structured format means the next agent skips ~80% of the context that would otherwise need re-explaining, and goes straight to "Immediate next steps."

## How to use them

The workflow is four steps:

1. **In the current session** (when you're at ~50% context usage or stepping away): type `/checkpoint`.
2. **Close the Claude Code window** with `Cmd+W`. (Do not use "Reload Window" — it doesn't actually free the context window.)
3. **Open a fresh Claude Code window.**
4. **Type `/resume`.** It finds your most recent checkpoint, summarizes it, and asks you to confirm before continuing.

If you have multiple parallel sessions in the same project (e.g. two VSCode windows in the same folder), `/resume` shows a picker with the 4 most recent checkpoints so you can grab the right one.

## Best practices

- **Run `/checkpoint` at ~50% context, not 90%.** Writing a good handoff takes tokens. Leave room for the agent to do it well.
- **Always close the window after `/checkpoint`.** "Reload Window" looks like it would work but doesn't.
- **`/resume` should be the very first thing in a new session**, not the fifth. Read the handoff before you start typing new instructions.
- **Trust the "What NOT to redo" section.** If the prior session ruled something out, don't relitigate it without a reason.
- **For multi-project parents** (a CWD that contains several subprojects), pass the slug: `/checkpoint myproject`.

## Why this is better than alternatives

| Alternative | Problem | How the pair solves it |
|---|---|---|
| `/clear` and hope | Loses judgment, file paths, blockers, ruled-out approaches | `/checkpoint` captures all of that in a structured file |
| Auto-compaction at the model layer | Lossy; misses "what NOT to redo"; not human-reviewable | `/checkpoint` has explicit "What NOT to redo" section; the file is markdown you can read and edit |
| Manual scroll-back-and-paste | Tedious, error-prone, forgets edge cases | `/resume` loads the structured handoff in seconds |
| External handoff doc you maintain by hand | Drifts; gets stale; forgotten between sessions | `/checkpoint` is a single slash command at end of session |

## Eval result

Both skills passed skill-creator's trigger-accuracy benchmark at 100% precision and 100% recall on a 20-query test set (10 should-trigger + 10 adversarial should-not-trigger). See the root [eval-results.md](../../eval-results.md) for full methodology.

## Install

See the root [INSTALL.md](../../INSTALL.md). Quick version:

```bash
cp -r charles-claude-skills/skills/session-continuity/{checkpoint,resume} ~/.claude/skills/
```

Then close your Claude Code window and open a fresh one.
