---
phase: "138"
slug: "lifecycle-failure-and-recovery-matrix"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-21"
---

# Phase 138 — Validation Strategy

Planning contract only. All RECOV requirements remain pending until executable
packaged-host observations and separate semantic verification pass.

## Test Infrastructure

| Property | Value |
|---|---|
| Framework | Existing ExUnit plus Python standard-library verifier fixtures |
| Config | `test/test_helper.exs`, `config/test.exs`, existing twin host |
| Quick command | `mix test test/install_smoke/twin_*_test.exs --seed 0` |
| Full regression | `mix ci` as defined by RUNNING.md |
| Real acceptance | `python3 scripts/maintainer/built_package_twin.py run --verify --cleanup` with the planned full-matrix mode |
| Runtime | Measure during execution; fast focused feedback target under 30s excluding first compile; five ordinary AV attempts require a separately bounded longer run |

Prefix Mix/runner commands with
`ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 ASDF_NODEJS_VERSION=20.18.1`.
Preserve root lock and toolchain files. Docker-free fast tests never substitute
for real matrix acceptance. No new framework or heavy CI lane is authorized.

## Sampling Rate

- After every task: its focused automated behavioral/negative-control command.
- After every plan wave: affected focused suites plus the available packaged-host
  slice where its implementation exists; partial runs cannot pass the full verifier.
- At phase integration: all six cases from one fresh archive, retained input/archive
  verification in a separate invocation, repeated safe cleanup, relevant RUNNING.md
  quality/regression gates and `./scripts/maintainer/automation_first_contract.sh`.
- Before goal verification: retain current-source evidence; failed or interrupted
  attempts remain failed even if later infrastructure disposal succeeds.

## Per-Requirement Verification Map

The planner expands this table to exact task IDs, wave numbers, threat IDs and
new test paths after decomposition. Do not mark draft entries green from planning.

| Requirement | Fast behavior/negative controls | Real acceptance oracle | Status |
|---|---|---|---|
| RECOV-01 | Existing twin tracer/receipt contracts extended for recreated client, wrong offset and duplicate stimuli | Completed nonfinal PATCH; new client HEAD; same session; final checksum; ready asset and exact keys | pending |
| RECOV-02 | Existing twin fault and purge tests; missing-object vs denied/unknown absence | Same durable purge job retryable attempt 1, independent source absence, ordinary attempt 2 completes | pending |
| RECOV-03 | AV failure/discard vs repair and receipt controls | Real five-attempt FFmpeg failure, runtime_status, genuinely enqueued public repair, probe plus full decode | pending |
| RECOV-04 | Worker regression suite for stale/duplicate/equal/missing/concurrent events, rollback and secret canaries | Actual Mux adapter/local HTTP fixture, signed ingress, ordinary provider queue, exact identities/effects | pending |
| RECOV-05 | Restart cut/quiescence/identity and replay controls | Promotion paused, available attempt-zero job committed; SIGKILL and new runtime; same job completes | pending |
| RECOV-06 | Existing cleanup/maintenance contracts plus per-resource inventory and foreign-resource controls | Real multipart part, genuine expiry, post-delete janitor interruption, same-resource reruns, complete pre-disposal audit | pending |

## Wave 0 Requirements

- Extend existing finite twin contract fixtures as each case lands; add new focused
  test files explicitly to owning PLAN tasks before referencing them in verification.
- Preserve old Phase 137 receipt interpretation without counting it as six-case success.
- Capture valid tiny video/audio fixture, supported tus route and local Mux HTTP
  responses through finite host-owned additions, not producer-private hooks.
- Establish bounded runtime launch/queue barriers and single-use maintenance process
  configuration without endpoint collisions or competing queue consumers.
- No test dependency installation is needed. Existing test paths cited above exist;
  new paths must have explicit creation tasks and cannot silently skip.

## Manual-Only Verifications

None. Every active requirement closes through executable tests, probes and evidence
collectors. A human approval may authorize an external action; it supplies no acceptance.

## Validation Sign-Off

- [ ] Exact task/wave/threat map reconciled to final plans.
- [ ] Every task has an automated command and observable `fails_when` signal.
- [ ] No three consecutive tasks lack fast automated feedback.
- [ ] New verification files have explicit creation ownership.
- [ ] Full six-case run and separate retained-input verifier pass at current source.
- [ ] All residue classes audited before disposal; repeated cleanup preserves foreign state.
- [ ] Relevant RUNNING.md checks pass; measured timings retained without CI speed credit.
- [ ] Nyquist audit determines `nyquist_compliant`; planning does not set it true.

**Approval:** pending executable validation.
