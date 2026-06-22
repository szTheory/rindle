---
phase: 106
slug: trigger-split-matrix-lane-refinement
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-22
reconstructed: 2026-06-22
---

# Phase 106 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> **Reconstructed retroactively** (State B) during the v1.20 milestone audit — the phase
> shipped & verified (`106-VERIFICATION.md`, 5/5) without a VALIDATION.md. This document
> records the now-committed automated regression coverage for every LANE requirement.

CI/CD-infrastructure phase: deliverables are GitHub Actions workflows (the trigger split,
`nightly.yml`, concurrency) + the A–E classification doc + CONTRIBUTING label. Per-requirement
coverage is a committed ExUnit file-content parity test (`test/install_smoke/ci_lane_split_test.exs`)
that reads the live `.github/**`, `scripts/**`, and docs and asserts the lane topology — so a
future edit that breaks the PR-only concurrency, un-splits package-consumer, makes `nightly.yml`
visible to the release train, or weakens the `CI Summary` required-check fails the merge gate.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) |
| **Config file** | none — uses the repo's existing `test/` tree + `mix test` |
| **Quick run command** | `mix test test/install_smoke/ci_lane_split_test.exs` |
| **Full suite command** | `mix ci` |
| **Estimated runtime** | ~0.03s (parity test) / ~10s (full `mix ci` gate) |

---

## Sampling Rate

- **After every task commit:** `mix test test/install_smoke/ci_lane_split_test.exs`
- **After every plan wave:** `mix ci`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~10 seconds (full `mix ci`)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 106-02/04 | 02,04 | 1,3 | LANE-01 | top-level `concurrency` keyed on workflow+ref; `cancel-in-progress` true ONLY for `pull_request` (push:main/dispatch serialize, never cancel) | parity | `mix test test/install_smoke/ci_lane_split_test.exs` | ✅ | ✅ green |
| 106-03 | 03 | 2 | LANE-02 | lean PR `package-consumer` + off-PR `package-consumer-full` (`if: != pull_request`, 5-profile `[video,image,tus,mux,gcs]`, `fail-fast: false`, no `continue-on-error`); full job OMITTED from `ci-summary.needs`, lean IS in needs | parity | `mix test test/install_smoke/ci_lane_split_test.exs` | ✅ | ✅ green |
| 106-04 | 04 | 3 | LANE-03 | `nightly.yml` (`name: Nightly`, schedule + dispatch, NO pull_request/push); broad OTP×Elixir compat matrix; owned gating Dialyzer (no continue-on-error key); moved `gcs-soak` + `package-consumer-gcs-live`; `nightly-failure-issue` least-privilege `issues: write` | parity | `mix test test/install_smoke/ci_lane_split_test.exs` | ✅ | ✅ green |
| 106-01 | 01 | 1 | LANE-04 | `CONTRIBUTING.md` trust/speed label (on-PR vs after-merge/nightly, ≤7-min, `image` smoke); `106-LANE-CLASSIFICATION.md` documents A–E buckets (D & E empty) | parity | `mix test test/install_smoke/ci_lane_split_test.exs` | ✅ | ✅ green |
| — | — | — | (SC5 invariant) | ci.yml line 1 `name: CI`; `REQUIRED_CHECKS=("CI Summary")` (single entry); automerge listens on `CI`; release gate reads `workflow_id: 'ci.yml'` — release train not weakened | parity | `mix test test/install_smoke/ci_lane_split_test.exs` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure (`mix test` / `mix ci`) covers all phase requirements. The single
new file `test/install_smoke/ci_lane_split_test.exs` (15 tests) was added retroactively
during the audit; it runs in the default suite (no exclude tag — matching the sibling
`release_docs_parity_test.exs` / `ci_cache_hygiene_test.exs`) and owns LANE topology only
(no duplication of the Phase-104 cache-hygiene assertions).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Actual GitHub Actions cancellation, matrix fan-out, and nightly cron firing | LANE-01/02/03 | Only observable on GitHub's runtime; cannot be exercised without pushing | Observe a real PR (stale run cancels), a push:main run (full matrix fans out), and the scheduled nightly run on the Actions tab |

The *topology* that could silently regress in a diff (concurrency expression, split jobs,
needs-omission, nightly triggers/permissions, release coupling) is fully covered automatically
by the parity test above; only the live runtime *effect* is manual, and it is non-regressing
configuration once the topology is asserted.

---

## Validation Sign-Off

- [x] All tasks have automated verify or existing-infrastructure coverage
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (1 new parity test added)
- [x] No watch-mode flags
- [x] Feedback latency < 11s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-06-22 (retroactive reconstruction during v1.20 milestone audit)

---

## Validation Audit 2026-06-22

| Metric | Count |
|--------|-------|
| Gaps found | 4 (LANE-01, LANE-02, LANE-03, LANE-04) + 1 release-coupling invariant |
| Resolved | 5 (new `ci_lane_split_test.exs`, 15 tests) |
| Escalated | 0 |
