#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
RELEASE_WORKFLOW_URL="${RELEASE_WORKFLOW_URL:-}"
CI_GATE_URL="${CI_GATE_URL:-}"
PUBLIC_VERIFY_URL="${PUBLIC_VERIFY_URL:-}"

if [[ -z "$VERSION" ]]; then
  echo "Usage: update_release_train_baseline.sh VERSION" >&2
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LEDGER="${REPO_ROOT}/.planning/RELEASE-TRAIN.md"

if [[ ! -f "$LEDGER" ]]; then
  echo "Missing $LEDGER" >&2
  exit 1
fi

hex_date="$(date -u +%Y-%m-%d)"
if command -v mix >/dev/null 2>&1 && mix hex.info rindle "$VERSION" >/dev/null 2>&1; then
  parsed="$(mix hex.info rindle "$VERSION" 2>/dev/null | sed -nE 's/^.*Published at: ([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/p' | head -n 1)"
  hex_date="${parsed:-$hex_date}"
fi

export VERSION LEDGER hex_date RELEASE_WORKFLOW_URL CI_GATE_URL PUBLIC_VERIFY_URL

python3 <<'PY'
import os
import re

ledger = os.environ["LEDGER"]
version = os.environ["VERSION"]
hex_date = os.environ["hex_date"]
release_url = os.environ.get("RELEASE_WORKFLOW_URL", "")
ci_url = os.environ.get("CI_GATE_URL", "")
public_url = os.environ.get("PUBLIC_VERIFY_URL", "")

lines = [
    f"- Latest released version: `{version}` (Hex.pm, {hex_date})",
    "- Catch-up release: none (published)",
    "- GSD posture: `demand-gated-pause` (formalized 2026-05-27)",
    "- Release automation: Release Please + exact-ref dispatch publish (see `.github/workflows/release.yml`)",
]

if release_url:
    lines.append(f"- Last publish workflow: {release_url}")
if ci_url:
    lines.append(f"- Last publish CI gate: {ci_url}")
if public_url:
    lines.append(
        f"- Last public verify: {public_url} (Hex index + `scripts/public_smoke.sh` passed)"
    )
elif release_url:
    lines.append("- Last public verify: public smoke passed in publish workflow")

lines.append("")
lines.append(
    "Update this section after each successful Hex publish with run ID, version, and public-smoke proof."
)

block = "\n".join(lines)
text = open(ledger, encoding="utf-8").read()
pattern = r"(?ms)^## Current Baseline\n.*?(?=^## )"
replacement = f"## Current Baseline\n\n{block}\n\n"
new_text, count = re.subn(pattern, replacement, text, count=1)

if count != 1:
    raise SystemExit(f"Failed to rewrite Current Baseline in {ledger}")

open(ledger, "w", encoding="utf-8").write(new_text)
print(f"Updated Current Baseline in {ledger} for version {version}")
PY
