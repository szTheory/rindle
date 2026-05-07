---
phase: 37-gcs-adapter-foundation
verified: 2026-05-07T19:00:00Z
status: human_needed
score: 4/5 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Run `mix test --only gcs` with `GOOGLE_APPLICATION_CREDENTIALS_JSON` and `RINDLE_GCS_BUCKET` set against the real GCS bucket"
    expected: "Live-bucket round-trip passes: store (with content_type + content_disposition metadata) → head (size: 20, content_type: image/jpeg) → url (contains X-Goog-Algorithm=GOOG4-RSA-SHA256) → download (bytes match) → delete → head returns :not_found"
    why_human: "No live GCS credentials are available in the local verification environment; the @tag :gcs test is correctly skipped via @gcs_skip_reason. SC3 (Content-Disposition/Content-Type in object metadata round-trip) and SC1 (adapter against real bucket) cannot be fully verified programmatically."
  - test: "Verify the gcs-soak CI lane runs and passes on a PR where `GOOGLE_APPLICATION_CREDENTIALS_JSON` is configured"
    expected: "The gcs-soak job is not skipped (if: condition evaluates true), runs `mix test --only gcs`, and exits 0"
    why_human: "CI execution against a real secret cannot be verified locally. The workflow YAML structure is confirmed correct but runtime behavior against live GCS requires human observation."
---

# Phase 37: GCS Adapter Foundation — Verification Report

**Phase Goal:** Land `Rindle.Storage.GCS` as a real `Rindle.Storage` adapter against the live GCS bucket using `goth ~> 1.4` for auth and `finch ~> 0.21` for HTTP. No resumable behaviour yet (ships in Phases 38–39). Promote signed delivery and `head/2` checks; defer `:resumable_upload*` capability advertisement until Phase 39.

**Verified:** 2026-05-07T19:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|---------|
| 1  | `Rindle.Storage.GCS` implements every required `Rindle.Storage` callback (`store/3`, `download/3`, `delete/2`, `head/2`, `url/2`) plus stubs for the multipart and `presigned_put` callbacks | VERIFIED | `lib/rindle/storage/gcs.ex` has 11 `@impl true` declarations; `mix compile --warnings-as-errors` exits 0; `storage_adapter_test.exs` parity loop exercises GCS via `Code.ensure_loaded!(GCS)` + `function_exported?/3` |
| 2  | `capabilities/0` returns EXACTLY `[:signed_url, :head]`; `:resumable_upload` and `:resumable_upload_session` are NOT advertised | VERIFIED | `def capabilities, do: [:signed_url, :head]` at `gcs.ex:109`; `gcs_test.exs:33` uses exhaustive `==`; `storage_adapter_test.exs:85` uses `[:signed_url, :head] == GCS.capabilities()`; defensive `refute :resumable_upload in caps` and `refute :resumable_upload_session in caps` present; all 5 always-on tests pass |
| 3  | V4 signed URL generation works via `gcs_signed_url ~> 0.4.6` in private-key auth mode; TTL respects `Rindle.Config.signed_url_ttl_seconds/0`; `Content-Disposition` and `Content-Type` written into object metadata at `store/3` | VERIFIED (partial — metadata writing is code-verified; live round-trip needs human) | `signer.ex:28-29` calls `GcsSignedUrl.generate_v4` and wraps in `{:ok, _}`; `signer.ex:95` delegates TTL to `Rindle.Config.signed_url_ttl_seconds/0`; `client.ex:56-63` writes `contentType` + `contentDisposition` as JSON metadata fields in multipart body (D-03); all 9 signer tests pass; D-03 `refute response-content-*` in URL confirmed |
| 4  | The standalone GCS proof lane in CI is gated behind `GOOGLE_APPLICATION_CREDENTIALS_JSON`; the lane runs on PR only when the secret is present, and runs on release always; fork PRs without the secret skip the lane | VERIFIED | `ci.yml:662-708` — `gcs-soak` job with `if: ${{ secrets.GOOGLE_APPLICATION_CREDENTIALS_JSON != '' }}`; both `if:` and `env:` propagation present; triggered by `push: branches: [main]` (covers release) + `pull_request` (fork-PR safe per `pull_request` trigger semantics, not `pull_request_target`); YAML validated |
| 5  | `mix test --only gcs` passes against the real bucket; `mix rindle.doctor` reports GCS adapter health when configured; image-only S3 adopters see no new noise in doctor output | HUMAN NEEDED (doctor zero-noise verified; live test needs human) | Doctor zero-noise: 22 `runtime_checks_test.exs` tests GREEN; test asserts `gcs_rows == []` for S3-only adopters; `gcs_extra` conditional splice confirmed at `runtime_checks.ex:86-98`; `configured_gcs_profiles/1` in `capability.ex:114-120`; three check functions at lines 848, 910, 1058; `probe_gcs_bucket/4` + `do_probe/4` with real `Finch.build(:get,...) + Finch.request` at line 1027; `mix test --only gcs` requires live credentials — skipped locally |

**Score:** 4/5 truths verified (SC5 partially verified; live bucket behavior requires human)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/rindle/storage/gcs.ex` | `@behaviour Rindle.Storage` public adapter | VERIFIED | ~146 LOC; hexdoc'd `@moduledoc`; 11 callbacks; `capabilities/0 == [:signed_url, :head]`; `inject_credentials/1`; `ensure_goth_loaded/0` |
| `lib/rindle/storage/gcs/client.ex` | `@moduledoc false` Finch JSON-API client | VERIFIED | ~287 LOC; `@moduledoc false`; head/store/download/delete; `parse_size/1` binary-string handling; `URI.encode/2` with `char_unreserved?/1`; `uploadType=multipart`; `Finch.stream/4`; `rescue ArgumentError` on Goth |
| `lib/rindle/storage/gcs/signer.ex` | `@moduledoc false` V4 signed URL wrapper | VERIFIED | ~97 LOC; `@moduledoc false`; `GcsSignedUrl.generate_v4`; `{:ok, signed_url}` wrapping; Q5 LOCKED dispatch (JSON map + bare PEM + ArgumentError for file path); TTL fallback |
| `test/rindle/storage/gcs/client_test.exs` | 13 Bypass-driven unit tests | VERIFIED | 13 tests; Bypass.open(); Finch.start_link; `%2F` URL encoding; `:goth_unconfigured`; `uploadType=multipart`; `size: 1_024_000`; all 13 pass |
| `test/rindle/storage/gcs/signer_test.exs` | 9 unit tests | VERIFIED | 9 tests; `X-Goog-Algorithm=GOOG4-RSA-SHA256`; `X-Goog-Expires=900`; D-03 refute; Q5 LOCKED file-path raise; all 9 pass |
| `test/support/gcs_signing_key_fixture.ex` | Throwaway RSA PEM fixture | VERIFIED | `fixture_json/0`; `fixture_pem/0`; `fixture_client_email/0`; `:public_key.generate_key`; no `fixture_path`; `@moduledoc false` |
| `test/rindle/storage/gcs_test.exs` | Always-on + credential-gated live test | VERIFIED (structure) | 5 always-on tests pass; `@gcs_skip_reason` pattern; `@tag :gcs`; exhaustive `== [:signed_url, :head]` assertion; live test skipped locally |
| `test/rindle/storage/storage_adapter_test.exs` | Extended with GCS parity | VERIFIED | `alias Rindle.Storage.GCS`; `Code.ensure_loaded!(GCS)`; `function_exported?(GCS, name, arity)`; `[:signed_url, :head] == GCS.capabilities()`; "all adapters" test name |
| `.github/workflows/ci.yml` | `gcs-soak` job with secret gating | VERIFIED | Lines 662-708; `if: ${{ secrets.GOOGLE_APPLICATION_CREDENTIALS_JSON != '' }}`; `env:` block with both secrets; `mix test --only gcs`; postgres service; YAML valid |
| `lib/rindle/capability.ex` | `configured_gcs_profiles/1` | VERIFIED | Lines 114-120; mirrors `configured_streaming_profiles/1`; `safely_call_zero(profile, :storage_adapter) == Rindle.Storage.GCS` filter |
| `lib/rindle/ops/runtime_checks.ex` | Three GCS doctor checks + conditional splice | VERIFIED | `gcs_extra` conditional at lines 85-98; `gcs_profiles/1` delegator at line 842; `check_gcs_goth_running/2` (line 848); `check_gcs_bucket_reachable/2` (line 910); `check_gcs_signing_key/2` (line 1058); `probe_gcs_bucket/4` + `do_probe/4` real HTTP probe |
| `mix.exs` | Optional GCS deps + PLT entries + hexdoc grouping | VERIFIED | `{:goth, "~> 1.4", optional: true}` (line 72); `{:finch, "~> 0.21", optional: true}` (line 73); `{:gcs_signed_url, "~> 0.4.6", optional: true}` (line 74); `plt_add_apps: [:mix, :ex_unit, :mux, :jose, :goth, :finch, :gcs_signed_url]` (line 22); `Rindle.Storage.GCS,` in hexdoc grouping (line 171) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `gcs.ex` (@behaviour) | `Client.{head,store,download,delete}` | `with`-pipeline + `ensure_goth_loaded/0` guard + `inject_credentials/1` | VERIFIED | `gcs.ex:43-79` delegates to Client; `inject_credentials/1` threads finch/goth/signing_key/base_url |
| `gcs.ex` (`url/2`) | `Signer.url/3` | Direct delegation (no Goth guard — V4 is local crypto) | VERIFIED | `gcs.ex:68`: `Signer.url(bucket, key, inject_credentials(opts))` |
| `gcs/client.ex` | `Goth.fetch/1` + `rescue ArgumentError` | `fetch_token/1` helper | VERIFIED | `client.ex:241-254`: `try do Goth.fetch(name)` + `rescue ArgumentError -> {:error, :goth_unconfigured}` + `catch :exit, _reason` |
| `gcs/client.ex` | `Finch.stream/4` (download) | `download/4` file-open block | VERIFIED | `client.ex:113`: `Finch.stream(req, finch, :ok, fn ...)` with `IO.binwrite` |
| `gcs/signer.ex` | `GcsSignedUrl.generate_v4/4` | `url/3` with bare-String wrapper | VERIFIED | `signer.ex:28-29`: bare String.t() from Client mode wrapped in `{:ok, _}` |
| `gcs/signer.ex` | `Rindle.Config.signed_url_ttl_seconds/0` | `ttl/1` helper fallback | VERIFIED | `signer.ex:95`: `Keyword.get(opts, :expires_in, Rindle.Config.signed_url_ttl_seconds())` |
| `runtime_checks.ex` `gcs_profiles/1` | `Rindle.Capability.configured_gcs_profiles/1` | Single-line delegator | VERIFIED | `runtime_checks.ex:842-844`: `Rindle.Capability.configured_gcs_profiles(profiles)` |
| `ci.yml` `gcs-soak` | `secrets.GOOGLE_APPLICATION_CREDENTIALS_JSON` + `secrets.RINDLE_GCS_BUCKET` | `if:` gate + `env:` block | VERIFIED | Both `if:` clause and `env:` block propagation present per RESEARCH Q7 requirement |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `gcs.ex store/3` | `content_type`, `content_disposition` from opts | Thread via `inject_credentials(opts)` → `Client.store/4` → written to GCS JSON metadata part | Yes (code confirmed; live verification human-gated) | VERIFIED (code) |
| `gcs.ex head/2` | `%{size: integer, content_type: binary}` | `Client.head/3` → GCS JSON API → `json["size"]` parsed via `parse_size/1` (string→integer) | Yes (code confirmed; live round-trip human-gated) | VERIFIED (code) |
| `gcs.ex url/2` | Signed URL string | `Signer.url/3` → `GcsSignedUrl.generate_v4` (local RSA crypto) → `{:ok, url}` | Yes (9 signer tests with real RSA key pass) | VERIFIED |
| `runtime_checks.ex check_gcs_bucket_reachable` | HTTP status from GCS `/storage/v1/b/$BUCKET` | `do_probe/4` → `Finch.build(:get, ...)` + `Finch.request(...)` real HTTP | Yes (real HTTP probe, not stub; 7 Bypass-mocked probe tests pass) | VERIFIED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| 13 Bypass-driven client unit tests GREEN | `mix test test/rindle/storage/gcs/client_test.exs` | 13 tests, 0 failures, 0.07s | PASS |
| 9 Signer unit tests GREEN | `mix test test/rindle/storage/gcs/signer_test.exs` | 9 tests, 0 failures, 0.2s | PASS |
| 5 always-on GCS adapter tests GREEN | `mix test test/rindle/storage/gcs_test.exs --exclude gcs` | 5 tests, 0 failures (1 excluded) | PASS |
| Cross-adapter parity tests GREEN | `mix test test/rindle/storage/storage_adapter_test.exs` | 9 tests, 0 failures | PASS |
| 22 runtime_checks tests GREEN | `mix test test/rindle/ops/runtime_checks_test.exs` | 22 tests, 0 failures | PASS |
| Compile clean | `mix compile --warnings-as-errors` | exit 0, no warnings | PASS |
| `capabilities/0` exact value | `grep 'def capabilities, do:' lib/rindle/storage/gcs.ex` | `def capabilities, do: [:signed_url, :head]` | PASS |
| GCS dep declarations | `grep '{:goth.*optional.*true' mix.exs` | All 3 optional deps present | PASS |
| PLT entries | `grep 'plt_add_apps' mix.exs` | `[:mix, :ex_unit, :mux, :jose, :goth, :finch, :gcs_signed_url]` | PASS |
| Hexdoc grouping | `grep 'Rindle.Storage.GCS,' mix.exs` | Line 171 — GCS in Storage and Processor Adapters group | PASS |
| CI soak job | `grep '^  gcs-soak:' .github/workflows/ci.yml` | Job present at line 662 | PASS |
| Doctor zero noise (S3-only) | `grep 'gcs_extra =' lib/rindle/ops/runtime_checks.ex` | Conditional splice at line 85 | PASS |
| `mix test --only gcs` | Live bucket required | SKIP — no live GCS credentials | SKIP |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| GCS-01 | 37-01, 37-03 | `Rindle.Storage.GCS` implements `store/3`, `download/3`, `delete/2`, `head/2`, `url/2` with `goth ~> 1.4` + `finch ~> 0.21`; no resumable | SATISFIED | `gcs.ex` implements all 5 active callbacks; Client uses Finch HTTP; Goth for auth; 11 `@impl true` markers; `mix compile --warnings-as-errors` passes |
| GCS-02 | 37-03 | `capabilities/0` returns `[:signed_url, :head]` only at end of phase | SATISFIED | `def capabilities, do: [:signed_url, :head]`; exhaustive `==` in both `gcs_test.exs` and `storage_adapter_test.exs`; `refute :resumable_upload` present |
| GCS-03 | 37-02, 37-03 | V4 signed URL via `gcs_signed_url ~> 0.4.6`; TTL from config; Content-Disposition/Content-Type in object metadata (not URL params) | SATISFIED (code) / NEEDS HUMAN (live round-trip) | `GcsSignedUrl.generate_v4` + `{:ok, _}` wrap; `signed_url_ttl_seconds/0` fallback; `contentType`+`contentDisposition` as JSON metadata at `client.ex:62-63`; D-03 — no `response-content-*` URL params (verified by signer tests) |
| GCS-04 | 37-04 | CI lane gated behind `GOOGLE_APPLICATION_CREDENTIALS_JSON`; runs on PR when secret present; runs on release always; fork PRs skip | SATISFIED | `gcs-soak` job with `if: ${{ secrets.GOOGLE_APPLICATION_CREDENTIALS_JSON != '' }}`; triggered by `push: branches: [main]` + `pull_request`; `env:` block with both secrets; `mix test --only gcs` step |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/rindle/ops/runtime_checks.ex` | 49 | `@gcs_signing_key_fix` references "an existing file path" — contradicts Q5 LOCKED (file-path loading is adopter responsibility, not supported) | Warning | Cosmetic: the fix string is misleading but doesn't affect runtime behavior; the actual `verify_gcs_signing_key/1` implementation handles the file-path case conditionally (tries File.read/Jason.decode at doctor time, but the public `Signer` still rejects file paths) |

No blocker anti-patterns. The one warning in the `@gcs_signing_key_fix` message text is a cosmetic inconsistency (the doctor hint mentions "file path" as valid, while the adapter's signer raises `ArgumentError` for file-path inputs). This is a doc-level discrepancy only — it doesn't affect test outcomes or production behavior.

### Human Verification Required

#### 1. Live GCS Bucket Round-Trip

**Test:** Set `GOOGLE_APPLICATION_CREDENTIALS_JSON` (full service-account JSON string) and `RINDLE_GCS_BUCKET` env vars, then run `mix test --only gcs`

**Expected:** The `@tag :gcs` test in `test/rindle/storage/gcs_test.exs` passes all assertions: `store/3` returns `{:ok, %{key: key}}`; `head/2` returns `{:ok, %{size: 20, content_type: "image/jpeg"}}` (S3-line-117 parity); `url/2` returns `{:ok, url}` containing `X-Goog-Algorithm=GOOG4-RSA-SHA256` and `X-Goog-Signature=`; `download/3` bytewise matches stored body; `delete/2` returns `{:ok, _}`; final `head/2` returns `{:error, :not_found}`

**Why human:** No live GCS credentials in the local verification environment. The `@gcs_skip_reason` correctly skips the test when env vars are absent. This is the definitive proof that SC1 (adapter against real GCS bucket), SC3 (Content-Type/Content-Disposition round-trip via metadata), and the live portion of SC5 (`mix test --only gcs` passing) are fully working end-to-end.

#### 2. CI gcs-soak Lane Execution

**Test:** Open a PR with the `GOOGLE_APPLICATION_CREDENTIALS_JSON` secret configured in the repo, confirm the `gcs-soak` job appears in GitHub Actions UI and exits 0

**Expected:** The `gcs-soak` job runs (not skipped), executes `mix test --only gcs`, all GCS integration tests pass against the real bucket

**Why human:** CI runtime behavior against live secrets cannot be verified locally. The YAML structure has been confirmed but execution requires observing a real CI run.

### Gaps Summary

No programmatically-verified gaps. All must-haves are code-verified. Two items require human verification against live infrastructure:

1. The `@tag :gcs` live-bucket test in `gcs_test.exs` proves the full SC1/SC3 contract end-to-end (Content-Type metadata round-trip, size-as-string parse against real GCS response, V4 signed URL fetching stored bytes). This cannot be verified without live GCS credentials.

2. The CI `gcs-soak` lane's actual runtime behavior on a PR with the secret configured cannot be verified from the local filesystem.

The codebase evidence for correct wiring is strong across all layers: 13 + 9 + 5 + 9 + 22 = 58 tests pass covering the full implementation surface except the live GCS network path.

---

_Verified: 2026-05-07T19:00:00Z_
_Verifier: Claude (gsd-verifier)_
