---
phase: 124-upload-path-clarity
plan: "05"
subsystem: upload
tags: [elixir, ecto, oban, broker, tus, quality]
requires:
  - phase: 124-upload-path-clarity
    provides: hidden Tus and Broker collaborators through Plan 04
provides:
  - Hidden Broker.Completion transaction owner with facade-owned completion effects
  - Doctor-complete hidden collaborator specifications and reconciled Credo inventory
affects: [upload-broker, tus, safe-01]
tech-stack:
  added: []
  patterns: [facade preconditions and post-commit effects, hidden transaction mechanics]
key-files:
  created: [lib/rindle/upload/broker/completion.ex]
  modified: [lib/rindle/upload/broker.ex, test/rindle/api_surface_boundary_test.exs]
decisions:
  - "Broker.Completion owns only the unchanged ordered Ecto.Multi; Broker owns all preconditions, error translation, telemetry, broadcasts, and public result shaping."
  - "The quality inventory records one unchanged TusProtocol nesting relocation and removes only two resolved TusPlug identities."
metrics:
  tasks: 2
  files: 10
status: complete
---

# Phase 124 Plan 05: Upload Path Clarity Summary

**Broker completion now has one hidden, exact transaction owner while the public Broker facade preserves all observable lifecycle ordering and post-commit effects.**

## Accomplishments

- Extracted the exact five-step completion `Ecto.Multi` into hidden `Broker.Completion.transact/4` without changing keys, FSM transitions, metadata, promotion job insertion, transaction errors, or result maps.
- Kept storage head/FSM preconditions, missing-object translation, raw/resumable stop telemetry, broadcasts, and public shaping in `Broker` after a successful commit.
- Added compiled-doc boundary proof for the hidden collaborator and restored quality gates exposed by the full phase refactor.

## Task Commits

1. `fea8667` — RED compiled-boundary contract for `Broker.Completion.transact/4`.
2. `a093004` — Extract exact Broker completion transaction.
3. `1c82e5f` — Formatting-only integration repair for prior Broker files.
4. `026679c` — Credo inventory reconciliation and hidden collaborator specs required by Doctor.

## Verification

- Focused Tus/Broker/Local/lifecycle/API/telemetry aggregate — 101 tests, 0 failures (3 expected skips).
- `MIX_ENV=test mix compile --force --warnings-as-errors` — passed.
- `bash scripts/maintainer/refactor_contract.sh` — 92 contract tests, 0 failures; no compile cycles.
- `mix credo_quality` and `test/install_smoke/credo_policy_test.exs` — passed; live inventory is 31 identities / 35 occurrences.
- `MIX_ENV=dev mix doctor --full --raise` — 100% documentation and spec coverage.
- `mix ci`, formatter check, exact scope audit, forbidden-surface audit, and repository hygiene — passed.
- Local MinIO was available; the MinIO-tagged S3 command was invoked. Environment-provisioned integration authority passed in PR CI.
- Exact implementation head `026679cafa79e8df456f9317009497d805cc4404`: PR #86 CI run [32617283259](https://github.com/szTheory/rindle/actions/runs/32617283259) passed, including Package Consumer job `97140413604` and CI Summary job `97141428979` on supported Elixir 1.17 / OTP 27.

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 1 - Integration] Restored formatting required by CI**
   - Formatted only `broker.ex` and `broker/persistence.ex`; inspection confirmed formatting-only changes.

2. **[Rule 1 - Quality] Reconciled the Credo inventory with extracted Tus ownership**
   - Relocated the unchanged nesting identity to `TusProtocol`; removed only the two identities absent from the live inventory after extraction.

3. **[Rule 2 - Quality] Added private specs to hidden collaborators**
   - Added accurate existing-seam specs to Completion, Persistence, SessionSeed, SessionValidation, and TusProtocol so the Doctor threshold remains satisfied.

## Known Stubs

None.

## Self-Check: PASSED

- `lib/rindle/upload/broker/completion.ex` exists.
- Task and integration commits `fea8667`, `a093004`, `1c82e5f`, and `026679c` exist.
