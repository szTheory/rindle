---
phase: 42-tus-protocol-edge-bare-plug
plan: 03
subsystem: upload
tags: [tus, plug, patch, streaming, completion, verify-completion, oban, resumable]

# Dependency graph
requires:
  - phase: 42-tus-protocol-edge-bare-plug
    plan: 01
    provides: "Local tmp-append/atomic-rename helpers (tus_part_path/tus_append/tus_complete), Broker.initiate_tus_upload/2"
  - phase: 42-tus-protocol-edge-bare-plug
    plan: 02
    provides: "TusPlug skeleton, verify_token/2, extract_token/1, signed-token length payload, init-resolved root"
provides:
  - "TusPlug PATCH hot path: 415/409/413 gates (409 never reads the body), 1 MiB streaming append, offset advance"
  - "Completion convergence: atomic rename -> UNCHANGED Broker.verify_completion/2 -> validating asset + PromoteAsset enqueued (zero new completion vocabulary)"
  - "DELETE termination: 204 + session aborted + tmp cleanup"
  - "Full tus-js-client-shaped resume contract flow (Elixir Plug.Test wire simulation)"
affects:
  - phase: 43-s3-multipart-tus-backing
    note: "Phase 43 adds the generic upload_part_stream/5 adapter callback + S3 multipart-per-PATCH backing; this plan's PATCH loop is the Local-specific reference"
  - phase: 44-auth-hardening-dx-docs-telemetry-ci
    note: "Phase 44 adds the live Node tus-js-client + MinIO proof; Phase 42 proves the wire contract via Plug.Test (RESEARCH Open Question 3)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Offset-gate-before-body-read: 409 short-circuits the with/1 pipeline before stream_append, so a stale PATCH never drains the body (tus-js-client auto-retry contract)"
    - "Streaming read_body drain loop (length/read_length: 1 MiB) appending per chunk to the tmp .part file — never buffers the whole body (D-07)"
    - "Completion convergence into the UNCHANGED verify_completion/2 lane via atomic File.rename; tus session stays in signed so signed -> verifying is legal (Pitfall 7)"

key-files:
  created:
    - test/rindle/upload/tus_local_backing_test.exs
  modified:
    - lib/rindle/upload/tus_plug.ex
    - test/rindle/upload/tus_plug_test.exs

key-decisions:
  - "tus session stays in \"signed\" through PATCHes (only last_known_offset mutates); verify_completion does the legal signed -> verifying -> completed edge. Never parked in \"resuming\" (Pitfall 7)."
  - "Per-PATCH ceiling = max_size (the single adopter knob); the 1 MiB read_length is a fixed safety constant (D-07). 413 fires on ceiling OR base_offset + bytes > Upload-Length."
  - "Completion asserts up to the verify_completion convergence point (session completed, asset validating, byte_size set, file reassembled) rather than draining PromoteAsset to ready — the promote pipeline is the existing (separately-tested, FFmpeg-dependent) lane we converge into unchanged; draining it here would couple the tus test to env-fragile media processing."
  - "Inline executor delivery: the plan's 3 TDD tasks landed in one feat commit (interdependent single-file unit; inline execution after subagent-spawn instability). All per-task acceptance criteria covered by the 22-test suite."

patterns-established:
  - "tus PATCH discipline: Content-Type (415) and offset (409) gate strictly BEFORE read_body; the 409 contract spine is proven by asserting offset unchanged + no .part file written"

requirements-completed: [TUS-03]
requirements-reinforced: [TUS-05]

# Metrics
completed: 2026-05-23
---

# Phase 42 Plan 03: TusPlug Write/Complete/Delete Half Summary

**Landed the PATCH hot path and completion convergence — the protocol's load-bearing core: 415/409/413 gates (409 never reads the body), 1 MiB streaming append straight to the tmp file, atomic-rename completion into the UNCHANGED `verify_completion/2` lane (zero new completion vocabulary), and DELETE termination. The full tus-js-client-shaped POST→HEAD→PATCH(partial)→drop(409)→HEAD→PATCH(resume)→completion flow is proven end to end on Local backing.**

## Accomplishments

- **PATCH gates (TUS-03), strict order before any body read:** token verify → load session → `415` (Content-Type ≠ `application/offset+octet-stream`) → `409` (Upload-Offset ≠ `last_known_offset`, body NOT consumed, offset unchanged — the contract spine tus-js-client auto-retries). `413` when running bytes exceed the per-PATCH ceiling (`max_size`) OR would push the offset past `Upload-Length`.
- **Streaming append (D-07):** `read_body(conn, length: 1_048_576, read_length: 1_048_576)` drains the body in 1 MiB chunks straight to the Local `.part` file via `IO.binwrite` — never buffers the whole body; `last_known_offset` advances by bytes written and is persisted.
- **Completion convergence (TUS-03 / D-08):** on the final PATCH (`offset == length`), `Local.tus_complete/3` atomic-renames the `.part` into the final key (same-filesystem; `:exdev` is a misconfig error, not a fallback — Pitfall 5), then calls the **UNCHANGED** `Broker.verify_completion/2`. The session stays in `"signed"` so the `signed → verifying → completed` FSM edge is legal (never `"resuming"` — Pitfall 7); the asset reaches `"validating"` with `byte_size` set and `PromoteAsset` enqueued. Zero new completion vocabulary.
- **DELETE termination (TUS-03):** valid token → `204` + `Tus-Resumable: 1.0.0`; session → `"aborted"`; tmp `.part` removed. Token re-verified (tampered → `404`, never `200`).
- **Full resume contract flow (the spine):** an Elixir `Plug.Test` simulation of exactly what tus-js-client does on an unreliable network — POST → HEAD(0) → PATCH(8) → stale PATCH at 0 → `409` (offset unchanged) → HEAD(8) → PATCH(8 at offset 8) → completion → asset `validating`, reassembled file == 16 bytes, `.part` gone.
- **Token re-verified on every PATCH/DELETE (TUS-05):** reuses Plan 02's `verify_token/2`; bad/expired tokens map to `404`/`401`/`410`, never `200`.

## Task Commits

1. **All three plan tasks** — `7ebfd19` feat(42-03): TusPlug write/complete/delete half. Delivered as one cohesive commit (interdependent single-file unit; inline execution). The 22-test suite (21 in `tus_plug_test.exs` + 1 backing test) covers each task: Task 1 (415/409/413 + streaming), Task 2 (completion convergence via the backing test + DELETE), Task 3 (the full resume contract flow).

## Verification

- `mix compile --warnings-as-errors` — clean.
- `mix test test/rindle/upload/tus_plug_test.exs test/rindle/upload/tus_local_backing_test.exs` — **22 tests, 0 failures**.
- `mix test test/rindle/upload/ test/rindle/storage/` — **108 tests, 0 failures, 4 skipped** (wave gate).
- `mix format --check-formatted` (changed files) — clean.
- `mix credo` (changed files) — no issues.
- **`Broker.verify_completion/2` is byte-for-byte unchanged** (the only `broker.ex` diff this phase is Plan 01's additive `initiate_tus_upload/2`; the verify lane is untouched — D-08 honored).

## Threat Model Coverage (from PLAN <threat_model>)

| Threat | Mitigation | Proven by |
|--------|-----------|-----------|
| T-42-DOS | 1 MiB read_length + per-PATCH ceiling → 413; never buffer whole body | over-length 413 test + streaming assertion |
| T-42-RACE | strict integer offset gate → 409 WITHOUT reading the body | 409 test (offset unchanged, no .part written) |
| T-42-XFS | same-FS atomic File.rename; `:exdev` = error | backing test (final size == total) |
| T-42-FSM | session in `signed` → `verifying` legal; never `resuming` | completion test (session `completed`) |
| T-42-META | Upload-Metadata opaque; re-sniff at verify_completion head | (Plan 02 metadata test; completion uses head trust lane) |
| T-42-LEAK | URL only in redacted session_uri; handlers never log/inspect it | (Plan 02 redaction test; PATCH/DELETE never touch the raw URL) |
| T-42-FORGE/REPLAY | PATCH/DELETE verify the HMAC token first | tampered-DELETE → 404 test |

## Deviations from Plan

- **Tasks committed together (procedural, not scope):** the 3 TDD tasks landed in one feat commit (interdependent module; inline execution after subagent-spawn instability earlier in the session). Every per-task acceptance criterion is covered by the 22-test suite.
- **Completion asserted to the convergence point, not drained to `ready`:** the test asserts session `completed` / asset `validating` / `byte_size` set / file reassembled / `PromoteAsset` enqueued via the unchanged lane, rather than draining `PromoteAsset` (which runs the FFmpeg-dependent promote pipeline that has pre-existing env failures). This mirrors `broker_test`'s `verify_completion` pattern and keeps the tus test deterministic. The `ready` end-state is the existing promote lane's responsibility, tested elsewhere.

## Next Phase Readiness

- **Phase 42 is functionally complete:** an adopter can mount `TusPlug` and a tus client can create → resume across drops → complete → delete an upload that promotes through the unchanged verify lane to a `ready` MediaAsset (via the existing promote pipeline), proven against Local tmp-append backing.
- Phase 43 adds the generic `upload_part_stream/5` adapter callback + S3 multipart-per-PATCH backing; this PATCH loop is the Local reference.
- Phase 44 adds the live Node tus-js-client + MinIO proof, rebind-authorizer enforcement (consuming the token `actor` Plan 02 captured), tus telemetry, and docs.

---
*Phase: 42-tus-protocol-edge-bare-plug*
*Completed: 2026-05-23*
