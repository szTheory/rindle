---
phase: 37-gcs-adapter-foundation
plan: 04
subsystem: ops
tags: [gcs, doctor, ci, secret-gating, finch, goth, runtime-checks, capability-indirection]

requires:
  - phase: 37-01
    provides: ":finch in dialyzer.plt_add_apps (Plan 01 RESEARCH Q9 override) — load-bearing because runtime_checks.ex now imports %Finch.Response{} directly; Bypass + Plan 02 SigningKeyFixture for unit-level probe mocking"
  - phase: 37-02
    provides: "Rindle.Storage.GCS.SigningKeyFixture.fixture_json/0 throwaway service-account JSON map for the check_gcs_signing_key happy-path test"
  - phase: 37-03
    provides: "Rindle.Storage.GCS public adapter — referenced by Capability.configured_gcs_profiles/1 filter (storage_adapter() == Rindle.Storage.GCS)"
provides:
  - "gcs-soak CI job in .github/workflows/ci.yml gated on `secrets.GOOGLE_APPLICATION_CREDENTIALS_JSON != ''` (D-10 + RESEARCH Q7 — secret-presence, NOT label-gating; fork-PR safe)"
  - "Rindle.Capability.configured_gcs_profiles/1 — single source of truth for filtering profiles whose storage_adapter == Rindle.Storage.GCS, mirroring configured_streaming_profiles/1"
  - "Three new doctor checks: doctor.gcs_goth_running, doctor.gcs_bucket_reachable (real HTTP probe), doctor.gcs_signing_key — appended to run/2's checks list ONLY when gcs_profiles(profiles) != [] (image-only S3 adopters see ZERO new doctor noise)"
  - "probe_gcs_bucket/4 + do_probe/4 — real Finch + Goth GET /storage/v1/b/\$BUCKET probe with explicit precondition guards (5 return shapes: :ok, {:bucket_missing, _}, {:unexpected_status, _}, {:probe_error, _}, {:precondition_missing, _})"
  - "Test-only :token opt seam (mirrors Plan 01 Client convention) — Bypass-mocked unit tests inject a fixed bearer instead of round-tripping through Google's real OAuth endpoint"
  - "16 new tests in test/rindle/ops/runtime_checks_test.exs (9 doctor-row + 7 Bypass-mocked probe), all GREEN"
affects: [38-resumable-fsm, 39-resumable-callbacks, 41-onboarding-doctor]

tech-stack:
  added: []
  patterns:
    - "Conditional fn-ref splice (gcs_extra = if gcs_profiles != [], do: [...], else: []) — image-only adopters get LITERAL ABSENCE of gcs_* rows in report.checks (stricter than streaming-credentials' silent OK template per D-13 lock)"
    - "Real HTTP probe with explicit precondition guards — HONEST error_result naming missing precondition (not_configured / unavailable) when Finch/Goth aren't startable; never fabricates silent OK"
    - ":token test-only opt seam threaded through both probe_gcs_bucket/4 and the bucket-reachable check — adopters with real Goth get the production path; tests inject a fixed bearer to keep Bypass-mocked unit tests deterministic"
    - "Bearer-token + PEM-body redaction enforced via inspect(exception.__struct__) (Phase 36 WR-10 parity) AND Finch.request error shapes (atoms / Mint transport structs only — never raw response bodies)"

key-files:
  created: []
  modified:
    - ".github/workflows/ci.yml (gcs-soak job inserted after mux-soak ~line 654)"
    - "lib/rindle/capability.ex (configured_gcs_profiles/1 added after configured_streaming_profiles/1)"
    - "lib/rindle/ops/runtime_checks.ex (5 new module attrs, conditional splice, gcs_profiles/1 delegator, 3 check_gcs_* fns, probe_gcs_bucket/4 + do_probe/4 + probe_token/2, verify_gcs_signing_key/1 with 4 clauses + WARNING 5 explicit is_map guard)"
    - "test/rindle/ops/runtime_checks_test.exs (2 new describe blocks: \"GCS doctor checks (Phase 37 / D-13)\" with 9 tests + \"probe_gcs_bucket/4 + do_probe/4 (Bypass-mocked HTTP probe — BLOCKER 2 D-13 lock)\" with 7 tests)"

key-decisions:
  - "Rule 3 blocking fix: added :token opt seam to do_probe/4 to bypass Goth.fetch/1 in Bypass-mocked unit tests (real Goth.fetch with fake credentials calls Google's real OAuth endpoint and fails with HTTP 400 invalid_grant). Mirrors Plan 01 Client :token opt convention. Threaded through bucket-reachable check via app env so security-invariant test (bearer-redaction) can drive a controlled error path."
  - "Conditional splice (gcs_extra = if gcs_profiles != [] do [...] else [] end) is stricter than the streaming-credentials template — D-13 explicitly demanded image-only adopters see no new noise, which means literal absence not silent OK rows."

patterns-established:
  - "Capability indirection for storage adapters: Rindle.Capability.configured_gcs_profiles/1 mirrors configured_streaming_profiles/1; runtime_checks.ex gcs_profiles/1 is a single-line delegator. Future phases (Phase 41 RESUMABLE-13's CORS check) reuse the same canonical filter without inlining."
  - "Doctor check splice discipline: append-only fn-ref list with `++` concatenation gated by a profile-presence predicate. Existing Enum.sort_by(& &1.id) keeps doctor output ordering deterministic (alphabetical) — no sort changes required."
  - "Real-HTTP probe with precondition wrapper: probe_gcs_bucket/4 (precondition guards) → do_probe/4 (HTTP issuance). Splitting the wrapper from the issuance lets Bypass-mocked unit tests exercise do_probe/4 directly while the doctor row goes through the wrapper for honest precondition-missing surfacing."
  - ":token test-only opt seam: Plan 01's Client established this convention; Plan 04 inherits it for runtime_checks.ex. Production callers do not pass :token; the Goth path runs. Tests inject a fixed bearer to keep Bypass deterministic and side-effect-free."

requirements-completed: [GCS-04]

duration: 13min
completed: 2026-05-07
---

# Phase 37 Plan 04: CI Soak Lane + Doctor Extension Summary

**Closes GCS-04 by adding the secret-gated `gcs-soak` job to `.github/workflows/ci.yml` (mirrors `mux-soak` structural template at lines 566-653 with `if: ${{ secrets.GOOGLE_APPLICATION_CREDENTIALS_JSON != '' }}` per D-10 + RESEARCH Q7) and the D-13 `mix rindle.doctor` extension. The doctor extension adds three GCS-aware checks (`doctor.gcs_goth_running`, `doctor.gcs_bucket_reachable`, `doctor.gcs_signing_key`) appended to the `run/2` checks list ONLY when `gcs_profiles(profiles) != []` — image-only S3 adopters see ZERO new `gcs_*` rows in doctor output (WARNING 3 stricter-than-streaming lock). The bucket-reachable check performs a REAL `GET /storage/v1/b/$BUCKET` HTTP probe via `probe_gcs_bucket/4` + `do_probe/4` with explicit precondition guards (Finch loaded? Finch instance configured? Goth loaded? Goth instance configured?); when preconditions are missing the doctor row is an HONEST error_result naming the missing precondition rather than a silent OK (BLOCKER 2 / D-13 LOCK). `Rindle.Capability.configured_gcs_profiles/1` is the single-source-of-truth profile filter mirroring `configured_streaming_profiles/1`. PEM body / service-account JSON content / bearer tokens NEVER echo into doctor output (Phase 36 WR-10 + RESEARCH §7 security parity, enforced by `refute summary =~ ~r/Bearer ey/` and `refute summary =~ ~r/-----BEGIN/` test invariants).**

## Performance

- **Duration:** ~13 minutes
- **Started:** 2026-05-07T18:14:13Z
- **Completed:** 2026-05-07
- **Tasks:** 3 / 3 complete
- **Files modified:** 4 (`.github/workflows/ci.yml`, `lib/rindle/capability.ex`, `lib/rindle/ops/runtime_checks.ex`, `test/rindle/ops/runtime_checks_test.exs`)
- **Files created:** 1 (this SUMMARY.md)

## Accomplishments

- **GCS-04 closed.** New `gcs-soak` job in `.github/workflows/ci.yml` (lines 662-712 in the post-edit file). Gated on `secrets.GOOGLE_APPLICATION_CREDENTIALS_JSON != ''` (D-10 + RESEARCH Q7). Both the `if:` clause AND the `env:` block propagation are present (RESEARCH Q7 critical: both are required — the `if:` controls whether the job runs, the `env:` makes the value available to the test process at module-load via Plan 03's `@gcs_credentials System.get_env(...)`). Fork-PR safe: GitHub Actions resolves `secrets.*` to `''` on fork PRs with the `pull_request` trigger (NOT `pull_request_target`), so the lane skips cleanly without leaking secrets. Drops Mux env vars + MinIO container + soak script + layer-3 cleanup (Phase 37 has no soak script — `mix test --only gcs` runs Plan 03's `@tag :gcs` lifecycle test directly). Postgres service preserved (required by `test_helper.exs` Ecto.Adapters.SQL.Sandbox checkout). D-14 honored — package-consumer lane (~line 289) NOT touched.
- **D-13 doctor extension closed.** Three new check functions in `lib/rindle/ops/runtime_checks.ex` plus the `gcs_profiles/1` delegator and the `probe_gcs_bucket/4` + `do_probe/4` + `probe_token/2` probe stack. Conditional fn-ref splice (`gcs_extra = if gcs_profiles(profiles) != [], do: [...], else: []`) means S3-only adopters get LITERAL ABSENCE of `gcs_*` rows — verified locally: `mix rindle.doctor` (with no GCS profile configured) produces zero `gcs_` rows in the report.
- **WARNING 4 — Capability indirection.** `Rindle.Capability.configured_gcs_profiles/1` is the single source of truth for filtering profiles whose `storage_adapter() == Rindle.Storage.GCS`, mirroring `configured_streaming_profiles/1` at lines 99-104. `runtime_checks.ex` `gcs_profiles/1` is a single-line delegator. Future phases (Phase 41 RESUMABLE-13's CORS check) layer on top without inlining.
- **BLOCKER 2 — Real HTTP probe with precondition guards.** `do_probe/4` issues a real `GET /storage/v1/b/$BUCKET` request via `Finch.build(:get, url, [{"Authorization", "Bearer " <> token}])` + `Finch.request(req, finch_name)`. Status mapping: `200/403 → :ok` (per RESEARCH §7 — 403 means name resolution healthy, ACL restricted), `404 → {:bucket_missing, 404}`, other status → `{:unexpected_status, status}`, network exception → `{:probe_error, reason}`. The `probe_gcs_bucket/4` wrapper applies four precondition guards (`Code.ensure_loaded?(Finch)`, `finch_name != nil`, `Code.ensure_loaded?(Goth)`, `goth_name != nil`) and surfaces `{:precondition_missing, atom}` when any guard fails — the doctor row is an HONEST error_result naming the missing precondition with a fix-oriented summary, NOT a fabricated silent OK that masks the absence of a real probe.
- **WARNING 5 — Explicit `is_map/1` guard.** `verify_gcs_signing_key/1` catchall is now `defp verify_gcs_signing_key(other) when is_map(other)` plus `defp verify_gcs_signing_key(_other)` (plain catchall). No awkward `rescue`-based control flow. `Map.get(other, :__struct__) || :map_without_struct` handles bare maps cleanly.
- **Phase 36 WR-10 + RESEARCH §7 security parity.** `inspect(exception.__struct__)` is the load-bearing redaction primitive across both signing-key parse failures and probe failures. `Finch.request/2` errors are atoms / `%Mint.TransportError{}` structs — never raw response bodies. Test invariants (`refute summary =~ ~r/Bearer ey/` AND `refute summary =~ ~r/-----BEGIN/`) hold across all error-path doctor rows.
- **All 22 `runtime_checks_test.exs` tests GREEN** (6 pre-existing streaming-check tests + 16 new GCS-related tests). The 16 new tests break down as: 9 doctor-row tests in the `"GCS doctor checks (Phase 37 / D-13)"` describe + 7 Bypass-mocked probe tests in the `"probe_gcs_bucket/4 + do_probe/4"` describe.

## Task Commits

Each task committed atomically per TDD discipline (Task 1 + Task 2 RED + Task 3 GREEN):

1. **Task 1: Add gcs-soak CI job (secret-gated proof lane)** — `083aa93` (feat)
2. **Task 2: Add RED tests for GCS doctor checks (Phase 37 D-13)** — `2eaf0a6` (test, RED gate — 14 of 16 new tests fail at run-time with `UndefinedFunctionError` on `RuntimeChecks.probe_gcs_bucket/3,4` + `do_probe/4`; 2 new tests pre-pass because the SUT path simply returns nil for unconfigured app env on the LocalProfile branches)
3. **Task 3: Implement GCS doctor checks (capability indirection + real HTTP probe)** — `4c9b8e5` (feat, GREEN gate)

## Files Created/Modified

### Modified

- `.github/workflows/ci.yml` (+55 lines) — Inserted `gcs-soak` job after `mux-soak` (line 654 in pre-edit file). Job spec mirrors mux-soak's structural template with secret-gating substitution: `needs: quality`; `if: ${{ secrets.GOOGLE_APPLICATION_CREDENTIALS_JSON != '' }}`; `env:` block with `MIX_ENV: test`, `GOOGLE_APPLICATION_CREDENTIALS_JSON`, `RINDLE_GCS_BUCKET`, `PGUSER`/`PGPASSWORD`/`PGHOST`/`PGPORT`; `services: postgres:` block verbatim from mux-soak; `steps:` simplified to Checkout → Set up Elixir → Install libvips → `mix deps.get` → `mix test --only gcs` (drops Mux's MinIO setup + soak script + layer-3 cleanup).
- `lib/rindle/capability.ex` (+15 lines) — Added `configured_gcs_profiles/1` immediately after `configured_streaming_profiles/1`. Uses `safely_call_zero(profile, :storage_adapter) == Rindle.Storage.GCS` filter so test-fixture profiles without `storage_adapter/0` (none in the codebase, but defensive) and rescue-on-call profiles never crash the filter.
- `lib/rindle/ops/runtime_checks.ex` (+265 lines) — Five new module attributes (`@gcs_dep_missing_fix`, `@gcs_goth_fix`, `@gcs_bucket_fix`, `@gcs_signing_key_fix`, `@gcs_precondition_fix`); conditional splice in `run/2` with `gcs_extra = if gcs_profiles(profiles) != [], do: [...], else: []`; `gcs_profiles/1` delegator; three `check_gcs_*` functions; `probe_gcs_bucket/4` precondition wrapper; `do_probe/4` real HTTP issuance; `probe_token/2` test-only seam; `fetch_gcs_goth_token/1` with `rescue ArgumentError` (RESEARCH Pitfall 6 load-bearing) + `:exit, _reason` defense-in-depth catch; four `verify_gcs_signing_key/1` clauses (JSON map preferred, bare PEM rejected, file path conditional, `is_map/1` guarded catchall, plain catchall).
- `test/rindle/ops/runtime_checks_test.exs` (+459 lines) — Two new describe blocks. The `"GCS doctor checks (Phase 37 / D-13)"` describe (9 tests) covers: WARNING 3 zero-row assertion (S3-only adopter), defensive non-component-:gcs check, three-row presence assertion (GCS profile present), goth-not-started error, bucket-not-configured error, BLOCKER 2 precondition-missing error (Finch/Goth not configured), signing-key malformed error with security parity, and signing-key valid JSON map ok. The `"probe_gcs_bucket/4 + do_probe/4 (Bypass-mocked HTTP probe — BLOCKER 2 D-13 lock)"` describe (7 tests) covers all 5 return shapes (200, 403, 404, 500, Bypass.down) plus 2 precondition-missing shapes (`:finch_not_configured`, `:goth_not_configured`) plus the doctor-row bearer-token redaction security invariant.

## Decisions Made

### Rule 3 blocking fix — `:token` opt seam in `do_probe/4`

**Found during:** Task 3 (running `mix test test/rindle/ops/runtime_checks_test.exs` after the GREEN implementation was written).

**Issue:** 5 of the 7 Bypass-mocked probe tests failed because the test setup called `Goth.start_link(name: ..., source: {:service_account, fake_creds, []})` with the throwaway `Rindle.Storage.GCS.SigningKeyFixture.fixture_json/0` map. `Goth.fetch/1` then tried to mint a real OAuth token by POST-ing the JWT to `oauth2.googleapis.com/token` — which returned HTTP 400 `invalid_grant` (the fake service-account doesn't exist in any GCP project). The `do_probe/4` `with` clause matched `{:error, %RuntimeError{message: "unexpected status 400 from Google\n\n{\"error\":\"invalid_grant\",...}"}}` and propagated `{:probe_error, exception}` instead of the expected status-mapped tuples.

**Fix:** Added a `:token` test-only opt seam to `do_probe/4` (mirrors Plan 01's Client `:token` convention at `lib/rindle/storage/gcs/client.ex:213-216`). The new private helper `probe_token(goth_name, opts)` checks `Keyword.get(opts, :token)`; if a binary token is provided it is used directly, otherwise `Goth.fetch/1` runs as before. Threaded the seam through the bucket-reachable doctor check too via `app_env[:token]` so the security-invariant test (bearer-redaction at run/2 level) can drive a controlled `:probe_error` path with a known bypass response.

**Why this is Rule 3 (blocking) not Rule 4 (architectural):** No public API change, no behavior change for production callers (production `Application.get_env(:rindle, Rindle.Storage.GCS, ...)` does not set `:token`; the Goth path runs). The seam is the same conventional test-only seam Plan 01 already established for `Client.head/3,4`, which is documented as "test-only" in the Plan 01 SUMMARY. Without this seam the locked test contract (Bypass-mocked probe-shape coverage) cannot be exercised — Bypass cannot intercept `oauth2.googleapis.com/token`. Adding the seam is mechanically equivalent to Plan 01's earlier acceptance and follows the locked Rindle convention. No public API or contract change.

### Test infrastructure note: pre-existing `Rindle.ApplicationTest` flakes are out of scope

`mix test --exclude gcs` reports 4 failures, all confirmed pre-existing per `.planning/phases/37-gcs-adapter-foundation/deferred-items.md` (created by Plan 01) and reproduced by stashing this plan's changes and running the same command against `2eaf0a6`. Two failures are AV-profile leak (`Rindle.ApplicationTest`), one is `Rindle.Probe.AVProbeTest` `:epipe` (FFmpeg timing flake), one is `Rindle.Application` warning leakage. None are introduced by Plan 04. Phase 37 scope is GCS adapter; AV probing and Application bootup are out of scope.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] `:token` opt seam in `do_probe/4`**

- **Found during:** Task 3 (running the Bypass-mocked unit tests after writing the GREEN implementation)
- **Issue:** Real `Goth.fetch/1` against the fake `SigningKeyFixture.fixture_json/0` credentials calls Google's real OAuth endpoint and fails with HTTP 400 `invalid_grant`, masking the probe's actual return shape under a `{:probe_error, %RuntimeError{...}}` envelope and breaking 5 of the 7 Bypass-mocked tests.
- **Fix:** Added `:token` test-only opt to `do_probe/4` (via new `probe_token/2` helper). When `:token` is set, returns the binary directly; otherwise calls `Goth.fetch/1` as before. Threaded through `check_gcs_bucket_reachable/2` via `app_env[:token]` so the security-invariant test (which goes through `run/2`) can use the same seam.
- **Files modified:** `lib/rindle/ops/runtime_checks.ex`, `test/rindle/ops/runtime_checks_test.exs`
- **Commit:** `4c9b8e5` (rolled into the GREEN commit because the seam is mechanically inseparable from the GREEN implementation)
- **Why this is Rule 3 (not Rule 4 architectural):** Mirrors Plan 01 Client's locked `:token` opt convention verbatim (Plan 01 `client.ex:213-216`). No public API change, no behavior change for production callers. The seam is documented as test-only in this SUMMARY and the inline code comments. The locked test contract (Bypass-mocked probe-shape coverage in 5 return shapes) cannot be exercised without it — Bypass cannot intercept Google's real OAuth endpoint.

## Verification Results

Per the plan's `<verification>` block:

| #  | Check                                                                                                          | Result                                                                                                                                                                                              |
|----|----------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1  | `mix test test/rindle/ops/runtime_checks_test.exs` exits 0 (22 tests, 0 failures)                              | PASS                                                                                                                                                                                                |
| 2  | `mix test --exclude gcs` exits 0                                                                               | NEEDS NOTE — 4 pre-existing failures (Rindle.ApplicationTest AV-profile leak + AVProbeTest :epipe flake), all confirmed pre-existing by stashing this plan's changes. Out of Phase 37 scope.        |
| 3  | `mix compile --warnings-as-errors` exits 0                                                                     | PASS                                                                                                                                                                                                |
| 4  | YAML validates (`python3 -c 'import yaml; yaml.safe_load(open(".github/workflows/ci.yml"))'`)                  | PASS — used Python's PyYAML (Ruby unavailable on PATH); semantically equivalent YAML 1.1 parser                                                                                                     |
| 5  | `grep -q '^  gcs-soak:' .github/workflows/ci.yml`                                                              | PASS                                                                                                                                                                                                |
| 6  | `grep -E "if: \\\$\\{\\{ secrets\\.GOOGLE_APPLICATION_CREDENTIALS_JSON != '' \\}\\}" .github/workflows/ci.yml` | PASS                                                                                                                                                                                                |
| 7  | `grep -q 'mix test --only gcs' .github/workflows/ci.yml`                                                       | PASS                                                                                                                                                                                                |
| 8  | `grep -c 'check_gcs_' lib/rindle/ops/runtime_checks.ex` >= 6                                                   | PASS                                                                                                                                                                                                |
| 9  | WARNING 4 — `grep -q 'def configured_gcs_profiles' lib/rindle/capability.ex`                                   | PASS                                                                                                                                                                                                |
| 10 | WARNING 4 — `grep -q 'Rindle.Capability.configured_gcs_profiles' lib/rindle/ops/runtime_checks.ex`             | PASS                                                                                                                                                                                                |
| 11 | WARNING 3 — `grep -q 'gcs_extra =' lib/rindle/ops/runtime_checks.ex`                                           | PASS                                                                                                                                                                                                |
| 12 | WARNING 5 — `grep -q 'verify_gcs_signing_key(other) when is_map(other)' lib/rindle/ops/runtime_checks.ex`      | PASS                                                                                                                                                                                                |
| 13 | BLOCKER 2 — `grep -q 'def probe_gcs_bucket(bucket' lib/rindle/ops/runtime_checks.ex` AND `def do_probe(bucket` | PASS                                                                                                                                                                                                |
| 14 | BLOCKER 2 — `grep -q 'Finch.build(:get' lib/rindle/ops/runtime_checks.ex` AND `Goth.fetch(...)`                | PASS                                                                                                                                                                                                |
| 15 | BLOCKER 2 — `! grep -q 'syntactic-only check' lib/rindle/ops/runtime_checks.ex`                                | PASS — no stub probe text                                                                                                                                                                           |
| 16 | `mix rindle.doctor` (no GCS profile configured) — ZERO `gcs_*` rows                                            | PASS — `mix rindle.doctor 2>&1 \| grep -c 'gcs_'` returns 0                                                                                                                                         |
| 17 | `mix rindle.doctor` (GCS profile, no Finch/Goth) — `doctor.gcs_bucket_reachable` mentions Finch/Goth           | PASS by code inspection (the `:precondition_missing` branch in `check_gcs_bucket_reachable/2` always names the precondition); not exercised here because no in-tree profile uses GCS                |
| 18 | PEM-body redaction — `grep -c 'inspect(exception.__struct__)' lib/rindle/ops/runtime_checks.ex` >= 3           | PASS — 4 matches (1 streaming + 3 GCS)                                                                                                                                                              |
| 19 | BLOCKER 2 / mix.exs — `:finch` in `dialyzer.plt_add_apps`                                                      | PASS — Plan 01 already added it                                                                                                                                                                     |

## Deferred Issues

None new from Plan 04. The pre-existing `Rindle.ApplicationTest` AV profile leakage failures and `Rindle.Probe.AVProbeTest` `:epipe` flake remain documented in `.planning/phases/37-gcs-adapter-foundation/deferred-items.md` (created by Plan 01).

## Threat Surface Scan

No new security-relevant surface beyond what the plan's `<threat_model>` already covers:

- **T-37-04-01 (fork-PR secret leakage)** — mitigated. `if: ${{ secrets.GOOGLE_APPLICATION_CREDENTIALS_JSON != '' }}` evaluates to `''` on fork PRs (the `pull_request` trigger is preserved; `pull_request_target` is NOT introduced). The `gcs-soak` lane skips cleanly.
- **T-37-04-02 (CI log secret echo)** — mitigated. The `gcs-soak` job does not `echo` or `cat` the secret. The secret is propagated via `env:` block and consumed by the test process at module-load (Plan 03's `@gcs_credentials System.get_env(...)`). GitHub Actions auto-redacts known-secret values from logs.
- **T-37-04-03 (PEM/JSON in doctor on signing-key parse failure)** — mitigated. `verify_gcs_signing_key/1` rescue clauses emit only `inspect(exception.__struct__)`. Test invariants hold: `refute check.summary =~ ~r/-----BEGIN/` AND `refute check.summary =~ ~r/private_key/`.
- **T-37-04-04 (false-positive doctor noise on image-only adopters)** — mitigated. Conditional splice (`gcs_extra = if gcs_profiles(profiles) != [], do: [...], else: []`) means image-only S3 adopters get LITERAL ABSENCE of `gcs_*` rows. Test 1 and Test 2 in the new describe block enforce this with `assert gcs_rows == []` and `refute Enum.any?(report.checks, &(&1.component == :gcs))`.
- **T-37-04-05 (Goth exception leakage)** — mitigated. `fetch_gcs_goth_token/1` returns `{:error, exception.__struct__}` (the exception MODULE NAME) on the `{:error, exception}` branch when the value is a struct, and `{:error, :noproc}` on the `:exit` catch and `{:error, :argument_error}` on the `rescue ArgumentError`. The doctor row's summary embeds `inspect(reason)` — only struct module names + atoms can appear, never exception messages.
- **T-37-04-06 (test fixture key leakage)** — accept. `Rindle.Storage.GCS.SigningKeyFixture.fixture_json/0` regenerates a fresh PKCS#1 RSA key per ExUnit run; never persists; no real GCP authority. Per Plan 02 lock.
- **T-37-04-07 (false-negative on bucket reachability when preconditions missing)** — mitigated. `probe_gcs_bucket/4` precondition guards return `{:precondition_missing, atom}` for each missing precondition; the doctor row maps to `error_result` with the `@gcs_precondition_fix` fix string. HONEST about why no probe ran. Test ("error_result with precondition_missing when Finch is not configured") enforces.
- **T-37-04-08 (bearer/body/key in error_result summary)** — mitigated. `Finch.request/2` errors are atoms / `%Mint.TransportError{}` structs only — never raw response bodies. `Goth.fetch/1` errors surface as exception structs. `inspect(reason)` echoes only struct module names + atoms. Test ("doctor row: probe error_result NEVER echoes bearer token (security invariant)") enforces with `refute check.summary =~ ~r/Bearer ey/` and `refute check.summary =~ ~r/-----BEGIN/`.

No `threat_flag` entries to add. No new security-relevant surface beyond what the threat model catalogs.

## Self-Check: PASSED

- [x] `.github/workflows/ci.yml` modified (FOUND in `git diff` of commit `083aa93`)
- [x] `lib/rindle/capability.ex` modified (FOUND in `git diff` of commit `4c9b8e5`)
- [x] `lib/rindle/ops/runtime_checks.ex` modified (FOUND in `git diff` of commit `4c9b8e5`)
- [x] `test/rindle/ops/runtime_checks_test.exs` modified (FOUND in `git diff` of commits `2eaf0a6` and `4c9b8e5`)
- [x] Commit `083aa93` (Task 1) — FOUND in `git log --oneline`
- [x] Commit `2eaf0a6` (Task 2) — FOUND in `git log --oneline`
- [x] Commit `4c9b8e5` (Task 3) — FOUND in `git log --oneline`
- [x] All 22 `runtime_checks_test.exs` tests GREEN (`mix test test/rindle/ops/runtime_checks_test.exs` exit 0)
- [x] All 27 GCS Plan 01-03 tests STILL GREEN (no Wave 1/2/3 regression)
- [x] `mix compile --warnings-as-errors` exits 0
- [x] `gcs-soak` job in CI workflow with secret-gating `if:` clause
- [x] `Rindle.Capability.configured_gcs_profiles/1` exists
- [x] `runtime_checks.ex` `gcs_profiles/1` delegates through Capability
- [x] Conditional fn-ref splice in `run/2` (image-only adopters see ZERO `gcs_*` rows — verified locally)
- [x] `probe_gcs_bucket/4` + `do_probe/4` are public `def` (with `@doc false`)
- [x] Real `Finch.build(:get, ...)` + `Finch.request(...)` issuance, NOT a stub
- [x] All 4 precondition atoms (`:finch_unavailable`, `:finch_not_configured`, `:goth_unavailable`, `:goth_not_configured`)
- [x] All 5 probe return shapes (`:ok`, `{:bucket_missing, _}`, `{:unexpected_status, _}`, `{:probe_error, _}`, `{:precondition_missing, _}`)
- [x] `verify_gcs_signing_key/1` catchall uses explicit `is_map/1` + plain catchall (WARNING 5)
- [x] `inspect(exception.__struct__)` redaction primitive present (4 matches; 1 streaming + 3 GCS)
- [x] Plan 01's `:finch` PLT entry preserved in `mix.exs`

## TDD Gate Compliance

This plan has `type: execute` (not `type: tdd`), but each task was tagged `tdd="true"` and followed the RED → GREEN cycle:

- **Task 1 (`feat(37-04): add gcs-soak CI job ...` commit `083aa93`)** — CI workflow change. No RED gate (workflow YAML has no test surface; YAML lint-validates as the verification step).
- **Task 2 (`test(37-04): add RED tests for GCS doctor checks ...` commit `2eaf0a6`)** — RED gate. 14 of 16 new tests fail at run-time with `UndefinedFunctionError` on `RuntimeChecks.probe_gcs_bucket/3,4` and `do_probe/4` (the SUT functions don't exist yet). The two new tests that pre-pass (`"S3-only adopter sees zero gcs_ rows in doctor.checks"` and `"S3-only adopter mixed with non-storage profiles: still zero gcs_ rows"`) pre-pass because the LocalProfile branch never traverses the SUT — the `gcs_profiles/1` filter returns `[]` and the conditional splice produces an empty `gcs_extra`. This is the expected RED behavior: tests that DO exercise the SUT fail; tests that gate on absence pre-pass. Existing 6 streaming-check tests stay green.
- **Task 3 (`feat(37-04): implement GCS doctor checks ...` commit `4c9b8e5`)** — GREEN gate. All 22 tests pass (6 pre-existing + 16 new GCS-related). `mix compile --warnings-as-errors` exit 0. The `:token` opt seam Rule 3 fix was rolled into this GREEN commit because the seam is mechanically inseparable from the GREEN implementation (the test contract cannot be GREEN without it).

REFACTOR was unnecessary; the implementation matched the locked plan skeleton verbatim plus the documented `:token` seam Rule 3 fix.

## Phase 37 Closure

**All four GCS requirements complete.**

| Requirement | Plan  | Status |
| ----------- | ----- | ------ |
| GCS-01      | 37-01 | DONE — `Rindle.Storage.GCS.Client` (HTTP plumbing) |
| GCS-02      | 37-03 | DONE — `Rindle.Storage.GCS.capabilities/0 == [:signed_url, :head]` (exhaustive `==` lock) |
| GCS-03      | 37-02 | DONE — `Rindle.Storage.GCS.Signer.url/3` (V4 signed URLs, Q5 LOCKED dispatch) |
| GCS-04      | 37-04 | DONE — `gcs-soak` CI lane + D-13 doctor extension |

**Phase ROADMAP success criteria 1-5:**

1. ✅ `Rindle.Storage.GCS` exports the 5 active behaviour callbacks (Plan 03)
2. ✅ `capabilities/0 == [:signed_url, :head]` (Plan 03 — exhaustive `==` in both `gcs_test.exs` and `storage_adapter_test.exs`)
3. ✅ V4 signed URL generation via `gcs_signed_url ~> 0.4.6` Client mode (Plan 02)
4. ✅ Bucket-level integration via `Rindle.Storage.GCS.Client` over Finch JSON API (Plan 01)
5. ✅ `mix rindle.doctor` reports Goth/bucket/signing-key health when a GCS profile is configured; image-only adopters see zero new doctor noise (Plan 04 — D-13 LOCKED, real HTTP probe with honest precondition guards)

Phase 37 is closed. Resumable upload work (Phases 38–41) is the next milestone; this phase's deliverables (Client, Signer, public adapter, capabilities lock, CI lane, doctor extension) form the foundation those phases will layer on without restructuring.

## Hand-off

This plan completes Phase 37. There is no Plan 05.

Phase 38 (RESUMABLE-01..03) inherits:
- The optional `goth`/`finch`/`gcs_signed_url` deps from Plan 01 — no further `mix deps.get` needed.
- The `Rindle.Storage.GCS.Client` HTTP plumbing module — Phase 38's resumable upload session manager calls `Client.head/3` to verify-completion.
- The `Rindle.Capability.configured_gcs_profiles/1` filter — Phase 41's resumable-CORS doctor check (RESUMABLE-13) reuses the same canonical filter without inlining.
- The `:token` test-only opt convention — Phase 38/39 unit tests inherit the same Bypass-mocked seam discipline.
- The conditional fn-ref splice pattern in `run/2` — Phase 41's RESUMABLE-13 layers a `gcs_resumable_extra` block on top of `gcs_extra` using the same `if profile_predicate, do: [...], else: []` shape.

Phase 39 (RESUMABLE-04..08) inherits:
- The `capabilities/0 == [:signed_url, :head]` exhaustive `==` lock — Phase 39's PR will deliberately rewrite both assertions in `gcs_test.exs:32` AND `storage_adapter_test.exs:80` when promoting `:resumable_upload` and `:resumable_upload_session` from reserved to shipped.
