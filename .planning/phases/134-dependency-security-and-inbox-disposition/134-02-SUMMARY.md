---
phase: 134-dependency-security-and-inbox-disposition
plan: 02
subsystem: infra
tags: [bash, jq, gh, hex-audit, dependabot, ci-gates, fake-gh-harness]
status: complete

requires:
  - phase: 134-01
    provides: fake-gh PATH-shim harness pattern and inventory collector
provides:
  - "scripts/maintainer/dep_landing_evidence.sh: DEPS-01 per-landing attribution (squash lock delta, mix.exs guard) and post-merge gate evidence (schema rindle-dep-landing-v1)"
  - "scripts/ci/test_dep_landing_evidence.sh: git-repo plus fake-gh harness with mutation tripwire (58 checks)"
  - "ci.yml quality job: advisory 'Audit Hex advisories (advisory)' step (mix hex.audit)"
  - "dependabot.yml: muontrap semver-major ignore for the mix ecosystem"
  - "nightly_policy_test: upload-artifact pin derived from nightly.yml, no literal SHA"
affects: [134-03, 134-04, 134-05, 134-06]

actuals:
  tokens: 21000
  tasks: 3
  commits: 3
plan_head_before: 71621905e98e541daca4453600d32b1b798546a5
plan_head_after: 082bd29b

tech-stack:
  added: []
  patterns:
    - "single gh_get / gh_jobs GET-only wrapper; no method or field flag"
    - "gate map as one jq definition (exact names plus matrix-leg prefixes) with missing / fail / inherited_red / pass"
    - "action pins asserted by shape and by agreement with the workflow text, never by literal SHA"

key-files:
  created:
    - scripts/maintainer/dep_landing_evidence.sh
    - scripts/ci/test_dep_landing_evidence.sh
  modified:
    - .github/workflows/ci.yml
    - .github/dependabot.yml
    - test/install_smoke/quality_signal_policy_test.exs
    - test/install_smoke/dependabot_policy_test.exs
    - test/install_smoke/nightly_policy_test.exs

key-decisions:
  - "attributable also requires mix.exs unchanged, so a mix.exs edit yields verdict attribution_failed (exit 1) with mix_exs_changed true"
  - "A red gate job with no --baseline-sha is classed regression (nothing proves it inherited); inherited_red needs a baseline run in which the job was red or absent"
  - "skipped conclusion on a gate job counts as not-success (no credit for a lane that did not run)"
  - "Exit 75 emits no JSON (run absent or not completed), only a stderr line"

requirements-completed: []
requirements-advanced: [DEPS-01, SEC-09]

coverage:
  - id: D1
    description: "A squash SHA yields attributable, per-gate JSON evidence incl. main-only lanes; twin fixed to the not-applicable literal; regression vs inherited_red vs missing vs in-progress"
    requirement: DEPS-01
    verification:
      - kind: integration
        ref: "bash scripts/ci/test_dep_landing_evidence.sh"
        status: pass
    human_judgment: false
  - id: D2
    description: "Quality runs mix hex.audit as an advisory continue-on-error step directly after deps.audit, locked by a policy test"
    requirement: SEC-09
    verification:
      - kind: unit
        ref: "mix test test/install_smoke/quality_signal_policy_test.exs"
        status: pass
    human_judgment: false
  - id: D3
    description: "MuonTrap semver-major is ignored by Dependabot and action pins no longer appear as literals in install_smoke tests"
    requirement: DEPS-01
    verification:
      - kind: unit
        ref: "mix test test/install_smoke/dependabot_policy_test.exs test/install_smoke/nightly_policy_test.exs"
        status: pass
    human_judgment: false
---

# Phase 134 Plan 02: Landing Evidence and Config Summary

**`dep_landing_evidence.sh` turns a squash SHA into attributable per-gate JSON (lock delta subset check, mix.exs guard, post-merge push-run gate map incl. main-only lanes, regression vs inherited_red), plus an advisory `mix hex.audit` Quality step, a MuonTrap-major Dependabot ignore, and SHA-literal-free Nightly policy assertions.**

Duration: about 30 min. Tasks: 3. Files: 2 created, 5 modified.

## Accomplishments

- **Task 1 (tracer, de835f43):** the evidence script and a 58-check harness (real temp git repo with crafted squash, mix.exs, workflow-only, workflow-plus-lock and merge commits; fake gh answering run/job reads; mutation tripwire self-tested). Covers clean pass, extra package, mix.exs edit, merge commit rejection, `actions` group with empty packages, missing exact job / prefix with no leg / Smoke not standing in for E2E, regression (exit 1), inherited_red (exit 3), no baseline, in-progress and absent run (exit 75), baseline mode, usage errors, atomic `--out`.
- **Task 2 (030e22a4):** `Audit Hex advisories (advisory)` step (`if: matrix.lint`, `continue-on-error: true`) directly after `Audit dependencies (advisory)`; policy test asserts run, if, continue-on-error and position.
- **Task 3 (082bd29b):** `ignore: muontrap / version-update:semver-major` in the mix entry; policy test; `assert_upload_artifact_pin!` helper in `nightly_policy_test.exs` (shape match plus equality with the pin(s) in nightly.yml).

## Verification

- Precondition: PR #120 MERGED at ae08818a, ancestor of origin/main and HEAD (checked before editing ci.yml).
- `bash scripts/ci/test_dep_landing_evidence.sh`: **58 passed, 0 failed**; also under `/bin/bash` 3.2 and in `ubuntu:22.04` with jq 1.6.
- ExUnit: quality_signal_policy, ci_observability, ci_lane_split, nightly_policy, live_truth_parity, evidence_census: **113 tests, 0 failures** (1 excluded); dependabot_policy + nightly_policy: **9 tests, 0 failures**.
- Live read-only run, baseline mode against current main: gates supported_toolchain / public_contract / package_consumer all `pass`, twin literal, verdict pass; confirms the gate job names match real ci.yml push-run job names.
- Acceptance greps: no non-GET method flag in the script; no `.planning/phases/134` path in scripts, tests or workflows; no 40-hex action pin literal left in nightly_policy_test.exs; `grep -c 'run: mix hex.audit' ci.yml` is 1; task 2 commit lists only its two files.
- `./scripts/maintainer/automation_first_contract.sh`: exit 0.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Branch guard vs sequential-on-phase-branch execution**
- Same adaptation as 134-01: the commit assertion kept the protected-branch check but skipped the `agent-*` allow-list because the orchestrator assigned `gsd/phase-134`.

**2. [Rule 2 - Missing critical] Extra test hooks in meta-test sweep**
- Ran `live_truth_parity_test` and `evidence_census_test` too (the latter lists `mix deps.audit` as a detector literal); no literal was broken, no edit needed.

**Total deviations:** 2 (process only). **Impact:** none on scope.

## Notes for downstream plans (03, 04, 05)

- Interface exactly as planned. JSON keys: `schema, sha, group, lock, lock_delta[{package,from,to}], mix_exs_changed, attributable, run, baseline_run, gates{supported_toolchain,public_contract,package_consumer,twin}, jobs[], verdict`. `verdict` is one of `pass | attribution_failed | missing_gate | regression | inherited_red`. `from`/`to` are `null` for added/removed packages; non-hex lock sources show version `non-hex`.
- In baseline mode (`--group` absent) `attributable`, `mix_exs_changed` are `null` and `lock_delta` is `[]`.
- Group mode needs the SHA present locally (fetch main first) and is run from inside the repo; it resolves the repo root itself.
- Plan 03 should wire `scripts/ci/test_dep_landing_evidence.sh` (needs only bash, git, jq) into `ci-script-tests` next to `test_collect_inbox.sh`; this plan did not touch that job.
- Nothing blocks 134-03. PR #120 is already merged. The actions group #113 can now go green with respect to the Nightly SHA literal; rebase/refresh of #113 is a Plan 04/05 concern.

## Known Stubs

None.

## Threat Flags

None. All GitHub access is GET-only (harness tripwire); no new endpoint or auth path.

## Self-Check: PASSED

- scripts/maintainer/dep_landing_evidence.sh and scripts/ci/test_dep_landing_evidence.sh exist.
- Commits de835f43, 030e22a4, 082bd29b are ancestors of HEAD.
