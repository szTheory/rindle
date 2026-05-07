---
phase: 35
slug: signed-webhook-plug-idempotent-ingest
status: verified
threats_open: 0
asvs_level: 1
created: 2026-05-07
---

# Phase 35 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.
> Phase 35 lands the mountable `Rindle.Delivery.WebhookPlug` (Plan 01), the
> idempotent `Rindle.Workers.IngestProviderWebhook` Oban worker + Mux Event
> typed branch (Plan 02), the test-only signing helper + JSON fixtures
> (Plan 03), and the `mix rindle.runtime_status --provider-stuck` operator
> filter (Plan 04). The HMAC-verified Plug edge is the trust boundary; the
> worker, PubSub, and operator-facing CLI all consume verified-and-normalized
> data with `provider_asset_id` redacted at every adopter-facing emit site.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Mux → adopter HTTPS endpoint | Untrusted POST body. HMAC-SHA256 in `Mux-Signature` header is the only authenticator. | Raw JSON body up to 1 MiB; signed-payload `"<ts>.<body>"`. |
| `Plug.Parsers` → `Rindle.Delivery.WebhookBodyReader` | Body-reader MFA contract. Hostile bodies traverse here BEFORE HMAC verification. | Raw bytes; cached as list-of-binaries in `conn.assigns[:raw_body]`. |
| `Rindle.Delivery.WebhookPlug` → `Rindle.Workers.IngestProviderWebhook` (Oban DB) | Verified-but-untrusted normalized event in Oban args jsonb. The Plug is the trust boundary; the worker trusts upstream verification. | Stringified-keys event map (NO `raw_body`); `event_id` for unique-job dedup. |
| `Rindle.Workers.IngestProviderWebhook` → `media_provider_assets` | FSM-validated `Repo.update` against the matched row. | Normalized FSM transition payload + `playback_ids` + `last_sync_error`. |
| `Rindle.Workers.IngestProviderWebhook` → `Phoenix.PubSub` | Public subscribers receive `{:rindle_event, _, payload}` on two topics keyed by `MediaAsset.id`. | Public payload — `provider_asset_id` FORBIDDEN per security invariant 14. |
| `Mux.Event.normalize/1` → `provider_event` map | `data.id` vs `data.asset_id` for `video.upload.asset_created` is the silent-corruption surface. | Typed branch maps `data.asset_id → :provider_asset_id` and `data.id → :upload_id`. |
| `mix rindle.runtime_status --provider-stuck` → operator terminal / CI logs | Operator-facing console output. Sensitive `provider_asset_id` MUST be redacted. | Sample rows — `provider_asset_id` routed through `MediaProviderAsset.redact_id/1`. |

---

## Threat Register

All 31 threats verified against implementation by file:line citation.

| Threat ID | Category | Component | Disposition | Mitigation Evidence | Status |
|-----------|----------|-----------|-------------|---------------------|--------|
| T-35-01 | Spoofing | `Rindle.Delivery.WebhookPlug.call/2` HMAC verify | mitigate | `Mux.Webhooks.verify_header/4` constant-time compare invoked per secret in loop at `lib/rindle/streaming/provider/mux.ex:285`; mismatch returns `{:error, :provider_webhook_invalid}` (line 284 init) → Plug `send_invalid` at `lib/rindle/delivery/webhook_plug.ex:289-293` | closed |
| T-35-02 | Tampering | Webhook payload during transit | mitigate | HMAC signature covers `"<ts>.<body>"`; `verify_header/4` (SDK) called at `lib/rindle/streaming/provider/mux.ex:285` over the raw body fetched at `lib/rindle/delivery/webhook_plug.ex:223-237` (`fetch_raw_body/1`) | closed |
| T-35-03 | Repudiation | Replay attack with stale timestamp | mitigate | Tolerance loaded from config (`webhook_tolerance_seconds`, default 300s) at `lib/rindle/streaming/provider/mux.ex:276` and passed to `verify_header/4` at line 285; SDK rejects stale ts; SDK telemetry at line 302-305 lets operators distinguish reason via `sdk_reason` metadata | closed |
| T-35-04 | Repudiation | Secret rotation failure | mitigate | Multi-secret loop with `Enum.with_index` + first-match-wins at `lib/rindle/streaming/provider/mux.ex:282-284`; `secret_used` telemetry with `secret_index` emitted at lines 287-291 — operators can confirm rotation completed before retiring previous secret | closed |
| T-35-05 | Information disclosure | `provider_asset_id` in Plug-edge telemetry | mitigate | Plug emits only `event_id` (Mux UUID, public) + `event_type` (raw string) in `:verified` metadata at `lib/rindle/delivery/webhook_plug.ex:157-162, 192-197`; `:rejected` metadata never includes `provider_asset_id` (lines 295-301). No `provider_asset_id` field present in either emit helper | closed |
| T-35-06 | Denial of service | Large bodies exhaust memory | mitigate | 1 MiB hard cap `@max_body_bytes 1_048_576` declared at `lib/rindle/delivery/webhook_body_reader.ex:38`; enforced on both `:ok` (line 59) and `:more` (line 72) chunk paths; over-limit returns `{:error, :too_large}` at lines 60, 73 | closed |
| T-35-07 | Denial of service | Oban DB pool exhaustion | mitigate | `Oban.insert/1` wrapped in `try/rescue` at `lib/rindle/delivery/webhook_plug.ex:166-210`; rescue branch (lines 200-209) emits `:oban_unavailable` telemetry and `send_resp(503, "")` so Mux retries | closed |
| T-35-08 | Elevation of privilege | Provider callback module substituted by adopter | accept | See Accepted Risks Log entry R-35-08. `init/1` at `lib/rindle/delivery/webhook_plug.ex:88-91` raises `ArgumentError` if `:provider` doesn't export `verify_webhook/3` — that boundary protection is implemented | closed |
| T-35-09 | Tampering | Empty `:secrets` config bypass | mitigate | `secrets == []` guard at `lib/rindle/delivery/webhook_plug.ex:115-117` emits `:no_secrets_configured` telemetry and calls `send_invalid/1` (400 `provider_webhook_invalid`); NEVER 200 without verification | closed |
| T-35-10 | Information disclosure | Provider callback raises and leaks state | mitigate | `safe_verify/4` at `lib/rindle/delivery/webhook_plug.ex:214-221` wraps `provider.verify_webhook/3` in `try/rescue`; rescue returns `{:error, :callback_raised, message}`; handler at lines 140-146 puts message ONLY in telemetry metadata `:error` field — response body is generic `provider_webhook_invalid` via `send_invalid/1` | closed |
| T-35-11 | Spoofing | Header-case ambiguity | mitigate | Dead `Mux-Signature` case-fork removed; `fetch_sig_header/1` at `lib/rindle/streaming/provider/mux.ex:361-366` uses lowercase `"mux-signature"` only. `grep -v '^#' ... | grep -c 'Mux-Signature'` returns 0 | closed |
| T-35-12 | Denial of service | Unknown event types create unbounded queue | mitigate | `dispatch_kind/1` allowlist at `lib/rindle/streaming/provider/mux.ex:338-356`; default fallthrough `def dispatch_kind(_other), do: :drop` at line 356; Plug `:drop` branch at `lib/rindle/delivery/webhook_plug.ex:155-164` returns 200 with no Oban work queued | closed |
| T-35-13 | Information disclosure | `provider_asset_id` in worker telemetry | mitigate | `emit/3` helper at `lib/rindle/workers/ingest_provider_webhook.ex:383-400` routes `provider_asset_id` through `MediaProviderAsset.redact_id/1` at line 390 BEFORE `:telemetry.execute/3`; ALL worker telemetry funnels through this single helper (15 call sites use `emit(:processed/:ignored/:exception, ...)`) | closed |
| T-35-14 | Information disclosure | `provider_asset_id` in PubSub payload | mitigate | `broadcast/2` payload at `lib/rindle/workers/ingest_provider_webhook.ex:355-363` includes only `asset_id, playback_ids, profile, provider, state` — `provider_asset_id` is FORBIDDEN per inline comment at line 362 | closed |
| T-35-15 | Information disclosure | `provider_asset_id` in PubSub topic | mitigate | Topic strings keyed by `MediaAsset.id` (`row.asset_id`) at `lib/rindle/workers/ingest_provider_webhook.ex:366-367` (`"rindle:provider_asset:#{row.asset_id}"`, `"rindle:asset:#{row.asset_id}"`); `provider_asset_id` never interpolated into topic strings | closed |
| T-35-16 | Tampering | Race-snooze leaking event metadata indefinitely | mitigate | `handle_missing_row/2` at `lib/rindle/workers/ingest_provider_webhook.ex:145-167`; snooze pushes back same `args` (no augmentation, no `raw_body`); `attempt < 5` guard bounds retries; `attempt ≥ 5` → `{:cancel, :provider_asset_row_missing}` at line 166 | closed |
| T-35-17 | Tampering | Worker payload bloat via raw body in args | mitigate | Plug enqueue args constructed at `lib/rindle/delivery/webhook_plug.ex:168-173` contain only `event_id, provider, event_type, event` (normalized verified event); `raw_body` is NEVER in args. `stringify_event/1` at lines 314-321 only includes the normalized event map | closed |
| T-35-18 | Spoofing | `video.upload.asset_created` mis-attribution of `data.id` | mitigate | Typed branch at `lib/rindle/streaming/provider/mux/event.ex:27-40` matches `"video.upload.asset_created"` BEFORE the generic clause at line 42; reads `data.asset_id` for `:provider_asset_id` (line 33) and `data.id` for `:upload_id` (line 34); `provider_event` typespec extends with optional `:upload_id` at `lib/rindle/streaming/provider.ex:64` | closed |
| T-35-19 | Denial of service | FSM rejection loops infinitely | mitigate | `transition_and_broadcast/5` at `lib/rindle/workers/ingest_provider_webhook.ex:310-344` returns `{:cancel, fsm_err}` (line 342) on `{:error, {:invalid_transition, _, _}}`; same pattern in `dispatch/3` `video.asset.created` clause at line 261 | closed |
| T-35-20 | Repudiation | Missing row dropped silently | mitigate | Race-snooze 5-attempt curve at `lib/rindle/workers/ingest_provider_webhook.ex:77, 145-157`; on exhaustion (`attempt ≥ 5`) at lines 159-167 emits `:exception` telemetry with `kind: :race_snooze_exhausted` and `{:cancel, :provider_asset_row_missing}` | closed |
| T-35-21 | Tampering | Repo error masked as success | mitigate | `transition_and_broadcast/5` at `lib/rindle/workers/ingest_provider_webhook.ex:325-332` returns `{:error, _changeset}` on changeset failure (worker retries via Oban backoff); same pattern in `video.asset.created` (line 244-251), `video.upload.asset_created` (line 280-282), and unknown-event (line 301-303) dispatch clauses | closed |
| T-35-22 | Information disclosure | `last_sync_error` field stores raw Mux message | accept | See Accepted Risks Log entry R-35-22. Inspect impl on `MediaProviderAsset` at `lib/rindle/domain/media_provider_asset.ex:119-129` redacts `provider_asset_id` and `raw_provider_metadata`; `last_sync_error` is the human-readable summary | closed |
| T-35-23 | Information disclosure | Real production secret in fixtures | mitigate | Test secret constants are placeholders: `"phase-35-test-secret-aaaa"` at `test/rindle/test/mux_webhook_fixtures_test.exs:6`, `"test_webhook_secret_phase35"` at `test/rindle/delivery/webhook_plug_test.exs:22`. Fixture JSON files contain no secrets (verified by file inspection) | closed |
| T-35-24 | Tampering | Forged stale signatures spoofing test assertions | mitigate | Helper at `test/support/mux_webhook_fixtures.ex:27-36` uses `:crypto.mac(:hmac, :sha256, secret, "<ts>.<body>")` — byte-accurate against SDK's `Mux.Webhooks.verify_header/4`. `:timestamp` override at line 28 enables replay-attack tests asserting REJECTION; verified by `test/rindle/test/mux_webhook_fixtures_test.exs` round-trip test against `Mux.Webhooks.verify_header/4` | closed |
| T-35-25 | Spoofing | Test helper enabled in `:prod` build | mitigate | `mix.exs:47` `defp elixirc_paths(:test), do: ["lib", "test/support", "test/adopter"]`; line 48 `defp elixirc_paths(_), do: ["lib"]` — `test/support/mux_webhook_fixtures.ex` is NOT compiled in `:dev` or `:prod` envs | closed |
| T-35-26 | Information disclosure | Realistic Mux-style asset IDs in fixtures | accept | See Accepted Risks Log entry R-35-26. Fixtures use synthetic IDs with obvious suffix tags: `evt-fixture-{ready,errored,deleted,created,upload-asset-created}-0001` event ids and asset ids ending in `del/rdy/err/crt/upl` (verified in `test/fixtures/mux/webhook_*.json`) | closed |
| T-35-27 | Information disclosure | Raw `provider_asset_id` printed by `mix rindle.runtime_status --provider-stuck` | mitigate | `provider_asset_sample/2` at `lib/rindle/ops/runtime_status.ex:207-225` routes `row.provider_asset_id` through `MediaProviderAsset.redact_id/1` at line 215 BEFORE inserting into the sample map; text formatter `format_provider_findings/1` at `lib/mix/tasks/rindle.runtime_status.ex:134-144` consumes the already-redacted `sample.provider_asset_id` | closed |
| T-35-28 | Information disclosure | `MediaAsset.id` exposed to operators | accept | See Accepted Risks Log entry R-35-28 | closed |
| T-35-29 | Tampering | Filter values from `OptionParser` could be exotic types | mitigate | `OptionParser.parse(args, strict: [..., provider_stuck: :boolean])` at `lib/mix/tasks/rindle.runtime_status.ex:34-42`; `normalize_provider_stuck/1` at `lib/rindle/ops/runtime_status.ex:710-713` validates `nil/true/false`, returns `{:error, {:invalid_provider_stuck, value}}` for anything else | closed |
| T-35-30 | Information disclosure | `last_sync_error` surfaces verbatim in samples | accept | See Accepted Risks Log entry R-35-30 (sibling of R-35-22) | closed |
| T-35-31 | Denial of service | Operator passes huge `--limit` value | accept | See Accepted Risks Log entry R-35-31. Existing `normalize_limit/1` at `lib/rindle/ops/runtime_status.ex:699-701` validates positive integer and falls back to `@default_limit`; reused unchanged | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| R-35-08 | T-35-08 | Adopter controls their `router.ex` mount; substituting a stub `provider` module that returns `{:ok, _}` for every input bypasses HMAC verification — but that requires push access to the adopter codebase, which is already a privileged action. The library-side protection we owe is `init/1` ArgumentError when `:provider` doesn't `function_exported?(:verify_webhook, 3)` (`lib/rindle/delivery/webhook_plug.ex:88-91`); deployment-time misconfigurations crash boot, not first-webhook delivery. | gsd-security-auditor | 2026-05-07 |
| R-35-22 | T-35-22 | The `last_sync_error` field exists by design — operators rely on it for production debugging via `mix rindle.runtime_status --provider-stuck`. Redacting it would defeat the field's purpose. The custom `Inspect` impl on `Rindle.Domain.MediaProviderAsset` (`lib/rindle/domain/media_provider_asset.ex:119-129`) already redacts `provider_asset_id` and `raw_provider_metadata`; `last_sync_error` is the operator-facing human-readable summary. Mux's documented webhook error vocabulary (`type` + `messages`) does not include `provider_asset_id`-shaped strings; the `format_error/1` builder at `lib/rindle/workers/ingest_provider_webhook.ex:406-412` joins those fields verbatim and persists at most 4096 chars (length validation at `lib/rindle/domain/media_provider_asset.ex:110`). | gsd-security-auditor | 2026-05-07 |
| R-35-26 | T-35-26 | Fixture JSON files in `test/fixtures/mux/webhook_*.json` use synthetic asset/upload IDs with obvious suffix tags (`...del017A`, `...rdy017A`, `...err017A`, `...crt017A`, `...upl017A`) and synthetic event ids (`evt-fixture-{kind}-0001`). They are shaped like Mux IDs only enough for byte-accurate test signing; they are not real production data. | gsd-security-auditor | 2026-05-07 |
| R-35-28 | T-35-28 | `MediaAsset.id` is the operator's natural key — they need it to find the corresponding `media_assets` row, look at variants, etc. Schema design (`MediaAsset.id` is a binary_id UUID, not a customer-PII identifier) makes operator-side exposure a non-issue at ASVS L1. | gsd-security-auditor | 2026-05-07 |
| R-35-30 | T-35-30 | Sibling of R-35-22 — `last_sync_error` is operator-facing diagnostic data; redacting it would defeat its purpose in `mix rindle.runtime_status --provider-stuck` output. | gsd-security-auditor | 2026-05-07 |
| R-35-31 | T-35-31 | Existing `normalize_limit/1` at `lib/rindle/ops/runtime_status.ex:699-701` caps row count via `@default_limit` fallback for invalid values and accepts only positive integers; reused unchanged from prior phases. The CLI cannot pass a non-integer to `:limit` (OptionParser strict `:integer` at `lib/mix/tasks/rindle.runtime_status.ex:38`). | gsd-security-auditor | 2026-05-07 |

*Accepted risks do not resurface in future audit runs.*

---

## Unregistered Flags

None of the four phase summaries (`35-01-SUMMARY.md` ... `35-04-SUMMARY.md`) contains a `## Threat Flags` section. Executor reported no new attack surface beyond the declared register.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-05-07 | 31 | 31 | 0 | gsd-security-auditor |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer) — 25 mitigate, 6 accept, 0 transfer.
- [x] Accepted risks documented in Accepted Risks Log — R-35-08, R-35-22, R-35-26, R-35-28, R-35-30, R-35-31.
- [x] `threats_open: 0` confirmed.
- [x] `status: verified` set in frontmatter.

**Approval:** verified 2026-05-07
