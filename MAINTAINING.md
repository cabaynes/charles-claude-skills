# Maintaining `charles-claude-skills`

The release workflow. If you edited a local skill and want the change to show up in the public repo, this is the path.

## Mental model

- **Canonical source** = `~/.claude/skills/<name>/SKILL.md` (the local copies Claude Code uses day-to-day for the maintainer).
- **Public repo** = this folder (`~/CLAUDE/charles-claude-skills/`). A **one-way snapshot** of the canonical source, with personal paths and names sanitized.
- **Source of truth flows one direction**: local → repo. Never the other way.
- **`/newproject` is the exception** — it diverges intentionally. Local is hard-coded to `~/CLAUDE/`; the public copy uses `$WORKSPACE_DIR`. `snapshot.sh` skips it.

## Files in this repo, and where each lives canonically

| Repo path | Canonical source | Refreshed by |
|---|---|---|
| `skills/session-continuity/putdown/SKILL.md` | `~/.claude/skills/putdown/SKILL.md` | `snapshot.sh` |
| `skills/session-continuity/pickup/SKILL.md` | `~/.claude/skills/pickup/SKILL.md` | `snapshot.sh` |
| `skills/skill-dict/SKILL.md` | `~/.claude/skills/skill-dict/SKILL.md` | `snapshot.sh` |
| `skills/skill-dict/references/*.md` | `~/.claude/skills/skill-dict/references/*.md` | `snapshot.sh` |
| `skills/newproject/SKILL.md` | **this file is canonical here** (parameterized fork) | Edit directly |
| `skills/*/README.md` | **canonical here** | Edit directly |
| `skills/*/LICENSE` | Copy of root `LICENSE` | Manual copy or `cp` after editing root |
| `README.md`, `INSTALL.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `eval-results.md` | **canonical here** | Edit directly |
| `scripts/snapshot.sh` | **canonical here** | Edit directly |

## Releasing an edit to an existing skill

You changed `~/.claude/skills/putdown/SKILL.md` (or `pickup`, or `skill-dict`). To ship that change:

```bash
# 1. Refresh the repo snapshot (copy + sanitize)
bash ~/CLAUDE/charles-claude-skills/scripts/snapshot.sh

# 2. Review the diff
cd ~/CLAUDE/charles-claude-skills && git diff

# 3. If you changed a description: re-run the eval (see CONTRIBUTING.md)
#    Paste the new precision/recall + judge summary into eval-results.md
#    Update the headline table in eval-results.md if numbers changed

# 4. Bump CHANGELOG.md — add a new version entry under a new ## heading
#    Example:
#    ## [0.2.0] — YYYY-MM-DD
#    ### Changed
#    - /putdown: <one-line summary of the change and why>

# 5. Update the version badge in README.md if you bumped a major number

# 6. Verify sanitization (defense in depth — snapshot.sh hard-fails on residue:
#    a leaked "Charles" or a third-person pronoun (he/his/him/he's) left after
#    sanitizing aborts the snapshot. If it does, fix the LOCAL source — rewrite
#    third-person subject lines ("Charles maintains ... he's installed") as
#    possessives ("Charles's") or second person ("You maintain") — then re-run.)
grep -rnE '/Users/charles|Charles' ~/CLAUDE/charles-claude-skills/skills/

# 7. Commit + push
cd ~/CLAUDE/charles-claude-skills
git add .
git commit -m "<version>: <one-line summary>"
git push
```

That's it. The repo now reflects your local change.

## Releasing an edit to `/newproject` (the public version)

`snapshot.sh` skips `/newproject` because local and public diverge structurally. If you want to update the public parameterized version:

```bash
# Edit directly in the repo:
vim ~/CLAUDE/charles-claude-skills/skills/newproject/SKILL.md

# Then steps 3–7 above (eval if description changed, bump CHANGELOG, verify, commit, push)
```

If you want to update the **local** (Charles-specific) version, edit `~/.claude/skills/newproject/SKILL.md` directly. That change does NOT propagate to the public repo unless you also make the equivalent change in the parameterized fork.

## Adding a new skill to the public repo

You authored a new skill at `~/.claude/skills/<new-name>/SKILL.md` and want it shipped.

1. **Decide bundling**: standalone (like `/skill-dict`) or paired with another skill (like the session-continuity pair)? If paired, the two skills live in a shared parent folder under `skills/`.
2. **Edit `scripts/snapshot.sh`**:
   - Add the new skill to the copy block at the top.
   - Add its `SKILL.md` (and any `references/*.md`) to the `SANITIZE_TARGETS` array.
3. **Run snapshot.sh**: produces `skills/<new-name>/SKILL.md` in the repo.
4. **Write `skills/<new-name>/README.md`**: ~400-500 words, sections: What / Benefits / Best practices / Why better than alternatives / Eval result / Install. Use `skills/skill-dict/README.md` as a template.
5. **Copy LICENSE**: `cp LICENSE skills/<new-name>/LICENSE`
6. **Update top-level `README.md`**: add a row to the "Standalone utilities" table (or create a new bundle section if it's a pair).
7. **Update `INSTALL.md`**: add a copy-command block for the new skill.
8. **Update `CHANGELOG.md`**: new version entry under a new `##` heading.
9. **Run the 20-query eval** on the new skill's description. Methodology in `CONTRIBUTING.md`. Append results to `eval-results.md` (headline table + per-skill section).
10. **Verify sanitization**: `grep -rnE '/Users/charles|Charles' skills/`
11. **Commit + push**.

## Verifying the release

Before pushing, sanity-check:

```bash
# Sanitization sweep (zero matches outside LICENSE copyright lines and snapshot.sh self-references)
grep -rnE '/Users/charles|Charles' ~/CLAUDE/charles-claude-skills/

# Confirm skills/ has no personal paths or names
grep -rnE '/Users/charles|Charles' ~/CLAUDE/charles-claude-skills/skills/

# Diff against last release
cd ~/CLAUDE/charles-claude-skills && git diff HEAD~1
```

After pushing, open the GitHub repo and confirm:
- The new README content renders correctly
- The badge images load
- The eval-results.md table reflects the latest numbers
- The skill folder structure looks right in the file browser

## What the eval is for

Each public skill should have ≥80% precision and recall on a 20-query trigger-accuracy benchmark before release. The bar today is 100% — don't regress it without good reason.

Methodology lives in `CONTRIBUTING.md`. Short version:

1. Draft 20 queries per skill — 10 should-trigger (realistic) + 10 should-not-trigger (adversarial near-miss).
2. Have an LLM-as-judge sub-agent score each query against just the skill description, deciding TRIGGER or NO_TRIGGER.
3. Compute recall = correct TRIGGER / 10, precision = correct NO_TRIGGER / 10.
4. If either drops below 80%, revise the description and re-run (max 2 iterations).

You can spawn 4 parallel sub-agents (one per skill, one query batch each) to make this fast. Past evals are in `eval-results.md` — replicate that structure for new entries.

## Why this workflow exists

- **Snapshot pattern** = local-as-source, repo-as-snapshot. Lets you edit one place (your daily-use copies) and ship without manual copy-pasting. Sanitization runs as part of the snapshot so you can't accidentally publish `/Users/charles/...` paths.
- **`/newproject` divergence** = the local version assumes Charles's `~/CLAUDE/` workspace + fan-out memory script; the public version reads `$WORKSPACE_DIR` and works without the helper. Maintaining both isn't free, but the alternatives are worse: either ship a Charles-specific skill nobody else can use, or make Charles's local workflow more complex.
- **Bundling `/putdown` + `/pickup` in `session-continuity/`** = they only work as a pair. Structural enforcement prevents anyone (including future-you) from installing half of the feature.
- **Eval gate on description changes** = trigger accuracy is the one quality metric that's easy to regress and hard to notice. Running the eval before pushing catches that automatically.

## Quick reference: the most common commands

```bash
# Most common: I changed a local skill and want to push the update
bash ~/CLAUDE/charles-claude-skills/scripts/snapshot.sh \
  && cd ~/CLAUDE/charles-claude-skills \
  && git diff  # review
# ...bump CHANGELOG, then:
git add . && git commit -m "..." && git push

# Less common: I changed only the parameterized /newproject in the repo
cd ~/CLAUDE/charles-claude-skills && git diff
git add . && git commit -m "..." && git push

# Verify nothing personal leaked
grep -rnE '/Users/charles|Charles' ~/CLAUDE/charles-claude-skills/skills/

# Re-snapshot from scratch (if local skills changed substantially)
bash ~/CLAUDE/charles-claude-skills/scripts/snapshot.sh
```
