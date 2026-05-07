---
phase: 35-signed-webhook-plug-idempotent-ingest
plan: 01
subsystem: delivery
tags: [webhook, plug, hmac, body-reader, security, mux, replay-protection, multi-secret-rotation, telemetry, dispatch-table]

# Dependency graph
requires:
  - phase: 33-streaming-provider-boundary
    provides: Rindle.Streaming.Provider behaviour with verify_webhook/3 callback contract; provider_event() typespec
  - phase: 34-mux-rest-adapter-server-push-sync
    provides: Rindle.Streaming.Provider.Mux verify_webhook/3 implementation (Mux.Webhooks.verify_header/4 + multi-secret loop + Event.normalize)
provides:
  - Rindle.Delivery.WebhookPlug — mountable @behaviour Plug with init/1 opts validation, POST-only call/2, secrets resolver (4 shapes), HMAC verify-and-enqueue pipeline, locked response code table (202/200/400/405/500/503), Plug-edge telemetry
  - Rindle.Delivery.WebhookBodyReader — Plug.Parsers :body_reader MFA contract; drains chunked reads, enforces 1 MiB hard cap, caches body in conn.assigns[:raw_body] as list of binaries (multipart-safe); raw_body/1 accessor
  - Rindle.Streaming.Provider.Mux.dispatch_kind/1 — :dispatch | :drop allowlist for the Plug-side DROP table
  - Rindle.Streaming.Provider.Mux provider-internal telemetry inside verify_webhook/3 ([:rindle, :provider, :mux, :webhook_attempt, :secret_used | :rejected])
affects: [35-02-worker, 35-03-test-fixtures, 35-04-runtime-status, 36-mux-onboarding, 37-direct-creator-upload]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Mountable provider-aware Plug — one forward per provider (Stripe.WebhookPlug parity); behaviour seam is verify_webhook/3 on the provider module"
    - "Raw-body cache via Plug.Parsers :body_reader MFA — body in conn.assigns[:raw_body] as list of binaries, raw_body/1 accessor with reverse-iodata-join"
    - "Multi-secret rotation resolver — 4 shapes: [binary()] / {:system, env_var} / {:application, app, [atom()]} / 0-arity fn; resolved at call/2 time, NOT init/1, so runtime rotation works without app restart"
    - "Provider-internal telemetry (additive, public callback contract unchanged) — operators distinguish secret-rotation issues from upstream queue lag via [:rindle, :provider, :mux, :webhook_attempt, _] events"
    - "Plug-side DROP table via provider.dispatch_kind/1 — :drop returns 200 OK + telemetry kind: :dropped (no Oban work); :dispatch enqueues worker"

key-files:
  created:
    - lib/rindle/delivery/webhook_plug.ex
    - lib/rindle/delivery/webhook_body_reader.ex
    - test/rindle/delivery/webhook_body_reader_test.exs
  modified:
    - lib/rindle/streaming/provider/mux.ex

key-decisions:
  - "D-01..D-05 implemented: mountable Plug, init/1 opts (provider + secrets), init/1 validation with ArgumentError, POST-only call/2 (405 on others), lowercase-only header lookup"
  - "D-06..D-10, D-16 implemented: list-of-binaries assigns shape, drain {:more, _, conn} loop, 1 MiB cap with {:error, :too_large}, body reader in adopter endpoint.ex globally, raw_body/1 accessor with read_body fallback, 500 server_misconfigured on body-reader-missing"
  - "D-11..D-15 implemented: provider.verify_webhook/3 inside try/rescue (rescue → 400 + provider_callback_raised telemetry), 400 + no_secrets_configured on empty secrets, 202 happy path, 400 provider_webhook_invalid on sig_mismatch, 503 oban_unavailable on Oban.insert/1 rescue"
  - "D-17 implemented: provider-internal telemetry inside Mux.verify_webhook/3 ([:rindle, :provider, :mux, :webhook_attempt, :secret_used | :rejected]); public callback contract unchanged"
  - "D-28 implemented: dispatch_kind/1 allowlist on Rindle.Streaming.Provider.Mux — :dispatch for video.asset.{ready,errored,deleted,created} + video.upload.asset_created (Phase 37 forward-compat); :drop for the Mux 2026 catalog noise + default-drop for unknown event types"
  - "D-05 cleanup applied: removed dead fetch_sig_header/1 case-fork checking both 'mux-signature' and 'Mux-Signature' — Plug.Conn lowercases all headers per HTTP/2 spec; only 'mux-signature' lookup remains"

patterns-established:
  - "Webhook trust boundary at Plug edge: HMAC verify in Plug; worker (Plan 02) trusts upstream verification (no raw_body in Oban args)"
  - "Multi-secret rotation telemetry pattern: SDK-internal :secret_used event records secret_index so operators can confirm rotation completed before retiring previous secret"
  - "Provider-callback rescue pattern: try/rescue around provider.verify_webhook/3 surfaces Exception.message(e) ONLY in telemetry metadata, NEVER in 400 response body (T-35-10)"
  - "Forward-compat default: dispatch_kind/1 falls through to :drop for unknown event types — Mux ships novelty regularly, library should not crash or queue work for unrecognized types"

requirements-completed: [MUX-09, MUX-10, MUX-11, MUX-12, MUX-13]

# Metrics
duration: ~25min
completed: 2026-05-07
---

# Phase 35 Plan 01: Mountable WebhookPlug + Raw-Body Cache + Mux Dispatch Helpers Summary

**Mountable Rindle.Delivery.WebhookPlug + Rindle.Delivery.WebhookBodyReader pair (1 MiB raw-body cache via Plug.Parsers :body_reader MFA, multi-secret rotation, replay-window via Mux.Webhooks.verify_header/4, locked 202/200/400/405/500/503 response codes, [:rindle, :provider, :webhook, :verified | :rejected] telemetry) + dispatch_kind/1 allowlist + provider-internal telemetry on Rindle.Streaming.Provider.Mux**

## Performance

- **Duration:** ~25 min (fixture timer not started — wall-clock estimate from commit timestamps)
- **Started:** 2026-05-07T02:05:00Z (approximate; first commit at 2026-05-07T02:13Z based on session)
- **Completed:** 2026-05-07T02:30:26Z
- **Tasks:** 3 (1 TDD with RED+GREEN commits, 2 auto)
- **Files created:** 3 (webhook_plug.ex, webhook_body_reader.ex, webhook_body_reader_test.exs)
- **Files modified:** 1 (mux.ex)

## Accomplishments

- Shipped the mountable `Rindle.Delivery.WebhookPlug` so adopters can mount Mux webhook ingestion via a single `forward "/webhooks/rindle/mux", Rindle.Delivery.WebhookPlug, ...` declaration in their router.
- Shipped `Rindle.Delivery.WebhookBodyReader` with the canonical Stripe/Plaid/Mux pattern: list-of-binaries cache in `conn.assigns[:raw_body]` (multipart-safe), 1 MiB hard cap, drain loop over `{:more, _, conn}` reads that `Plug.Parsers.JSON.decode/3` does not loop on.
- Added the `dispatch_kind/1` allowlist on `Rindle.Streaming.Provider.Mux` so the Plug can drop noise events (master files, tracks, static renditions, live-stream, upload lifecycle) with 200 OK + telemetry, no Oban work.
- Added provider-internal telemetry inside `Rindle.Streaming.Provider.Mux.verify_webhook/3` (`:secret_used` + `:rejected` events) so operators can distinguish secret-rotation issues from upstream queue lag without changing the public callback contract.
- Removed the dead `fetch_sig_header/1` case-fork that checked both `Mux-Signature` and `mux-signature` — `Plug.Conn` lowercases all request headers per HTTP/2 spec, so the uppercase branch was unreachable from the Plug edge and inconsistent with the existing test maps (which already used lowercase).

## Task Commits

1. **Task 1 RED: failing tests for WebhookBodyReader** — `900d4e3` (test)
2. **Task 1 GREEN: implement Rindle.Delivery.WebhookBodyReader** — `b729a6e` (feat)
3. **Task 2: dispatch_kind/1 + provider-internal telemetry on Mux** — `053ba4d` (feat)
4. **Task 3: implement Rindle.Delivery.WebhookPlug** — `85a1c8d` (feat)

_Note: Task 1 followed TDD; Tasks 2 and 3 were implementation-only (Task 3's tests are deferred to Plan 03 because they depend on the signing helper that ships there)._

## Files Created/Modified

- `lib/rindle/delivery/webhook_plug.ex` — created. Mountable `@behaviour Plug`. `init/1` validates provider exports `verify_webhook/3` and that `:secrets` is one of the four locked resolver shapes (raises `ArgumentError` otherwise). `call/2` enforces POST-only (405 on others), resolves secrets at call time (runtime rotation), reads raw body via `WebhookBodyReader.raw_body/1` with `Plug.Conn.read_body/2` fallback (500 on body-reader-missing), invokes `provider.verify_webhook/3` inside try/rescue, dispatches via `provider.dispatch_kind/1` (200 on :drop, 202 on :dispatch enqueue with `Oban.insert/1` wrapped in try/rescue → 503), emits `[:rindle, :provider, :webhook, :verified | :rejected]` telemetry. Forward-references `Rindle.Workers.IngestProviderWebhook` (ships in Plan 02) — `@compile {:no_warn_undefined, ...}` keeps `--warnings-as-errors` clean.
- `lib/rindle/delivery/webhook_body_reader.ex` — created. `read_body/2` MFA contract (drains `{:more, _, conn}` chunks, caps at 1 MiB, caches in `conn.assigns[:raw_body]` as list-of-binaries most-recent-first); `raw_body/1` accessor (single-binary list returns `List.first`; multi-chunk list returns `Enum.reverse |> IO.iodata_to_binary`; missing assign returns `nil`). Module is public — adopters wire it into `endpoint.ex` Plug.Parsers `:body_reader` option.
- `test/rindle/delivery/webhook_body_reader_test.exs` — created. 7 ExUnit tests: small-body cache, chunked drains over 8KB, 1 MiB cap rejection, exact-boundary acceptance, raw_body/1 nil/single/multi-chunk shapes.
- `lib/rindle/streaming/provider/mux.ex` — modified. Three additive edits: (1) `verify_webhook/3` body instrumented with provider-internal telemetry on `:secret_used` (with `secret_index`) and `:rejected` (with `secret_index` + `sdk_reason`); the public callback contract `{:ok, provider_event()} | {:error, :provider_webhook_invalid}` is unchanged. (2) `dispatch_kind/1` added — function-head allowlist for `:dispatch` events, prefix-matched DROP table for noise events, default-drop for unknown types. (3) Dead `fetch_sig_header/1` case-fork removed — only lowercase `"mux-signature"` lookup remains (D-05). The function is `@doc false` (internal helper) per plan-checker fix.

## Decisions Made

None — followed plan as specified. All implementation decisions (D-01..D-17, D-28) were locked in `35-CONTEXT.md` before execution and implemented verbatim, with the single planner-flagged caveat applied (the `do_read_body` `{:ok, ...}` branch uses the corrected join-then-prepend logic per the plan's "NOTE on the do_read_body" footnote, not the buggy first-listed body that the plan author included for contrast).

## Deviations from Plan

None - plan executed exactly as written. The plan was unusually high-fidelity (every response code, every telemetry event, every secret-resolver shape was locked in CONTEXT.md before execution), and `mix format` flagged a single line-length wrap on `valid_secrets_resolver?/1` that was applied silently as part of normal formatting.

**Total deviations:** 0 auto-fixed
**Impact on plan:** None.

## Issues Encountered

- Worktree lacked `deps/` so the first `mix test` invocation failed with "the dependency is not available". Resolved by running `mix deps.get` (one-time bootstrap; not a code issue). Subsequent test runs were clean.

## User Setup Required

None — no external service configuration required. Adopters in v1.6 will need `RINDLE_MUX_WEBHOOK_SECRETS` set, but the documented onboarding lives in Phase 36 (`Rindle.Profile.Presets.MuxWeb`, `mix rindle.doctor` streaming validation, `guides/streaming_providers.md`).

## Next Phase Readiness

Plan 35-02 (`Rindle.Workers.IngestProviderWebhook` + `Event.normalize/1` extension + end-to-end Plug tests) is unblocked:

- The Plug forward-references `Rindle.Workers.IngestProviderWebhook.new/2` with the locked args shape (`%{"event_id", "provider", "event_type", "event"}`) and Oban unique opts `[fields: [:args], keys: [:event_id], states: [:scheduled, :executing, :retryable], period: 86_400]`. Plan 02 implements the worker module and the matching `Oban.Worker` callbacks (`perform/1`, `timeout/1`, race-snooze for missing rows).
- `Rindle.Streaming.Provider.Mux.dispatch_kind/1` is in place so the worker's dispatch table can be a thin pattern-match on `event_type` rather than re-deriving the allowlist.

Plan 35-03 (test fixtures + signing helper) is unblocked — fixtures will exercise the Plug end-to-end via `Plug.Test.conn(:post, "/webhooks/rindle/mux", body)` plus the `mux-signature` HMAC header derived from `Mux.Webhooks.TestUtils.generate_signature/2`.

Plan 35-04 (`mix rindle.runtime_status --provider-stuck`) is unblocked but not yet wired to Plan 02's worker telemetry; Plan 02 ships the dependency.

## Self-Check

Verifying claims before returning.

- `lib/rindle/delivery/webhook_plug.ex`: FOUND
- `lib/rindle/delivery/webhook_body_reader.ex`: FOUND
- `test/rindle/delivery/webhook_body_reader_test.exs`: FOUND
- `lib/rindle/streaming/provider/mux.ex` (modified): FOUND
- Commit `900d4e3`: FOUND (Task 1 RED)
- Commit `b729a6e`: FOUND (Task 1 GREEN)
- Commit `053ba4d`: FOUND (Task 2)
- Commit `85a1c8d`: FOUND (Task 3)

## Self-Check: PASSED

---
*Phase: 35-signed-webhook-plug-idempotent-ingest*
*Completed: 2026-05-07*
