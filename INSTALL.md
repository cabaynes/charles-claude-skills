# Install

Three steps to install any combination of the four skills in this repo. They're all standalone except for the **session-continuity pair** (`/putdown` + `/pickup`), which must always be installed together.

## Prerequisite

You need Claude Code installed. User-scope skills live at `~/.claude/skills/<name>/SKILL.md` and are auto-discovered on session start.

## 1. Session-continuity pair: `/putdown` + `/pickup`

These are a matched pair — `/pickup` reads the handoff files that `/putdown` writes. Installing one without the other gets you half a feature.

```bash
git clone https://github.com/cabaynes/charles-claude-skills.git
cp -r charles-claude-skills/skills/session-continuity/{putdown,pickup} ~/.claude/skills/
```

That copies **both** skill folders into `~/.claude/skills/` in one command. Verify:

```bash
ls ~/.claude/skills/putdown/SKILL.md ~/.claude/skills/pickup/SKILL.md
```

No environment-variable setup required.

## 2. Optional: `/newproject`

Bootstraps a new project directory with a starter `CLAUDE.md`, memory directory, optional git init, and optional umbrella-file entry.

```bash
cp -r charles-claude-skills/skills/newproject ~/.claude/skills/
```

**Configure your workspace directory once** (the skill asks the first time, but setting this in your shell rc skips that step forever):

```bash
# In ~/.zshrc or ~/.bashrc:
export WORKSPACE_DIR=~/projects
```

Optional: if you keep a memory-fan-out script at `$WORKSPACE_DIR/scripts/fanout-memory.sh` (a user-supplied helper that symlinks universal memory files into each project), the skill will use it. Otherwise it falls back to plain `mkdir`.

## 3. Optional: `/skill-dict`

Maintain a hand-curated catalog of every Claude Code skill you've installed or authored.

```bash
cp -r charles-claude-skills/skills/skill-dict ~/.claude/skills/
```

By default, the skill looks for the catalog at `~/skills-library/`. If you want a different path, edit `~/.claude/skills/skill-dict/SKILL.md` and replace the `~/skills-library/` references with your preferred location.

## Symlink vs. copy

The instructions above use `cp -r` (copy). The alternative is `ln -s` (symlink) — that way, when you `git pull` to update the repo, the installed skills update too.

**Copy** (default):
- ✓ Independent of the repo after install
- ✗ Updates require re-running `cp`

**Symlink:**
```bash
# Example for the session-continuity pair:
ln -s "$(pwd)/charles-claude-skills/skills/session-continuity/putdown" ~/.claude/skills/putdown
ln -s "$(pwd)/charles-claude-skills/skills/session-continuity/pickup" ~/.claude/skills/pickup
```
- ✓ `git pull` updates your installed skills
- ✗ Deleting the repo breaks your installed skills

Pick based on whether you plan to track upstream.

## After install: restart Claude Code

Newly installed skills are discovered when Claude Code starts a new session. In VSCode, **close the Claude Code window (Cmd+W) and open a fresh one**.

> ⚠️ `Cmd+Shift+P → Developer: Reload Window` does **NOT** free Claude Code's context window memory and does NOT reliably refresh the skill registry. Only opening a fresh Claude Code window works.

## Troubleshooting

**Skill doesn't appear in the registry:**
1. Confirm the folder structure: `~/.claude/skills/<name>/SKILL.md` (the `SKILL.md` file must be exactly that name).
2. Confirm the YAML frontmatter is valid (no tabs, no trailing whitespace, all required fields present: `name`, `description`).
3. Open a fresh Claude Code window (not Reload Window).

**Permission prompts every time I invoke a skill:**
Each skill ships with an `allowed-tools` frontmatter field that pre-authorizes the tools it needs. If you're still getting prompts, your Claude Code settings may be overriding this. Check `~/.claude/settings.json` and `~/.claude/settings.local.json` for permission entries that conflict.

**`/putdown` says "no project slug, multi-project parent":**
Pass the slug as an argument: `/putdown <name>`. This happens when your CWD is a parent folder containing multiple projects (e.g. you're in `~/projects/` rather than `~/projects/foo/`).

**`/pickup` can't find a putdown:**
Make sure the putdown files exist at `~/.claude/putdowns/<project-slug>/`. If you're in a different CWD than when you ran `/putdown`, the project slug won't match — see the `/pickup` skill's "no putdown found" branch, which lists all available project slugs.

**`/newproject` keeps asking about `WORKSPACE_DIR`:**
Export it in your shell rc so it persists across sessions (see step 2 above).

## Uninstall

```bash
rm -rf ~/.claude/skills/{putdown,pickup,newproject,skill-dict}
```

Restart Claude Code in a fresh window.
