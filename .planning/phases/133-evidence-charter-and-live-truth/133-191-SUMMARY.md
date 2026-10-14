---
phase: 133-evidence-charter-and-live-truth
plan: "191"
subsystem: evidence
tags: [fixture, capture, sha256, private-stderr, plan-192]
requires:
  - phase: 133-189
    provides: Completed historical guard prerequisite; no authority transfers to this fixture repair.
provides:
  - Complete original request/result capture verified through a real disposable V8 bridge.
  - Plan 192-only collector with private stderr retention and exclusive first reservation.
affects: [133-192, evidence-capture, producer-diagnostics]
actuals:
  tokens: "not measured"
  tasks: 2
tech-stack:
  added: []
  patterns: [nonce-bound private readback, serialization-safe JSON, exclusive diagnostic reservation]
key-files:
  created:
    - scripts/maintainer/phase_133_tool_capture_191.mjs
    - scripts/maintainer/phase_133_tool_capture_191.test.mjs
    - scripts/maintainer/phase_133_registry_collection_191.mjs
    - scripts/maintainer/phase_133_registry_collection_191.test.mjs
    - .planning/phases/133-evidence-charter-and-live-truth/133-191-CAPTURE-FIXTURE.json
requirements-completed: []
coverage:
  - id: capture_transport
    description: Exact request sealed and reread before the call; untouched complete result immediately stored, hex-transferred, and independently compared.
    verification:
      - kind: other
        ref: node scripts/maintainer/phase_133_tool_capture_191.mjs verify-fixture --proof .planning/phases/133-evidence-charter-and-live-truth/133-191-CAPTURE-FIXTURE.json
        status: pass
      - kind: unit
        ref: scripts/maintainer/phase_133_tool_capture_191.test.mjs
        status: pass
    human_judgment: false
  - id: private_diagnostics
    description: Private bounded stderr survives fixture clone cleanup; exclusive reservation precedes Git/callbacks; red/blocked/ready remain distinct with zero effects.
    verification:
      - kind: unit
        ref: scripts/maintainer/phase_133_registry_collection_191.test.mjs
        status: pass
    human_judgment: false
duration: "not measured"
completed: 2026-10-13
status: complete
---

# Phase 133 Plan 191: Evidence Capture Repair Summary

**Fixture-proven complete tool capture and private stderr retention for the Plan 192-only collector. No production collection or qualification occurred.**

## Accomplishments

- Added restricted 0700 scratch and 0600 segment/raw files, bounded ordered hex transfer, fsync, exact byte-count/SHA-256 readback, and nonce/mode/source-bound safe fixture proof.
- The parent ran a fresh real `functions.exec` fixture against the final committed helper. Its exact argument object was validated, stringified once, encoded with pure JavaScript UTF-8, sealed and independently reread before the nested call. The complete untouched returned object was stored immediately after `await`, before projection or writer calls. No `Buffer`, `btoa`, filesystem or `TextEncoder` was used in V8.
- A separate Node readback compared `result.raw` byte-for-byte to the original stored serialization. It verified Unicode, quotes, newline and nested null data. Every actual response property was retained; absent `session_id` is unavailable. No tool metadata was reconstructed.
- The collector accepts only Plan 192, preserves inherited offline signed-supply/guard/source contracts and spent Plan 190 history, and retains bounded original stderr privately before clone cleanup. Durable receipts contain safe size/hash/classification only; Plan 190 producer cause remains unknown.
- All five requirements remain Pending; all eleven edge rows remain unresolved; qualification credit is zero.

## Real Fixture Anchors

- Nonce: `1829579fa119b836836be74b0c9fd07979d8b50d1414db36`; mode: `fixture`; status: `fixture_only`.
- Exact request: 344 bytes; SHA-256 `d9f6016b651958205764d7d78df92c790a96ba30bf9f469470b9e66d73d35283`.
- Complete original result: 232 bytes; SHA-256 `7a72f17df12e627695f0271f09a963f4063ba64acd64c48d8f729a4b7934da58`.
- Helper blob: `bb40508a7aa237db3d055128496a064219b2fb42`; helper SHA-256 `7e57a03fbfeaa7ad1806dd1f203f457a9d65260a38cbe330b18e886a0128448b`.
- Observed response keys: `chunk_id, wall_time_seconds, exit_code, original_token_count, output`; unavailable: `session_id`.
- Command identity hashes the exact captured allowlisted harmless Node command. Raw request/result remain private; this file grants no actual-host or producer authority.

## Task Commits

| Commit | Purpose |
|---|---|
| `241b0e06` | Task 1 failing capture tests (RED). |
| `5b9c3f53` | Task 1 helper and initial safe fixture. |
| `d9b6521f` | Task 2 private stderr regression (RED). |
| `324d042c` | Larger bounded capture coverage. |
| `989ec62a` | Task 2 collector and fixture regressions. |
| `67eb00ae` | Initial summary, superseded by independent review. |
| `07f067fd` | Corrective tamper regressions (12 tests, 3 failures). |
| `cd093531` | Corrective implementation and 14 passing tests. |
| `df755ba7` | Truthful pending-proof handoff. |
| `b3bc734d` | Bind live Unicode/null fixture command to exact request. |

Final proof and this reconciled summary are committed together after fresh verification.

## Deviations and Issues

Independent review rejected the initial passing self-check: the fixture verifier accepted invented response-key metadata, arrays could lose extra properties, and controlled fixture paths ran Git before reservation. A fresh corrective executor added RED evidence, rejected dropped/accessor/hook properties, bound strict compact UTF-8 request/result JSON to exact response metadata and both seals, and reserved output before subprocesses/callbacks. Fixture branches now enforce source/private-stderr links, preparation exclusivity and zero effects.

The corrective worker explicitly withdrew the initial live-bridge claim and left its old safe proof stale. The parent refreshed it with the actual documented V8 surface after all helper changes, then independently verified equality to the stored original result. This was disposable fixture work; no producer was replayed. Unmeasured token/time estimates were removed. Historical Plan 189/190 bytes were preserved.

## Verification

- Focused Node suite: 14 tests passed, 0 failed; no skipped tests.
- Syntax checks on both helpers and both test files passed.
- `verify-fixture` returned `verified_fixture_only`, zero credit, false actual-host authority and false producer authority.
- Independent readback: `original_stored_result_equal: true`; Unicode/quotes/newline/null payload verified.
- Automation-first contract passed; immutable historical receipts and inherited helper bytes unchanged.

## Production Effects

Zero production producer, actual-host guard, private production clone, Mix, registry HTTP, external network, remote mutation, authorization, qualification or credit. Disposable fixture repositories/clones and injected results only. No Plan 192 production receipts exist.

## Next Readiness

Plan 191 is complete. Plan 192 is the next ready gap plan in wave 39 and still requires its own fresh same-runtime transport preflight, distinct clean source, exact reviewed command and original-response authentication. This fixture proof is a prerequisite only. Phase 133 remains incomplete; no phase acceptance or re-verification is claimed. Shared tracking is owned by the orchestrator.

## Self-Check: PASSED

All declared files exist; RED precedes GREEN; fresh focused tests, syntax, the real fixture CLI and independent original-result readback passed. No shared STATE/ROADMAP/REQUIREMENTS writes were made by executors. All historical receipt bytes remain unchanged.
