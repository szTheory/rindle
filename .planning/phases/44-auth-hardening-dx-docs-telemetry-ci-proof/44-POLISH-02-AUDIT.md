---
phase: 44-auth-hardening-dx-docs-telemetry-ci-proof
artifact: POLISH-02
source_review: .planning/milestones/v1.6-phases/35-signed-webhook-plug-idempotent-ingest/35-REVIEW.md
status: complete
---

# Phase 44 POLISH-02 Audit

This audit records the explicit disposition for every advisory finding from the
Phase 35 review. Per D-12, warning-level trust-boundary items are fixed where
they materially strengthen the shipped contract. Per D-13, info-only items are
either already resolved elsewhere in the tree or explicitly waived when they do
not change current adopter-facing behavior.

## WR-01

- disposition: resolved
- rationale: Phase 44 fixes the fallback body-cap gap exactly as required by D-12. `WebhookPlug.fetch_raw_body/1` now caps the fallback `Plug.Conn.read_body/2` call at `1_048_576` bytes and treats `{:more, ...}` as `:body_missing`, so a missing `body_reader` hook cannot silently widen the trust boundary.
- file: `lib/rindle/delivery/webhook_plug.ex`
- file: `test/rindle/delivery/webhook_plug_test.exs`
- decision: D-12

## WR-02

- disposition: resolved
- rationale: The Plug now delegates directly to `IngestProviderWebhook.unique_job_opts/0`, so the enqueue path and worker share one idempotency source of truth instead of duplicating unique-job configuration inline.
- file: `lib/rindle/delivery/webhook_plug.ex`
- decision: D-12

## WR-03

- disposition: resolved
- rationale: `WebhookPlug.init/1` rejects `{:application, app, []}` by requiring a non-empty path, so the documented boot-time validation contract matches runtime behavior.
- file: `lib/rindle/delivery/webhook_plug.ex`
- decision: D-12

## WR-04

- disposition: resolved
- rationale: Mux webhook tolerance is normalized through `get_tolerance/0`, which falls back to a sane integer default when config is nil or invalid. The verify path no longer relies on an unchecked `Keyword.get/3` result.
- file: `lib/rindle/streaming/provider/mux.ex`
- decision: D-12

## WR-05

- disposition: resolved
- rationale: Verified webhook payloads without a top-level event id are rejected before enqueue, preventing `nil`-keyed Oban uniqueness collisions and keeping telemetry honest.
- file: `lib/rindle/delivery/webhook_plug.ex`
- decision: D-12

## WR-06

- disposition: resolved
- rationale: `runtime_status/1` now computes subreports once and builds recommendations from those in-memory results instead of rerunning the same queries for recommendation harvesting.
- file: `lib/rindle/ops/runtime_status.ex`
- decision: D-12

## IN-01

- disposition: waived
- rationale: The Mux SDK timestamp check remains one-sided, but this is an upstream SDK behavior note rather than a current adopter-facing defect in Rindle’s signed-webhook contract. Phase 44 keeps the boundary explicit rather than forking provider verification logic.
- file: `lib/rindle/streaming/provider/mux.ex`
- decision: D-13

## IN-02

- disposition: waived
- rationale: Iteration continues after a JSON parse failure on a verified secret, but the public outcome remains `{:error, :provider_webhook_invalid}` and does not widen the trust boundary. Phase 44 does not broaden scope into provider-internal control-flow cleanup.
- file: `lib/rindle/streaming/provider/mux.ex`
- decision: D-13

## IN-03

- disposition: resolved
- rationale: Dynamic provider atom creation is no longer used on the signed-webhook path; provider names are normalized through explicit helpers and current code comments document the remaining safe cases.
- file: `lib/rindle/delivery/webhook_plug.ex`
- file: `lib/rindle/streaming/provider/mux.ex`
- decision: D-13

## IN-04

- disposition: resolved
- rationale: The originally speculative tie-breaker concern was closed by live MinIO regression coverage in Phase 43, which proves the reaper and abort paths behave correctly against real backing state.
- file: `.planning/phases/43-s3-multipart-backing-minio-proof/43-VERIFICATION.md`
- decision: D-13

## IN-05

- disposition: waived
- rationale: FSM rejection on idempotent retransmits is still an implementation quality note, but Phase 44 is intentionally scoped to auth, docs, telemetry, and trust-boundary DX. The current behavior is explicit and does not misreport success to adopters.
- file: `lib/rindle/workers/ingest_provider_webhook.ex`
- decision: D-13

## IN-06

- disposition: waived
- rationale: `last_sync_error` may still surface in operator-facing reports by design; keeping that breadcrumb is more useful than suppressing provider failure context, and Phase 44 does not change the runtime-status disclosure posture.
- file: `lib/rindle/ops/runtime_status.ex`
- decision: D-13

## IN-07

- disposition: waived
- rationale: `stringify_event/1` still does not recursively stringify every nested atom-keyed map shape, but Phase 44 does not add nested atom-key payloads on this boundary and the current verified provider payloads already normalize into the supported storage shape.
- file: `lib/rindle/delivery/webhook_plug.ex`
- decision: D-13
