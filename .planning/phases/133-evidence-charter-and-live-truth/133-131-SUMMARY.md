---
phase: 133-evidence-charter-and-live-truth
plan: "131"
subsystem: infra
tags: [hex, otp27, registry, evidence, provenance]

requires:
  - phase: "133-130"
    provides: [immutable zero-request Plan 130 halt, pinned Elixir 1.17.3 / OTP 27 identity]
provides:
  - Historical Plan 130 source/report verification across evidence-only and later commits
  - Offline OTP 27 Hex inventory with a frozen exact missing-source/build halt
  - Plan 132 compatibility readiness gate that refuses preflight and request artifacts on a false report
affects: ["133-132", "133-129"]

actuals:
  tokens: 27032
  tasks: 3
  commits: 7
  plan_head_before: 624eb8419c8c97ad0bcb26dcf5e1da4a4c4622b5
  plan_head_after: 6d744be9a175a2d8cc4638cf94d28b5fbe6b2de7

tech-stack:
  added: []
  patterns: [historical source/report identity verification, offline compatibility inventory, zero-credit successor gate]

key-files:
  created:
    - scripts/maintainer/phase_133_registry_compat.exs
    - test/install_smoke/phase_133_registry_compat_test.exs
    - .planning/phases/133-evidence-charter-and-live-truth/133-131-COMPATIBILITY.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-131-TASK1-TDD-RED-EVIDENCE.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-131-TASK2-TDD-RED-EVIDENCE.json
  modified:
    - scripts/maintainer/phase_133_registry_supply.mjs
    - test/install_smoke/phase_133_registry_supply_test.mjs
    - .planning/phases/133-evidence-charter-and-live-truth/133-132-PLAN.md

key-decisions:
  - "Plan 130 remains immutable historical zero-credit evidence; its source is verified at its recorded commit, while its report commit and later history are checked separately."
  - "No provenance-identified Hex source or build for Elixir 1.17.3 / OTP 27 was local, so compatibility stays halted and grants no request or qualification credit."
  - "Plan 132's false-compatibility path requires an exact machine-readable halt receipt and no preflight or later request artifacts."

patterns-established:
  - "Historical evidence binds its committed report bytes to the frozen source tree and enumerates allowed source-to-report commits."
  - "A successor readiness verifier rehashes compatibility source, pinned runtime, installed Hex binaries, lock, cache, and preserved evidence before admitting the result."

requirements-completed: []
requirements-reviewed: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]

coverage:
  - id: D1
    description: "Plan 130's immutable halt verifies across its report-only commit, while protected source and lock changes are rejected."
    verification:
      - kind: unit
        ref: "test/install_smoke/phase_133_registry_supply_test.mjs#verifies a report-only commit against its frozen source while allowing later source evolution"
        status: pass
      - kind: other
        ref: "node scripts/maintainer/phase_133_registry_supply.mjs verify-preflight --report .planning/phases/133-evidence-charter-and-live-truth/133-130-REGISTRY-PREFLIGHT.json"
        status: pass
    human_judgment: false
  - id: D2
    description: "Plan 131 records a zero-credit halt because no audited OTP 27 compatible Hex source or build is available locally."
    verification:
      - kind: unit
        ref: "test/install_smoke/phase_133_registry_compat_test.exs#produces a zero-credit stop when no provenance-identified OTP 27 Hex source is available"
        status: pass
      - kind: other
        ref: "ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 elixir scripts/maintainer/phase_133_registry_compat.exs verify --report .planning/phases/133-evidence-charter-and-live-truth/133-131-COMPATIBILITY.json"
        status: pass
    human_judgment: false
  - id: D3
    description: "Plan 132 refuses preflight, authorization, request, and supply artifacts when compatibility is false."
    verification:
      - kind: unit
        ref: "test/install_smoke/phase_133_registry_supply_test.mjs#verify-readiness CLI accepts the committed false report only with its exact halt receipt"
        status: pass
      - kind: other
        ref: "./scripts/maintainer/automation_first_contract.sh"
        status: pass
    human_judgment: false

duration: 23 min
completed: 2026-10-08
status: complete
---

# Phase 133 Plan 131: Evidence Charter and Live Truth Summary

**Historical Plan 130 evidence now verifies across report-only commits, while the offline OTP 27 inventory records the missing audited Hex build and gates Plan 132 before preflight or request.**

## Performance

- **Duration:** 23 min
- **Started:** 2026-10-08T18:10:00Z
- **Completed:** 2026-10-08T18:33:13Z
- **Tasks:** 3
- **Files modified:** 8

## Accomplishments

- Repaired historical verification so Plan 130's unchanged report digest `7b90732cd17d31561c637aa906da89ab28974f5b85c0fd31b2fa87915c1b82af` remains valid across its report-only commit and later unrelated history; protected source, lock, cache, report-byte, and ancestry mismatches are rejected.
- Inventoried local Hex inputs without network, Mix, install, or cache writes. The only installed Hex CLI is 2.5.1 and its recorded OTP 27 load failed with exit 78; no provenance-identified compatible Hex source or build was found. The frozen Plan 131 report digest is `562ed2c538cedcde7c1b15068df362d2ae64b65e987bde64e96c6fcb9546d647` with blocker `provenance_identified_otp27_hex_source_or_build_missing`.
- Added a successor verifier that checks Plan 131 report history, source, pinned runtime, Hex binaries, API contract, mix.lock, cache, and preserved evidence. Plan 132's halt receipt now requires zero requests, authorization, and qualification, with no preflight or later artifacts.

The compatibility report records **0** network requests, Mix children, native children, installs, authorization eligibility, and qualification credit. Cache bytes remained unchanged at `0f4f54217bcdafd992f9ed6bdc518a72d11f497a07a7586b19f1a35b45f66951`. The canonical Nightly receipt remains run `34638437301`, digest `1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4`, subject `1470cf8cb0f111d0b233efbf77ee69e92f25fd68`. Barred SHA `87572a019636ba1367c0c7245ae5cb89d0ea1909` is preserved; EVID-01 through EVID-04 and TRUTH-08 remain Pending, and all 11 edge rows remain unresolved.

## Task Commits

Each task was committed atomically:

1. **Task 1: Verify the terminal report across its report-only commit** — `6e5fa871` (RED), `d19caa69` (GREEN)
2. **Task 2: Prove an OTP 27 compatible Hex and its actual cache-write API offline** — `d1eb29a6` (RED), `b8d13cd9` (inventory), `a8f4ce25` (JSON null digest fix), `40b9d64a` (frozen halt report)
3. **Task 3: Bind the successor supply and Plan 129 handoff to the proven route** — `6d744be9`

## Files Created/Modified

- `scripts/maintainer/phase_133_registry_supply.mjs` — historical and current Plan 130 checks plus Plan 131 compatibility/readiness verification.
- `test/install_smoke/phase_133_registry_supply_test.mjs` — history, drift, wrong-identity, and Plan 132 halt-gate coverage.
- `scripts/maintainer/phase_133_registry_compat.exs` and `test/install_smoke/phase_133_registry_compat_test.exs` — local OTP 27 Hex inventory, exact missing-input report, digest validation, and no-clobber publication.
- `.planning/phases/133-evidence-charter-and-live-truth/133-131-COMPATIBILITY.json` — frozen zero-credit missing-input result.
- `.planning/phases/133-evidence-charter-and-live-truth/133-132-PLAN.md` — machine-readable halt receipt contract for Plan 132.
- `.planning/phases/133-evidence-charter-and-live-truth/133-131-TASK1-TDD-RED-EVIDENCE.json` and `133-131-TASK2-TDD-RED-EVIDENCE.json` — classified intentional RED evidence for the two TDD tasks.

## Decisions Made

- Treat Plan 130's source commit, report commit, and present-day source as distinct identities. Historical evidence remains valid only for its committed bytes and recorded source blobs.
- Keep Plan 131 at the designed exact missing-input halt. A future plan must obtain an audited Hex source archive or commit, reproducibly build it for Elixir 1.17.3 / OTP 27, and prove its exports, signed fixture, repo origin, lock projection, disposable cache write, persistence, and offline readback before Plan 132 may proceed.
- Make Plan 132's false-compatibility summary machine-readable so its no-preflight/no-request stop can be checked without human acceptance.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Preserved JSON null in compatibility report digests**

- **Found during:** Task 2, end-to-end report verification
- **Issue:** The canonical JSON serializer emitted Elixir `nil` as the string `"nil"`, so the report digest failed after publication when `selected_hex` was null.
- **Fix:** Normalized both `nil` and decoded JSON null to the JSON literal `null`, and added a null round-trip digest assertion.
- **Files modified:** `scripts/maintainer/phase_133_registry_compat.exs`, `test/install_smoke/phase_133_registry_compat_test.exs`
- **Verification:** OTP 27 compatibility tests and `verify --report` passed.
- **Committed in:** `a8f4ce25`

**2. [Rule 2 - Missing critical] Added an executable halt-receipt contract to Plan 132**

- **Found during:** Task 3
- **Issue:** Plan 132 requested a halt summary and verifier call but did not define machine-readable fields for checking the exact blocker, zero counts, pending requirements, and preserved evidence.
- **Fix:** Added exact receipt keys to Plan 132's task instructions and required them in `verify-readiness`; false compatibility rejects preflight and all later request/supply artifacts.
- **Files modified:** `.planning/phases/133-evidence-charter-and-live-truth/133-132-PLAN.md`, `scripts/maintainer/phase_133_registry_supply.mjs`, `test/install_smoke/phase_133_registry_supply_test.mjs`
- **Verification:** Plan 132 readiness tests passed; `automation_first_contract.sh` passed.
- **Committed in:** `6d744be9`

**Total deviations:** 2 auto-fixed (1 bug, 1 missing critical acceptance contract). **Impact:** Both changes make the planned report verifiable and keep the false-compatibility route fail-closed; no request or qualification scope was added.

## Issues Encountered

- No provenance-identified Hex source or build compatible with the pinned Elixir 1.17.3 / OTP 27 runtime exists in the inspected local inputs. This is the designed zero-credit halt; it does not block completion of Plan 131's missing-input route.
- Git worktree metadata writes require the elevated workspace path because `.git` is outside the writable worktree root. Commits ran normally with hooks enabled; no hook bypass was used.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 132 must consume the verified compatibility report and stop before writing its preflight if `compatible` is false. The next work to enable a true route is a separate authority boundary: obtain an audited Hex source archive or commit and build it for Elixir 1.17.3 / OTP 27, then prove the actual cache API and signed offline fixture path. No Plan 132 request, authorization, or qualification is permitted from Plan 130 or Plan 126 evidence.

## Self-Check: PASSED

PASSED — all eight task-output files are present, the seven Plan 131 task commits are reachable from the plan base, and the Plan 130 and Plan 131 report digests match their committed artifacts. Plan-level verification and the automation-first contract passed.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-10-08*
