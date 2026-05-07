---
phase: 37-gcs-adapter-foundation
plan: 02
subsystem: storage
tags: [gcs, signed-url, v4-signing, gcs_signed_url, q5-locked]

requires:
  - phase: 37-01
    provides: "Optional :gcs_signed_url ~> 0.4.6 dep already declared in mix.exs (Plan 01); GcsSignedUrl.Client + GcsSignedUrl.generate_v4 in deps tree"
provides:
  - "Rindle.Storage.GCS.Signer.url/3 — V4 signed URL wrapper around gcs_signed_url Client mode (private-key auth)"
  - "Bare-String -> {:ok, _} envelope (RESEARCH Q3 wrap; Client mode does not return {:ok, _})"
  - "RESEARCH Q5 LOCKED dispatch: JSON map preferred + bare PEM accepted with :client_email configured + file-path/anything-else raises ArgumentError"
  - "D-04 TTL precedence: opts -> Rindle.Config.signed_url_ttl_seconds/0 (mirrors S3 lib/rindle/storage/s3.ex:55-61)"
  - "D-03 compliance: NO response-content-disposition / response-content-type query params (Content-Type / Content-Disposition live in GCS object metadata at Plan 01 store/4)"
  - "Throwaway service-account fixture (test/support/gcs_signing_key_fixture.ex) with PKCS#1 PEM regenerated per ExUnit run"
affects: [37-03-adapter, 37-04-doctor, 38-resumable-fsm, 39-resumable-callbacks, 41-onboarding-doctor]

tech-stack:
  added: []
  patterns:
    - "V4 signed URL local-only generation (no network in Client mode); pure-local unit tests assert canonical query param contents"
    - "Bare-PEM dispatch with :client_email separately configured — convenience for adopters with PEM + email split across env vars"
    - "ArgumentError early-rejection for file-path inputs — clearer than gcs_signed_url's deep KeyError otherwise"

key-files:
  created:
    - "lib/rindle/storage/gcs/signer.ex (~95 LOC, @moduledoc false)"
    - "test/rindle/storage/gcs/signer_test.exs (9 unit tests)"
    - "test/support/gcs_signing_key_fixture.ex (~85 LOC, throwaway PKCS#1 PEM + service-account JSON map)"
  modified: []

key-decisions:
  - "Q5 LOCKED dispatch contract: accept decoded JSON map (preferred) AND bare PEM string only; file-path loading is explicitly out of scope"
  - "Bare-PEM dispatch path requires :client_email separately configured via Application.get_env(:rindle, Rindle.Storage.GCS, [])[:client_email]; missing :client_email raises ArgumentError"
  - "PKCS#1 PEM (`pem_entry_encode(:RSAPrivateKey, ...)`) is the fixture default; PKCS#8 manual ASN.1 wrap kept as commented [FALLBACK] only"
  - "Comment in signer.ex avoids the literal string 'response-content-' so the D-03 grep verification stays clean (verification step #7); the contract intent is preserved in different wording"

patterns-established:
  - "build_client/1 three-clause pattern match: JSON map clause -> bare-binary clause (PEM-vs-other dispatch via String.starts_with?) -> catchall clause; raises ArgumentError on unsupported shapes"
  - "configured_client_email/0 helper extracts :client_email from Rindle.Storage.GCS app env — Plan 03 adapter inherits the same Application.get_env/3 keying convention"
  - "ttl/1 mirrors S3's exact precedence shape (opts :expires_in -> Rindle.Config.signed_url_ttl_seconds/0 fallback) so cross-adapter parity stays trivial"

requirements-completed: [GCS-03]

duration: 6min
completed: 2026-05-07
---

# Phase 37 Plan 02: GCS Signer (V4 Signed URLs) Summary

**`Rindle.Storage.GCS.Signer.url/3` ships V4 signed URL generation via `gcs_signed_url ~> 0.4.6` in Client (private-key) mode, returning `{:ok, signed_url}` with the bare-String wrap RESEARCH Q3 demanded; the Q5 LOCKED dispatch (JSON map preferred, bare PEM accepted with `:client_email` config, file path raises `ArgumentError`) honors the literal CONTEXT D-08 contract; D-04 TTL precedence mirrors S3 line-for-line; D-03 compliance is enforced by both code (no `query_params` on `generate_v4`) and the test contract (a refute on the `response-content-*` substrings).**

## Performance

- **Duration:** ~6 minutes
- **Started:** 2026-05-07T17:50:23Z
- **Completed:** 2026-05-07
- **Tasks:** 3 / 3 complete
- **Files modified:** 0
- **Files created:** 3 (signer.ex, signer_test.exs, gcs_signing_key_fixture.ex)

## Accomplishments

- Landed `Rindle.Storage.GCS.Signer` as a `@moduledoc false` internal V4-signing wrapper per CONTEXT D-01 (third file in the 3-file split). The behaviour-implementing public `Rindle.Storage.GCS` module ships in Plan 03 (Wave 3); Plan 02 + Plan 01 (Client) share NO files and ran in Wave 2 independent of Plan 01's Wave 1.
- All 9 locked tests in `signer_test.exs` GREEN — V4 canonical query params (`X-Goog-Algorithm=GOOG4-RSA-SHA256`, `X-Goog-Signature=`, `X-Goog-Expires=`); D-03 refute on `response-content-*`; D-04 TTL fallback (default 900, explicit opt overrides, configured TTL); RESEARCH Q5 LOCKED dispatch (map preferred, bare PEM with `:client_email`, file path raises, missing `:client_email` raises).
- The bare-String -> `{:ok, _}` wrap is the entire point of this module (RESEARCH Q3 — `GcsSignedUrl.generate_v4/4` Client mode returns `String.t()`, NOT `{:ok, _}`). The wrapper supplies the `{:ok, _}` envelope expected by the public `Rindle.Storage.url/2` callback.
- Throwaway PKCS#1 PEM fixture regenerated per ExUnit run via `:public_key.generate_key/1`; never persists, never sourced from a real GCP account, no real signing-key material checked in. PKCS#8 ASN.1 wrap kept as a commented `[FALLBACK]` only — the locked plan called this out as a Warning 9 reordering rationale.
- Bare-PEM dispatch path requires `:client_email` separately configured. This is intentional — JSON map remains the preferred shape; bare PEM is a convenience for adopters with PEM + email split across separate env vars (e.g., Kubernetes secret with two keys). Missing `:client_email` raises a clear `ArgumentError` with the fix instructions.
- File-path inputs raise `ArgumentError` early per Q5 LOCKED. Without the explicit raise, `gcs_signed_url`'s `Client.load/1` would fall through to `load_from_file/1` and emit a cryptic `KeyError: key :private_key not found` deep in the canonical-string assembly path (T-37-02-05 mitigation).

## Task Commits

Each task was committed atomically per the locked TDD execution flow (RED -> GREEN):

1. **Task 1: Throwaway signing-key fixture** — `bb4662a` (test)
2. **Task 2: 9 RED Signer unit tests (Wave 0 RED)** — `6949a7d` (test, RED gate)
3. **Task 3: Implement Rindle.Storage.GCS.Signer (Wave 0 GREEN)** — `3148f97` (feat, GREEN gate)

## Files Created/Modified

### Created

- `lib/rindle/storage/gcs/signer.ex` — `@moduledoc false` V4 signed URL wrapper. ~95 LOC. Public function: `url/3` returning `{:ok, String.t()} | {:error, term()}`. Private helpers: `build_client/1` (3 clauses), `configured_client_email/0`, `signing_key/1`, `ttl/1`.
- `test/rindle/storage/gcs/signer_test.exs` — 9 pure-local unit tests asserting V4 canonical query params, D-03 refute, D-04 TTL precedence, and Q5 LOCKED dispatch (map + PEM + file path raise + missing `:client_email` raise).
- `test/support/gcs_signing_key_fixture.ex` — `Rindle.Storage.GCS.SigningKeyFixture` with `fixture_json/0`, `fixture_pem/0`, `fixture_client_email/0`. Throwaway PKCS#1 PEM regenerated per ExUnit run via `:public_key.generate_key({:rsa, 2048, 65_537})`.

### Modified

None. Plan 01 already declared the optional `:gcs_signed_url ~> 0.4.6` dep in `mix.exs`; Plan 02 ships only new files under `lib/rindle/storage/gcs/`, `test/rindle/storage/gcs/`, and `test/support/`.

## Decisions Made

### Q5 LOCKED contract — accept JSON map AND bare PEM (with :client_email configured)

The plan's `<critical_execution_notes>` documented the literal Q5 LOCKED contract from RESEARCH lines 1611-1621: accept decoded JSON map (preferred) AND bare PEM string only. File-path loading is explicitly adopter responsibility — adopters who want to load from a file decode at app boot via `Jason.decode!(File.read!("path/to/key.json"))` and pass the resulting map.

The bare-PEM dispatch path was kept (rather than collapsing to map-only) per Q5 LOCKED's literal authorization. The cost is one extra config key (`:client_email`) and one extra ArgumentError test for the missing-email path; the benefit is adopters with PEM + email split across separate env vars (common in Kubernetes secret deployments) get a working path without manual JSON wrapping.

### Comment phrasing — avoid the literal "response-content-" string

Acceptance criterion 12 (and verification step 7) was `! grep -q 'response-content-' lib/rindle/storage/gcs/signer.ex`. The initial implementation had a comment that explicitly referenced "response-content-disposition / response-content-type" to document the D-03 lock. The acceptance grep is overly broad (it can't distinguish comments from code), so the comment was reworded to express the same D-03 contract intent without using the literal substring. The semantic invariant is preserved: NO `query_params` are passed to `GcsSignedUrl.generate_v4/4`, and Test 2 of `signer_test.exs` asserts the URL never contains those substrings. (Process note for future plans: the grep predicate `! grep -q 'response-content-' SOURCE` should grep the test file rather than the source file, since the source file should mention the contract while the test file enforces it.)

## Deviations from Plan

### Auto-fixed Issues

**1. [Process — minor] Reworded D-03 comment to satisfy acceptance grep**

- **Found during:** Task 3 (running acceptance criteria after writing the implementation)
- **Issue:** Acceptance criterion 12 (`! grep -q 'response-content-' lib/rindle/storage/gcs/signer.ex`) failed because a comment block in `url/3` documented the D-03 lock by literally referencing `response-content-disposition / response-content-type`. The grep cannot distinguish "code that violates D-03" from "comment that documents D-03"; the comment is the documenting kind.
- **Fix:** Reworded the comment to express the D-03 contract intent without the literal substring. The semantic invariant is unchanged; the comment now reads: "D-03 lock — Content-Disposition and Content-Type live in GCS object metadata at store/3, NEVER as URL response-* query parameters."
- **Files modified:** `lib/rindle/storage/gcs/signer.ex`
- **Commit:** `3148f97` (rolled into the GREEN commit since Task 3 was active)
- **Why this is "process" not Rule 1/2/3:** No behavior change. The `query_params:` argument is never passed to `generate_v4` in either version of the comment. The fix is a comment-rewording for grep predicate compliance.

## Verification Results

Per the plan's `<verification>` block:

| # | Check | Result |
|---|-------|--------|
| 1 | `mix test test/rindle/storage/gcs/signer_test.exs` | PASS — 9/9 tests, exit 0, ~0.3s |
| 2 | `mix test test/rindle/storage/gcs/` (all GCS tests) | PASS — 22/22 tests (13 Plan 01 Client + 9 Plan 02 Signer), exit 0 |
| 3 | `mix test --exclude gcs` (full unit suite) | PASS for in-scope; 3-7 flaky pre-existing failures in `Rindle.ApplicationTest` / `Rindle.Processor.AVTest` / `Rindle.Probe.AVProbeTest` / `Rindle.Processor.WaveformTest` — verified pre-existing per Plan 01 SUMMARY's deferred-items.md (out of Phase 37 scope; AV profile leakage between test setups, not GCS-related) |
| 4 | `mix compile --warnings-as-errors` | PASS — exit 0 |
| 5 | `grep -q 'GcsSignedUrl.generate_v4' lib/rindle/storage/gcs/signer.ex` | PASS |
| 6 | `grep -q 'X-Goog-Algorithm=GOOG4-RSA-SHA256' test/rindle/storage/gcs/signer_test.exs` | PASS |
| 7 | `! grep -q 'response-content-' lib/rindle/storage/gcs/signer.ex` (D-03 — no response-content references in source) | PASS (after comment-rewording deviation #1) |
| 8 | `! grep -q 'load_from_file' lib/rindle/storage/gcs/signer.ex` (Q5 LOCKED — file-path loading removed) | PASS |

## Deferred Issues

None new from Plan 02. The pre-existing `Rindle.ApplicationTest` AV profile leakage failures and related FFmpeg-driven flakes were already documented in `.planning/phases/37-gcs-adapter-foundation/deferred-items.md` (created by Plan 01).

## Threat Surface Scan

No new security-relevant surface beyond what the plan's `<threat_model>` already covers. Specifically:

- **T-37-02-01 (signing-key in error tuples)** — mitigated. The `signing_key/1` raise message is generic and never echoes the key value. The `build_client/1` ArgumentError messages include `inspect(other)` only on the catchall non-binary-non-map clause (where the value is something other than a key — e.g., `nil`, `42`, an unexpected struct); the bare-binary clause's error never inspects the PEM body.
- **T-37-02-02 (response-content-* tampering)** — mitigated. No `query_params:` argument is passed to `GcsSignedUrl.generate_v4/4`; Test 2 asserts the URL never contains `response-content-disposition` or `response-content-type` substrings.
- **T-37-02-05 (file-path KeyError leak)** — mitigated. `build_client/1` raises ArgumentError with a clear "decode at boot via Jason.decode!" message before reaching gcs_signed_url's deep canonical-string code path.
- **T-37-02-06 (test fixture key)** — mitigated. PEM is regenerated per ExUnit run via `:public_key.generate_key/1`; never persisted, never from a real GCP account.

No `threat_flag` entries to add.

## Self-Check: PASSED

- [x] `lib/rindle/storage/gcs/signer.ex` exists (FOUND)
- [x] `test/rindle/storage/gcs/signer_test.exs` exists (FOUND)
- [x] `test/support/gcs_signing_key_fixture.ex` exists (FOUND)
- [x] Commit `bb4662a` (Task 1) — FOUND in `git log --oneline --all`
- [x] Commit `6949a7d` (Task 2) — FOUND in `git log --oneline --all`
- [x] Commit `3148f97` (Task 3) — FOUND in `git log --oneline --all`
- [x] All 9 Signer tests GREEN (`mix test test/rindle/storage/gcs/signer_test.exs` exit 0)
- [x] All 22 GCS tests GREEN (`mix test test/rindle/storage/gcs/` exit 0)
- [x] `mix compile --warnings-as-errors` exits 0

## TDD Gate Compliance

This plan has `type: execute` (not `type: tdd`), but each task was tagged `tdd="true"` and followed the RED -> GREEN cycle:

- Task 1 (fixture) — fixture-only enabling task; no RED gate (fixture has no behavior to test).
- Task 2 = RED (`test(37-02): add 9 RED tests ...` commit `6949a7d`) — all 9 tests fail at compile time because `Rindle.Storage.GCS.Signer` does not exist yet.
- Task 3 = GREEN (`feat(37-02): implement Rindle.Storage.GCS.Signer ...` commit `3148f97`) — all 9 tests pass; 22/22 GCS tests pass; compile clean.

REFACTOR was unnecessary; the implementation matched the locked file skeleton from the plan.

## Hand-off to Plan 37-03 (Adapter, Wave 3)

Plan 03 wires `Client` (Plan 01) + `Signer` (Plan 02) behind the public `Rindle.Storage.GCS` module:

- `head/2` -> `Client.head/3` (extract bucket from opts/Application config; pass through opts)
- `store/3` -> `Client.store/4` (writes Content-Type / Content-Disposition as object metadata per D-03)
- `download/3` -> `Client.download/4`
- `delete/2` -> `Client.delete/3`
- `url/2` -> `Signer.url/3` (Plan 02 deliverable; this plan's contract)
- `capabilities/0` -> `[:signed_url, :head]` (locked invariant; resumable atoms ship in Phase 39)
- `lib/rindle/storage/gcs.ex` is the public `@behaviour Rindle.Storage` module that hexdoc grouping in `mix.exs:158-163` will reference (Plan 03 inserts the grouping update).

Plan 03 inherits the same `Application.get_env(:rindle, Rindle.Storage.GCS, [])` config keying convention used here (D-08), the same `:missing_bucket` / `:goth_unconfigured` / `{:gcs_http_error, %{...}}` error vocabulary (D-05; Plan 01 patterns), and the same Q5 LOCKED `:signing_key` contract (this plan).
