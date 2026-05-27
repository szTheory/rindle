# Phase 58 Validation Plan

## Goal Verification
The goal of this phase is to implement the tus `concatenation` extension in `Rindle.Upload.TusPlug` and the underlying storage adapters (`Local`, `S3`, `GCS`). This validation plan ensures parallel chunked uploads can be successfully combined.

## Nyquist Coverage Gap Analysis
The tests detailed below will cover the core implementation of the concatenation extension, including the `is_partial` flag persistence, the `final` assembly process, and error handling for invalid or incomplete partials. This ensures no validation gap in the system.

## Required Tests (Automated)

### 1. Storage Concatenation Tests
- **Local:** Test that `Rindle.Storage.Local.concatenate/3` successfully combines multiple files and cleans up sources.
- **S3:** Test that `Rindle.Storage.S3.concatenate/3` successfully invokes `UploadPartCopy` and cleans up sources.
- **GCS:** Test that `Rindle.Storage.GCS.concatenate/3` successfully invokes the `compose` API and cleans up sources.

### 2. TusPlug Concatenation Tests
- **OPTIONS:** Ensure `concatenation` is present in `Tus-Extension`.
- **POST (Partial):** Test that `Upload-Concat: partial` creates an upload session with `is_partial: true` stored in `multipart_parts`.
- **POST (Final) Success:** Test that `Upload-Concat: final;URL1 URL2` successfully concatenates completed partials and returns `201 Created`.
- **POST (Final) Failure (Incomplete):** Test that providing an incomplete partial URL returns `400 Bad Request`.
- **POST (Final) Failure (Invalid URL):** Test that providing invalid or missing URLs returns `400 Bad Request`.

## Manual Verification (if needed)
- Start the server using `mix phx.server`.
- Perform a manual tus upload using curl or tus-js-client utilizing the `concatenation` extension to verify end-to-end integration across all configured storage providers.

## Output
Produce tests in `test/rindle/upload/tus_plug_test.exs` and `test/rindle/storage_test.exs` asserting the above criteria. Execution of `mix test` must pass.
