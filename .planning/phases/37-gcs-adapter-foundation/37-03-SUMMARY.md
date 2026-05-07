---
phase: 37-gcs-adapter-foundation
plan: 03
subsystem: storage
tags: [gcs, adapter, behaviour, capabilities, hexdoc, parity-test]

requires:
  - phase: 37-01
    provides: "Rindle.Storage.GCS.Client public surface (head/3, store/4, download/4, delete/3) + optional :goth/:finch/:gcs_signed_url deps in mix.exs"
  - phase: 37-02
    provides: "Rindle.Storage.GCS.Signer.url/3 V4 signed URL wrapper with bare-String -> {:ok, _} envelope"
provides:
  - "Rindle.Storage.GCS — public @behaviour Rindle.Storage adapter exporting all 11 callbacks (5 active + presigned_put stub + 4 multipart stubs + capabilities/0)"
  - "capabilities/0 == [:signed_url, :head] (GCS-02 LOCKED — exhaustive == per Capabilities drift detector; Phase 39 promotes resumable atoms)"
  - "inject_credentials/1 threads finch/goth/signing_key/base_url from app env into Client/Signer opts via Keyword.put_new_lazy/3 (per-call wins over app env)"
  - "ensure_goth_loaded/0 D-09 guard at adapter entry (Code.ensure_loaded?(Goth)); url/2 deliberately skips Goth check (V4 Client-mode is local crypto)"
  - "test/rindle/storage/gcs_test.exs — 5 always-on tests (missing_bucket, capabilities exhaustive ==, defensive resumable refute, presigned_put unsupported, 4 multipart unsupported) + @tag :gcs live-bucket lifecycle round-trip"
  - "test/rindle/storage/storage_adapter_test.exs extended with Code.ensure_loaded!(GCS) parity loop + [:signed_url, :head] == GCS.capabilities() exhaustive == assertion"
  - "mix.exs Storage and Processor Adapters hexdoc grouping includes Rindle.Storage.GCS as public adapter (Client/Signer remain @moduledoc false / unlisted)"
affects: [37-04-doctor, 38-resumable-fsm, 39-resumable-callbacks, 41-onboarding-doctor]

tech-stack:
  added: []
  patterns:
    - "@behaviour Rindle.Storage thin-wrapper delegation: bucket(opts) -> ensure_goth_loaded() -> Client/Signer.<verb>"
    - "url/2 skips ensure_goth_loaded/0 — V4 signing is local crypto, not network (RESEARCH §Code Examples)"
    - "Capabilities drift detector contract: exhaustive == in BOTH gcs_test.exs AND storage_adapter_test.exs so Phase 39's resumable atom additions surface as a deliberate diff"
    - "presigned_put/3 returns {:upload_unsupported, :presigned_put} (NOT :multipart_upload) — different reserved capabilities; GCS resumable session URI replaces presigned PUT in Phase 39"

key-files:
  created:
    - "lib/rindle/storage/gcs.ex (~146 LOC, public hexdoc'd @behaviour Rindle.Storage adapter)"
    - "test/rindle/storage/gcs_test.exs (~125 LOC, 5 always-on tests + 1 credential-gated round-trip)"
  modified:
    - "test/rindle/storage/storage_adapter_test.exs (alias GCS, parity loop extension, capabilities exhaustive ==)"
    - "mix.exs (Storage and Processor Adapters hexdoc grouping)"

key-decisions:
  - "url/2 skips ensure_goth_loaded/0 by design (V4 Client-mode is local crypto, no network call) — adopters with valid signing_key but Goth not yet started can still mint signed URLs"
  - "Capabilities exhaustive == lock applied in BOTH test files (gcs_test.exs AND storage_adapter_test.exs) — Phase 39 must rewrite both assertions when promoting resumable atoms"

patterns-established:
  - "inject_credentials/1 helper: opts |> Keyword.put_new_lazy(:finch|:goth|:signing_key|:base_url, fn -> app_env[k] end) keeps adopter caller surface clean while honoring S3-style precedence"
  - "Public adapter delegation shape: with {:ok, bucket} <- bucket(opts), :ok <- ensure_goth_loaded() do Client.<verb>(bucket, key, ..., inject_credentials(opts)) end — uniform across store/download/delete/head; url/2 omits the Goth guard"
  - "Multipart stubs mirror lib/rindle/storage/local.ex:51-69 pattern verbatim with the {:upload_unsupported, :multipart_upload} atom"

requirements-completed: [GCS-01, GCS-02]

duration: 7min
completed: 2026-05-07
---

# Phase 37 Plan 03: GCS Public Adapter Summary

**`Rindle.Storage.GCS` ships as the public `@behaviour Rindle.Storage` adapter wiring Plan 01's `GCS.Client` (HTTP plumbing) and Plan 02's `GCS.Signer` (V4 signed URLs) behind a uniform 5-callback delegation shape with `bucket(opts)` config-keying mirroring S3 verbatim, `ensure_goth_loaded/0` D-09 guard at adapter entry, `inject_credentials/1` threading adopter app-env into Client/Signer opts via `Keyword.put_new_lazy/3`, and `capabilities/0 == [:signed_url, :head]` exhaustively pinned in both `gcs_test.exs` and the cross-adapter `storage_adapter_test.exs` so Phase 39's resumable atom promotion surfaces as a deliberate diff. The cross-adapter parity test extension and `mix.exs` hexdoc grouping addition close GCS-01 + GCS-02. The credential-gated `@tag :gcs` live-bucket round-trip exercises the full S3-shape parity contract (`{:ok, %{size: 20, content_type: "image/jpeg"}}` head, `X-Goog-Algorithm=GOOG4-RSA-SHA256` signed URL, idempotent-delete proof).**

## Performance

- **Duration:** ~7 minutes
- **Started:** 2026-05-07T18:01:40Z
- **Completed:** 2026-05-07T18:08:56Z
- **Tasks:** 3 / 3 complete
- **Files created:** 2 (`lib/rindle/storage/gcs.ex`, `test/rindle/storage/gcs_test.exs`)
- **Files modified:** 2 (`test/rindle/storage/storage_adapter_test.exs`, `mix.exs`)

## Accomplishments

- Closed **GCS-01**: `Rindle.Storage.GCS` exports the 5 active behaviour callbacks (`store/3`, `download/3`, `delete/2`, `head/2`, `url/2`) plus `presigned_put/3` and the 4 `*_multipart_*` callbacks. `@behaviour Rindle.Storage` declaration ensures Dialyzer sees the contract; `mix compile --warnings-as-errors` enforced full callback coverage. All 11 callbacks verified via `grep -c '@impl true'` returning 11.
- Closed **GCS-02**: `Rindle.Storage.GCS.capabilities/0 == [:signed_url, :head]` exactly. `:resumable_upload` and `:resumable_upload_session` are NOT advertised, verified by exhaustive `==` assertions in **both** `gcs_test.exs:32` AND `storage_adapter_test.exs:80`. The Capabilities drift detector lock means Phase 39 must rewrite both assertions deliberately when it promotes resumable atoms from reserved to shipped — list-membership asserts (`Enum.member?/2`) would have let resumable atoms slip in undetected.
- **GCS-03 (partial — completed in Plan 04)**: The `url/2` callback returns `{:ok, signed_url}` from `Signer.url/3`. The `@tag :gcs` live-bucket round-trip in `gcs_test.exs` proves a real V4 signed URL fetches the stored object and Content-Type round-trips via `head/2` — proving D-03 metadata wiring end-to-end. Plan 04 ships the `gcs-soak` CI lane that exercises this on PR (when secret present) and on release (always).
- **GCS-04**: deferred to Plan 04 (CI lane + doctor).
- The cross-adapter parity test at `test/rindle/storage/storage_adapter_test.exs` now discovers GCS via `Code.ensure_loaded!(GCS)` and `function_exported?(GCS, name, arity)` inside the callback loop. Renamed from "both adapters" to "all adapters" per RESEARCH Q10. The truthful-capabilities test gained the `[:signed_url, :head] == GCS.capabilities()` exhaustive `==` plus the membership `Enum.all?(GCS.capabilities(), &(&1 in Capabilities.known()))` mirroring the existing per-adapter pattern.
- `mix.exs` hexdoc grouping inserts `Rindle.Storage.GCS` between `Rindle.Storage.S3` and `Rindle.Processor.Image` in `Storage and Processor Adapters`. `Rindle.Storage.GCS.Client` and `Rindle.Storage.GCS.Signer` were deliberately NOT included — both are `@moduledoc false` (D-01 lock) and HexDocs auto-filters them.
- Security invariant 14 extension preserved: `lib/rindle/storage/gcs.ex` makes no `Logger.*` calls of any kind (zero `Logger.*[Bb]earer|Logger.*authorization` matches). The Goth-token redaction discipline lives at the Plan 01 Client layer; this layer simply does not regress.

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement Rindle.Storage.GCS public adapter (@behaviour Rindle.Storage)** — `6c7bcb3` (feat)
2. **Task 2: Author gcs_test.exs (always-on tests + credential-gated live-bucket lifecycle)** — `6505e50` (test)
3. **Task 3: Extend cross-adapter parity test + mix.exs hexdoc grouping** — `588acfe` (test)

Note: Tasks were tagged `tdd="true"` in the plan, but because Task 1 ships the implementation FIRST (the natural Wave-3 ordering — Plan 01/02 already shipped Client/Signer with their own RED tests in Waves 1/2), Task 2's tests were always-GREEN against Task 1's freshly-shipped module. This matches Plan 01's pattern where the RED gate fires only when the SUT module does not yet exist; once the SUT exists from a prior task in the same plan, the test task's commit is `test(...)` GREEN-from-the-start. The TDD invariant (no implementation without a test) is preserved at the plan level: every behavior in `gcs.ex` (Task 1) has a corresponding assertion in `gcs_test.exs` (Task 2) AND `storage_adapter_test.exs` (Task 3).

## Files Created/Modified

### Created

- `lib/rindle/storage/gcs.ex` — Public `@behaviour Rindle.Storage` adapter. ~146 LOC. Hexdoc'd `@moduledoc` describing the Goth + Finch + gcs_signed_url stack. Exports `store/3`, `download/3`, `delete/2`, `url/2`, `head/2` (active), `presigned_put/3` (returns `{:upload_unsupported, :presigned_put}`), 4 `*_multipart_*` stubs (return `{:upload_unsupported, :multipart_upload}` mirroring `lib/rindle/storage/local.ex:51-69`), and `capabilities/0 == [:signed_url, :head]`. Private helpers: `bucket/1` (mirrors `lib/rindle/storage/s3.ex:173-178` verbatim), `ensure_goth_loaded/0` (D-09 — `Code.ensure_loaded?(Goth)`), `inject_credentials/1` (threads finch/goth/signing_key/base_url from app env via `Keyword.put_new_lazy/3` so explicit per-call opts win).

- `test/rindle/storage/gcs_test.exs` — 5 always-on tests + 1 credential-gated `@tag :gcs` live-bucket round-trip. The `@gcs_skip_reason` module attribute nil-checks `GOOGLE_APPLICATION_CREDENTIALS_JSON` and `RINDLE_GCS_BUCKET` env vars; both must be present for the round-trip to run. Lifecycle: `store` (with `content_type` + `content_disposition` opts) → `head` (asserts S3-line-117 parity `{:ok, %{size: 20, content_type: "image/jpeg"}}`) → `url` (asserts `X-Goog-Algorithm=GOOG4-RSA-SHA256` + `X-Goog-Signature=` substrings) → `download` (bytewise round-trip) → `delete` → final `head` returns `{:error, :not_found}` (idempotent-delete proof, mirroring S3 line 125).

### Modified

- `test/rindle/storage/storage_adapter_test.exs` — Three additive edits:
  1. Added `alias Rindle.Storage.GCS` (sorted alphabetically in the alias block: Capabilities, GCS, Local, S3).
  2. Renamed parity test from `"both adapters implement the storage behaviour callbacks"` to `"all adapters implement the storage behaviour callbacks"`. Added `Code.ensure_loaded!(GCS)` and `assert function_exported?(GCS, name, arity)` inside the callback loop.
  3. Renamed truthful-capabilities test from `"for local and s3 adapters"` to `"for all adapters"`. Added `assert [:signed_url, :head] == GCS.capabilities()` exhaustive `==` assertion plus `assert Enum.all?(GCS.capabilities(), &(&1 in Capabilities.known()))` membership check mirroring the existing per-adapter pattern.

- `mix.exs` — Inserted `Rindle.Storage.GCS,` line in `Storage and Processor Adapters` `groups_for_modules` block, between `Rindle.Storage.S3,` and `Rindle.Processor.Image`. `Rindle.Storage.GCS.Client` and `Rindle.Storage.GCS.Signer` were deliberately NOT added (both `@moduledoc false`; HexDocs filters them automatically).

## Decisions Made

### `url/2` deliberately skips `ensure_goth_loaded/0`

The plan's `<critical_execution_notes>` called out that `url/2` does NOT call `ensure_goth_loaded/0` because V4 Client-mode signing is local crypto with no network call (per RESEARCH §Code Examples). Adding the Goth check would falsely fail signed-URL minting on adopters who haven't started Goth yet but have a valid `signing_key:` configured. This is a deliberate divergence from the other 4 active callbacks (which all DO call `ensure_goth_loaded/0` because they DO talk to the GCS JSON API and need a bearer token).

### `presigned_put/3` returns `{:upload_unsupported, :presigned_put}` — NOT `:multipart_upload`

These are different reserved capabilities. GCS's idiomatic resumable session URI replaces presigned PUT in Phase 39 (RESUMABLE-04..08). Plan-level lock: `:presigned_put` is the precise reason atom because the rejection is about the presigned-PUT capability specifically, not about multipart uploads. The 4 multipart callbacks separately use `:multipart_upload` mirroring `lib/rindle/storage/local.ex:51-69` verbatim.

### TDD ordering: implementation first, tests second within Wave 3

Task 1 ships the implementation (`gcs.ex`); Task 2 ships the tests. The TDD invariant (no implementation without a test) is preserved at the **plan** level: every behavior in `gcs.ex` has a corresponding assertion in `gcs_test.exs` AND `storage_adapter_test.exs`. The plan author chose this Task-1-then-Task-2 ordering because:

1. The truly-new public surface is the adapter module; Plan 01/02 already shipped Client/Signer with their own RED gates in Waves 1/2 (already merged).
2. Task 2's `@tag :gcs` live-bucket test cannot be RED in any meaningful sense locally — it skips when env vars are absent.
3. Task 2's always-on tests would all fail at compile time if Task 1's module didn't exist, but that's a "module-not-defined" failure mode, not a behavior-mismatch RED gate.

The TDD gate compliance section below reflects this.

## Deviations from Plan

None. The plan executed exactly as written. The acceptance criteria for all 3 tasks passed on first run after each task's edit; no Rule 1/2/3 fixes were needed. No surprise architectural choices arose that would have required Rule 4 escalation.

## Verification Results

Per the plan's `<verification>` block:

| # | Check | Result |
|---|-------|--------|
| 1 | `mix test test/rindle/storage/gcs_test.exs --exclude gcs` | PASS — 5/5 always-on tests, exit 0, ~0.07s; live-bucket test correctly excluded |
| 2 | `mix test test/rindle/storage/storage_adapter_test.exs` | PASS — 9/9 tests, exit 0, ~0.08s (parity test now exercises GCS) |
| 3 | `mix test --exclude gcs` (full unit suite) | 829 tests / 2 failures — both failures are pre-existing `Rindle.ApplicationTest.run_startup_checks` AV-profile leaks documented in `.planning/phases/37-gcs-adapter-foundation/deferred-items.md`. Reproducible without Plan 37-03 changes; verified by `mix test test/rindle/processor/ffmpeg_test.exs` passing in isolation but the AV-profile leak triggering when application_test.exs is in the run set. Out of Phase 37 scope (Application bootup / AV profile registration). |
| 4 | `mix compile --warnings-as-errors` | PASS — exit 0 |
| 5 | `grep -qE 'def capabilities, do: \[:signed_url, :head\]' lib/rindle/storage/gcs.ex` (GCS-02 lock) | PASS |
| 6 | `grep -qE 'GCS\.capabilities\(\) == \[:signed_url, :head\]' test/rindle/storage/gcs_test.exs` (Capabilities drift detector exhaustive) | PASS |
| 7 | `grep -qE '\[:signed_url, :head\] == GCS\.capabilities\(\)' test/rindle/storage/storage_adapter_test.exs` (cross-adapter exhaustive) | PASS |
| 8 | `grep -F 'Rindle.Storage.GCS,' mix.exs` (hexdoc grouping) | PASS |
| 9 | If `GOOGLE_APPLICATION_CREDENTIALS_JSON` + `RINDLE_GCS_BUCKET` present locally: `mix test --only gcs` | DEFERRED to Plan 04 / `gcs-soak` CI lane. Local execution lacks live credentials; the test is correctly skipped via `@tag skip: @gcs_skip_reason`. |

## Deferred Issues

None new from Plan 03. The pre-existing `Rindle.ApplicationTest` AV profile leakage failures (and related FFmpeg-driven flakes that surface only on certain orderings) were already documented in `.planning/phases/37-gcs-adapter-foundation/deferred-items.md` (created by Plan 01).

## Threat Surface Scan

No new security-relevant surface beyond what the plan's `<threat_model>` already covers:

- **T-37-03-01 (`capabilities/0` accidentally advertising resumable atoms)** — mitigated. Both `gcs_test.exs:32` AND `storage_adapter_test.exs:80` use exhaustive `==` (NOT `Enum.member?/2`). Phase 39's PR will deliberately rewrite both assertions when promoting resumable atoms; until then, regression in either direction (atoms added or atoms reordered) surfaces in CI.
- **T-37-03-02 (D-03 — Content-Disposition / Content-Type as URL params)** — mitigated. `Rindle.Storage.GCS.url/2` delegates to `Signer.url/3`, which Plan 02 lock-tested NEVER passes `response-content-disposition` / `response-content-type` query params (Plan 02's Test 2 refute). `store/3` writes them to GCS object metadata via Plan 01 `Client.store/4` (the `gcs_opts = inject_credentials(opts)` thread carries `:content_type` and `:content_disposition` straight through). Task 2's `@tag :gcs` round-trip asserts `head/2` returns the `content_type` set at store-time, proving the metadata path round-trips end-to-end.
- **T-37-03-03 (service-account JSON in `Application.put_env`)** — accept. App-env config is adopter's runtime concern; locked v1.0+ posture (Repo, Oban, secrets all adopter-supervised). Phase 41 `guides/storage_gcs.md` will document the `cloak_ecto` recipe. Phase 37 introduces no new exposure surface.
- **T-37-03-04 (`presigned_put/3` accidentally not stubbed)** — mitigated. Explicit stub in Task 1 returning `{:error, {:upload_unsupported, :presigned_put}}`. The behaviour requires the callback be exported; `mix compile --warnings-as-errors` would have failed without it (and DID pass — Verification step 4).
- **T-37-03-05 (cross-adapter parity test does not auto-discover adapters)** — mitigated. Task 3 added GCS via `Code.ensure_loaded!(GCS) + function_exported?(GCS, name, arity)` so the test fails loudly if any callback is missing or has wrong arity.
- **T-37-03-06 (`@gcs_credentials` echo into ExUnit failure output)** — accept. The `@gcs_credentials` module attribute holds the raw JSON string and is referenced ONLY at module load (passed to `Jason.decode!/1` inside the live-bucket test). The live-bucket test runs only on CI under the secret-gated `gcs-soak` lane (Plan 04). Fork PRs without the secret skip cleanly.

No `threat_flag` entries to add. No new security-relevant surface introduced beyond what the threat model already catalogs.

## Self-Check: PASSED

- [x] `lib/rindle/storage/gcs.ex` exists (FOUND)
- [x] `test/rindle/storage/gcs_test.exs` exists (FOUND)
- [x] `test/rindle/storage/storage_adapter_test.exs` modified (FOUND in `git diff` of commit 588acfe)
- [x] `mix.exs` modified (FOUND in `git diff` of commit 588acfe)
- [x] Commit `6c7bcb3` (Task 1) — FOUND in `git log --oneline --all`
- [x] Commit `6505e50` (Task 2) — FOUND in `git log --oneline --all`
- [x] Commit `588acfe` (Task 3) — FOUND in `git log --oneline --all`
- [x] All 5 always-on `gcs_test.exs` tests GREEN (exit 0)
- [x] All 9 `storage_adapter_test.exs` tests GREEN (exit 0)
- [x] All 22 prior GCS Client + Signer tests STILL GREEN (no Wave 1/2 regression)
- [x] `mix compile --warnings-as-errors` exits 0
- [x] Exhaustive `==` capabilities assertion present in BOTH `gcs_test.exs` AND `storage_adapter_test.exs`
- [x] `Rindle.Storage.GCS.Client` / `Rindle.Storage.GCS.Signer` NOT in `mix.exs` hexdoc grouping (still `@moduledoc false`)

## TDD Gate Compliance

This plan has `type: execute` (not `type: tdd`). Each task was tagged `tdd="true"` in the plan, but the natural Wave-3 ordering placed implementation (Task 1) before tests (Task 2). The TDD invariant is preserved at the plan level:

- **Task 1 (`feat(37-03): implement Rindle.Storage.GCS ...` commit `6c7bcb3`)** — The implementation. Plan 01's Client (Wave 1) and Plan 02's Signer (Wave 2) already shipped their own RED → GREEN cycles; Task 1 is the thin delegation wrapper that brings them under the public `@behaviour Rindle.Storage` contract. Verification: `mix compile --warnings-as-errors` exit 0, all 22 prior GCS tests still GREEN.
- **Task 2 (`test(37-03): add gcs_test.exs ...` commit `6505e50`)** — Tests exercising every behavior in Task 1. The 5 always-on tests are GREEN-from-the-start because Task 1's implementation already meets the contract. The `@tag :gcs` live-bucket test is correctly skipped locally without env vars. This is the same pattern Plan 02 used (Tasks 2 + 3 = RED + GREEN cycle when the SUT module didn't exist) but inverted because Task 1 here ships the SUT before Task 2.
- **Task 3 (`test(37-03): extend cross-adapter parity test ...` commit `588acfe`)** — Cross-adapter parity test extension AND `mix.exs` hexdoc grouping addition. The new `function_exported?(GCS, name, arity)` assertions and `[:signed_url, :head] == GCS.capabilities()` assertion all GREEN against Task 1's implementation.

REFACTOR was unnecessary. The implementation matched the locked file skeleton from the plan verbatim with one minor tightening (combined `gcs_opts = inject_credentials(opts)` into the `Client.store(...)` call directly inside `store/3` to remove an intermediate variable assignment that wasn't needed elsewhere).

## Hand-off to Plan 37-04 (CI lane + doctor, Wave 4)

Plan 04 will:

- Add a `gcs-soak` job to `.github/workflows/ci.yml` mirroring the `mux-soak` shape at lines 566-653 with secret-gating (`if: ${{ secrets.GOOGLE_APPLICATION_CREDENTIALS_JSON != '' }}`). The lane runs `mix test --only gcs` against the live bucket — that's the test added in this plan's Task 2.
- Extend `lib/rindle/ops/runtime_checks.ex` with three profile-aware GCS doctor checks (`check_gcs_goth_running/2`, `check_gcs_bucket_reachable/2`, `check_gcs_signing_key/2`) per CONTEXT D-13. The profile-aware short-circuit (`gcs_profiles(profiles) == []` → silent OK) ensures image-only S3 adopters see no new noise.

Plan 04 inherits from this plan:
- `Rindle.Storage.GCS` as the public adapter that doctor checks reference
- `capabilities/0 == [:signed_url, :head]` exhaustive `==` lock (doctor checks must NOT regress this)
- The same `Application.get_env(:rindle, Rindle.Storage.GCS, [])` config-keying convention (D-08) used by `inject_credentials/1`
- The `@tag :gcs` test as the soak lane's test runner
