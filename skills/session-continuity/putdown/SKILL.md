---
name: putdown
description: Use when the user says "putdown" or "checkpoint", when ending or stepping away from a working session, or when the context window is filling up (around 50% used). Creates a handoff file that a fresh Claude Code session reads (via /pickup) to resume without losing momentum, then commits and pushes all session work — a putdown means the session is ending, nothing stays unpushed.
argument-hint: "[project-slug]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
---

# /putdown — Context handoff before clearing

The user is about to clear the context window and start fresh. Your job: capture **everything a new agent would need** so the next session loses no momentum.

> Renamed 2026-06-12 from `/checkpoint` (paired with `/resume` → `/pickup`) because those names shadow Claude Code built-ins (`/checkpoint` is an alias for `/rewind`; `/resume` opens the conversation picker). The handoff FILES are still called checkpoints and still live in the same folders — nothing about storage changed.

## Step 1 — Read current state (parallel)

Before writing anything, gather context. Run these in parallel:

- `pwd` — where the session is rooted
- `git status` and `git log --oneline -10` — if it's a git repo (skip silently if not)
- `git diff --stat` — what's changed, uncommitted
- Read the project-level `CLAUDE.md` if one exists in the CWD
- Read `~/.claude/projects/<project-slug>/memory/MEMORY.md` to know which memory files exist
- Check the current TodoWrite list state (if you have one in this session — recall from conversation, don't invent)
- `echo "$CLAUDE_CODE_ENTRYPOINT"` — which surface this is. `cli` = terminal (standalone **or** VSCode's integrated terminal); anything else (or empty) = VSCode's visual-editor chat panel or another GUI surface. This decides the clear-context instructions in Step 5.

Also pull from your conversation memory:
- What was the user actually trying to accomplish in this session?
- What did you finish? What's half-done?
- What file paths and line numbers are you in the middle of?
- What did you try that didn't work, and why?
- Any decisions made with non-obvious rationale?
- Any errors, blockers, or open questions waiting on the user?

## Step 2 — Update memory files

Update auto-memory **only** for things that match the memory rules in the system prompt (user, feedback, project, reference). Do not save ephemeral conversation state to memory — that goes in the handoff file, not memory.

Specifically:
- If a `project_*.md` memory exists for this project, update it with the current state (status, what's next, blockers). Always convert relative dates to absolute dates.
- If something the user said this session qualifies as feedback (correction or validated approach), save it.
- If you learned something new about the user's role/preferences, update `user_profile.md`.

## Step 3 — Update the project CLAUDE.md (if applicable)

If there's a `CLAUDE.md` in the current project directory:
- Add or update sections that reflect **stable** facts about the project (architecture, conventions, how to run it, how to test it).
- Do NOT pollute CLAUDE.md with session-state ("we're currently working on X"). That belongs in the handoff file.
- If no project CLAUDE.md exists and the project has accumulated meaningful conventions, suggest creating one — don't create unprompted.

## Step 4 — Write the handoff file

Save to `~/.claude/checkpoints/<project-slug>/<YYYY-MM-DD-HHMM>.md`. Create the per-project subfolder if it doesn't exist (`mkdir -p`).

**Determining `<project-slug>`:**
- If the user passed an argument (e.g. `/putdown jessica`), use that as the slug. This is the right choice when the CWD is a parent folder containing multiple projects (e.g. CWD is `CLAUDE` but the work is about jessica).
- Otherwise, use the basename of the CWD (e.g. `jessica`, `BookmarkSync`).
- If the CWD basename looks like a multi-project parent (e.g. `CLAUDE`) and no argument was given, **ask the user** which project this checkpoint is for before saving — don't dump it under the parent folder name.

Use this structure exactly — the next agent will be reading it cold:

```markdown
# Checkpoint: <project> — <date> <time>

**CWD**: <absolute path>
**Branch / git state**: <branch, ahead/behind, dirty file count>
**Session goal (this conversation)**: <one paragraph — what the user came to do>

## Where we are right now
<2-4 sentences. The single most important section. If the next agent reads only this, they should be unblocked.>

## What's done this session
- <bullet>
- <bullet>

## What's in progress (resume here)
- <task>: <file:line>, <what state it's in>, <what's left>

## Immediate next steps (in order)
1. <concrete action with file path>
2. <concrete action>
3. <concrete action>

## Blockers / open questions for the user
- <thing waiting on user decision, or "none">

## Key decisions made & why
- <decision>: <rationale — especially anything non-obvious from the code>

## What NOT to redo
- <approaches already tried and rejected, with why — saves the next agent from repeating>

## Environment state
- Dev servers running: <list or "none">
- Background processes: <list or "none">
- Modified-but-uncommitted files: <list — should be "none" after Step 4.5 commits>
- Pushed to origin: <branch @ short SHA — filled in by Step 4.5; or "no remote" / "PUSH FAILED: <why>">
- Anything the user needs to manually do before resuming: <list or "none">

## First message to paste in the new session
> <Literal text the user should send. Easiest: just have them type `/pickup` — the pickup skill will load this latest checkpoint automatically. Only write a custom message if there's something the next agent needs to know that isn't captured in the sections above.>
```

## Step 4.5 — Commit + push (a checkpoint means the session is ending)

Skip this step entirely if the CWD is not a git repo.

1. **In-repo checkpoint copy — private repos only.** If the repo is **private** AND its contents are not publicly served (a GitHub Pages site publishes everything on its deployed branch), copy the just-written handoff file to `<repo>/.checkpoints/<same-YYYY-MM-DD-HHMM>.md` (`mkdir -p .checkpoints`). This is what makes the checkpoint readable from Claude Code on the web. For **public repos** and Pages-served repos, skip the copy — committed checkpoints there would be published; the local file in `~/.claude/checkpoints/` is the only copy. Check visibility with `gh repo view --json visibility` or the project CLAUDE.md; if still unsure, skip the copy and say so.
2. **Secrets gate before staging.** Run `git status --porcelain` and review the file list. Never stage `.env*` (except `.env.example`), `secrets*`, `*.pem`, `*.key`, or credential files — they should already be gitignored; if one shows up untracked, add it to `.gitignore` instead of committing it. Never use `git add -f`.
3. **Commit everything** with a descriptive message summarizing the session's work (not "checkpoint" — say what changed). Include the in-repo checkpoint copy from substep 1.
4. **Push** the current branch if a remote exists (`git push`, or `git push -u origin <branch>` for a new branch). Then update the handoff file's "Pushed to origin" line with `<branch> @ <short SHA>` — and refresh the in-repo copy if it is now stale. If there is **no remote** or the **push fails**, write that prominently in the handoff file and tell the user in Step 5 — never fail silently; unpushed work is invisible to web sessions.

## Step 5 — Show it to the user

After saving, print to chat — in this exact order:
1. The full path to the saved checkpoint file (so they can re-open it later)
2. **A clear-the-context reminder, matched to the current surface.** Use the `CLAUDE_CODE_ENTRYPOINT` value you read in Step 1 — the right way to free context differs by surface, so don't give the wrong one:
   - **Terminal CLI** (`CLAUDE_CODE_ENTRYPOINT` is `cli`) — this covers both a standalone terminal and VSCode's *integrated terminal*. Here `/clear` genuinely frees the context window. Tell the user to type `/clear`, then `/pickup`. No window juggling needed.
     - **Exception:** if MCP servers or config were added/changed *this session*, `/clear` won't load them — the process must be restarted. Tell them to fully quit (`Ctrl+C` twice, or `/exit`) and relaunch `claude`, then `/pickup`.
   - **VSCode visual-editor panel, or any other/unknown surface** (`CLAUDE_CODE_ENTRYPOINT` is anything other than `cli`, or empty) — `/clear` does **not** reliably free context here. Tell the user to **`Cmd+W` to close this Claude Code window, then open a new Claude Code window** in VSCode. (Closing affects only this window — other VSCode windows stay untouched. Note: `Cmd+Shift+P → "Developer: Reload Window"` does NOT actually free the context window — you confirmed this.)
3. A code block containing exactly `/pickup` — what they type once the context is cleared (in the CLI, right after `/clear`; in a new/reopened window otherwise)
4. A one-line confirmation of what memory/CLAUDE.md was updated
5. The commit + push result: `<branch> @ <short SHA> pushed to <repo>` — or a **prominent warning** if there was no remote or the push failed (that work is invisible to Claude Code on the web until pushed)

Keep your final reply tight — the handoff document does the heavy lifting; don't summarize it again in chat.

## Notes on judgment

- **Be specific, not generic.** "Continue working on the auth flow" is useless. "In `<workspace-root>/jessica/pipeline/generate.py:142`, the `--seed` flag isn't being passed to ComfyUI; need to add it to the request payload" is useful.
- **Include failure context.** If you spent 20 minutes ruling something out, write it down so the next agent doesn't repeat it.
- **Don't overwrite prior checkpoints.** Each is timestamped; keep history.
- **If the project is brand new and there's nothing meaningful to hand off, say so** rather than padding with filler.
