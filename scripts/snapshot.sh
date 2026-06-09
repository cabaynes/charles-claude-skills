#!/usr/bin/env bash
#
# snapshot.sh — refresh the public repo from local skills with sanitization.
#
# Source of truth: ~/.claude/skills/<name>/  (Charles's local, daily-use copies)
# Target:          this repo's skills/<name>/  (sanitized public snapshot)
#
# This script does NOT touch /newproject — that skill has a separate parameterized
# fork (skills/newproject/SKILL.md) maintained by hand.
#
# Run from anywhere; resolves its own location.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_SKILLS="${HOME}/.claude/skills"
PUBLIC_SKILLS="${REPO_DIR}/skills"

echo "Refreshing public snapshot in ${PUBLIC_SKILLS}/ from ${LOCAL_SKILLS}/"

# --- 1. Copy the session-continuity pair (atomic — both or neither) ---
echo "  • copying checkpoint + resume into session-continuity/"
mkdir -p "${PUBLIC_SKILLS}/session-continuity/checkpoint"
mkdir -p "${PUBLIC_SKILLS}/session-continuity/resume"
cp "${LOCAL_SKILLS}/checkpoint/SKILL.md" "${PUBLIC_SKILLS}/session-continuity/checkpoint/SKILL.md"
cp "${LOCAL_SKILLS}/resume/SKILL.md" "${PUBLIC_SKILLS}/session-continuity/resume/SKILL.md"

# --- 2. Copy skill-dict (including references/) ---
echo "  • copying skill-dict + references/"
mkdir -p "${PUBLIC_SKILLS}/skill-dict/references"
cp "${LOCAL_SKILLS}/skill-dict/SKILL.md" "${PUBLIC_SKILLS}/skill-dict/SKILL.md"
cp "${LOCAL_SKILLS}/skill-dict/references/"*.md "${PUBLIC_SKILLS}/skill-dict/references/"

# --- 3. Apply sanitization to every copied *.md file ---
# Order matters: do longer/more-specific patterns BEFORE shorter ones.
echo "  • sanitizing personal paths and names"

SANITIZE_TARGETS=(
  "${PUBLIC_SKILLS}/session-continuity/checkpoint/SKILL.md"
  "${PUBLIC_SKILLS}/session-continuity/resume/SKILL.md"
  "${PUBLIC_SKILLS}/skill-dict/SKILL.md"
  "${PUBLIC_SKILLS}/skill-dict/references/sync.md"
  "${PUBLIC_SKILLS}/skill-dict/references/check-updates.md"
  "${PUBLIC_SKILLS}/skill-dict/references/add.md"
)

for f in "${SANITIZE_TARGETS[@]}"; do
  # Memory-dir slug specifics first (longer pattern)
  sed -i '' 's|-Users-charles-CLAUDE|<project-slug>|g' "$f"
  # Library root (specific path) before generic CLAUDE root
  sed -i '' 's|/Users/charles/CLAUDE/skills-library/|~/skills-library/|g' "$f"
  sed -i '' 's|/Users/charles/CLAUDE/skills-library|~/skills-library|g' "$f"
  # Charles's workspace root
  sed -i '' 's|/Users/charles/CLAUDE/|<workspace-root>/|g' "$f"
  sed -i '' 's|/Users/charles/CLAUDE|<workspace-root>|g' "$f"
  # .claude home dir
  sed -i '' 's|/Users/charles/.claude/|~/.claude/|g' "$f"
  sed -i '' 's|/Users/charles/.claude|~/.claude|g' "$f"
  # Catch-all home dir
  sed -i '' 's|/Users/charles/|~/|g' "$f"
  sed -i '' 's|/Users/charles|~|g' "$f"
  # Personal name (possessive first, then bare)
  sed -i '' "s|Charles's|your|g" "$f"
  sed -i '' 's|Charles |you |g' "$f"
  sed -i '' 's|Charles$|you|g' "$f"
  sed -i '' 's|Charles\.|you.|g' "$f"
  sed -i '' 's|Charles,|you,|g' "$f"
done

# --- 4. Guard against sanitization residue ---
# The sed rules above convert "Charles" / "Charles's" → "you" / "your", which only
# reads correctly when the source uses possessives or second person. A source line
# written in third-person subject form (e.g. "Charles maintains ... he's installed")
# sanitizes to broken text ("you maintains ... he's installed"): sed can't fix verb
# agreement, and bare pronouns (he/his/him/he's) referring to the maintainer aren't
# caught by the name rules. Those pronouns almost always travel with such drift, so
# fail loudly on a leaked name or pronoun — drift gets fixed at the source, never
# shipped silently. (The content has no legitimate third-person pronouns; if a future
# skill needs one referring to someone else, narrow this check then.)
echo "  • checking for sanitization residue"
RESIDUE=0
for f in "${SANITIZE_TARGETS[@]}"; do
  if grep -nEi "\bCharles\b|\bhe's\b|\bhis\b|\bhim\b|\bhe\b" "$f"; then
    echo "    ↑ residue in ${f#${REPO_DIR}/}" >&2
    RESIDUE=1
  fi
done
if [ "$RESIDUE" -ne 0 ]; then
  echo "" >&2
  echo "ERROR: sanitization residue detected (see matches above)." >&2
  echo "Fix the LOCAL source in ${LOCAL_SKILLS}/ — rewrite third-person subject" >&2
  echo "references (\"Charles maintains\", \"he's installed\") as possessives" >&2
  echo "(\"Charles's\") or second person (\"You maintain\"), then re-run." >&2
  exit 1
fi

echo ""
echo "Done. Verify with:"
echo "  grep -rE '/Users/charles|Charles' ${PUBLIC_SKILLS}/  || echo OK"
