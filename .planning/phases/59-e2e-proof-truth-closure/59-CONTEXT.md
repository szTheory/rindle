# Phase 59 Context: E2E Proof & Truth Closure

This document records the locked decisions and constraints for Phase 59, following the discussion and assumptions analysis.

## Core Decisions

1. **Proof Harness Expansion:** The existing Node `tus-js-client@4.3.1` integration test within `test/install_smoke/support/generated_app_helper.ex` must be extended. It must explicitly exercise the three new tus extensions added in Phases 57 and 58:
   - **Concatenation:** Triggered via `parallelUploads: 2` (or higher).
   - **Creation-Defer-Length:** Triggered via `uploadLengthDeferred: true`.
   - **Checksum:** Asserting that `tus-js-client` correctly negotiates and transmits valid checksums.
2. **Guide Parity:** `guides/resumable_uploads.md` must be updated to explicitly state support for the full suite of tus 1.0.0 protocol extensions (Creation, Expiration, Termination, Checksum, Creation-Defer-Length, Concatenation). It must include adopter guidance for enabling them (e.g., using `parallelUploads` in Uppy).
3. **Smoke Asserts:** The existing parity assertions in `test/install_smoke/generated_app_smoke_test.exs` (and related docs tests) must be augmented to lock in these new documentation claims, preventing silent regressions of the protocol's capabilities in the docs.
4. **Milestone Closure:** Upon completion of these tasks, the overarching milestone will be audited and closed, finalizing the protocol completeness track.

## Constraints
- **Do not invent a new proof lane.** Piggyback on the existing MinIO-backed `install_smoke` sequence.
- **Maintain client pinning.** Keep `tus-js-client@4.3.1` pinned as the proof driver.
- **No breaking public API changes.** This phase is strictly about test coverage, doc parity, and E2E verification of work already completed in Phases 57 and 58.
