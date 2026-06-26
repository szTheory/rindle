# Phase 105: Aggregate Required Check + Branch-Protection Flip - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-21
**Phase:** 105-aggregate-required-check-branch-protection-flip
**Areas discussed:** Gate job placement (A), needs/skip semantics (B), branch-protection collapse (C), rollout safety (D)

User requested deep subagent research on all four areas and a one-shot locked set of
coherent recommendations (no interview). Three parallel research passes ran: (1) GitHub
Actions ecosystem best-practice; (2) szTheory sibling-repo prior art; (3) Rindle-internal
code grounding. Recommendations were locked from their convergence; the one divergence
(area B, soak-lane inclusion) was resolved by the orchestrator.

---

## A. `CI Summary` job: new dedicated vs extend `ci-observability`

| Option | Description | Selected |
|--------|-------------|----------|
| New dedicated job | Pure, network-free, zero-permission gate evaluating only `needs.*.result` | ✓ |
| Extend `ci-observability` | Reuse existing aggregator that already `needs:` most jobs | |

**User's choice:** New dedicated job (locked recommendation accepted).
**Notes:** `ci-observability` runs a `set -euo pipefail` paginated `gh api` read and can exit
non-zero on a transient GitHub API 401/5xx (the 401-class flake recorded in 103-BASELINE).
A required check must not be able to false-red on infra. All three research passes agreed.

---

## B. `needs:` set + skipped/cancelled semantics

| Option | Description | Selected |
|--------|-------------|----------|
| `needs:` all 14 jobs (incl. soak/live trio) | "Cover everything so no failure sneaks through" (ecosystem-generic instinct) | |
| `needs:` the 11 deterministic gating jobs; exclude soak/live trio | Matches `ci-observability`; soak/live are real-API + nightly-bound | ✓ |
| `re-actors/alls-green` action | Maintained third-party gate action with `allowed-skips` | |
| Inline bash loop over `needs.*.result`, skipped→pass / failure+cancelled→fail | House idiom (lattice_stripe/rulestead/sigra), explicit result check | ✓ |

**User's choice:** 11-job needs set + inline bash loop, skipped+success=pass,
failure+cancelled=fail (locked).
**Notes:** Divergence resolved AGAINST including the soak/live trio: `package-consumer-gcs-live`
is `continue-on-error: true` (result masked → gating meaningless); `mux-soak`/`gcs-soak` hit
live third-party APIs (gating every merge on them = false-red on provider outages); Phase 106
moves them to nightly anyway. Skipped-as-pass is mandatory to close the fork trap
(`cohort-demo-smoke`/`adoption-demo-e2e`/`brandbook-tokens` are fork-gated). Explicit result
evaluation avoids the "green checkmark lie" (an `if: always()` job that doesn't check results
reports green on failure). No szTheory repo adopted alls-green → bash loop for coherence.

---

## C. Branch-protection list reconciliation

| Option | Description | Selected |
|--------|-------------|----------|
| Collapse `REQUIRED_CHECKS` to single `CI Summary` | One context; immune to matrix-name churn | ✓ |
| Keep 13-entry list | Fine-grained but fragile (drifts on every matrix bump) | |

**User's choice:** Collapse to single `CI Summary` context (locked).
**Notes:** Edit the two in-lockstep spots in `setup_branch_protection.sh` (array + heredoc).
`brandbook-tokens` leaves the required list (already drifted off live) but keeps running and
becomes transitively gated via `CI Summary`'s `needs:` — a deliberate tightening to flag in
the PR. The current 13-entry list hardcodes matrix strings like `Quality (1.15, 26)` and
would orphan on any OTP/Elixir bump — the strongest argument for the collapse.

---

## D. Rollout safety

| Option | Description | Selected |
|--------|-------------|----------|
| Flip protection in/with the PR | Single atomic change | |
| Two-step: merge job (non-required) first, flip protection after ≥1 green run on main | Avoids never-seen-context pending-forever trap | ✓ |

**User's choice:** Two-step maintainer-gated cutover (locked).
**Notes:** GitHub does not verify a required context name was ever produced — requiring
`CI Summary` before any run posts it hangs every PR forever. PR makes no live mutation; the
maintainer applies the flip (admin-PAT script / nightly) after `CI Summary` is green once.
Verify via `check_required_checks.sh` + `gh api .../check-runs`. The same `if: always()`
gate also fixes the existing latent fork trap (`Cohort Demo Smoke` is both required and
fork-gated today). Release coupling is workflow-level and untouched.

## Claude's Discretion

- Exact bash/jq phrasing of the result loop, the `$GITHUB_STEP_SUMMARY` table wording, and
  `runs-on` pin — planner/executor, as long as the locked semantics hold.
- Optional adoption of mailglass's `verify-branch-protection.sh` (not required;
  `check_required_checks.sh` covers it).

## Deferred Ideas

- Soak/live lanes → nightly / off PR critical path (Phase 106, LANE-03).
- Conditional skip-normalization (rulestead `release_gate.sh` pattern) — revisit in Phase 106
  only if the lane split introduces `paths:`-filtered jobs.
- mailglass `verify-branch-protection.sh` read-only drift detection (optional polish).
- Reviewed-not-folded todo: `2026-06-19-fix-docker-demo-startup-warnings.md` (weak keyword
  match; unrelated to CI gating).
