---
phase: 122-live-truth-compile-clarity
plan: "05"
subsystem: maintainer-and-adopter documentation
tags: [ci, support-policy, tus, storage, streaming, parity]
dependency_graph:
  requires: [122-01, 122-02, 122-03, 122-04]
  provides: [truthful-ci-support-docs, truthful-resumability-docs, mux-doc-parity]
  affects: [README.md, CONTRIBUTING.md, RUNNING.md, guides]
tech_stack:
  added: []
  patterns: [source-derived-doc-parity, adapter-capability-boundaries]
key_files:
  created: []
  modified:
    - README.md
    - CONTRIBUTING.md
    - guides/storage_capabilities.md
    - guides/profiles.md
    - guides/resumable_uploads.md
    - guides/streaming_providers.md
    - test/install_smoke/docs_parity_test.exs
    - test/install_smoke/phoenix_tus_truth_parity_test.exs
    - test/install_smoke/streaming_cancel_docs_parity_test.exs
decisions:
  - "Repository CI cells, including Elixir 1.17/OTP 27, remain the supported-toolchain authority; local Elixir 1.19/OTP 28 output is diagnostic only."
  - "Local/S3 server-mediated tus and GCS provider-direct resumable sessions are distinct capabilities with no silent fallback."
  - "Mux remains the one shipped optional streaming provider."
metrics:
  tasks_completed: 3
  files_modified: 9
  completed_date: 2026-08-22
status: complete
---

# Phase 122 Plan 05: Current CI, Upload, and Streaming Truth Summary

Root and guide documentation now describes the actual CI gate, adapter-specific resumability boundary, and single optional Mux provider, each protected by focused parity tests.

## Completed Tasks

1. Locked root documentation to the shipped `CI Summary` policy, current lane split, and CI-supported Elixir 1.17/OTP 27 posture.
2. Corrected the capability matrix so Local/S3 server-mediated tus (`:tus_upload`) is distinct from GCS provider-direct resumable sessions, with unsupported paths failing rather than falling back.
3. Made the single-provider Mux posture explicit and locked playback, webhook, polling, and cancellation references against source seams.

## Verification

- PASS — `MIX_ENV=test mix test test/install_smoke/docs_parity_test.exs test/install_smoke/ci_lane_split_test.exs test/install_smoke/quality_signal_policy_test.exs test/install_smoke/release_guard_meta_test.exs` (69 tests)
- PASS — `MIX_ENV=test mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/storage/storage_adapter_test.exs test/rindle/upload/tus_plug_test.exs test/rindle/storage/gcs_test.exs` (60 tests, 1 expected excluded)
- PASS — focused current-doc parity plus Admin contract test (37 tests) and `bash scripts/maintainer/refactor_contract.sh` (86 contract tests)
- PASS — `mix format --check-formatted` after the Phase 122-04 owner formatted its test.
- PASS — archive-diff scope: this plan changed no archives, workflow, runtime, dependency, or lockfile paths.
- DIAGNOSTIC — local `mix ci` under Elixir 1.19/OTP 28 stopped in the Credo quality script because compilation banners entered its JSON comparison. This is local-toolchain variance, not a support-policy change; supported CI (including Elixir 1.17/OTP 27) remains authoritative.
- PENDING EXTERNAL STATE — `repo_hygiene_check.sh` found the local `main` checkout one commit behind `origin/main` and main CI in progress; it reported 9 PASS, 1 WARN, 1 BLOCK. No project file was changed to mask either release-train condition.

## Deviations from Plan

### Auto-fixed Issues

1. [Rule 3 - Blocking verification] Formatted the modified docs-parity test after `mix ci` identified it. The independently owned Admin parity formatting fix was applied by the Phase 122-04 owner.

## Known Stubs

None.

## Self-Check: PASSED

The three task commits and every listed documentation/parity file exist. No new runtime, workflow, dependency, API, telemetry, error-shape, schema, or archive surface was introduced.
