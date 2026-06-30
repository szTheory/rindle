---
phase: 113
slug: evaluation-baseline-release-hygiene
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-29
---

# Phase 113 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `113-RESEARCH.md` § Validation Architecture. This is a docs/release-hygiene
> phase — most "tests" are file-existence + content-grep + YAML-presence checks, not ExUnit cases.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.17 / OTP 27) + `junit_formatter ~> 3.4` (CI-gated) |
| **Config file** | `test/test_helper.exs` (JUnitFormatter wiring, lines 31–47) |
| **Quick run command** | `mix test test/install_smoke/package_metadata_test.exs` (smoke-script shape; fast, no MinIO) |
| **Full suite command** | `mix ci` (`mix.exs` alias; mirrors PR merge-blocking set) |
| **Workflow lint** | `actionlint` over new/edited `.github/workflows/*.yml` (must add ZERO findings) |
| **Estimated runtime** | grep/file checks sub-second; `package_metadata_test` ~5s; `mix ci` minutes |

---

## Sampling Rate

- **After every task commit:** Run the file-existence / content-grep check for that task (sub-second).
- **After every plan wave:** `mix test test/install_smoke/package_metadata_test.exs` (+ any new meta-test);
  `actionlint` over new workflow YAML — must add ZERO new findings.
- **Before phase gate:** Track A checks all green by Claude; Track B's "0.3.2 live" observed via Actions + Hex API.
- **Max feedback latency:** < 10 seconds for Track A automated checks.

---

## Per-Task Verification Map

| Req ID | Behavior | Test Type | Automated Command / Check | File Exists | Track |
|--------|----------|-----------|---------------------------|-------------|-------|
| EVAL-01 | EVAL doc at locked path, ~1 page, two scored tables, mapping matches REQUIREMENTS | file-existence + content-grep | `test -f .planning/milestones/v1.22-OSS-QUALITY-EVAL.md && grep -q 'TRUST-01' .planning/milestones/v1.22-OSS-QUALITY-EVAL.md` | ❌ W0 (new doc) | A |
| HYGIENE-01 (investigation) | Root cause recorded in RELEASE-TRAIN + release_publish guide | content-grep | `grep -q 'Bad credentials' .planning/RELEASE-TRAIN.md guides/release_publish.md` | ❌ W0 | A |
| HYGIENE-01 (drift guard) | Drift workflow present + OFF required `CI Summary` path | YAML-presence + required-path absence | `test -f .github/workflows/release-train-drift.yml`; assert NOT referenced in `ci-summary` `needs`/required checks | ❌ W0 | A |
| HYGIENE-01 (token guard) | Token-validity step present in `release.yml` Release Please job | YAML-presence grep | `grep -q 'gh api user' .github/workflows/release.yml` | ❌ W0 | A |
| HYGIENE-01 (junit, D-08) | `public_smoke` survives abnormal-exit suite without `bad argument` | harness fix + optional regression assertion | observed in `public_verify`; optional `test_helper` guard meta-test | ❌ W0 | A |
| HYGIENE-01 (cut) | Hex live = 0.3.2; mix.exs/manifest/CHANGELOG = 0.3.2 | **HUMAN-GATED** then machine-observable | `curl -s hex.pm/api/packages/rindle \| jq -r .latest_stable_version` == `0.3.2` | — | **B** |
| HYGIENE-01 (truth) | PROJECT/MILESTONES/RETROSPECTIVE reconcile "0.3.2 now live" (D-11) | content-grep | `grep -q 'released in v1.22 Phase 113' .planning/PROJECT.md` | — | **B** |
| HYGIENE-02 | SEED-003/004 `status: consumed` + `consumed_by` | frontmatter-grep | `grep -A6 '^status:' .planning/seeds/SEED-003*.md \| grep -q 'consumed'` | ❌ W0 | A |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `.planning/milestones/v1.22-OSS-QUALITY-EVAL.md` — new (EVAL-01).
- [ ] `.github/workflows/release-train-drift.yml` (+ issue template if used) — new (D-06a).
- [ ] Token-validity step in `release.yml` `Release Please` job — additive (D-06b).
- [ ] D-08 junit hardening in `scripts/public_smoke.sh` and/or `test/test_helper.exs`.
- [ ] (Recommended) an `install_smoke` meta-test asserting the new guard workflow stays OFF `ci-summary` required
      path — mirrors the existing `ci_observability_test.exs` OBS-02 grep-meta-test pattern.

*No new ExUnit framework needed — existing infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `RELEASE_PLEASE_TOKEN` rotated (fine-grained PAT or GitHub App token) with `contents:write` + `pull-requests:write` | HYGIENE-01 (cut) | Repo-admin secret action — Claude cannot set repo secrets | Maintainer rotates token, updates repo secret; this is the single irreducible human checkpoint (Track B gate) |
| 0.3.2 actually publishes to Hex via the canonical chain | HYGIENE-01 (cut) | Downstream of the human rotation; observed, not driven, by Claude | After rotation + phase-113 push, watch release-please → automerge → publish; confirm `curl … == 0.3.2` |

*Everything downstream of the token rotation is automated by the existing pipeline.*

---

## Validation Sign-Off

- [ ] All Track A tasks have an automated grep/file/YAML verify or Wave 0 dependency
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (new EVAL doc, new workflow, junit fix)
- [ ] Track B "0.3.2 live" marked `checkpoint:human-verify` (token rotation), then machine-observable via Hex API
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s for Track A
- [ ] `nyquist_compliant: true` set in frontmatter once the planner wires every req to a check

**Approval:** pending
