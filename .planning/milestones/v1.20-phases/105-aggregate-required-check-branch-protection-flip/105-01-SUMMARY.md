---
phase: 105-aggregate-required-check-branch-protection-flip
plan: 01
subsystem: ci-cd
tags: [ci, branch-protection, github-actions, gating, aggregate-check]
status: complete
requires:
  - "ci.yml ci-observability job skeleton (Phase 103) as the copy analog"
  - "scripts/setup_branch_protection.sh single-source-of-truth array (pre-existing)"
  - "scripts/ci/check_required_checks.sh read-only verifier (Phase 103, reused as-is)"
provides:
  - "ci-summary aggregate job (name: CI Summary) — the canonical CI-health signal"
  - "setup_branch_protection.sh REQUIRED_CHECKS collapsed to single CI Summary context"
  - "105-FLIP-RUNBOOK.md post-merge human flip + verification procedure"
affects:
  - ".github/workflows/ci.yml"
  - "scripts/setup_branch_protection.sh"
  - "live branch protection on main (DEFERRED to post-merge human flip — Task 4)"
tech-stack:
  added: []
  patterns:
    - "Pure aggregate gate over toJSON(needs) + jq (drift-proof, network-free, zero-permission)"
    - "Skip-as-pass result evaluation (success+skipped pass; failure+cancelled fail)"
    - "Two-step cutover: additive PR, then post-merge human branch-protection flip"
key-files:
  created:
    - ".planning/phases/105-aggregate-required-check-branch-protection-flip/105-FLIP-RUNBOOK.md"
  modified:
    - ".github/workflows/ci.yml"
    - "scripts/setup_branch_protection.sh"
decisions:
  - "ci-summary declares NO permissions: and makes NO gh api call (D-02) — pure needs.*.result evaluation, immune to the 401-class API flake that ci-observability is exposed to."
  - "needs: is exactly the 11 gating jobs; mux-soak/gcs-soak/package-consumer-gcs-live excluded (D-04 — continue-on-error/live-third-party lanes that would mask or false-red the gate)."
  - "Required context string is the job name: value 'CI Summary', NOT the job id 'ci-summary' (Pitfall 2)."
  - "Live branch-protection flip is a deliberate post-merge human go/no-go step (D-11), deferred as a blocking checkpoint — it cannot and must not run in PR CI."
metrics:
  duration: "8 min"
  completed: 2026-06-21
  tasks_completed: 3
  tasks_total: 4
  files_touched: 3
---

# Phase 105 Plan 01: Aggregate Required Check + Branch-Protection Flip Summary

A single stable `CI Summary` aggregate job — pure, network-free, zero-permission, evaluating
`toJSON(needs)` with skip-as-pass — is now the canonical CI-health signal, and
`setup_branch_protection.sh` declares exactly that one required context; the high-blast-radius
live flip is documented in a committed runbook and deferred to a post-merge human checkpoint.

## What Was Built (Tasks 1–3)

### Task 1 — `ci-summary` aggregate job (GATE-01) — commit `5290ea4`

Appended a new top-level `ci-summary` job (`name: CI Summary`, `runs-on: ubuntu-22.04`) to the
end of `.github/workflows/ci.yml`, modeled on `ci-observability` but stripped to a pure gate:

- `needs:` exactly the 11 gating jobs (quality, optional-dependencies, integration, contract,
  proof, package-consumer, adoption-demo-unit, cohort-demo-smoke, adoption-demo-e2e, adopter,
  brandbook-tokens). `mux-soak`, `gcs-soak`, `package-consumer-gcs-live` deliberately absent (D-04).
- `if: always()` so it runs even when a dependency fails/skips.
- **No `permissions:` block and no `gh api` call** (D-02) — inherits the workflow default
  `contents: read`; cannot false-red on a GitHub API hiccup.
- Result step reads `${{ toJSON(needs) }}` via a `NEEDS_JSON` env var and iterates with `jq`:
  `success`/`skipped` pass, `failure`/`cancelled` fail (D-05). Collect-all-then-`exit 1` (D-06),
  with a `| Job | Result |` table appended to `$GITHUB_STEP_SUMMARY`.
- `name: CI` (`ci.yml:1`) and the filename are untouched (release coupling preserved).

### Task 2 — collapse `setup_branch_protection.sh` (GATE-02) — commit `114a2b7`

Collapsed the required-check declaration from 13 matrix-suffixed contexts to the single
context `CI Summary`, edited in the two in-lockstep spots only:

- `REQUIRED_CHECKS=(...)` array → single element `"CI Summary"`.
- `print_expected_text()` heredoc → single bullet `  - CI Summary`.
- `expected_json()`, the `--print-expected*` cases, and the `gh api -X PUT` body are
  byte-unchanged (they read `${REQUIRED_CHECKS[@]}` generically). No third encoding added (D-08).
- String is exactly `CI Summary` (matches the job `name:`, not the job id).

### Task 3 — `105-FLIP-RUNBOOK.md` (D-09/D-11/D-13) — commit `ec7e0f1`

Committed a maintainer runbook documenting the post-merge cutover:

- Do-not-reorder cutover (D-10→D-11→D-13) — the PR is additive/reversible; the flip happens
  only after `ci-summary` has run on `main` once.
- Pending-forever-trap warning (D-12) — merge-job-first, flip-protection-second; required
  string is the `name:` value `CI Summary`, not the job id.
- Copy-into-PR callout (D-09) — `brandbook-tokens` goes non-gating → transitively gating.
- Four labeled human/post-merge commands: pre-flip dump, `check-runs` name confirm, flip,
  post-flip verify (verbatim from RESEARCH).
- Note that the release coupling is workflow-level (`name: CI`) and invisible to the flip.

## Verification Performed

All Task 1–3 `<verify>` automated checks passed:

- **Task 1:** YAML structure (name=`CI`, `jobs.ci-summary.name`=`CI Summary`, exact 11-job
  `needs:`, soak/live exclusion, `if: always()`, no `permissions:`); no `gh api` in the job
  mapping; result loop references `skipped` (skip-as-pass). — 3/3 OK.
- **Task 2:** `bash -n` syntax OK; `--print-expected-json` `.contexts == ["CI Summary"]`;
  exactly one bullet under the `Expected required status checks:` section. — 3/3 OK.
- **Task 3:** runbook exists; covers `check_required_checks.sh main`, `setup_branch_protection.sh main`,
  `check-runs`, and `brandbook-tokens`. — 2/2 OK.
- **Release coupling invariant:** `grep -q "workflow_id: 'ci.yml'" .github/workflows/release.yml` — OK.

## Deviations from Plan

None — Tasks 1–3 executed exactly as written. No Rule 1–4 deviations were required.

## Deferred / Outstanding: Task 4 (blocking human, post-merge)

**Task 4 — Post-merge live branch-protection flip + verification (D-11/D-13)** is a
`checkpoint:human-verify` with `gate="blocking-human"` and was **NOT executed** — by design.
It mutates live external state (branch protection on `main`) under maintainer admin authority
and **cannot run in CI or now**. It requires, in order:

1. This PR merged.
2. The `ci-summary` job to have run on `main` at least once (else the pending-forever trap, D-12).
3. A maintainer admin `gh` session / admin PAT.

The maintainer must then follow `105-FLIP-RUNBOOK.md` step by step: pre-flip dump → confirm the
`CI Summary` check-run name on the latest `main` commit → `GH_TOKEN=<admin-PAT> bash
scripts/setup_branch_protection.sh main` → verify live `.contexts[]` == `["CI Summary"]` with an
empty diff via `bash scripts/ci/check_required_checks.sh main`.

**This is the single outstanding post-merge action for the orchestrator to surface.**

## Known Stubs

None.

## Self-Check: PASSED

- `.github/workflows/ci.yml` — FOUND (modified, `jobs.ci-summary` present)
- `scripts/setup_branch_protection.sh` — FOUND (modified, collapsed to `CI Summary`)
- `.planning/phases/105-aggregate-required-check-branch-protection-flip/105-FLIP-RUNBOOK.md` — FOUND
- Commit `5290ea4` (Task 1) — FOUND
- Commit `114a2b7` (Task 2) — FOUND
- Commit `ec7e0f1` (Task 3) — FOUND
