#!/usr/bin/env bash
# Plan 133-209: re-runnable losslessness proof for the archived inherited working-tree dirt.
# Usage: verify_lossless.sh <repo-root>
# Creates a disposable detached worktree at MANIFEST base_commit, applies inherited.patch,
# and asserts every recorded pre-image sha256, the whole-patch sha256 and the lock-copy sha256.
# Exits 0 only if every assertion holds. Never touches the live working tree or other worktrees.
set -euo pipefail

ROOT="${1:?usage: verify_lossless.sh <repo-root>}"
ROOT="$(cd "$ROOT" && pwd -P)"
ARC_REL=".planning/forensics/133-209-inherited-dirt"
ARC="$ROOT/$ARC_REL"
MANIFEST="$ARC/MANIFEST.json"

sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
fail() { echo "verify_lossless: FAIL: $*" >&2; exit 1; }

[ -f "$MANIFEST" ] || fail "missing $MANIFEST"
field() { node -e 'const m=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const v=process.argv[2].split(".").reduce((o,k)=>o[k],m);process.stdout.write(String(v))' "$MANIFEST" "$1"; }

BASE="$(field base_commit)"
PATCH="$ROOT/$(field patch_path)"
PATCH_SHA="$(field patch_sha256)"
LOCK_COPY="$ROOT/$(field lock.copy_path)"
LOCK_SHA="$(field lock.sha256)"
LOCK_COPY_SHA="$(field lock.copy_sha256)"

[ "$(sha "$PATCH")" = "$PATCH_SHA" ] || fail "inherited.patch sha256 != manifest patch_sha256"
[ "$LOCK_SHA" = "$LOCK_COPY_SHA" ] || fail "manifest lock.sha256 != lock.copy_sha256"
[ "$(sha "$LOCK_COPY")" = "$LOCK_SHA" ] || fail "milestone.lock.copy sha256 != manifest lock.sha256"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/rindle-133-209-lossless.XXXXXX")"
WT="$TMP/wt"
cleanup() {
  git -C "$ROOT" worktree remove --force "$WT" >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

git -C "$ROOT" worktree add --quiet --detach "$WT" "$BASE"
[ "$(git -C "$WT" rev-parse HEAD)" = "$(git -C "$ROOT" rev-parse "$BASE^{commit}")" ] || fail "disposable worktree not at base"

git -C "$WT" apply --check --binary "$PATCH" || fail "git apply --check failed"
git -C "$WT" apply --binary "$PATCH" || fail "git apply failed"

# Per-path assertions: "state<TAB>path<TAB>head_sha256<TAB>worktree_sha256"
node -e '
const m=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
for (const p of m.paths) process.stdout.write([p.state,p.path,p.head_sha256,p.worktree_sha256||""].join("\t")+"\n");
' "$MANIFEST" > "$TMP/paths.tsv"

COUNT=0
while IFS=$'\t' read -r STATE P HEAD_SHA WT_SHA; do
  COUNT=$((COUNT + 1))
  [ -f "$WT/$P" ] || fail "reproduced file missing: $P"
  GOT="$(sha "$WT/$P")"
  case "$STATE" in
    modified) [ "$GOT" = "$WT_SHA" ] || fail "$P reproduced sha256 $GOT != worktree_sha256 $WT_SHA" ;;
    clean)    [ "$GOT" = "$HEAD_SHA" ] || fail "$P sha256 $GOT != head_sha256 $HEAD_SHA" ;;
    *) fail "unknown state $STATE for $P" ;;
  esac
  [ "$(git -C "$WT" show "HEAD:$P" | shasum -a 256 | cut -d' ' -f1)" = "$HEAD_SHA" ] || fail "$P HEAD blob sha256 != head_sha256"
done < "$TMP/paths.tsv"
[ "$COUNT" -eq 10 ] || fail "expected 10 manifest paths, got $COUNT"

REDIFF="$(git -C "$WT" diff --binary --full-index --no-color --no-ext-diff --no-textconv HEAD | shasum -a 256 | cut -d' ' -f1)"
[ "$REDIFF" = "$PATCH_SHA" ] || fail "re-derived diff sha256 $REDIFF != patch_sha256 $PATCH_SHA"

echo "verify_lossless: OK base=$BASE paths=$COUNT patch_sha256=$PATCH_SHA lock_sha256=$LOCK_SHA"
