---
phase: 133-evidence-charter-and-live-truth
plan: "104"
subsystem: evidence
tags: [offline, hex, source-binding, native-supply, first-red]
requires:
  - phase: 133-evidence-charter-and-live-truth
    provides: Existing local-gates runner and immutable Plans 97–100 terminal evidence
provides:
  - Lock-authenticated Hex cache inventory and private cache staging with adversarial fixtures
  - Source-bound halted preflight identifying the runtime parser failure before any Mix child
affects: [phase-133-local-qualification, phase-133-census]
actuals:
  tokens: 23121
  tasks: 2
  commits: 1
  plan_head_before: a17b345368ecf0d32c9e16a068e370b95a5c679d
  plan_head_after: 3801a8932dd18b7ef38a1f523d8692051c59809c
tech-stack:
  added: []
  patterns:
    - Authenticate both Hex checksums and package identity before copying cache bytes
    - Reconstruct source, runtime, cache and guard observations during read-only verification
    - Preserve a first-red report without repair or qualification retry
key-files:
  created:
    - scripts/maintainer/phase_133_local_supply.mjs
    - scripts/maintainer/test_phase_133_local_supply.sh
    - .planning/phases/133-evidence-charter-and-live-truth/133-104-PREFLIGHT.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-104-SUMMARY.md
  modified:
    - scripts/maintainer/phase_133_local_gates.sh
    - scripts/maintainer/test_phase_133_local_gates.sh
    - .planning/phases/133-evidence-charter-and-live-truth/133-VALIDATION.md
    - .planning/WINDOWS.md
key-decisions:
  - Preserve the runtime-parser first red and grant no qualification or requirement credit.
  - Treat sandbox startup failure as unproved enforcement, never as successful network denial.
requirements-completed: []
requirements-addressed: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
coverage:
  - id: D1
    description: Fake offline supply and nested qualification reject archive, source, runtime, path, report, coverage and network-fallback substitutions.
    verification:
      - kind: integration
        ref: bash scripts/maintainer/test_phase_133_local_supply.sh
        status: pass
      - kind: integration
        ref: bash scripts/maintainer/test_phase_133_local_gates.sh
        status: pass
    human_judgment: false
  - id: D2
    description: A halted current-source preflight authenticates 67 locked archives, preserves protected evidence and records zero qualification children.
    verification:
      - kind: other
        ref: node scripts/maintainer/phase_133_local_supply.mjs verify --report .planning/phases/133-evidence-charter-and-live-truth/133-104-PREFLIGHT.json
        status: pass
      - kind: other
        ref: ./scripts/maintainer/automation_first_contract.sh
        status: pass
    human_judgment: false
duration: 23min
completed: 2026-10-07
status: halted
qualification_credit: 0
---

# Phase 133 Plan 104: Offline Local Supply Summary

**All 67 locked Hex archives authenticated and were staged locally, but the real preflight halted on an asdf table-parsing defect before runtime qualification or Mix.**

## Performance

- **Started:** 2026-10-07T12:00:13Z
- **Completed:** 2026-10-07T12:23:08Z
- **Duration:** 23 min
- **Tasks:** 2/2 executed through the designed first-red branch; local qualification remains unachieved.
- **Files changed:** 8
- **Actuals:** Character-count estimate over the realized changes; commit count measured from the persisted plan ledger before this terminal metadata commit.

## Accomplishments

- Added `collect`, `stage`, `stage-native`, `guard`, and read-only `verify` operations. Hex archives are checked against both committed lock checksums, package metadata, tar headers, and bounded safe member paths; staged bytes are reauthenticated. Publication is exclusive and does not replace prior evidence.
- Extended the existing runner with `--offline-cache`, private nested-worktree Hex supply, `HEX_OFFLINE=1`, sandbox-wrapped Mix descendants, network-fallback rejection, and source-bound offline report fields while preserving its CI/coverage schema. Its original regression harness now uses fake runtime probes, with Node resolved before fake asdf shadows the host shim.
- Passed 33 supply assertions, including a fake nested qualification, mutated archives/locks/source/tree/target/runtime, poisoned metadata, missing native inputs, staged-cache tampering, no-clobber output, complete-report validation, and a denied network attempt that returns a red CI result without coverage.
- Published one immutable halted preflight and verified its observations anew. All 67 locked archives are available and staged; this establishes package supply only. No real runtime/native-route qualification, Mix, local gates, coverage, census, Nightly, installation, external fetch or remote action ran.

## Task Commits

1. **Task 1: Prove local locked-package supply** — `3801a893` (`feat(133-104): verify and stage source-bound offline supply`).
2. **Task 2: Record the terminal first red** — this summary commit, together with the preflight, validation addendum and defect-ledger entry.

The post-commit tracer reran both harnesses successfully before the real preflight. No source repair or second collection followed the first red.

## Exact Attempt and Evidence

- **Source SHA:** `3801a8932dd18b7ef38a1f523d8692051c59809c`
- **Source tree:** `da2e19b25461380cc50647df01550181bb8f4257`
- **Preflight report digest:** `883b57f70515b3d46399ceab4775e3c57ed90a6697e0f7028c58404402dad165`
- **Preflight file digest:** `60e87af4e2bc7c8f3a27849c3e5a475bc324a780645bcbe7dcf8041ef31a6969`
- **Staged archive-set digest:** `dcaa601752e5bc113d6acb814c5cbaf190c48b3a4cc8d3e88421e5a50d8f5cad`
- **Protected Nightly receipt digest:** `1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4`

Collection command (exit 0 means the halted report was published, not qualification success):

```sh
ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 HEX_OFFLINE=1 node scripts/maintainer/phase_133_local_supply.mjs collect --subject 3801a8932dd18b7ef38a1f523d8692051c59809c --target _build/phase133-offline-hex --report .planning/phases/133-evidence-charter-and-live-truth/133-104-PREFLIGHT.json
```

The attempted probe argv/exits are also embedded in `probe_commands`:

1. `["asdf", "current", "erlang"]` — exit **0**; collector validation then raised `unsupported_runtime` for `erlang`.
2. `["sandbox-exec", "-p", "(version 1) (allow default) (deny network*)", "/Users/jon/.asdf/installs/nodejs/22.14.0/bin/node", "-e", "process.exit(0)"]` — exit **71**; sandbox startup control failed, so the network-denial probe was not started.

The read-only follow-up `ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 HEX_OFFLINE=1 asdf current erlang` exited 0 and showed:

```text
Name            Version         Source              Installed
erlang          27.3.4.15       ASDF_ERLANG_VERSION true
```

The collector takes the second token of the whole output (`Version`), rather than selecting the `erlang` row. This is a new collector defect, not evidence that Erlang is absent. Elixir identity, Vix target/checksum derivation and Lexbor availability were not evaluated after runtime resolution failed. The headerless fake runtime output did not cover this host output shape.

## Files Created/Modified

- `scripts/maintainer/phase_133_local_supply.mjs` — authentication, supply staging, guard control and independent observation reconstruction; runtime table parsing remains defective as recorded above.
- `scripts/maintainer/test_phase_133_local_supply.sh` — independent Python archive fixtures and fake-command adversarial integration checks.
- `scripts/maintainer/phase_133_local_gates.sh` — offline nested supply and sandbox-wrapped child execution.
- `scripts/maintainer/test_phase_133_local_gates.sh` — fake runtime isolation for existing regression tests.
- `133-104-PREFLIGHT.json` — exact-source halted observation, package identities/digests, probe exits and zero child counts.
- `133-VALIDATION.md` — executable evidence and first-red cause.
- `.planning/WINDOWS.md` — open defect #38 for the asdf table parser.
- `133-104-SUMMARY.md` — terminal zero-credit result.

## Decisions Made

- Followed Task 2's first-red rule: no helper repair, new source, second collection or qualification retry after this preflight.
- Kept the five requirement IDs pending and `requirements-completed` empty; this plan explicitly prohibits requirement completion credit.
- Recorded sandbox exit 71 as failed startup, without claiming that a network-deny profile was enforced.

## Deviations from Plan

**[Rule 1 - Bug, deferred under the explicit first-red boundary] Runtime parser rejects header-bearing asdf output.**

- **Found during:** Task 2 real preflight.
- **Issue:** Task 1's headerless fake `asdf current` output passed, but the host emits a header. The parser rejects the supported installed Erlang selection before resolving runtime executables.
- **Disposition:** No repair or retry in this attempt. The explicit Task 2 stop rule takes precedence over automatic repair. Recorded the exact output and open defect #38 for a successor plan.
- **Files:** `scripts/maintainer/phase_133_local_supply.mjs`, its fake runtime harness; introduced in `3801a893`.
- **Verification:** The immutable halted preflight independently reconstructs; read-only asdf output establishes the parser cause. Real runtime/native qualification remains unproved.

**Total deviations:** 1 deferred defect; 0 post-preflight repairs. **Impact:** Local qualification is halted and the source cannot authorize census or remote evidence. The sandbox startup failure is a separate observed environment limitation, not an inferred network-denial success.

## Verification

- Task 1 command and post-commit tracer: both shell harnesses passed; supply harness reported 33 assertions.
- Node syntax, shell syntax and `git diff --check`: passed.
- Read-only preflight verifier: passed, including all staged archive bytes.
- Automation-first contract: passed.
- Protected-history byte comparison: 20 files matched dispatch base, including Plans 97–100, canonical Nightly receipt, requirements, STATE, ROADMAP and `.tool-versions`.
- Halt invariants: zero real qualification children; `133-104-LOCAL-GATES.json` absent; all five requirements pending.
- Full real CI/coverage: ineligible after the halted preflight, not passing evidence.

## Issues Encountered

The existing fake runtime harness initially intercepted the asdf-backed Node shim; resolving Node before installing fake asdf fixed that fixture collision before Task 1 committed. Git metadata writes required sandbox escalation for the authorized safety sentinel, commit ledger, fixture worktrees and normal commits. No hooks were bypassed.

## User Setup Required

None for this terminal result. A successor plan must reproduce and fix header-bearing asdf parsing and establish a working network-deny control before a new immutable source can qualify.

## Next Phase Readiness

**Halted.** The 67 authenticated archives are usable supply evidence, but there is no locally qualified source. A later explicit gap plan is required; Plans 100–103 cannot treat this halt as retrospective success. EVID-01, EVID-02, EVID-03, EVID-04 and TRUTH-08 remain pending. STATE.md and ROADMAP.md are unchanged for the orchestrator.

## Self-Check: PASSED

All created files exist, the source commit is reachable on this branch, and the evaluation-scope resolver reports `3801a8932dd18b7ef38a1f523d8692051c59809c`. The exact Task 2 conditional verification command passed for the halted branch, including read-only preflight verification, summary status, canonical receipt digest and automation-first contract. This self-check verifies the terminal halt record; it grants no real qualification or requirement credit.
