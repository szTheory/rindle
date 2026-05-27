# Phase 57 Validation Plan

## Goal Verification
The goal of this phase is to implement the tus `checksum` and `creation-defer-length` extensions in `Rindle.Upload.TusPlug`. This validation plan ensures these extensions work as intended and conform to the Tus protocol.

## Nyquist Coverage Gap Analysis
The tests detailed below will cover the core implementation of the checksum algorithms (SHA1, SHA256), the error cases for mismatched checksums, and the lifecycle of deferred length uploads. This ensures no validation gap in the system.

## Required Tests (Automated)

### 1. Checksum Tests
- **OPTIONS:** Ensure `checksum` is present in `Tus-Extension` and `Tus-Checksum-Algorithm: sha1,sha256` is returned.
- **PATCH Success:** Test that a valid chunk with a correct SHA-256 and SHA-1 checksum succeeds.
- **PATCH Failure:** Test that an invalid checksum results in a `460 Checksum Mismatch` and that the temporary chunk file is cleaned up.

### 2. Defer-Length Tests
- **OPTIONS:** Ensure `creation-defer-length` is present in `Tus-Extension`.
- **POST:** Test that a POST with `Upload-Defer-Length: 1` successfully creates an upload without an initial `Upload-Length`.
- **PATCH Success:** Test that the first PATCH to a deferred-length upload correctly accepts the `Upload-Length` header, persists it in the database (`upload_length`), and proceeds with the upload.
- **PATCH Failure:** Test that a PATCH to a deferred-length upload *without* the `Upload-Length` header fails with a `400 Bad Request`.

## Manual Verification (if needed)
- Start the server using `mix phx.server`.
- Perform a manual tus upload using curl or tus-js-client with the checksum and deferred-length headers to verify end-to-end integration.

## Output
Produce `test/rindle/upload/tus_plug_test.exs` tests asserting the above criteria. Execution of `mix test test/rindle/upload/tus_plug_test.exs` must pass.