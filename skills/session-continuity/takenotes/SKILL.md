---
name: takenotes
description: Saves durable knowledge into permanent storage — typed memory, CLAUDE.md, or a docs/ file — and corrects anything already stored that has gone stale. Handles both a single fact and a whole-session harvest. Use when the user says "takenotes", asks you to remember or record something, asks you to save what was learned this session, or asks you to update memory and CLAUDE.md after solving a problem, making a decision, or reaching a natural checkpoint. Also invoked by /putdown. Do NOT use for transcribing a meeting, video, or article, or for capturing ephemeral session state (that is /putdown).
argument-hint: "[topic-to-focus-on]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
---

# /takenotes — Harvest a session into durable memory

Write this session's durable knowledge somewhere it survives a `/clear`.

This is **not** a transcript dump. It is a harvest, a reconcile, and a routing decision.

The value of this skill over a plain "save that to memory" is **Step 3**. Anyone can append a new
fact. Almost nobody goes back and checks whether what's already stored is still true. Do not skip it.

---

## Step 0 — Scope gate (always first)

Decide which of these you're doing. Getting this wrong makes the skill annoying to use.

| Situation | Do this |
|---|---|
| One discrete fact ("remember I prefer tabs", "the API key rotates monthly") | Take the **single-fact path** below. Do not run Steps 2–5. |
| Session checkpoint — solved a problem, made a decision, finished a feature, asked to "save what we learned" | Full harvest. Continue to Step 1. |
| A topic argument was passed (`/takenotes auth flow`) | Full harvest, but scope Steps 2–4 to that topic only. |
| Called from `/putdown` | Full harvest. Continue to Step 1. |
| Nothing durable happened (pure Q&A, reading code, no decisions) | Say so plainly in one line and stop. Do not manufacture findings to look productive. |

### Single-fact path

Skipping Steps 2–5 must not mean skipping the rules for writing a memory correctly. Do all of
these, then stop:

1. **Locate the memory directory** (Step 1a) — you still need to know where to write.
2. **Check for an existing memory on the topic** (`ls "$MEMDIR/memory/"`) and update it rather than
   adding a second file that says nearly the same thing.
3. **Decide scope.** If the fact is about *how the assistant should work* or *who you are*, it
   applies to every project, not just this one — see **Shared memories** in Step 4a. If it's about
   *this codebase*, it's local.
4. **Add the one-line pointer to `MEMORY.md`** — a memory file with no index entry is a file
   nothing loads.
5. **Say what you did**, including the file path and whether it applies beyond this project.

### Memory file format

Both the single-fact path and Step 4a write this shape. `metadata` is a **nested mapping**, not a
dotted key:

```markdown
---
name: short-kebab-case-slug
description: one-line summary — future sessions match on this, so be specific
metadata:
  type: user | feedback | project | reference
---

The fact itself, with absolute dates. For `feedback` and `project`, follow with **Why:** and
**How to apply:** lines. Link related memories with [[slug]], where `slug` is the other memory's
`name:` value — a link to a memory that doesn't exist yet is fine, it marks one worth writing.
```

The four types: `user` (who you are — role, expertise, what you're building), `feedback` (rules
that change what the assistant does), `project` (state of this work — what's done, blocked, ruled
out), `reference` (pointers to external things — URLs, dashboards, ticket IDs).

---

## Step 1 — Locate the targets

**1a. Resolve the memory directory.** Claude Code stores per-project memory under
`~/.claude/projects/<project-slug>/memory/`, where the slug is normally the absolute project path
with `/` replaced by `-`. Resolve it from the **actual listing** rather than by building the string:

```bash
SLUG=$(pwd | sed 's|/|-|g')
MEMDIR=$(ls -1d "$HOME/.claude/projects/"*/ 2>/dev/null | sed 's|/$||' | grep -ix ".*/$SLUG" | head -1)
echo "${MEMDIR:-NO MATCH}"
```

Do not use `ls -d "$HOME/.claude/projects/$SLUG"`. On a case-insensitive filesystem (macOS default)
that *succeeds* against a differently-cased directory and echoes back the path you typed — which
then appears wrong in every report and breaks outright on a case-sensitive volume.

If `MEMDIR` comes back empty there's no memory dir yet — and since `$MEMDIR` is then the empty
string, **do not run `mkdir -p "$MEMDIR/memory"`**: that creates `/memory` at the filesystem root.
Build the path explicitly instead, and only if there's genuinely something to store:

```bash
MEMDIR="$HOME/.claude/projects/$SLUG"
mkdir -p "$MEMDIR/memory"
```

Throughout this skill `$MEMDIR` is the **project** directory; memory files live in `$MEMDIR/memory/`.

**1b. Read the index** — `$MEMDIR/memory/MEMORY.md`. It tells you what already exists without
reading every file.

**1c. Check for shared memories.** List the directory (`ls -la "$MEMDIR/memory/"`). If any entries
are **symlinks**, they point at a shared store used by more than one project — editing one changes
the rule everywhere. See **Shared memories** in Step 4a. If everything is a real file, all memory
here is local to this project and you can skip that section entirely.

**1d. Find the CLAUDE.md files and their line counts.**

```bash
wc -l ./CLAUDE.md 2>/dev/null
ls docs/ 2>/dev/null
```

List `docs/` too — you need to know which spoke files exist before creating new ones.

**1e. Drain the handoff memory inbox, if one exists.**

```bash
cat .putdowns/MEMORY-INBOX.md 2>/dev/null
```

Claude Code on the web can't reach `~/.claude/projects/`, so if you use `/putdown` there it queues
memory-bound findings in this file rather than dropping them. If it exists and has content, treat
each block as a harvest candidate alongside this session's own findings. Once the blocks are
genuinely written to memory, clear the file back to its bare `# Memory inbox` heading (don't delete
it) and note the drain in Step 5. If a block is stale or already covered, say so rather than writing
a duplicate. No inbox is the normal case — say nothing.

---

## Step 2 — Harvest candidates from the session

Pull out everything that would still matter to an agent who reads none of this conversation. For
each candidate, name **what it is** — that determines where it goes in Step 4.

Look for:

- **Decisions with non-obvious rationale.** Not what was chosen — *why*, and what was rejected.
- **Dead ends.** What was tried that didn't work, and the reason. This is the highest-value and most
  frequently lost category: the difference between a future session losing 20 minutes or zero.
- **Corrections.** If the user pushed back on your approach, that's `feedback`.
- **Facts about the user** — role, expertise, tools, what they're building. That's `user`.
- **Project state** — what works, what's deferred, what's blocked, what's ruled out. That's `project`.
- **External pointers** — URLs, dashboards, ticket IDs, account names. That's `reference`.
- **Stable project facts** — architecture, conventions, build/test/run commands. That's **CLAUDE.md**,
  not memory.
- **Gotchas** a fresh agent would step on. CLAUDE.md if short, `docs/` if not.

Deliberately exclude:

- Ephemeral session state ("we're mid-refactor on line 142") — that's `/putdown`'s job, not memory's.
- Anything the code, git history, or an existing CLAUDE.md already records. Memory is for what
  *isn't* recoverable from the repo.
- Secrets, credentials, tokens, keys — **never**, in any file, in any form. If a value came from a
  credential file, record only that it exists and where, never its contents.

---

## Step 3 — Reconcile against what's already stored

**This is the step that makes the skill worth running.** For every existing memory and CLAUDE.md
section this session's work touched:

1. **Is it still true?** Memories record what was true *when written* — some are months old.
2. **Did this session contradict it?** If so it's wrong now. Correct it; don't stack a contradicting
   fact beside it and leave both. Correcting is not erasing: if the old belief explains why the code
   looks the way it does ("we believed the vendor couldn't send webhooks until 2026-07-28, which is
   why polling existed"), keep one sentence of it. You're deleting the false *instruction*, not the
   record that it was once believed.
3. **Did this session supersede it?** Update in place rather than creating a near-duplicate. Two
   memories saying almost the same thing is worse than one — the next agent won't know which to trust.
4. **Do its concrete references still exist?** If a memory names a file, function, flag, script, or
   path, verify it:

```bash
ls <path-referenced-in-memory> 2>/dev/null || echo "STALE: <path>"
```

If the filesystem isn't authoritative here — you aren't in the repo, the tree isn't checked out, or
the paths sit outside the project — this check proves nothing, because a correct current path and a
deleted one both come back missing. Say so and reconcile from what the session established instead.

5. **Is it now wrong enough to delete?** Deleting a false memory is a real improvement. Say what you
   deleted and why in Step 5 — never silently.

Reconcile `MEMORY.md` too: if its one-line hooks no longer describe their files, fix them.

---

## Step 4 — Route and write

### 4a. Memory files

Write to `$MEMDIR/memory/<name>.md` in the shape given under **Memory file format** in Step 0.

- **Check for an existing file on the topic first** and update it instead of duplicating.
- **Convert relative dates to absolute** — "last week" is meaningless to a future reader.
- **Add a one-line pointer to `MEMORY.md`** — `- [Title](file.md) — hook`. One line, never content.

**Shared memories (optional — skip unless Step 1c found symlinks).**

Some multi-project setups keep cross-project rules (`feedback_*`, `user_*`) in one canonical store
and symlink them into each project's memory dir, so a rule written once applies everywhere. If
that's how this machine is set up:

- *Editing a shared memory* changes the rule for every project. That's often correct — it is never
  something to do silently. Say so in Step 5.
- *Creating a new shared memory* means writing it to the canonical store and re-running whatever
  sync step creates the symlinks. Skip that and it exists in one place and applies nowhere else.
- *Deciding which it is:* a rule about **how the assistant should work** regardless of project is
  shared. A fact about **this codebase** is local. When genuinely unsure, write it local — a local
  memory that should have been shared is a small loss; a shared memory that should have been local
  pollutes every project.

If Step 1c found no symlinks, none of this applies — write everything local.

### 4b. CLAUDE.md — guarded

CLAUDE.md is auto-loaded into context on **every session start**. Every line costs tokens forever.
Treat it as an index, not a document.

**Which CLAUDE.md?** Default to the project's own (`./CLAUDE.md`). If the workspace has a parent or
umbrella CLAUDE.md, that one is only correct for facts about the *workspace itself* — a new
subproject, a convention spanning projects. A fact about one project's code never belongs there.

Before writing, apply this gate in order:

1. **Does it belong here at all?** CLAUDE.md holds stable, structural facts: what the project is,
   critical gotchas, entry-point files, build/test/run commands, pointers to docs. It does **not**
   hold history, rationale, session state, long prose, or anything already in a parent CLAUDE.md.
   Rationale and history go to **memory**. If it fails this test, stop — route it elsewhere.

2. **How many lines would it add?**
   - **≤ 15 lines** → inline it.
   - **> 15 lines** → **extract to a `docs/` spoke** (4c) and inline only a pointer. Apply this
     *regardless of the current line count*. A 40-line block that fits under any cap still costs
     context on every session start — size is the trigger, not the cap.

   Measure the version you would actually write, not the tersest one you could compress it to —
   otherwise the threshold just ratifies whichever way you were already leaning. Anchor: if it needs
   more than a pointer plus two or three facts, it's a spoke.

3. **Backstop: keep CLAUDE.md under ~250 lines.** If an edit would breach that, refactor an existing
   oversized section out to `docs/` rather than declining to write. Target ~150 for headroom.

4. **Structural changes get shown before saving — but only actual restructuring.** Writing a *new*
   `docs/` spoke for new content moves nothing; just write it. Moving content that is *already in*
   CLAUDE.md out to `docs/` is a refactor — show the diff and let the user approve. When invoked
   from `/putdown` there may be no one available to approve; in that case make the change and report
   it prominently rather than blocking.

### 4c. `docs/` spokes

For anything over the 15-line threshold:

1. **Check for an existing file on the topic first** — `ls docs/`. Append to `docs/architecture.md`
   rather than creating `docs/architecture-notes-2.md`. A new file per finding just moves the sprawl
   one directory over.
2. Write to `docs/<topic>.md` with a real `#` heading and enough context to stand alone — someone
   opening it cold shouldn't need the CLAUDE.md line to understand it.
3. **Link it from CLAUDE.md with a pointer that earns its place.** The pointer exists so a future
   agent can decide *whether to open the file* without opening it. A bare link fails at that:

```markdown
❌  See [docs/webhooks.md](docs/webhooks.md)

✅  Webhook signing — see [docs/webhooks.md](docs/webhooks.md) for the signature algorithm,
    header names, and the replay-window handling.
```

Name the contents, not the existence of the file.

---

## Step 5 — Report

Print a compact summary. Paths, not prose — the user wants to know what moved and be able to open it.

```
Memory
  updated    project_sync.md — polling replaced by webhooks; old "no webhooks" claim was false
  created    reference_vendor_signing.md — HMAC ordering gotcha
  deleted    project_old_approach.md — superseded, abandoned 2026-08-03
  reconciled MEMORY.md — 2 hooks rewritten

CLAUDE.md / docs
  ./CLAUDE.md  +3 lines (now 88) — added the sync entry point
  created      docs/webhook-signing.md (58 lines) — new spoke, new content; linked from CLAUDE.md

Not stored
  mid-refactor state at receiver.py:142 — ephemeral, belongs in /putdown
```

Then:

- **Flag shared-memory writes explicitly.** "This now applies to all your projects" is something the
  user must actually see.
- **Do not commit.** Mid-session runs leave changes for `/putdown` to sweep, which keeps this skill
  safe to run at any moment without touching git state. If asked to commit, do it.
- Keep the reply tight. The files are the deliverable.

---

## Notes on judgment

- **Be specific or don't bother.** "Learned about the sync logic" is worthless. "Sync silently
  no-ops when the container isn't in the entitlements file — cost 40 minutes on 2026-08-03; check
  entitlements first" is worth keeping forever.
- **Dead ends are the highest-value thing you can write.** They're invisible in the code and
  unrecoverable from git. Write them down every time.
- **Fewer, better memories.** Consolidating two overlapping memories into one correct memory beats
  adding a third.
- **When a finding is real but its payload is missing, write the gap — never invent the values.** If
  the session established that three test vectors matter but you never saw them, record what they're
  for and where to get them, under an explicit "not captured" label. Plausible-looking invented
  values are worse than an acknowledged hole: they fail later and the blame lands on the code.
- **A finding can belong in two places.** When something is both memory-worthy and too long for
  CLAUDE.md, write the short version in memory and the detail in a `docs/` spoke, and have the memory
  name the spoke. That's deliberate, not the duplication "fewer, better memories" warns against —
  that rule is about two memories competing to describe the same thing.
- **Suspicious but unverified ≠ stale.** If something looks like it may have been falsified but the
  session never said so, leave it and flag it for a human. Silently deleting a working command is
  worse than leaving a questionable line in place.
- **Don't manufacture findings.** A short honest "nothing durable this session" is a good outcome and
  preserves trust in the summary.
