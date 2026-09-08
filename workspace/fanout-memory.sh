#!/bin/bash
#
# fanout-memory.sh — fan out universal memories from the workspace hub to each subproject
#
# Claude Code keeps per-folder memory at ~/.claude/projects/<slug>/memory/, where <slug> is
# the folder's absolute path with every "/" replaced by "-". The workspace root's memory dir
# is the HUB. Universal memory files (feedback_*.md and user_*.md) live ONLY in the hub; every
# subproject's memory dir gets a symlink back to each one, plus a MEMORY.md index line.
# Edit a universal file once and every project sees the change.
#
# project_*.md and reference_*.md files are NOT fanned out — they stay where they are.
#
# Usage:
#   fanout-memory.sh                  Status: which subprojects are missing which universals
#   fanout-memory.sh <project-name>   Seed/sync one subproject (creates its memory dir if needed)
#   fanout-memory.sh --all            Sync every existing subproject
#
# Configuration: honours $WORKSPACE_DIR (default ~/CLAUDE).

set -euo pipefail

WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/CLAUDE}"
WORKSPACE_DIR="${WORKSPACE_DIR/#\~/$HOME}"
WORKSPACE_DIR="${WORKSPACE_DIR%/}"
HUB_SLUG="$(printf '%s' "$WORKSPACE_DIR" | tr '/' '-')"
PROJECTS_BASE="$HOME/.claude/projects"
HUB_MEMORY="$PROJECTS_BASE/$HUB_SLUG/memory"
SUBPROJECT_PREFIX="${HUB_SLUG}-"

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  sed -n '/^# fanout-memory.sh/,/^$/p' "$0" | sed -E 's/^# ?//'
  exit 0
fi

mkdir -p "$HUB_MEMORY"

# Build the list of universal memory filenames from the hub
universal_files=()
for f in "$HUB_MEMORY"/feedback_*.md "$HUB_MEMORY"/user_*.md; do
  [ -e "$f" ] || continue
  universal_files+=("$(basename "$f")")
done

if [ "${#universal_files[@]}" -eq 0 ]; then
  echo "No universal memory files (feedback_*.md / user_*.md) in $HUB_MEMORY yet." >&2
  echo "Write one there first (user_profile.md is the usual starting point), then re-run." >&2
  echo "If that path is not what you expected, check \$WORKSPACE_DIR (currently: $WORKSPACE_DIR)." >&2
  exit 1
fi

# Turn a memory file's frontmatter into a one-line MEMORY.md index entry
make_index_entry() {
  local filepath="$1"
  local filename
  filename="$(basename "$filepath")"
  local name desc
  name="$(awk -F': ' '/^name:/ {sub(/^name: /, ""); print; exit}' "$filepath")"
  desc="$(awk -F': ' '/^description:/ {sub(/^description: /, ""); print; exit}' "$filepath")"
  name="${name%\"}"; name="${name#\"}"
  desc="${desc%\"}"; desc="${desc#\"}"
  desc="${desc//\\\"/\"}"
  if [ "${#desc}" -gt 140 ]; then
    desc="${desc:0:137}..."
  fi
  echo "- [$name]($filename) — $desc"
}

# Sync universal memories into one subproject's memory dir
fanout_one() {
  local project_name="$1"
  local project_memory="$PROJECTS_BASE/${SUBPROJECT_PREFIX}${project_name}/memory"

  echo "▸ $project_name"
  mkdir -p "$project_memory"

  local linked_count=0
  for filename in "${universal_files[@]}"; do
    local target="$project_memory/$filename"
    local src="$HUB_MEMORY/$filename"
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ]; then
      continue
    fi
    if [ -e "$target" ] && [ ! -L "$target" ]; then
      echo "    ! $filename exists here as a real file — skipping (move or rename it to fan out)"
      continue
    fi
    ln -sf "$src" "$target"
    linked_count=$((linked_count + 1))
    echo "    + $filename"
  done

  if [ "$linked_count" -eq 0 ]; then
    echo "    (symlinks already current)"
  fi

  # Seed MEMORY.md if missing; otherwise append any index lines that are missing
  local index="$project_memory/MEMORY.md"
  if [ ! -f "$index" ]; then
    echo "    + MEMORY.md (seeded with universals)"
    : > "$index"
    for filename in "${universal_files[@]}"; do
      make_index_entry "$HUB_MEMORY/$filename" >> "$index"
    done
  else
    local missing=()
    for filename in "${universal_files[@]}"; do
      if ! grep -qF -- "($filename)" "$index"; then
        missing+=("$filename")
      fi
    done
    if [ "${#missing[@]}" -gt 0 ]; then
      if [ -s "$index" ] && [ -n "$(tail -c1 "$index")" ]; then
        printf '\n' >> "$index"
      fi
      for filename in "${missing[@]}"; do
        make_index_entry "$HUB_MEMORY/$filename" >> "$index"
        echo "    + MEMORY.md entry: $filename"
      done
    fi
  fi
}

# Status report: which subprojects are missing which universals
show_status() {
  echo "Workspace: $WORKSPACE_DIR"
  echo "Hub:       $HUB_MEMORY"
  echo "Universal memories (${#universal_files[@]}):"
  for filename in "${universal_files[@]}"; do
    echo "  • $filename"
  done
  echo ""
  echo "Subproject status:"
  local found_any=0
  for d in "$PROJECTS_BASE/${SUBPROJECT_PREFIX}"*; do
    [ -d "$d" ] || continue
    found_any=1
    local project
    project="$(basename -- "$d" | sed "s|^${SUBPROJECT_PREFIX}||")"
    local project_memory="$d/memory"
    local missing=0
    for filename in "${universal_files[@]}"; do
      if [ ! -L "$project_memory/$filename" ]; then
        missing=$((missing + 1))
      fi
    done
    if [ "$missing" -eq 0 ]; then
      echo "  ✓ $project"
    else
      echo "  ⚠ $project — missing $missing universal symlink(s)"
    fi
  done
  if [ "$found_any" -eq 0 ]; then
    echo "  (no subprojects yet — /newproject <name> creates the first one)"
  fi
  echo ""
  echo "Run:"
  echo "  $0 <project-name>    Seed/sync one project"
  echo "  $0 --all             Sync every subproject"
}

case "${1:-}" in
  "")
    show_status
    ;;
  --all)
    for d in "$PROJECTS_BASE/${SUBPROJECT_PREFIX}"*; do
      [ -d "$d" ] || continue
      project="$(basename -- "$d" | sed "s|^${SUBPROJECT_PREFIX}||")"
      fanout_one "$project"
    done
    echo ""
    echo "Done."
    ;;
  *)
    fanout_one "$1"
    echo ""
    echo "Done."
    ;;
esac
