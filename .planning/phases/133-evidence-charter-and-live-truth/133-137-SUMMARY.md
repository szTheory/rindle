---
phase: 133-evidence-charter-and-live-truth
plan: "137"
subsystem: testing
tags: [elixir, node, hex, offline-proof, tdd]
requires:
  - phase: 133-133
    provides: Pinned Hex 2.5.1 source inventory and frozen source receipts
provides:
  - Plan 138 SSL-safe proof entrypoints and isolated bootstrap regression
  - Independent Plan 138 one-shot build gate with copy-only regressions
affects: [133-138, evidence-charter-and-live-truth]
actuals:
  tokens: 16183
  tasks: 2
  commits: 4
  plan_head_before: bb2daa07c4f1be3d84812ecb02c2438f373a2a99
  plan_head_after: eeecac9f48615c172331c32fab437d9775332905
tech-stack:
  added: []
  patterns: [Isolated SSL bootstrap verification, copied-root one-shot gate regression]
key-files:
  created:
    - scripts/maintainer/phase_133_registry_compat_138.exs
    - test/install_smoke/phase_133_registry_compat_138_test.exs
    - scripts/maintainer/phase_133_hex_build_138.mjs
    - test/install_smoke/phase_133_hex_build_138_test.mjs
    - .planning/phases/133-evidence-charter-and-live-truth/133-137-TASK1-RED.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-137-TASK2-RED.json
  modified:
    - test/install_smoke/phase_133_hex_build_test.mjs
key-decisions:
  - "Keep Plan 135 as immutable first-red history; Plan 138 has separate authorization, marker, receipt paths, and build-p138 destination."
  - "Do not create a Plan 138 preflight or run a build/proof child in this repair plan."
requirements-completed: []
coverage:
  - id: D1
    description: Plan 138 proof entrypoint starts SSL and captures its version before Hex.State startup.
    verification:
      - kind: integration
        ref: "ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 elixir test/install_smoke/phase_133_registry_compat_138_test.exs"
        status: pass
    human_judgment: false
  - id: D2
    description: Plan 138 has a distinct fixed-path one-shot gate whose copied regressions reject Plan 135 identity and consumed permission.
    verification:
      - kind: integration
        ref: "node --test test/install_smoke/phase_133_hex_build_test.mjs test/install_smoke/phase_133_hex_build_138_test.mjs"
        status: pass
      - kind: other
        ref: "./scripts/maintainer/automation_first_contract.sh"
        status: pass
    human_judgment: false
duration: 5 min
completed: 2026-10-08
status: complete
---

# Phase 133 Plan 137: SSL-Safe Plan 138 Proof and Gate Summary

**Plan 138 now has an SSL-safe Hex proof entrypoint and an independent one-shot build gate, with copied-root regressions that preserve Plan 135's consumed evidence.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-10-09T02:27:03Z
- **Completed:** 2026-10-09T02:31:56Z
- **Tasks:** 2
- **Files modified:** 7 task artifacts (five code/test files and two TDD RED evidence records)

## Accomplishments

- Added a Plan 138-only Elixir proof runner that starts `:ssl`, verifies its version, and does so before starting `Hex.State`; an isolated process confirms the unloaded/loaded distinction.
- Added an independent Plan 138 gate with its own preflight, authorization, started marker, compatibility report, and `-build-p138` destination. It binds build and proof argv to the new Elixir entrypoint and rejects Plan 135 identity and permission.
- Added copy-only tests for tampering, first-red behavior, wrong-plan markers, duplicate children, and one-shot enforcement. Repaired the existing Plan 135 CLI regression to use a temporary copied root containing its consumed marker.
- Preserved the five Pending requirements, zero qualification credit, and eleven unresolved edge rows. No Plan 138 preflight, authorization, marker, build, proof, or network child was created or run.

## Task Commits

Each TDD task has an intentional RED commit followed by its GREEN implementation commit:

1. **Task 1 RED:** `9b666bef` — `test(133-137): add failing test for SSL-safe Plan 138 proof entrypoint`
2. **Task 1 GREEN:** `744f274e` — `feat(133-137): add SSL-safe Plan 138 proof entrypoint`
3. **Task 2 RED:** `168ae495` — `test(133-137): add Plan 138 identity and gate regressions`
4. **Task 2 GREEN:** `eeecac9f` — `feat(133-137): add independent Plan 138 one-shot build gate`

## Files Created/Modified

| File | SHA-256 | Purpose |
|---|---|---|
| `scripts/maintainer/phase_133_registry_compat_138.exs` | `4844b9a92a2e0cf688a4355d64d7fc7cde404ababa19456a935560b843a22ed9` | SSL-safe Plan 138 proof-write/proof-read entrypoints |
| `test/install_smoke/phase_133_registry_compat_138_test.exs` | `f9ef58647c0fe5ea29a5bb8aeb08567be24a36c9d03649a034c9c00752e12cb6` | Isolated SSL cause/fix check |
| `scripts/maintainer/phase_133_hex_build_138.mjs` | `8f0e02efe07cf4910268e79a0a974054cd9a81847a3a6713611f1f9247661ec4` | Fixed-path Plan 138 preflight, authorization, one-shot, and terminal gate |
| `test/install_smoke/phase_133_hex_build_test.mjs` | `2bba58c9b48581535b958bc02e573e74fc817b2749f2ea5357c80a67a50fab69` | Plan 135 CLI regression now exercises a temporary copied root |
| `test/install_smoke/phase_133_hex_build_138_test.mjs` | `5220c41b294af36877e87ea0dc179627d9c00dad7855afec51ce7df9b49ca0ea` | Copied Plan 138 gate and first-red regressions |
| `.planning/phases/133-evidence-charter-and-live-truth/133-137-TASK1-RED.json` | `f062cfbf10cd559d56b719e8dd833dad580f7aa83e3aefb72bf1dbe94aaed68c` | Machine-validated Task 1 RED evidence |
| `.planning/phases/133-evidence-charter-and-live-truth/133-137-TASK2-RED.json` | `7ff03ec8fc6ff51082afd0fab3eb740ed3c472db81abe12cb33655c6ccc75363` | Machine-validated Task 2 RED evidence |

## TDD Gate Compliance

- **Task 1 RED:** The named TAP test ran and failed on the missing SSL-before-`Hex.State` behavior. `gsd-tools check tdd-red-evidence` returned `RED_EVIDENCE_OK`. The isolated process passes after the helper was added.
- **Task 2 RED:** The named Node TAP test ran and failed because the independent Plan 138 gate was absent. `gsd-tools check tdd-red-evidence` returned `RED_EVIDENCE_OK`. The copied gate suite passes after implementation.

## Decisions Made

- Plan 135 remains immutable terminal first-red history. Plan 138 uses only its own authorization digest, receipt paths, marker, and destination.
- This repair adds no build authorization or qualification credit; the next plan must freeze and authorize its own exact preflight.

## Deviations from Plan

None - plan executed as written.

## Issues Encountered

- The existing Plan 135 CLI regression assumed its consumed started marker was absent. It now copies the runner and marker into a temporary synthetic root and verifies the copied marker remains byte-identical after rejected CLI input.

## Next Phase Readiness

Plan 138 can freeze a distinct preflight only after this code is merged into its execution base. All five requirements remain Pending, qualification credit remains zero, and eleven edge rows remain unresolved. `STATE.md` and `ROADMAP.md` were not modified.

## Self-Check: PASSED

- All seven task artifacts exist and their committed hashes are listed above.
- The four task commits are present in this worktree; evaluation scope resolved the plan and found all four commits.
- Plan 135's source, compatibility receipt, and started marker are byte-identical to the plan base.
- No Plan 138 preflight or started marker exists.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-10-08*
