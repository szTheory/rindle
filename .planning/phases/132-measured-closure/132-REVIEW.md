---
phase: 132-measured-closure
reviewed: 2026-08-27T20:53:46Z
depth: standard
files_reviewed: 13
files_reviewed_list:
  - .github/workflows/ci.yml
  - scripts/ci/collect_pr_timing_receipt.sh
  - scripts/ci/install_apt_packages.sh
  - scripts/maintainer/automation_first_contract.sh
  - scripts/maintainer/repo_hygiene_check.sh
  - test/fixtures/ci_timing/phase_132_topology_projection.json
  - test/install_smoke/automation_first_contract_test.exs
  - test/install_smoke/ci_cache_hygiene_test.exs
  - test/install_smoke/ci_lane_split_test.exs
  - test/install_smoke/ci_timing_automation_test.exs
  - test/install_smoke/generated_app_smoke_test.exs
  - test/install_smoke/support/generated_app/workspace.ex
  - test/install_smoke/support/generated_app_helper.ex
findings:
  critical: 2
  warning: 0
  info: 0
  total: 2
status: issues_found
---

# Phase 132: Code Review Report

**Reviewed:** 2026-08-27T20:53:46Z
**Depth:** standard
**Files Reviewed:** 13
**Status:** issues_found

## Summary

The controller now has the repaired terminal-state, two-sequence, persisted-trigger, and paginated-population paths. The current receipt also passed a fresh live `verify` invocation against GitHub Actions; the sampled run and its `CI Summary` completion agree with the receipt. Two fail-closed gates remain bypassable, however, so the phase cannot safely claim its bounded-controller or automation-first guarantees.

## Critical Issues

### CR-01: Rate-limit retries can outlive every persisted controller deadline

**File:** `scripts/ci/collect_pr_timing_receipt.sh:255-291`
**Issue:** `gh_api_json` retries a rate-limited request forever. It is called synchronously by `same_sha_runs` before `wait_for_new_run` reaches its persisted absolute creation-deadline check (lines 577-590), and also inside run/quiescence deadline loops. A continuing primary or secondary API-rate-limit response therefore prevents those loops from evaluating their deadline at all. The controller can remain live indefinitely with an owned label/lock rather than terminalizing the durable state, violating the explicitly fail-closed bounded-sampling contract.
**Fix:** Pass an absolute deadline (or a bounded retry budget) into `gh_api_json`, check it before each attempt and before sleeping, and return a distinct timeout error when it expires. Have each caller terminalize/clean up as it already does for a missing trigger or exhausted run timeout. For example:

```bash
gh_api_json() {
  local endpoint="$1" pagination="$2" deadline="$3"
  # ... request ...
  if grep -qi 'rate limit exceeded' <<<"$output"; then
    [ "$(date +%s)" -lt "$deadline" ] || return 124
    sleep "$delay"
    continue
  fi
}
```

### CR-02: Valid human-action task markup can evade the automation-first gate

**File:** `scripts/maintainer/automation_first_contract.sh:57-69`
**Issue:** The AWK parser only starts a block when the opening tag begins with the exact substring `<task type="checkpoint:human-action"`. XML-like task markup with another valid attribute first (for example, `<task gate="blocking" type="checkpoint:human-action">`) is ignored entirely. Its purpose and any `<acceptance_criteria>`, `<verify>`, or `<verification>` fields are consequently never checked, allowing a plan to make human approval satisfy an active requirement while this merge-blocking script reports success.
**Fix:** Detect the `type` attribute independent of attribute order and quote style, then parse the complete task block before applying the existing checks. Add regression cases with `gate` before `type` and single-quoted attributes.

```bash
awk '
  /<task[[:space:]][^>]*type=["'\'' ]checkpoint:human-action["'\'' ][^>]*>/ { inside=1; block=$0 ORS; next }
  inside { block=block $0 ORS }
  inside && /<\/task>/ { printf "%s%c", block, 0; inside=0; block="" }
' "$plan" > "$blocks"
```

---

_Reviewed: 2026-08-27T20:53:46Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
