---
phase: 28
slug: onboarding-docs-ci-proof
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-05
---

# Phase 28 — Validation Strategy

> Per-phase validation contract for Phase 28 execution. This is the Nyquist gate
> artifact for AV-06-01 through AV-06-08.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit, Mix tasks, GitHub Actions workflow steps, shell gate for AV hygiene |
| **Config file** | `config/test.exs`, `test/test_helper.exs`, `.github/workflows/ci.yml` |
| **Quick run command** | `mix test test/install_smoke/docs_parity_test.exs test/rindle/doctor_test.exs test/rindle/error_test.exs --warnings-as-errors` |
| **Full phase command** | `mix test test/install_smoke/docs_parity_test.exs test/install_smoke/release_docs_parity_test.exs test/rindle/doctor_test.exs test/rindle/error_test.exs test/rindle/contracts/telemetry_contract_test.exs test/rindle/profile/presets_web_test.exs test/adopter/canonical_app/lifecycle_test.exs --warnings-as-errors --include adopter --include contract && mix rindle.doctor Rindle.Adopter.CanonicalApp.Profile Rindle.Adopter.CanonicalApp.VideoProfile && bash scripts/assert_av_hygiene.sh` |
| **Estimated runtime** | ~90-180 seconds once fixtures and CI-facing gates exist |

---

## Sampling Rate

- After every task commit: run the task’s `<automated>` command verbatim.
- After every plan wave: run the cumulative phase lane for all completed plans.
- Before `/gsd-verify-work`: run the full phase command and `mix compile --warnings-as-errors`.
- Max feedback latency: <= 30 seconds for targeted doc/contract commands; <= 180 seconds for the full phase lane.

---

## Phase Requirements → Plan/Test Map

| Req ID | Plan | Requirement Proof | Automated Command | Evidence Type | Status |
|--------|------|-------------------|-------------------|---------------|--------|
| AV-06-01 | 28-01 | Public FFmpeg install matrix exists and is linked from onboarding entrypoints | `mix test test/install_smoke/docs_parity_test.exs test/install_smoke/release_docs_parity_test.exs --warnings-as-errors` | docs parity | ⬜ pending |
| AV-06-02 | 28-01 | Smallest AV onboarding path is documented with `:kind => :video` and `mix rindle.doctor` | `mix test test/install_smoke/docs_parity_test.exs --warnings-as-errors` | docs parity | ⬜ pending |
| AV-06-03 | 28-02 | Public doctor task validates the fixture/example profiles and fails non-zero on drift | `mix test test/rindle/doctor_test.exs --warnings-as-errors && mix rindle.doctor Rindle.Adopter.CanonicalApp.Profile Rindle.Adopter.CanonicalApp.VideoProfile` | mix-task / CLI | ⬜ pending |
| AV-06-04 | 28-03 | Canonical adopter lane proves the smartphone fixture matrix through upload, probe, transcode, poster, and signed URL | `mix test --only adopter test/adopter/canonical_app/lifecycle_test.exs --warnings-as-errors` | adopter integration | ⬜ pending |
| AV-06-05 | 28-04 | Exact AV error vocabulary remains runtime-owned and parity-locked | `mix test test/rindle/error_test.exs --warnings-as-errors` | exact contract | ⬜ pending |
| AV-06-06 | 28-03 | `Rindle.Profile.Presets.Web` remains the canonical end-to-end demo path | `mix test test/rindle/profile/presets_web_test.exs test/adopter/canonical_app/lifecycle_test.exs --warnings-as-errors --include adopter` | preset / adopter | ⬜ pending |
| AV-06-07 | 28-04 | Telemetry names match documented conventions and stay in the allowlist | `mix test test/rindle/contracts/telemetry_contract_test.exs --warnings-as-errors --include contract` | contract | ⬜ pending |
| AV-06-08 | 28-02, 28-04 | AV hygiene gate blocks banned subprocess patterns under `lib/rindle/` and CI wires the right parity gate | `bash scripts/assert_av_hygiene.sh` | shell / CI gate | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirements | Automated Command | File Exists | Status |
|---------|------|------|--------------|-------------------|-------------|--------|
| 28-01-T1 | 28-01 | 1 | AV-06-01 | `mix test test/install_smoke/docs_parity_test.exs test/install_smoke/release_docs_parity_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 28-01-T2 | 28-01 | 1 | AV-06-02 | `mix test test/install_smoke/docs_parity_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 28-02-T1 | 28-02 | 2 | AV-06-03 | `mix test test/rindle/doctor_test.exs --warnings-as-errors && mix rindle.doctor Rindle.Adopter.CanonicalApp.Profile Rindle.Adopter.CanonicalApp.VideoProfile` | yes | ⬜ pending |
| 28-02-T2 | 28-02 | 2 | AV-06-08 | `bash scripts/assert_av_hygiene.sh` | no — created by execution | ⬜ pending |
| 28-03-T1 | 28-03 | 3 | AV-06-04 | `mix test --only adopter test/adopter/canonical_app/lifecycle_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 28-03-T2 | 28-03 | 3 | AV-06-06 | `mix test test/rindle/profile/presets_web_test.exs test/adopter/canonical_app/lifecycle_test.exs --warnings-as-errors --include adopter` | yes | ⬜ pending |
| 28-04-T1 | 28-04 | 4 | AV-06-05 | `mix test test/rindle/error_test.exs test/install_smoke/docs_parity_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 28-04-T2 | 28-04 | 4 | AV-06-07 | `mix test test/rindle/contracts/telemetry_contract_test.exs --warnings-as-errors --include contract` | yes | ⬜ pending |

---

## Required Automated Commands

- `mix test test/install_smoke/docs_parity_test.exs test/install_smoke/release_docs_parity_test.exs --warnings-as-errors`
- `mix test test/install_smoke/docs_parity_test.exs --warnings-as-errors`
- `mix test test/rindle/doctor_test.exs --warnings-as-errors && mix rindle.doctor Rindle.Adopter.CanonicalApp.Profile Rindle.Adopter.CanonicalApp.VideoProfile`
- `bash scripts/assert_av_hygiene.sh`
- `mix test --only adopter test/adopter/canonical_app/lifecycle_test.exs --warnings-as-errors`
- `mix test test/rindle/profile/presets_web_test.exs test/adopter/canonical_app/lifecycle_test.exs --warnings-as-errors --include adopter`
- `mix test test/rindle/error_test.exs test/install_smoke/docs_parity_test.exs --warnings-as-errors`
- `mix test test/rindle/contracts/telemetry_contract_test.exs --warnings-as-errors --include contract`
- `mix compile --warnings-as-errors`

---

## Phase Gate Evidence

- `28-01` proves the public docs entrypoints now teach AV onboarding and point
  to the linked runtime/install matrix.
- `28-02` proves the public doctor surface is truthful for real fixture/example
  profiles and that unsafe subprocess patterns are blocked under `lib/rindle/`.
- `28-03` proves the canonical adopter lane on a two-fixture smartphone matrix
  using the stock web preset path.
- `28-04` proves the final semver-sensitive contract closure: exact AV error
  copy, telemetry allowlist, and replacement of stale CI docs drift
  assumptions.
- Final phase gate: the full phase command plus `mix compile --warnings-as-errors`
  must be green before execution can be marked complete.

---

## Validation Sign-Off

- [x] All plans 28-01 through 28-04 are mapped to automated verification.
- [x] AV-06-01 through AV-06-08 each have at least one explicit automated command.
- [x] Mix-task, docs-parity, adopter-integration, contract, and CI shell-gate
  evidence are all represented in the validation contract.
- [x] `nyquist_compliant: true` is set because every requirement has an
  execution-time verification target.

**Approval:** approved (planner revision sign-off — Phase 28 execution may proceed against this validation contract)
