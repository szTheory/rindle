#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

TRANSIENT_FILES=(
  "init.json"
  "progress.txt"
  "recent.txt"
  "roadmap.json"
  "state.json"
)

TRANSIENT_GLOBS=(
  "rindle-*"
)

removed_paths=()
skipped_tracked=()

is_tracked() {
  git ls-files --error-unmatch -- "$1" >/dev/null 2>&1
}

remove_path() {
  local path="$1"

  if [ ! -e "$path" ]; then
    return 0
  fi

  if is_tracked "$path"; then
    skipped_tracked+=("$path")
    return 0
  fi

  rm -rf -- "$path"
  removed_paths+=("$path")
}

for path in "${TRANSIENT_FILES[@]}"; do
  remove_path "$path"
done

shopt -s nullglob
for pattern in "${TRANSIENT_GLOBS[@]}"; do
  for path in $pattern; do
    remove_path "$path"
  done
done
shopt -u nullglob

git worktree prune >/dev/null 2>&1 || true

active_worktrees=()
while IFS= read -r line; do
  case "$line" in
    worktree\ *)
      path=${line#worktree }
      if [ "$path" != "$ROOT_DIR" ]; then
        active_worktrees+=("$path")
      fi
      ;;
  esac
done < <(git worktree list --porcelain)

tracked_planning=()
untracked_planning=()
other_dirt=()

while IFS= read -r line; do
  [ -z "$line" ] && continue

  status=${line:0:2}
  path=${line:3}

  if [[ "$path" == .planning/* ]]; then
    if [[ "$status" == "??" ]]; then
      untracked_planning+=("$line")
    else
      tracked_planning+=("$line")
    fi
  else
    other_dirt+=("$line")
  fi
done < <(git status --short)

state_status=""
if [ -f .planning/STATE.md ]; then
  state_status=$(sed -n 's/^status: //p' .planning/STATE.md | head -1 | tr -d '"')
fi

echo "GSD cleanup complete."
echo

if [ ${#removed_paths[@]} -gt 0 ]; then
  echo "Removed transient local outputs:"
  for path in "${removed_paths[@]}"; do
    echo "  - $path"
  done
else
  echo "No transient local outputs found."
fi

if [ ${#skipped_tracked[@]} -gt 0 ]; then
  echo
  echo "Skipped tracked paths that matched cleanup rules:"
  for path in "${skipped_tracked[@]}"; do
    echo "  - $path"
  done
fi

echo
if [ ${#active_worktrees[@]} -gt 0 ]; then
  echo "Active non-primary worktrees:"
  for path in "${active_worktrees[@]}"; do
    echo "  - $path"
  done
  echo "Review and remove them intentionally with \`git worktree remove <path>\` when done."
else
  echo "No active non-primary worktrees."
fi

echo
echo "Remaining dirty state:"

if [ ${#tracked_planning[@]} -gt 0 ]; then
  echo "  Tracked planning changes:"
  for line in "${tracked_planning[@]}"; do
    echo "    $line"
  done
else
  echo "  Tracked planning changes: none"
fi

if [ ${#untracked_planning[@]} -gt 0 ]; then
  echo "  Untracked planning artifacts:"
  for line in "${untracked_planning[@]}"; do
    echo "    $line"
  done
else
  echo "  Untracked planning artifacts: none"
fi

if [ ${#other_dirt[@]} -gt 0 ]; then
  echo "  Other repo dirt:"
  for line in "${other_dirt[@]}"; do
    echo "    $line"
  done
else
  echo "  Other repo dirt: none"
fi

echo
echo "Recommended next steps:"

if [ ${#tracked_planning[@]} -gt 0 ]; then
  echo "  - Tracked planning files are intentional GSD state. Commit them, or finish the owning workflow before cleaning further."
fi

if [ ${#untracked_planning[@]} -gt 0 ]; then
  if [ "$state_status" = "milestone_complete" ]; then
    echo '  - Milestone is complete. Run `$gsd-cleanup` to archive completed milestone phase directories out of .planning/phases/.'
  else
    echo "  - Review untracked planning artifacts before deleting them. If they belong to completed work, archive them with the relevant GSD workflow instead of ignoring them."
  fi
fi

if [ "$state_status" = "milestone_complete" ]; then
  echo '  - If milestone archival is not done yet, run `$gsd-complete-milestone <version>`.'
fi

echo '  - When code is ready for review but .planning commits should stay out of the PR, run `$gsd-pr-branch`.'
