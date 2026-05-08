---
phase: 37-gcs-adapter-foundation
plan: 01
subsystem: storage
tags: [gcs, finch, goth, bypass, http-client, optional-deps]

requires:
  - phase: 36-prior
    provides: "v1.6 streaming-adapter optional-dep pattern (mux/jose), Bypass already in test-only deps, S3 head/2 head_result shape contract"
provides:
  - "Rindle.Storage.GCS.Client — hand-rolled Finch JSON-API client (head/store/download/delete) with shape-stable {:ok, _}/{:error, atom} returns"
  - "13 Bypass-driven unit tests proving HTTP plumbing in isolation (200/404/4xx/5xx + edge cases for each verb)"
  - "Optional-dep declarations for :goth ~> 1.4, :finch ~> 0.21, :gcs_signed_url ~> 0.4.6 + extended dialyzer plt_add_apps"
  - ":token opt seam (test-only) + :base_url opt seam (test-only Bypass discovery)"
  - "Goth.fetch/1 ArgumentError -> {:error, :goth_unconfigured} mapping (RESEARCH Pitfall 6)"
  - "URI.encode/2 with &URI.char_unreserved?/1 for `/` -> `%2F` path-segment encoding (RESEARCH Pitfall 1)"
  - "Finch.stream/4 download path (T-37-01-06 DoS mitigation for ≤2GB videos)"
affects: [37-02-signer, 37-03-adapter, 37-04-doctor, 38-resumable-fsm, 39-resumable-callbacks]

tech-stack:
  added:
    - ":goth ~> 1.4 (optional)"
    - ":finch ~> 0.21 (optional)"
    - ":gcs_signed_url ~> 0.4.6 (optional)"
  patterns:
    - "Hand-rolled Finch JSON-API client (rejected google_api_storage Tesla-coupled SDK per RESEARCH §3)"
    - "Bypass per-test setup (no shared fixture module per RESEARCH Q8) with per-test fresh Finch supervisor names via System.unique_integer/1"
    - ":token opt + :base_url opt as test-only seams (NOT advertised in user docs per RESEARCH Q4)"
    - "Goth.fetch/1 ArgumentError-rescue (load-bearing) + :exit, _reason catch (defense-in-depth)"

key-files:
  created:
    - "lib/rindle/storage/gcs/client.ex (~280 LOC, @moduledoc false)"
    - "test/rindle/storage/gcs/client_test.exs (13 Bypass-driven tests)"
  modified:
    - "mix.exs (3 new optional deps + extended dialyzer plt_add_apps + relaxed hackney to optional)"
    - "mix.lock (resolved goth 1.4.x, finch 0.21.x, gcs_signed_url 0.4.6, plus mint/nimble_options/nimble_pool/httpoison transitives)"

key-decisions:
  - "Override CONTEXT D-07 per RESEARCH Q9: :finch IS NOT in non-optional dep tree, so :finch was added to dialyzer.plt_add_apps"
  - "Relaxed hackney from `only: :test` to `optional: true` (Rule 3 blocking fix): gcs_signed_url -> httpoison ~> 2.0 declares hackney optional: false; mix's :only resolution requires consistency across all hackney paths"
  - "delete/3 on 404 returns {:error, :not_found} (NOT idempotent S3-style {:ok, ...}) per PATTERNS line 868-870; Plan 03 may normalize at public surface"
  - "Bypass 2.1 has no public Bypass.shutdown/1; setup relies on cowboy listener auto-cleanup when test process exits (Rule 3 fix during Task 3)"

patterns-established:
  - "GCS Client error envelope: 200..299 -> {:ok, _}, 404 -> {:error, :not_found}, other non-2xx -> {:error, {:gcs_http_error, %{status, body}}}, network exception -> {:error, exception}"
  - "Goth integration via fetch_token/1: ArgumentError rescue is the load-bearing branch (RESEARCH Pitfall 6); :exit, _reason catch is defense-in-depth"
  - "Multipart upload body shape: random `rindle_gcs_<hex8>` boundary; metadata JSON part with name/contentType/contentDisposition (atomic per D-03); file body streamed via File.stream!(_, [], 8192) so ≤2GB videos do not load into memory"
  - "Download memory safety: Finch.stream/4 chunk handler writes via IO.binwrite directly; status-aware accumulator transitions to :not_found / {:gcs_http_error, status} on non-2xx and the file is unlinked on error"

requirements-completed: [GCS-01]

duration: 9min
completed: 2026-05-07
---

# Phase 37 Plan 01: GCS Client (HTTP Plumbing) Summary

**Hand-rolled Finch JSON-API client (`Rindle.Storage.GCS.Client`) ships head/store/download/delete primitives over the GCS JSON API + multipart upload endpoint, proven by 13 Bypass-backed unit tests covering 200/404/4xx/5xx for each verb plus the GCS size-as-string parse, `/`->`%2F` URL encoding, multipart `uploadType` query param, and Goth ArgumentError rescue.**

## Performance

- **Duration:** ~9 minutes
- **Started:** 2026-05-07T17:32:01Z
- **Completed:** 2026-05-07 (Plan 37-01)
- **Tasks:** 3 / 3 complete
- **Files modified:** 4 (mix.exs, mix.lock, plus 2 created)
- **Files created:** 3 (client.ex, client_test.exs, deferred-items.md)

## Accomplishments

- Landed `Rindle.Storage.GCS.Client` as a `@moduledoc false` internal HTTP plumbing module per CONTEXT D-01 (3-file split — Wave 1 only). The behaviour-implementing public `Rindle.Storage.GCS` module ships in Plan 03 (Adapter, Wave 3); the V4 signer ships in Plan 02 (Wave 2).
- All four HTTP primitives (head/3, store/4, download/4, delete/3) return the shape-stable `{:ok, _}` / `{:error, atom}` envelope mirroring `lib/rindle/storage/s3.ex:130-149` parity assertion target.
- 13 Bypass-driven tests prove the HTTP plumbing in isolation BEFORE auth or signing add complexity (per locked execution order RESEARCH Q11). Live-bucket integration ships in Plan 03's `gcs_test.exs`.
- Optional-dep declarations follow the v1.6 mux/jose discipline so non-GCS adopters pay zero runtime cost. `Code.ensure_loaded?(Goth)` short-circuits `fetch_token/1` when adopters do not opt into GCS.
- Memory-safe download path: `Finch.stream/4` with `IO.binwrite` chunk handler ensures ≤2GB video downloads never buffer the full body in memory (T-37-01-06 mitigation).
- Security invariant: bearer tokens never appear in error tuples, `Logger.metadata/1`, `:telemetry.execute/3`, or `inspect/2` output (T-37-01-01 mitigation, security invariant 14 extension).

## Task Commits

Each task was committed atomically per TDD execution flow (RED → GREEN):

1. **Task 1: Add optional GCS deps + dialyzer PLT entries** — `540cae7` (feat)
2. **Task 2: 13 Bypass-driven RED tests for Rindle.Storage.GCS.Client** — `3c90f3f` (test, RED gate)
3. **Task 3: Implement Rindle.Storage.GCS.Client (Wave 0 GREEN)** — `6a1d8c6` (feat, GREEN gate)

## Files Created/Modified

### Created

- `lib/rindle/storage/gcs/client.ex` — Hand-rolled Finch JSON-API client. ~280 LOC. `@moduledoc false`. Public API: head/3, store/4, download/4, delete/3.
- `test/rindle/storage/gcs/client_test.exs` — 13 Bypass-driven unit tests (head/3 ×6, store/4 ×2, download/4 ×2, delete/3 ×2, Goth integration ×1).
- `.planning/phases/37-gcs-adapter-foundation/deferred-items.md` — Out-of-scope pre-existing test failures discovered during execution.

### Modified

- `mix.exs` — Added `{:goth, "~> 1.4", optional: true}`, `{:finch, "~> 0.21", optional: true}`, `{:gcs_signed_url, "~> 0.4.6", optional: true}` (D-06). Extended `dialyzer.plt_add_apps` from `[:mix, :ex_unit, :mux, :jose]` to `[:mix, :ex_unit, :mux, :jose, :goth, :finch, :gcs_signed_url]` (D-07 + RESEARCH Q9 override). Relaxed `{:hackney, "~> 1.20", only: :test}` to `{:hackney, "~> 1.20", optional: true}` (Rule 3 blocking fix — see Deviations below).
- `mix.lock` — Resolved 7 new entries: `goth`, `finch`, `gcs_signed_url`, `mint`, `nimble_options`, `nimble_pool`, `httpoison`. Updated `hackney` lock to `1.25.0`.

## Decisions Made

### CONTEXT D-07 override (RESEARCH Q9)

CONTEXT.md decision D-07 said `:finch — already in tree as a non-optional dep elsewhere; verify in plan`. RESEARCH Q9 (lines ~1101-1114) verified by `grep "finch" mix.lock` that `:finch` was NOT in the non-optional dep tree. Tesla declares it `optional: true` and Tesla is not loaded by Phase 37. Without the explicit PLT entry, dialyzer would error on `Finch.build/3,4,5`, `Finch.request/2,3`, and `%Finch.Response{}` references inside `gcs/client.ex`. Plan 37-01 added `:finch` to `plt_add_apps` to honor the RESEARCH override.

### `delete/3` on 404 returns `:not_found` (NOT idempotent)

Plan locked the choice to return `{:error, :not_found}` for 404 (not the idempotent S3-style `{:ok, ...}`). PATTERNS line 868-870 lists `:not_found` as the canonical emit at the Client layer. Plan 03 (Adapter) MAY normalize at the public surface if needed; the Client returns the raw shape.

### Bypass 2.1 has no public `Bypass.shutdown/1`

The locked test scaffold called `on_exit(fn -> Bypass.shutdown(bypass) end)`. Bypass 2.1's public API does not export `Bypass.shutdown/1`; the cowboy listener auto-cleans when the test process exits. Removed the on_exit call (Rule 3 blocking fix during Task 3).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] Hackney `only: :test` -> `optional: true`**

- **Found during:** Task 1 (`mix deps.get` after adding goth/finch/gcs_signed_url)
- **Issue:** `mix deps.get` failed with "Dependencies have diverged: hackney" because `gcs_signed_url ~> 0.4.6` transitively declares `httpoison ~> 2.0` whose hackney requirement is `optional: false`. Mix's `:only` resolution requires consistency across all paths reaching hackney; a `only: :test` declaration on hackney in `mix.exs` and an unrestricted requirement coming through `httpoison` cannot coexist.
- **Fix:** Relaxed the local `:hackney` declaration from `{:hackney, "~> 1.20", only: :test}` to `{:hackney, "~> 1.20", optional: true}`. Hackney remains effectively test-only at runtime since adopters opt into the gcs_signed_url/ex_aws optional deps that pull it in.
- **Files modified:** `mix.exs`, `mix.lock`
- **Commit:** `540cae7`
- **Why this is Rule 3 (not Rule 4 architectural):** No public API change, no behaviour change. Hackney was already in the runtime dep tree as ex_aws's optional HTTP client; Phase 37 only changes the metadata Mix uses to resolve transitive constraints.

**2. [Rule 3 — Blocking] Removed `on_exit(fn -> Bypass.shutdown(...) end)` from test setup**

- **Found during:** Task 3 (running tests after Client implementation)
- **Issue:** All 13 tests failed with `(UndefinedFunctionError) function Bypass.shutdown/1 is undefined or private`. Bypass 2.1 does not export `Bypass.shutdown/1` publicly.
- **Fix:** Removed the `on_exit` call. The cowboy listener Bypass starts is auto-cleaned when the test process exits, so explicit shutdown is unnecessary.
- **Files modified:** `test/rindle/storage/gcs/client_test.exs`
- **Commit:** `6a1d8c6` (rolled into the GREEN commit since the file was being modified anyway)

**3. [Process — minor] Added explicit Test 12 (`base_url` opt threading)**

- **Found during:** Task 2 (verifying acceptance criteria require `[ $(grep -c '    test "' ...) -ge 13 ]`)
- **Issue:** The locked test scaffold in the plan's `<action>` block contained 12 named tests, but the behavior list and acceptance criteria called for 13 (Test 12 = base_url threading; Test 13 = `%2F` URL encoding).
- **Fix:** Added an explicit `head/3` test that asserts `base_url:` opt threading hits the Bypass server (Test 12 per RESEARCH Section 2 / Q4). The other tests implicitly already exercise this seam, so the new test is partly belt-and-suspenders, but it makes the seam contract explicit and meets the >=13 acceptance threshold.
- **Files modified:** `test/rindle/storage/gcs/client_test.exs`
- **Commit:** `3c90f3f`

## Verification Results

Per the plan's `<verification>` block:

| # | Check | Result |
|---|-------|--------|
| 1 | `mix test test/rindle/storage/gcs/client_test.exs` | PASS — 13/13 tests, exit 0, ~0.07s |
| 2 | `mix test --exclude gcs` (full unit suite) | NEEDS NOTE — see Deferred Issues below |
| 3 | `mix compile --warnings-as-errors` | PASS — exit 0 |
| 4 | `mix dialyzer` PLT entries present | PASS — `plt_add_apps: [:mix, :ex_unit, :mux, :jose, :goth, :finch, :gcs_signed_url]` |
| 5 | `grep -F '{:goth, "~> 1.4", optional: true}' mix.exs` | PASS |
| 6 | `grep -F '{:finch, "~> 0.21", optional: true}' mix.exs` | PASS |
| 7 | `grep -F '{:gcs_signed_url, "~> 0.4.6", optional: true}' mix.exs` | PASS |
| 8 | `grep -E 'plt_add_apps: \[:mix, :ex_unit, :mux, :jose, :goth, :finch, :gcs_signed_url\]' mix.exs` | PASS |

## Deferred Issues

### Pre-existing failure: `Rindle.ApplicationTest` AV profile assertions

A subset of tests in `test/rindle/application_test.exs` (e.g., `test/rindle/application_test.exs:41-55` and adjacent assertions on `metadata.affected_profiles`) fail with `["Elixir.Rindle.Adopter.CanonicalApp.VideoProfile", "Elixir.Rindle.ApplicationTest.AVProfile"]` actual vs. `["Elixir.Rindle.ApplicationTest.AVProfile"]` expected. Verified pre-existing by `git stash` against Plan 37-01's base commit `47266ae` — the failures reproduce on the unmodified tree. Out of Phase 37 scope (Application bootup / AV profile registration; Phase 37 only touches GCS storage adapter HTTP plumbing). Logged to `.planning/phases/37-gcs-adapter-foundation/deferred-items.md`.

## Threat Surface Scan

No new security-relevant surface beyond what the plan's `<threat_model>` already covers. The bearer-token-redaction invariant (T-37-01-01) is enforced by code: no `Logger.*authorization`, no `Logger.*[Bb]earer`, no `inspect/2` of the auth header. The `:goth_unconfigured` mapping (T-37-01-02) is enforced by `rescue ArgumentError` in `fetch_token/1`. No `threat_flag` entries to add.

## Self-Check: PASSED

- [x] `lib/rindle/storage/gcs/client.ex` exists (FOUND)
- [x] `test/rindle/storage/gcs/client_test.exs` exists (FOUND)
- [x] `mix.exs` modified (FOUND in `git log` 540cae7)
- [x] `mix.lock` modified (FOUND in `git log` 540cae7)
- [x] Commit `540cae7` (Task 1) — FOUND in `git log --oneline --all`
- [x] Commit `3c90f3f` (Task 2) — FOUND in `git log --oneline --all`
- [x] Commit `6a1d8c6` (Task 3) — FOUND in `git log --oneline --all`
- [x] All 13 tests GREEN (`mix test test/rindle/storage/gcs/client_test.exs` exit 0)

## TDD Gate Compliance

This plan has `type: execute` (not `type: tdd`), but each task was tagged `tdd="true"` and followed the RED → GREEN cycle:

- Task 2 = RED (`test(37-01): add 13 Bypass-driven RED tests ...` commit `3c90f3f`) — tests fail at compile time because Client does not exist yet
- Task 3 = GREEN (`feat(37-01): implement Rindle.Storage.GCS.Client ...` commit `6a1d8c6`) — all 13 tests pass

REFACTOR was unnecessary; the implementation matched the locked file skeleton from the plan.

## Hand-off to Plan 37-02 (Signer, Wave 2)

Plan 02 builds `Rindle.Storage.GCS.Signer` (V4 signing wrapper around `gcs_signed_url ~> 0.4.6`). Plan 02 can now rely on:

- The optional-dep declarations from `mix.exs` (no further `mix deps.get` needed for `gcs_signed_url`)
- Independent module surface — `Signer` does not call `Client` and vice versa
- The same `Application.get_env(:rindle, Rindle.Storage.GCS, [])` config keying conventions

## Hand-off to Plan 37-03 (Adapter, Wave 3)

Plan 03 wires `Client` + `Signer` behind the public `Rindle.Storage.GCS` module:

- `head/2` → `Client.head/3` (extract bucket from opts/Application config; pass through opts)
- `store/3` → `Client.store/4` (writes Content-Type/Content-Disposition as object metadata per D-03)
- `download/3` → `Client.download/4`
- `delete/2` → `Client.delete/3`
- `url/2` → `Signer.url/3` (Plan 02 deliverable)
- `capabilities/0` → `[:signed_url, :head]` (locked invariant)
- `lib/rindle/storage/gcs.ex` is the public `@behaviour Rindle.Storage` module that hexdoc grouping in `mix.exs:158-163` will reference (Plan 03 inserts the grouping update).
