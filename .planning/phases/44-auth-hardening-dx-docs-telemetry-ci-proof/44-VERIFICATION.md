---
phase: 44-auth-hardening-dx-docs-telemetry-ci-proof
verified: 2026-05-24T15:30:00Z
status: gaps_found
score: 4/5 success criteria verified
requirements_verified: [TUS-10, TUS-11, TUS-12, TUS-13, POLISH-02]
requirements_blocked: [TUS-14]
verification_method: inline (local phase-surface tests + generated-app tus package-consumer proof attempt)
follow_ups:
  - "Fix generated-app tus package-consumer proof so `bash scripts/install_smoke.sh tus` completes end-to-end without `ECONNRESET`."
  - "Re-run `bash scripts/install_smoke.sh tus` after the generated-app socket-reset issue is closed, then re-audit v1.8."
---

# Phase 44: Auth Hardening, DX, Docs, Telemetry, CI Proof — Verification Report

**Phase Goal:** tus is adopter-ready and trustworthy — optional same-user resume authorization, fix-oriented errors, edge telemetry, doctor diagnostics, a copy-pasteable guide, and a generated-app package-consumer proof that a browser tus client survives a network drop against real storage.
**Verified:** 2026-05-24
**Status:** gaps_found

## Objective Evidence

- `mix test test/rindle/upload/tus_plug_test.exs test/rindle/error_test.exs test/rindle/ops/runtime_checks_test.exs test/install_smoke/generated_app_smoke_test.exs test/rindle/streaming/provider/mux/mux_test.exs test/rindle/workers/ingest_provider_webhook_test.exs test/rindle/streaming/create_direct_upload_test.exs test/rindle/delivery/streaming_dispatch_test.exs test/rindle/profile/presets/mux_direct_upload_web_test.exs test/rindle/live_view_direct_upload_test.exs test/rindle/streaming/direct_upload_flow_test.exs` → **141 tests, 0 failures (10 excluded)**.
- `bash scripts/install_smoke.sh tus` is now executable in this repo after closing two harness defects:
  - `scripts/install_smoke.sh` now accepts the `tus` profile.
  - Generated-app router wiring now uses `Application.compile_env!/2` instead of `Endpoint.config/1` at router compile time.
- The generated-app proof still fails end-to-end: the real tus package-consumer lane reaches the generated app and Node proof harness, but the upload attempt exits with `ECONNRESET` / `socket hang up` during `POST /uploads/tus`, so the Phase 44 package-consumer proof is not yet satisfied.

## Goal Achievement — ROADMAP Success Criteria

| # | Success Criterion | Status | Evidence |
|---|-------------------|--------|----------|
| 1 | Optional same-user resume authorizer re-validates request identity; tampered-URL contract tests never return `200`. | ✓ VERIFIED | `tus_plug_test.exs` covers `:ok` vs `:reject` resume authorization and signature-failure paths. `44-01-SUMMARY.md` records the locked auth contract and completed `TUS-10`. |
| 2 | tus errors surface through `Rindle.Error` with the locked reason atoms and fix-oriented copy. | ✓ VERIFIED | `error_test.exs` and `44-01/02-SUMMARY.md` cover `:tus_session_not_found`, `:tus_session_expired`, `:tus_offset_conflict`, `:tus_size_exceeded`, `:tus_url_signature_invalid`, and `{:upload_unsupported, :tus_upload}`. |
| 3 | Telemetry extends the existing resumable namespace and doctor reports tus capability drift. | ✓ VERIFIED | `telemetry_contract_test.exs`, `runtime_checks_test.exs`, and `44-02-SUMMARY.md` verify `protocol: :tus`, forbidden metadata filtering, and the stable `doctor.tus_capability` surface. |
| 4 | `guides/resumable_uploads.md` documents parser/CORS/security/no-silent-downgrade posture and client guidance accurately. | ✓ VERIFIED | `generated_app_smoke_test.exs` parity assertions and `44-03-SUMMARY.md` verify the guide text for parser pass-through, exposed headers, bearer-credential language, `@uppy/tus` vs `tus-js-client`, and sticky-session guidance. |
| 5 | Generated-app package-consumer CI proof uploads a large MP4 with one simulated drop against MinIO and asserts a ready asset. | ✗ GAP | `bash scripts/install_smoke.sh tus` now runs the real generated-app lane, but the proof still fails with `DetailedError: tus: failed to create upload ... socket hang up` on `POST /uploads/tus`. This leaves `TUS-14` unsatisfied. |

**Score:** 4/5 success criteria verified. `TUS-10`, `TUS-11`, `TUS-12`, `TUS-13`, and `POLISH-02` are satisfied; `TUS-14` remains blocked by the generated-app tus proof failure.

## Gap Summary

### Unsatisfied Requirement

- **TUS-14** — The guide is present and parity-checked, but the required generated-app tus package-consumer proof is not yet passing. The current failure is an `ECONNRESET` / `socket hang up` during the live Node `tus-js-client` upload against the generated app's mounted `TusPlug`.

### Resolved During Verification

- The install-smoke entrypoint drift was real and has been fixed: `scripts/install_smoke.sh` previously rejected the `tus` profile even though CI invoked it.
- The generated-app router wiring drift was also real and has been fixed: `secret_key_base` now comes from compile-time app config instead of `Endpoint.config/1` inside the router macro.
- The Node proof harness now uses file-backed tus URL storage instead of the default Node no-op storage, so resume discovery is no longer impossible by construction.

## Verdict

Phase 44 is implementation-complete on auth/error/telemetry/doctor/docs, but it is **not verified complete** because the real generated-app tus package-consumer proof still fails. Re-run this phase verification after the `install_smoke` tus flow is stable.
