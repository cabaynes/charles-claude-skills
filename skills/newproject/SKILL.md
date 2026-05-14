---
name: newproject
description: Use when bootstrapping a new project under a configured workspace directory ($WORKSPACE_DIR, default ~/projects/), or when an existing project folder needs the standard infrastructure (CLAUDE.md stub, memory dir, optional git init, optional umbrella entry). Triggers only when the user references a project folder under the workspace — do NOT use for generic git init, npm/Xcode init, or single-file creation. Idempotent — never overwrites existing user content.
argument-hint: "[project-name]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
---

# /newproject — Bootstrap or finish setting up a workspace project

The user wants to start a project under their workspace directory `$WORKSPACE_DIR` (default `~/projects/`). The folder may not exist yet OR it may already exist with partial setup (e.g., they did `mkdir $WORKSPACE_DIR/foo` and `code $WORKSPACE_DIR/foo` already). Your job: detect what's in place and create only what's missing — **never overwrite existing user content**.

## What ends up created

1. `$WORKSPACE_DIR/<name>/` — empty project directory
2. `$WORKSPACE_DIR/<name>/CLAUDE.md` — starter project documentation (stub)
3. `~/.claude/projects/<project-slug>/memory/` — memory dir (with universal-symlink fan-out if a `fanout-memory.sh` helper exists in `$WORKSPACE_DIR/scripts/`)
4. **Optional:** `$WORKSPACE_DIR/<name>/.git/` — initialized git repo with sensible `.gitignore`
5. **Optional:** updated `$WORKSPACE_DIR/CLAUDE.md` — if an umbrella file exists with a `## Subprojects` section, append an entry

## Step 1 — Resolve `WORKSPACE_DIR`

Check the env var:

```bash
echo "${WORKSPACE_DIR:-}"
```

- If set, use that path (expand `~` if present).
- If unset, **ask the user once** via `AskUserQuestion`:
  > "WORKSPACE_DIR isn't set. Default is `~/projects/`. Use that, or specify a different path?"
  > Options: `Use ~/projects/` | `Use a different path` (free-text)
- After resolution, recommend (don't enforce) that the user export it in their shell rc so they don't have to set it each session.

For the rest of this skill, **`$WORKSPACE_DIR`** is the resolved absolute path (e.g. `/Users/alice/projects`).

## Step 2 — Get the project name and one-line description

If the user provided a name as an argument, use it. Otherwise ask:

> "What's the project name? (lowercase, hyphens for spaces, no special characters — e.g., `tax-tracking`, `family-recipes`)"

Then ask:

> "One-line description for the umbrella CLAUDE.md? (e.g., 'Personal tax document tracker' or 'Recipe collection app')"

If `$WORKSPACE_DIR/CLAUDE.md` doesn't exist, the description is optional — skip if blank.

## Step 3 — Validate the name

Must match `^[a-z][a-z0-9-]*$` — starts with lowercase letter, then lowercase alphanumerics and hyphens. If not, ask the user to choose a different name (don't auto-correct, since they may have a specific naming preference).

## Step 4 — Survey current state (read-only)

Run all checks in parallel:

- `test -d "$WORKSPACE_DIR/<name>" && echo HAS_FOLDER || echo NEW_FOLDER` — note whether folder exists; either case is fine.
- `test -f "$WORKSPACE_DIR/<name>/CLAUDE.md" && echo HAS_CLAUDE_MD || echo NO_CLAUDE_MD` — note whether the project already has a CLAUDE.md.
- `test -d "$WORKSPACE_DIR/<name>/.git" && echo HAS_GIT || echo NO_GIT` — note whether git is already initialized.
- `test -f "$WORKSPACE_DIR/CLAUDE.md" && echo HAS_UMBRELLA || echo NO_UMBRELLA` — does the workspace have an umbrella CLAUDE.md to update?
- `test -x "$WORKSPACE_DIR/scripts/fanout-memory.sh" && echo HAS_FANOUT || echo NO_FANOUT` — does the optional fan-out helper exist?

These are all informational — they tell you which steps below to skip vs. run.

Quickly summarize to the user what you found, e.g.:

> "Folder already exists. Has: nothing yet. Will set up: CLAUDE.md stub, memory dir, optionally git. Umbrella file: present, will append entry. Fan-out script: not found, will use plain mkdir for memory dir."

## Step 5 — Create the folder (only if missing)

```bash
mkdir -p "$WORKSPACE_DIR/<name>"
```

`mkdir -p` is safe regardless of whether the folder exists.

## Step 6 — Generate the starter CLAUDE.md (ONLY if missing)

If the survey reported `HAS_CLAUDE_MD`, **skip this step entirely** and tell the user "CLAUDE.md already exists, leaving alone." Never overwrite a CLAUDE.md the user may have already started writing.

If `NO_CLAUDE_MD`, write `$WORKSPACE_DIR/<name>/CLAUDE.md` with this template (substituting name and description):

```markdown
# <Name>

<one-line description from Step 2, or omit if blank>

## Project goals
_(Add as the project takes shape.)_

## Repo layout
_(Document folders/files as the structure emerges.)_

## Conventions
_(Add as patterns appear — naming, error handling, commit style, etc.)_

## External references
_(Links to related repos, docs, dashboards, vendor accounts.)_

## Notes
_(Track ongoing decisions and context here.)_
```

Capitalize the project name appropriately (e.g., `tax-tracking` → `Tax Tracking`, `BookmarkSync` → `BookmarkSync`). Use sensible title-casing.

## Step 7 — Set up the memory directory

Compute the project slug from the absolute project path (this matches how Claude Code derives memory dir names):

```bash
SLUG="$(echo "$WORKSPACE_DIR/<name>" | tr '/' '-' | sed 's/^-//')"
MEMORY_DIR="$HOME/.claude/projects/$SLUG/memory"
```

Then:

**If `HAS_FANOUT`**: run the helper to set up the memory dir with universal-symlink fan-out:

```bash
"$WORKSPACE_DIR/scripts/fanout-memory.sh" <name>
```

(The fan-out helper is a user-supplied convention for symlinking universal memories from a workspace-level memory hub into each project's memory dir. If you've never used one, ignore — the fallback below handles you.)

**Otherwise**: create the memory directory plainly:

```bash
mkdir -p "$MEMORY_DIR"
# Seed an empty MEMORY.md if one doesn't exist
if [ ! -f "$MEMORY_DIR/MEMORY.md" ]; then
  touch "$MEMORY_DIR/MEMORY.md"
fi
```

Show the user what was created vs. already present.

## Step 8 — Git (only if `.git` doesn't already exist)

If the survey reported `HAS_GIT`, **skip this step** and tell the user "git already initialized, leaving alone."

If `NO_GIT`, ask: *"Initialize git for this project? (y/n)"*

If yes:

```bash
cd "$WORKSPACE_DIR/<name>" && git init -b main
```

Then create `.gitignore` with sensible defaults (only if no `.gitignore` exists yet):

```
.DS_Store
.env
.env.local
*.log
__pycache__/
node_modules/
.venv/
venv/
build/
dist/
*.pyc
.idea/
.vscode/*.local.json
```

Commit nothing yet — let the user make the first commit when they have actual content.

## Step 9 — Update the umbrella CLAUDE.md (only if applicable)

If `NO_UMBRELLA` (no `$WORKSPACE_DIR/CLAUDE.md` exists), **skip this step**. Don't create an umbrella file unprompted.

If `HAS_UMBRELLA`, look for a `## Subprojects` section in `$WORKSPACE_DIR/CLAUDE.md`. If absent, **skip** — don't restructure the user's umbrella file unprompted.

If present, check whether the project is already listed:

```bash
grep -q "^- \[<name>/](<name>/) " "$WORKSPACE_DIR/CLAUDE.md" && echo HAS_ENTRY || echo NO_ENTRY
```

If `NO_ENTRY`, append a new line in the same format as existing entries:

```
- [<name>/](<name>/) — <one-line description from Step 2>
```

Keep alphabetical order if the existing list is alphabetical, otherwise append at the end.

## Step 10 — Confirmation summary

Print a tight summary that matches what was actually done. Use ✓ for things created and ⊘ (or "skipped") for things already in place. Example output for a half-existing project:

```
Project: tax-tracking
WORKSPACE_DIR: /Users/alice/projects

  ⊘ Folder already existed at /Users/alice/projects/tax-tracking/
  ✓ Created CLAUDE.md (starter — fill in as you go)
  ✓ Memory dir set up at ~/.claude/projects/-Users-alice-projects-tax-tracking/memory/ (fallback — no fan-out script found)
  ⊘ Skipped git (already initialized)
  ✓ Added entry to umbrella /Users/alice/projects/CLAUDE.md

Next:
  Open in VSCode:  code /Users/alice/projects/tax-tracking
  Or in this session:  cd /Users/alice/projects/tax-tracking
```

End the skill cleanly — don't start working on the project unless the user asks.

## Edge cases

- **`WORKSPACE_DIR` unset and user doesn't want `~/projects/`**: ask for a custom path, validate it exists (or offer to `mkdir -p`), then proceed.
- **No argument given for name**: ask the user (Step 2).
- **Invalid name**: ask the user to rename, don't auto-correct.
- **Folder already exists with partial setup**: that's the expected case — proceed additively. Never overwrite existing `CLAUDE.md`, `.git`, or other user content.
- **Folder doesn't exist**: also fine — `mkdir -p` creates it.
- **No description given**: prompt the user for one before updating the umbrella file (or skip the umbrella update if they don't have one). Don't write "TBD" into the umbrella — that file is user-facing and a placeholder there is awkward.
- **Fan-out script missing**: not an error — use the plain `mkdir` fallback in Step 7 and tell the user.

## Why this is a skill rather than just a script

A pure shell script could do most of this but would feel rigid; the skill lets the agent:

- Adapt the starter CLAUDE.md template to match existing-project conventions
- Ask about description and git preferences conversationally
- Update the umbrella file in a way that matches its existing structure (alphabetical vs. chronological, with vs. without descriptions)
- Skip steps cleanly when they're already done, without erroring

The conversational shape is the point — bootstrap workflows benefit from a moment of judgment per step.
