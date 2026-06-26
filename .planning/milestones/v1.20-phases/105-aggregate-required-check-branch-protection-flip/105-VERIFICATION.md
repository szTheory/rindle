---
phase: 105-aggregate-required-check-branch-protection-flip
verified: 2026-06-21T00:00:00Z
reconciled: 2026-06-22T00:00:00Z
status: passed
score: 6/6 must-haves verified
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "Post-merge live branch-protection flip + read-back (Task 4, D-11/D-13)"
    expected: "After this PR merges AND ci-summary runs on main at least once, a maintainer with an admin gh session runs the 105-FLIP-RUNBOOK.md steps: pre-flip dump, confirm the `CI Summary` check-run name exists on the latest main commit, apply `bash scripts/setup_branch_protection.sh main`, then `bash scripts/ci/check_required_checks.sh main` shows live .contexts[] == [\"CI Summary\"] with an EMPTY diff."
    why_human: "Mutates live external state (branch protection on main) under maintainer admin authority via an admin-PAT gh api PUT. Cannot and must not run in PR CI (D-10/D-11); requires a real ci-summary run on main first (D-12 pending-forever trap). Deliberately deferred by design — NOT a gap."
  - test: "Fork-PR skip-as-pass behavior (optional, D-05)"
    expected: "A PR opened from a fork, where the repo-gated jobs (cohort-demo-smoke, adoption-demo-e2e, brandbook-tokens) skip, reports `CI Summary` as success rather than hanging pending-forever."
    why_human: "Logic-provable from the skip-as-pass case in the result loop, but observable only via a real fork PR raised against the merged workflow."
---

# Phase 105: Aggregate Required Check + Branch-Protection Flip Verification Report

**Phase Goal:** Isolate the single highest-blast-radius migration — making one stable aggregate the sole required check — into one reviewable PR, landed before any matrix/lane rename so subsequent renames never touch branch protection again.
**Verified:** 2026-06-21
**Status:** passed (human-verification items resolved 2026-06-22 — see Reconciliation)
**Re-verification:** No — initial verification

## Goal Achievement

This phase deliberately splits acceptance into automatable-now (PR/static scope) and human/post-merge (live flip) scopes. All six automatable must-haves are VERIFIED against the actual codebase. The single outstanding item — the live branch-protection flip — is correctly deferred to a blocking post-merge human checkpoint (Task 4) and is classified as a human-verification item, NOT a gap.

### Observable Truths

| # | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1 | `ci-summary` job named `CI Summary` runs on every CI run, aggregating the 11 gating jobs | ✓ VERIFIED | `ci.yml:1317-1331` — `ci-summary:` with `name: CI Summary`, `runs-on: ubuntu-22.04`, `needs:` exactly the 11 gating jobs (all 11 confirmed to exist as real jobs in `jobs:`) |
| 2 | `CI Summary` treats success+skipped as pass, failure+cancelled as fail | ✓ VERIFIED | `ci.yml:1352-1361` — jq result loop: `success\|skipped) ;;` pass; `*)` sets `failed=1`; `exit 1` at :1365 on any non-pass (collect-all-then-exit, D-06) |
| 3 | `CI Summary` makes no network/`gh api` call and declares no `permissions:` block | ✓ VERIFIED | `ci.yml:1333-1336` comment + assertion: `'permissions' not in job`, `'gh api' not in json.dumps(job)`. Pure `toJSON(needs)` evaluation via `NEEDS_JSON` env var (:1340) |
| 4 | `setup_branch_protection.sh` expected required-check set collapses to exactly `CI Summary` | ✓ VERIFIED | `setup_branch_protection.sh:17-19` array = `("CI Summary")`; `:24` heredoc single bullet. `--print-expected-json` → `.contexts == ["CI Summary"]`; `--print-expected` required section = exactly 1 bullet. `expected_json()` + PUT body byte-unchanged (read array generically) |
| 5 | `name: CI`, filename, and release coupling unchanged | ✓ VERIFIED | `ci.yml:1` = `name: CI`; filename `ci.yml` unchanged; `release.yml:180` `workflow_id: 'ci.yml'`; `release-please-automerge.yml:5-6` `workflows: [CI]` |
| 6 | Committed runbook documents post-merge flip order (D-10→D-11→D-13) + brandbook-tokens tightening (D-09) | ✓ VERIFIED | `105-FLIP-RUNBOOK.md` — cutover order §1, pending-forever trap §2, D-09 PR callout §3, four labeled commands §4.1-4.4, release-coupling note §5. All required strings present |

**Score:** 6/6 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `.github/workflows/ci.yml` | ci-summary aggregate job (name: CI Summary) | ✓ VERIFIED | Job present :1317-1367, substantive (51-line job with full result loop), wired (job `name:` matches required context string in script) |
| `scripts/setup_branch_protection.sh` | REQUIRED_CHECKS collapsed to single CI Summary | ✓ VERIFIED | Array + heredoc collapsed; `expected_json()` and PUT path untouched; bash syntax valid |
| `105-FLIP-RUNBOOK.md` | Post-merge human flip + verification runbook | ✓ VERIFIED | Exists (139 lines), all required sections + commands present |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `ci.yml` (ci-summary job) | `setup_branch_protection.sh` REQUIRED_CHECKS | job `name: CI Summary` == required-context string | ✓ WIRED | Both encode the exact literal `CI Summary` (the `name:` value, not job id `ci-summary` — Pitfall 2 avoided) |
| `setup_branch_protection.sh` | `check_required_checks.sh` (post-merge verify) | `--print-expected-json` reused as single source of truth | ✓ WIRED | `check_required_checks.sh:51` calls `setup_branch_protection.sh --print-expected-json`; comment at :17 documents the reuse |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Expected JSON contexts collapse | `setup_branch_protection.sh --print-expected-json \| jq` | `.contexts == ["CI Summary"]` true | ✓ PASS |
| Single required-check bullet | `--print-expected` awk-scoped grep count | 1 | ✓ PASS |
| Script syntax | `bash -n setup_branch_protection.sh` | exit 0 | ✓ PASS |
| ci-summary YAML structure | python yaml assert (name/needs/if/no-perms/no-gh-api) | OK | ✓ PASS |
| skip-as-pass present in result loop | `awk` job extract `\| grep skipped` | found | ✓ PASS |
| 11 gating jobs all exist as real jobs | python yaml set-diff | NONE missing | ✓ PASS |
| Excluded soak/live lanes are real jobs (deliberate omission) | python yaml set-intersect | all 3 exist, deliberately excluded | ✓ PASS |
| Release coupling intact | grep ci.yml workflow_id + automerge workflows:[CI] | both found | ✓ PASS |

Note: the live `gh api -X PUT` flip is NOT spot-checked — it mutates external state and is deferred to the human checkpoint by design (D-11). Step 7b constraint: no state mutation, no servers.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| GATE-01 | 105-01 | Single stable `CI Summary` aggregate job (needs all gating jobs, if: always(), skipped→pass) as sole CI-status signal | ✓ SATISFIED | `ci.yml:1317-1367`; truths 1-3. Live flip (live-gate activation) deferred to human checkpoint per design. REQUIREMENTS.md:54 marked [x] |
| GATE-02 | 105-01 | `setup_branch_protection.sh` + nightly re-assert require only `CI Summary`; fork pending-forever trap closed; CI name/filename + release coupling preserved | ✓ SATISFIED | `setup_branch_protection.sh:17-19`; truths 4-5; skip-as-pass (truth 2) closes fork trap logically; runbook enforces flip-second ordering. REQUIREMENTS.md:57 marked [x] |

Both declared requirement IDs accounted for. No orphaned requirements: REQUIREMENTS.md maps Phase 105 to exactly GATE-01..02, both claimed by plan 105-01. Nightly re-assert workflow (`branch-protection-apply.yml`) self-heals by running the same script verbatim — no separate edit needed (documented in plan Task 2).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| — | — | None | — | No TBD/FIXME/XXX debt markers in any modified file; no stubs; no empty implementations |

### Human Verification Required

#### 1. Post-merge live branch-protection flip + read-back (Task 4, D-11/D-13)

**Test:** After this PR merges AND `ci-summary` has run on `main` at least once, follow `105-FLIP-RUNBOOK.md`: (1) `bash scripts/ci/check_required_checks.sh main` (pre-flip dump); (2) confirm `CI Summary` check-run name on latest main via `gh api .../check-runs`; (3) `GH_TOKEN=<admin-PAT> bash scripts/setup_branch_protection.sh main`; (4) `bash scripts/ci/check_required_checks.sh main`.
**Expected:** Live `.contexts[]` == `["CI Summary"]` with an EMPTY diff vs `--print-expected-json`.
**Why human:** Mutates live external state under maintainer admin authority; cannot run in PR CI (D-10/D-11); requires a real ci-summary run on main first (D-12). Deferred by design — NOT a gap.

#### 2. Fork-PR skip-as-pass behavior (optional, D-05)

**Test:** Open a fork PR where repo-gated jobs skip.
**Expected:** `CI Summary` reports success rather than hanging.
**Why human:** Logic-provable but observable only via a real fork PR.

### Gaps Summary

No gaps. All automatable-scope must-haves are VERIFIED against the actual codebase — this is not a SUMMARY.md trust exercise: every claim was re-derived from the live files (`ci.yml`, `setup_branch_protection.sh`, `release.yml`, `release-please-automerge.yml`, `check_required_checks.sh`, `105-FLIP-RUNBOOK.md`) and re-run assertions. The only outstanding item is the live branch-protection flip, which is correctly architected as a deferred, blocking, post-merge human checkpoint (Task 4) and surfaced here as a human-verification item per the phase's two-scope acceptance design. Status is `human_needed` (not `passed`) solely because the human-verification section is non-empty; status is not `gaps_found` because nothing in the automatable scope failed.

### Reconciliation — Human-Verification Items Resolved (2026-06-22)

Both human-verification items are now satisfied; status advanced `human_needed` → `passed`.

**1. Post-merge live branch-protection flip + read-back — DONE (live).**
The accumulated v1.20 work was pushed to `origin/main`; after clearing two pre-existing
CI failures (`json_polyfill`/`--check-locked` lockfile bug `0751fdb`; S3-IMDS test stub
`6d2a385`), `CI Summary` ran green on `main` (HEAD `6d2a385`). The flip was then executed
per `105-FLIP-RUNBOOK.md`: `bash scripts/setup_branch_protection.sh main` (the new
pending-forever-trap guard passed — `CI Summary` check-run present on HEAD), and
`bash scripts/ci/check_required_checks.sh main` showed live `.contexts[] == ["CI Summary"]`
with an **EMPTY diff**. Live branch protection now requires exactly `CI Summary`.

**2. Fork-PR skip-as-pass — RESOLVED via automation (no longer human-only).**
The skip-as-pass gate logic was extracted to `scripts/ci/eval_ci_summary.sh` and pinned by
`scripts/ci/test_ci_summary_gate.sh` (mock `toJSON(needs)`: repo-gated-skipped → exit 0;
failure/cancelled → exit 1), run as the merge-blocking `ci-script-tests` job (commit
`ca70075`). GitHub's own fork `if:` evaluation remains platform behavior, out of unit-test
scope by design — but the regressable gate logic is now covered automatically.

---

_Verified: 2026-06-21 · Reconciled: 2026-06-22_
_Verifier: Claude (gsd-verifier)_
