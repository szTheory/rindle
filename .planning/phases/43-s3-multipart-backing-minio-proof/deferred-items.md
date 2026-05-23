# Phase 43 — Deferred / Out-of-Scope Items

Items discovered during execution that are NOT caused by the current plan's changes
and are therefore out of scope per the executor SCOPE BOUNDARY rule.

## Flaky AV/ffmpeg processor tests under full-suite parallel load

- **Discovered during:** Plan 43-05 execution (full `mix test` final verification).
- **Symptom:** Non-deterministic failures (1–4 per run, different tests each run) in
  `Rindle.Processor.FfmpegTest` and `Rindle.Processor.AVTest` (e.g. "processes
  video_transcode capability", "two-pass loudnorm explicit higher-fidelity branch",
  "falls back to the first I-frame when no scene-change frame qualifies").
- **Evidence it is pre-existing & unrelated:** Plan 43-05's only changes are two
  test files (`test/rindle/storage/s3_test.exs`, `test/rindle/upload/tus_s3_integration_test.exs`),
  both adding ONLY `@tag :minio` tests that are excluded from the default suite and
  cannot execute. Running the processor tests in isolation
  (`mix test test/rindle/processor/`) passes 0 failures; failures only appear under
  full-suite parallel load — a resource-contention / concurrency flake in the AV
  pipeline, not a logic regression.
- **Disposition:** Deferred. Not fixed (out of scope for the S3-multipart phase).
  Owner: AV processor maintenance. Candidate fix: serialize the ffmpeg-bound
  processor tests (e.g. `async: false` or a shared ffmpeg semaphore) so they do not
  contend under `max_cases`.
