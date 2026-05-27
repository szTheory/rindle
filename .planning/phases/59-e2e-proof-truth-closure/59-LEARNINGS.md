# Phase 59 Learnings — E2E Proof & Truth Closure

## Decisions

- **Parity triple-lock:** `guides/resumable_uploads.md`, `phoenix_tus_truth_parity_test.exs`, and generated-app install-smoke must use identical extension tokens (`checksum`, `creation-defer-length`, `concatenation`, `parallelUploads`, `uploadLengthDeferred`).
- Record machine-readable proof in `tmp/install_smoke_tus_last_run.json` for milestone audit consumption.

## Patterns (graduation candidate — promote to METHODOLOGY)

| Layer | Role |
|-------|------|
| Guide | Adopter-facing contract |
| Parity test | Fast CI drift gate |
| Install smoke | Package-consumer end-to-end proof |

All three must change together when tus vocabulary shifts.

## For v1.12+

- Planning ledger (JTBD, MILESTONES) must regenerate when a protocol milestone ships — otherwise agents re-open completed wedges.
