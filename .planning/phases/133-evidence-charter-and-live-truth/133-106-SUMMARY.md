---
phase: 133-evidence-charter-and-live-truth
plan: "106"
subsystem: evidence
tags: [offline, asdf, runtime, no-clobber, source-binding]
requires:
  - phase: 133-evidence-charter-and-live-truth
    provides: Plans 104/105 offline supply tooling and immutable halted observations
provides:
  - Safe missing-parent cache staging and exclusive offline preflight publication
  - Explicit Plan 108 collection identity and immutable historical receipt verification
  - Source-bound proof of installed OTP 27.3.4.15 and Elixir/Mix 1.17.3
affects: [phase-133-local-qualification, phase-133-census]
actuals:
  tokens: 17421
  tasks: 2
  commits: 3
  plan_head_before: 061a5c4c9c22d78ebe9de97bf9b35e3e18564213
  plan_head_after: 46abbebe63b2889f17ddc2ac6d38385bb58fc3b2
tech-stack:
  added: []
  patterns:
    - Validate ancestor type and identity before exclusive cache/report publication
    - Cross-check selected installs, resolved executables, release bytes and live runtime
key-files:
  created:
    - .planning/phases/133-evidence-charter-and-live-truth/133-106-TDD-RED-EVIDENCE.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-106-RUNTIME.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-106-SUMMARY.md
  modified:
    - scripts/maintainer/phase_133_local_supply.mjs
    - scripts/maintainer/phase_133_local_supply.test.mjs
    - scripts/maintainer/test_phase_133_local_supply.sh
key-decisions:
  - Only the expected _build parent may be created; cache targets and reports remain exclusive.
  - Preserve schema-1 receipts against their first committed identity and original source blobs; current collection emits schema 2.
  - Supply collection starts no Mix child; standalone runtime observation probes Mix --version only after exact BEAM and Elixir validation.
  - Keep all five requirements pending and grant zero qualification credit.
patterns-established:
  - Historical receipt verification does not replay historical runtime failures or authorize new qualification staging.
requirements-completed: []
requirements-addressed: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
qualification_credit: 0
coverage:
  - id: D1
    description: Missing-parent publication succeeds once; unsafe paths, competing creators, partial writes, substituted history and wrong runtimes fail.
    verification:
      - kind: integration
        ref: bash scripts/maintainer/test_phase_133_local_supply.sh
        status: pass
      - kind: integration
        ref: bash scripts/maintainer/test_phase_133_local_gates.sh
        status: pass
    human_judgment: false
  - id: D2
    description: A no-clobber source-bound record proves the exact installed runtime with ten successful ordered probes and zero qualification credit.
    verification:
      - kind: other
        ref: ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 node scripts/maintainer/phase_133_local_supply.mjs runtime-check
        status: pass
      - kind: integration
        ref: scripts/maintainer/phase_133_local_supply.test.mjs#fake collector publishes once with an absent _build parent
        status: pass
    human_judgment: false
duration: 12min
completed: 2026-10-07
status: complete
---

# Phase 133 Plan 106: Offline Publication and Exact Runtime Summary

**Offline preflights can create a checked `_build` parent and publish exclusively; a source-bound observation proves installed OTP 27.3.4.15 and Elixir/Mix 1.17.3.**

## Performance

- **Started:** 2026-10-07T17:52:16Z
- **Completed:** 2026-10-07T18:04:53Z
- **Duration:** 12 min
- **Tasks:** 2/2
- **Files changed:** 6, including this summary
- **Actuals:** Character count divided by four over the realized task diff, rounded up; three commits measured from the persisted ledger before this summary commit.

## Accomplishments

- Removed the fixture's pre-created `_build` directory and proved the original collector failed with `ENOENT`. The repaired collector validates ancestors with `lstat`, creates only the expected parent and a fresh private cache target, and publishes complete reports with exclusive temporary-file creation and a no-clobber hard link. Tests reject symlink/non-directory ancestors, escapes, existing targets, competing parent/target/report creators and partial writes.
- Added explicit `--plan 133-108` collection and verification, binding the Plan 105 summary alongside existing protected history. New reports use schema 2. Historical Plan 104/105 schema-1 receipts verify against their first committed receipt and original SHA/tree/blob identities; they cannot stage a new qualification. The actual Plan 104 receipt and an isolated Plan 105 fixture pass, while relabeling and recomputed-digest substitutions fail. The real Plan 105 preflight remains absent.
- Recorded ten successful runtime probes in `133-106-RUNTIME.json`. Task-scoped asdf selections, installed roots, resolved executable hashes, `releases/27/OTP_VERSION`, live BEAM root/major, Elixir version and Mix version agree. Supply collection itself starts no Mix; only the standalone runtime observation runs `mix --version`, after BEAM/Elixir validation.

## Task Commits

1. **Task 1 RED:** `8d6dc902` — `test(133-106): expose missing-parent preflight publication failure`.
2. **Task 1 GREEN:** `cfd5eed0` — `feat(133-106): safely publish offline supply and verify exact runtime`.
3. **Task 2:** `46abbebe` — `docs(133-106): record source-bound supported runtime observation`.

**Plan metadata:** This summary is committed separately after the task commits. Hooks ran normally on every commit.

## Runtime Observation

- **Source SHA:** `cfd5eed0e8589687bab6ff2ea437fabae1ce70e6`
- **Source tree:** `1244ae3562add40a751c9f7644edc44cc8ce60ca`
- **Report digest:** `348cb1be50e2fee32f744d73df3e8ae1dfe03944422424a0845480e95ea8b977`
- **Erlang install:** `/Users/jon/.asdf/installs/erlang/27.3.4.15`
- **Elixir install:** `/Users/jon/.asdf/installs/elixir/1.17.3-otp-27`
- **Observed:** OTP `27.3.4.15`, BEAM major `27`, Elixir `1.17.3`, Mix `1.17.3`, NIF `2.17`, target `aarch64-apple-darwin`.

The report was published once using:

```sh
ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 node scripts/maintainer/phase_133_local_supply.mjs runtime-check --report .planning/phases/133-evidence-charter-and-live-truth/133-106-RUNTIME.json
```

A separate invocation of the plan's exact `runtime-check` command returned a byte-equivalent parsed runtime object. Independent Python checks recomputed the report digest, source tree/helper hash, executable/release-file hashes, ten successful probe exits, and Mix-last ordering. Repeating publication returned `report_exists` and preserved the original bytes.

## Verification

- GSD `check tdd-red-evidence` returned `RED_EVIDENCE_OK`. The target test executed the fake collector and failed on its expected exit-code assertion (`1 !== 0`) because `_build/supply` had no parent. This was the planned behavior failure, not a discovery, import or fixture failure.
- Supply harness passed: **20 TAP tests**, **49 integration assertions**, and the existing Plan 105 outcome harness. Its post-commit tracer rerun passed before Task 2.
- Existing fake local-gates harness passed exact-subject sequencing, JOSE snapshots, sanitized diagnostics, private transients and no-clobber checks.
- Node/shell syntax, `git diff --check`, and the automation-first contract passed.
- Eight protected files matched the dispatch base: STATE, ROADMAP, REQUIREMENTS, `.tool-versions`, both Plan 104 artifacts, Plan 105 summary and the canonical Nightly receipt.
- Requirement readiness returned **0/5**. The plan's explicit zero-credit rule controls `requirements-completed: []`; the full plan array is retained under `requirements-addressed`.

## Files Created/Modified

- `phase_133_local_supply.mjs` — checked publication, plan identity, historical verification, exact runtime probes and runtime-record publication.
- `phase_133_local_supply.test.mjs` — TAP runtime/path/history tests and the moved fake collector integration fixture.
- `test_phase_133_local_supply.sh` — invokes the consolidated TAP suite and existing outcome fixtures.
- `133-106-TDD-RED-EVIDENCE.json` — complete failing TAP output and semantic assessment.
- `133-106-RUNTIME.json` — immutable source-bound local runtime observation.
- `133-106-SUMMARY.md` — execution results and handoff.

## Decisions Made

Only `_build` may be added as a missing cache parent; an existing or concurrently created target fails rather than merging supply. New runtime fields are schema-2 evidence, while old receipts retain their original meaning. No real package collection, qualification, installation, external fetch, census, Nightly or remote action ran. The real Mix invocations were version-only probes.

## Deviations from Plan

**1. [Rule 1 - Bug] Normalize aligned asdf table headers.**

- **Found during:** Task 1 runtime implementation.
- **Issue:** The inherited header comparison accepted only single spaces, whereas the real asdf output uses aligned columns.
- **Fix:** Normalize header whitespace before selecting the named row; reject rows marked uninstalled.
- **Files:** `scripts/maintainer/phase_133_local_supply.mjs`, `scripts/maintainer/phase_133_local_supply.test.mjs`.
- **Verification:** Aligned-header, uninstalled-row and exact-runtime tests passed; the real runtime observation passed.
- **Commit:** `cfd5eed0`.

**Total deviations:** 1 auto-fixed bug. **Impact:** Required for the planned real runtime proof; no product-scope change.

## Issues Encountered

The existing local-gates harness initially could not write its temporary Git object under the sandbox. It passed after escalation for the authorized fixture run. Safety sentinels, the commit ledger and commits also used the permission mechanism. No hooks were bypassed and no main-checkout command ran.

## User Setup Required

None. Both required runtime versions were installed and accessible without installation or network access.

## Next Phase Readiness

The runtime/publication prerequisite is ready for Plan 108 after its Plan 107 dependency is satisfied. Plan 108 owns fresh-source qualification and remaining verifier integration. Plans 104/105 remain halted history; all five Phase 133 requirements remain pending. STATE.md and ROADMAP.md are reserved for the orchestrator.

## Self-Check: PASSED

All three created artifacts exist. All three task commits are ancestors of this branch, and GSD's plan-scoped evaluation resolver reports them. Coverage metadata classifies both deliverables as automation-backed. The automation-first contract and whitespace check passed after summary creation. No blocking stubs or unrun plan verification remain; no structural codebase-map update or product-scope update was needed.
