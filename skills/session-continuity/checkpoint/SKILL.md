---
name: checkpoint
description: Use when the context window is filling up (around 50% used) or before stepping away from a long session. Creates a handoff file that a fresh Claude Code session reads to resume without losing momentum.
argument-hint: "[project-slug]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
---

# /checkpoint — Context handoff before clearing

The user is about to clear the context window and start fresh. Your job: capture **everything a new agent would need** so the next session loses no momentum.

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
- If the user passed an argument (e.g. `/checkpoint jessica`), use that as the slug. This is the right choice when the CWD is a parent folder containing multiple projects (e.g. CWD is `CLAUDE` but the work is about jessica).
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
- Modified-but-uncommitted files: <list>
- Anything the user needs to manually do before resuming: <list or "none">

## First message to paste in the new session
> <Literal text the user should send. Easiest: just have them type `/resume` — the resume skill will pick up this latest checkpoint automatically. Only write a custom message if there's something the next agent needs to know that isn't captured in the sections above.>
```

## Step 5 — Show it to the user

After saving, print to chat — in this exact order:
1. The full path to the saved checkpoint file (so they can re-open it later)
2. **A clear-the-context reminder, matched to the current surface.** Use the `CLAUDE_CODE_ENTRYPOINT` value you read in Step 1 — the right way to free context differs by surface, so don't give the wrong one:
   - **Terminal CLI** (`CLAUDE_CODE_ENTRYPOINT` is `cli`) — this covers both a standalone terminal and VSCode's *integrated terminal*. Here `/clear` genuinely frees the context window. Tell the user to type `/clear`, then `/resume`. No window juggling needed.
     - **Exception:** if MCP servers or config were added/changed *this session*, `/clear` won't load them — the process must be restarted. Tell them to fully quit (`Ctrl+C` twice, or `/exit`) and relaunch `claude`, then `/resume`.
   - **VSCode visual-editor panel, or any other/unknown surface** (`CLAUDE_CODE_ENTRYPOINT` is anything other than `cli`, or empty) — `/clear` does **not** reliably free context here. Tell the user to **`Cmd+W` to close this Claude Code window, then open a new Claude Code window** in VSCode. (Closing affects only this window — other VSCode windows stay untouched. Note: `Cmd+Shift+P → "Developer: Reload Window"` does NOT actually free the context window — you confirmed this.)
3. A code block containing exactly `/resume` — what they type once the context is cleared (in the CLI, right after `/clear`; in a new/reopened window otherwise)
4. A one-line confirmation of what memory/CLAUDE.md was updated

Keep your final reply tight — the handoff document does the heavy lifting; don't summarize it again in chat.

## Notes on judgment

- **Be specific, not generic.** "Continue working on the auth flow" is useless. "In `<workspace-root>/jessica/pipeline/generate.py:142`, the `--seed` flag isn't being passed to ComfyUI; need to add it to the request payload" is useful.
- **Include failure context.** If you spent 20 minutes ruling something out, write it down so the next agent doesn't repeat it.
- **Don't overwrite prior checkpoints.** Each is timestamped; keep history.
- **If the project is brand new and there's nothing meaningful to hand off, say so** rather than padding with filler.
