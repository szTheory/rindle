# Phase 39: Resumable Adapter Behaviour + Broker Wiring - Research

**Researched:** 2026-05-07 [VERIFIED: system date]
**Domain:** Optional storage callbacks, broker lifecycle wiring, GCS resumable JSON API mechanics, and proof strategy for brokered resumable uploads. [VERIFIED: .planning/ROADMAP.md:202-239] [VERIFIED: .planning/REQUIREMENTS.md:60-82]
**Confidence:** HIGH. [VERIFIED: repo evidence + official GCS docs + current Hex package metadata]

<user_constraints>
## User Constraints (from CONTEXT.md) [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:27-159]

### Locked Decisions

### Behaviour Contract And Capability Semantics

- **D-01:** `Rindle.Storage` adds the four optional resumable callbacks named
  in the roadmap and locked candidate:
  `initiate_resumable_upload/3`, `resumable_upload_status/3`,
  `cancel_resumable_upload/3`, and `verify_resumable_completion/3`.
- **D-02:** The callbacks stay genuinely optional at the behaviour layer.
  `Rindle.Storage.GCS` implements all four in Phase 39. `Rindle.Storage.S3`
  and `Rindle.Storage.Local` do **not** implement or advertise resumable
  support.
- **D-03:** `:resumable_upload` and `:resumable_upload_session` are shipped
  capability atoms, but their meaning must be documented in broker-first
  terms:
  - `:resumable_upload` means the adapter can mint a resumable upload and the
    broker can still converge through `verify_completion/2`
  - `:resumable_upload_session` means the adapter also supports broker-visible
    status/cancel operations
- **D-04:** `verify_resumable_completion/3` exists for adapter parity and
  lower-level escape-hatch use, but it is **not** the broker trust gate.
  Brokered completion remains `head/2`-based.

### Completion Convergence

- **D-05:** `Rindle.Upload.Broker.verify_completion/2` remains unchanged as
  the single completion path for presigned PUT, multipart, and resumable
  uploads.
- **D-06:** The durable storage-side truth for broker completion is object
  existence plus metadata via `head/2`, not session-URI state. This avoids
  dual completion semantics and keeps resumable uploads aligned with existing
  Rindle upload families.
- **D-07:** Planning/docs must explicitly call out the subtle but important
  distinction:
  `verify_resumable_completion/3` may exist on the adapter, but broker
  promotion still trusts `head/2` only.

### Broker Lifecycle Posture

- **D-08:** `initiate_resumable_session/2` mirrors the existing multipart
  posture:
  storage I/O happens before DB persistence, and persist failure triggers a
  compensating `cancel_resumable_upload/3`.
- **D-09:** The compensation flow should mirror the current
  `compensate_failed_multipart_persist/4` shape closely so maintainers see one
  obvious broker pattern rather than a second bespoke rescue design.
- **D-10:** `resumable_session_status/2` is observational by default. It may
  update durable resumable bookkeeping such as `last_known_offset`,
  `session_uri_expires_at`, and `region_hint`, but status polling alone must
  not move the lifecycle into `"resuming"` or any other more-progressed state.
- **D-11:** The `"resuming"` state remains narrow exactly as locked in Phase
  38: use it only for explicit recovery after interruption or uncertain
  completion, never for ordinary status checks.

### Public Error Vocabulary

- **D-12:** Locked public resumable failures for this phase are:
  `{:upload_unsupported, _}`, `:session_uri_expired`,
  `:session_uri_unknown`, `{:offset_mismatch, %{server: _, client: _}}`,
  `{:gcs_http_error, %{status: _, body: _}}`, `:goth_unconfigured`,
  `:missing_bucket`, and `:storage_object_missing`.
- **D-13:** `:region_pinned_initiation` is **not** a returned public error
  tuple. It is an advisory operator signal only.
- **D-14:** The current candidate doc’s treatment of
  `:region_pinned_initiation` as an error-like atom is superseded for Phase 39
  planning. If the atom survives at all, it belongs in telemetry metadata or
  internal warning classification, not in the broker success/error return
  contract.

### Region Pinning And Operator Visibility

- **D-15:** Region pinning is treated as successful initiation/status with
  visibility, not as an operation failure. The broker returns `{:ok, ...}`,
  persists `region_hint` when available, and emits telemetry that operators
  can alert on if cross-region initiation becomes a cost/performance issue.
- **D-16:** This follows the least-surprise rule for public APIs:
  returned errors mean the requested operation failed; non-fatal provider
  quirks belong in telemetry, docs, and persisted metadata.

### Cross-Adapter Honesty

- **D-17:** `Rindle.Storage.GCS.capabilities/0` becomes
  `[:signed_url, :head, :resumable_upload, :resumable_upload_session]` in
  Phase 39.
- **D-18:** `Rindle.Storage.S3.capabilities/0` and
  `Rindle.Storage.Local.capabilities/0` remain unchanged and explicitly do
  **not** advertise resumable atoms.
- **D-19:** Calling resumable broker entrypoints against a non-resumable
  adapter or non-resumable session row must return tagged
  `{:upload_unsupported, :resumable_upload}` or
  `{:upload_unsupported, :resumable_upload_session}` errors with no silent
  fallback to presigned PUT or multipart behaviour.

### Test And Proof Strategy

- **D-20:** Phase 39 should prove the full resumable path against a real GCS
  bucket, because the load-bearing risks are protocol mechanics, offset/status
  semantics, and callback/broker contract coherence rather than pure unit
  logic.
- **D-21:** Unit tests should still cover the broker/control-plane seams:
  capability gating, compensation on persist failure, non-resumable adapter
  rejection, error vocabulary mapping, and the explicit rule that broker
  completion remains `head/2`-based.
- **D-22:** Tests must defend against the main public-contract footgun:
  no second completion truth. If the adapter-level
  `verify_resumable_completion/3` is implemented, broker tests should still
  make clear that `verify_completion/2` does not depend on it.

### Claude's Discretion

- Exact typespec wording for the new callbacks and broker result structs,
  so long as the locked arities and decision boundaries above remain intact.
- Exact helper placement between `Rindle.Storage.GCS`, its client module, and
  `Rindle.Upload.Broker`, so long as broker completion stays `head/2`-centric
  and session-URI handling remains secret-safe.
- Exact telemetry event shape for the region-pinning advisory path, so long as
  it is observable and does not pollute the public returned error surface.

### Deferred Ideas (OUT OF SCOPE)

- None stated in `39-CONTEXT.md`. [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:151-159]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| RESUMABLE-04 | Add four resumable `Rindle.Storage` optional callbacks with locked arities and shapes. | Callback shape, optional-callback test fallout, and error vocabulary are pinned below. [VERIFIED: .planning/REQUIREMENTS.md:60-63] [VERIFIED: .planning/ROADMAP.md:202-207] [CITED: https://hexdocs.pm/elixir/typespecs.html] |
| RESUMABLE-05 | Implement GCS resumable initiation/status/cancel/verify over the JSON API using Finch. | Official JSON API mechanics, existing `GCS.Client` extension seam, and current package versions are pinned below. [VERIFIED: .planning/REQUIREMENTS.md:64-67] [VERIFIED: lib/rindle/storage/gcs/client.ex:13-286] [CITED: https://docs.cloud.google.com/storage/docs/performing-resumable-uploads] |
| RESUMABLE-06 | Add broker initiate/status/cancel entrypoints, keep storage I/O before DB persistence, and compensate failed persistence with remote cancel. | Existing multipart broker pattern, unchanged `verify_completion/2` trust gate, and exact persistence recommendations are pinned below. [VERIFIED: .planning/REQUIREMENTS.md:68-72] [VERIFIED: lib/rindle/upload/broker.ex:103-149] [VERIFIED: lib/rindle/upload/broker.ex:274-291] [VERIFIED: lib/rindle/upload/broker.ex:392-440] |
| RESUMABLE-07 | Keep S3 and Local non-resumable and fail with tagged capability errors. | Existing capability gate, Local/S3 honesty pattern, and required broker checks are pinned below. [VERIFIED: .planning/REQUIREMENTS.md:73-77] [VERIFIED: lib/rindle/storage/capabilities.ex:35-63] [VERIFIED: lib/rindle/storage/gcs.ex:81-109] [VERIFIED: test/rindle/storage/storage_adapter_test.exs:75-102] |
| RESUMABLE-08 | Exercise every locked resumable error atom from real adapter paths. | Error map, protocol-status mapping, and proof-layer split are pinned below, including the superseding decision that `:region_pinned_initiation` is advisory rather than returned. [VERIFIED: .planning/REQUIREMENTS.md:78-82] [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:82-105] [CITED: https://docs.cloud.google.com/storage/docs/resumable-uploads] |
</phase_requirements>

## Summary

Phase 39 should be planned as a sibling of the shipped multipart lane, not as a new lifecycle family. The current broker already demonstrates the exact shape Rindle wants: capability-gated entry, storage-side initiation before DB persistence, compensating cleanup when persistence fails, and a single `verify_completion/2` convergence point that trusts `adapter.head/2` rather than adapter-specific completion state. [VERIFIED: lib/rindle/upload/broker.ex:103-149] [VERIFIED: lib/rindle/upload/broker.ex:224-291] [VERIFIED: lib/rindle/upload/broker.ex:392-440]

The highest-risk implementation detail is the GCS session protocol, and the official docs are clear on three points the plan must honor: initiation is `POST ...?uploadType=resumable`, subsequent data upload and status checks use `PUT`, not `PATCH`, and the resumable session URI itself is a bearer credential that no longer needs an `Authorization` header on follow-up requests. [CITED: https://docs.cloud.google.com/storage/docs/performing-resumable-uploads] [CITED: https://docs.cloud.google.com/storage/docs/resumable-uploads] This corrects the current roadmap wording that says the proof fixture should stream chunked `PATCH` requests. The Phase 39 plan should use `PUT` end to end. [VERIFIED: .planning/ROADMAP.md:220-223] [CITED: https://docs.cloud.google.com/storage/docs/performing-resumable-uploads]

The second planning hazard is documentation drift inside the repo. `REQUIREMENTS.md` and `ROADMAP.md` still list `:region_pinned_initiation` among returned public error atoms, but `39-CONTEXT.md` explicitly supersedes that shape and treats region pinning as successful initiation plus telemetry/persisted `region_hint`. The planner should follow `39-CONTEXT.md` here, because it is the downstream decision lock for this phase. [VERIFIED: .planning/REQUIREMENTS.md:78-82] [VERIFIED: .planning/ROADMAP.md:230-236] [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:84-105]

**Primary recommendation:** plan Phase 39 as **five slices** with minimal blast radius: `1)` storage behaviour/typespec + contract-test rewrite, `2)` GCS client resumable protocol primitives, `3)` GCS adapter capability promotion + optional-callback wiring, `4)` broker/facade lifecycle entrypoints + compensation + trust-gate tests, `5)` real-bucket resumable proof and error-vocabulary coverage. [VERIFIED: .planning/ROADMAP.md:196-239] [VERIFIED: test/rindle/upload/broker_test.exs:252-450] [VERIFIED: test/rindle/storage/gcs_test.exs:12-124]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Optional resumable callback contract on `Rindle.Storage` | API / Backend | — | The behaviour module owns the compile-time callback/typespec contract. [VERIFIED: lib/rindle/storage.ex:10-198] |
| GCS resumable protocol initiation/status/cancel | API / Backend | External service | Rindle mints and queries the session through the JSON API, while data bytes ultimately flow to GCS over the session URI. [VERIFIED: lib/rindle/storage/gcs/client.ex:13-286] [CITED: https://docs.cloud.google.com/storage/docs/performing-resumable-uploads] |
| Durable resumable session persistence (`session_uri`, offsets, region hint) | API / Backend | Database / Storage | The broker and `MediaUploadSession` schema own the durable row; the DB stores the secret-bearing session state. [VERIFIED: lib/rindle/domain/media_upload_session.ex:47-95] |
| Completion trust gate | API / Backend | External service | Broker promotion remains a backend operation driven by `adapter.head/2` against storage. [VERIFIED: lib/rindle/upload/broker.ex:274-291] |
| Capability honesty for S3/Local | API / Backend | — | Broker gating and adapter capability lists prevent unsupported backends from entering resumable flows. [VERIFIED: lib/rindle/storage/capabilities.ex:35-63] [VERIFIED: test/rindle/storage/storage_adapter_test.exs:75-102] |
| Real-bucket resumable proof | Test harness / Backend | External service | The critical proof is live HTTP behavior against GCS, with local unit coverage only validating control-plane seams. [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:121-134] [VERIFIED: test/rindle/storage/gcs_test.exs:62-124] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `goth` | `1.4.5` | Access-token minting for GCS initiation and `head/2`. | Already locked into the repo’s GCS foundation and current on Hex for the configured constraint. [VERIFIED: mix hex.info goth] [VERIFIED: lib/rindle/storage/gcs.ex:1-145] |
| `finch` | `0.21.0` | HTTP transport for JSON API requests and streamed request bodies. | Already in the repo, supports `{:stream, stream}` request bodies, and keeps the adapter on the same transport stack as Phase 37. [VERIFIED: mix hex.info finch] [CITED: https://hexdocs.pm/finch/Finch.html] [CITED: https://hexdocs.pm/finch/Finch.Request.html] |
| `gcs_signed_url` | `0.4.6` | Existing V4 signed delivery URLs. | Phase 39 should reuse the shipped delivery/signing path and add no new delivery stack. [VERIFIED: mix hex.info gcs_signed_url] [VERIFIED: lib/rindle/storage/gcs.ex:65-70] |
| `ecto` | `3.13.5` locked, `3.13.6` latest | Session-row persistence and transaction boundaries. | No new persistence library is needed; the broker and domain schema already use Ecto transactions and changesets. [VERIFIED: mix hex.info ecto] [VERIFIED: lib/rindle/upload/broker.ex:350-451] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `ecto_sql` | `3.13.5` | Existing repo/migration plumbing for Phase 38 session columns. | Use indirectly through the existing repo and migration test harness; Phase 39 does not need new schema tooling. [VERIFIED: mix hex.info ecto_sql] [VERIFIED: priv/repo/migrations/20260507160000_extend_media_upload_sessions_for_resumable.exs] |
| `Bypass` | repo test dep | Unit-test GCS HTTP edges without live credentials. | Use for protocol-shape and error-mapping tests in `ClientTest`; do not rely on it for final resumable proof. [VERIFIED: test/rindle/storage/gcs/client_test.exs:8-205] |
| ExUnit + Mox | repo test deps | Broker contract, capability-gate, and trust-gate tests. | Use for broker entrypoint tests and “do not call `verify_resumable_completion/3` from broker” assertions. [VERIFIED: test/rindle/upload/broker_test.exs:1-520] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Extend `Rindle.Storage.GCS.Client` | `google_api_storage` | Rejected because the phase needs raw control over session-URI initiation/status/cancel semantics, while the current repo already owns a hand-rolled Finch seam for GCS. [VERIFIED: .planning/REQUIREMENTS.md:64-65] [VERIFIED: lib/rindle/storage/gcs/client.ex:1-286] |
| `head/2` as the single trust gate | Adapter-specific broker completion path | Rejected because the existing broker already converges multipart through `head/2`, and `39-CONTEXT.md` explicitly forbids a second completion truth. [VERIFIED: lib/rindle/upload/broker.ex:224-291] [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:47-63] |
| Bypass + real-bucket lane | Emulator-only proof | Rejected because the main unknowns are live session-URI behavior, HTTP 308/404/410 handling, and end-to-end broker convergence. [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:121-134] [CITED: https://docs.cloud.google.com/storage/docs/performing-resumable-uploads] |
| Capability-gated “unsupported” failures | Silent resumable fallback to presigned PUT or multipart | Rejected by both existing capability helpers and the locked phase decisions. [VERIFIED: lib/rindle/storage/capabilities.ex:47-63] [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:107-119] |

**Installation:**
```bash
mix deps.get
```

No new package is required beyond the Phase 37 GCS stack already present in the repo. [VERIFIED: mix.lock] [VERIFIED: lib/rindle/storage/gcs.ex:1-145]

## Architecture Patterns

### System Architecture Diagram

```text
caller / adopter
  -> Broker.initiate_resumable_session(profile, opts)
  -> capability gate (:resumable_upload_session)
  -> GCS adapter initiate_resumable_upload/3
  -> GCS JSON API POST uploadType=resumable
  -> session URI returned
  -> broker persists MediaAsset + MediaUploadSession(state="signed", upload_strategy="resumable")
    -> if persist fails: adapter.cancel_resumable_upload/3 compensates remote session

caller / client
  -> PUT chunk(s) to session URI directly
  -> optional Broker.resumable_session_status/2
    -> GCS status PUT Content-Range: bytes */*
    -> broker may update last_known_offset / session_uri_expires_at / region_hint
    -> broker does not advance lifecycle state

caller / adopter
  -> Broker.verify_completion(session_id)
  -> adapter.head(upload_key)
  -> Ecto.Multi promotes session + asset
  -> telemetry [:rindle, :upload, :stop]
```

The planner should treat direct byte upload as an external client-to-GCS flow and keep the broker strictly on initiation, observation, cancellation, and final trust-gated promotion. [VERIFIED: lib/rindle/upload/broker.ex:274-340] [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:53-80] [CITED: https://docs.cloud.google.com/storage/docs/performing-resumable-uploads]

### Recommended Project Structure

```text
lib/
├── rindle/storage.ex                    # add typedocs + @optional_callbacks
├── rindle/storage/gcs.ex                # public adapter methods + capability list
├── rindle/storage/gcs/client.ex         # JSON API initiate/status/cancel helpers
├── rindle/upload/broker.ex              # resumable broker entrypoints + compensation
└── rindle.ex                            # public facade delegates, if Phase 39 chooses parity with multipart

test/
├── rindle/storage/storage_adapter_test.exs
├── rindle/storage/gcs_test.exs
├── rindle/storage/gcs/client_test.exs
├── rindle/upload/broker_test.exs
└── rindle/upload/lifecycle_integration_test.exs or new resumable integration file
```

This layout keeps the public surface in `storage.ex`, adapter logic in `gcs.ex`, wire protocol in `gcs/client.ex`, and lifecycle orchestration in `upload/broker.ex`, matching the existing Phase 37 split. [VERIFIED: lib/rindle/storage/gcs.ex:37-145] [VERIFIED: lib/rindle/storage/gcs/client.ex:1-286] [VERIFIED: lib/rindle/upload/broker.ex:103-451]

### Pattern 1: Add Real Optional Callbacks, Then Rewrite the Behaviour Contract Test

**What:** Add the four resumable callbacks as `@callback`s plus `@optional_callbacks`, and stop asserting that every adapter exports every callback listed by `behaviour_info(:callbacks)`. [VERIFIED: .planning/REQUIREMENTS.md:60-63] [CITED: https://hexdocs.pm/elixir/typespecs.html] [CITED: https://hexdocs.pm/elixir/Module.html]

**When to use:** Use this as the first slice so the rest of the phase can compile without forcing Local/S3 stub implementations that the locked context explicitly rejects. [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:32-39] [VERIFIED: test/rindle/storage/storage_adapter_test.exs:40-50]

**Example:**
```elixir
# Source: synthesized from lib/rindle/storage.ex + Elixir optional-callback docs
@type resumable_init_result :: %{
  required(:session_uri) => String.t(),
  required(:upload_id) => String.t(),
  required(:expires_at) => DateTime.t(),
  optional(:region_hint) => String.t() | nil,
  optional(atom()) => term()
}

@type resumable_status_result :: %{
  required(:committed_bytes) => non_neg_integer(),
  required(:state) => :in_progress | :complete | :expired,
  optional(atom()) => term()
}

@callback initiate_resumable_upload(String.t(), pos_integer() | nil, keyword()) ::
  {:ok, resumable_init_result()} | {:error, term()}
@callback resumable_upload_status(String.t(), String.t(), keyword()) ::
  {:ok, resumable_status_result()} | {:error, term()}
@callback cancel_resumable_upload(String.t(), String.t(), keyword()) ::
  {:ok, %{cancelled: boolean()}} | {:error, term()}
@callback verify_resumable_completion(String.t(), String.t(), keyword()) ::
  {:ok, head_result()} | {:error, term()}

@optional_callbacks initiate_resumable_upload: 3,
                    resumable_upload_status: 3,
                    cancel_resumable_upload: 3,
                    verify_resumable_completion: 3
```

### Pattern 2: Initiate First, Persist Second, Compensate on Persist Failure

**What:** Copy the multipart broker posture almost verbatim, but persist a resumable session row with `upload_strategy: "resumable"` and a `state` of `"signed"` because the session credential already exists when initiation returns. [VERIFIED: lib/rindle/upload/broker.ex:103-149] [VERIFIED: lib/rindle/domain/media_upload_session.ex:47-95] [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:67-80]

**When to use:** Use for `initiate_resumable_session/2`. It minimizes new state choreography and preserves the “storage side effects outside DB transactions” invariant. [VERIFIED: lib/rindle/storage.ex:3-7] [VERIFIED: lib/rindle/upload/broker.ex:392-440]

**Example:**
```elixir
# Source: synthesized from lib/rindle/upload/broker.ex:103-149 and :392-440
with :ok <- Capabilities.require_upload(adapter, :resumable_upload_session),
     {:ok, resumable} <- adapter.initiate_resumable_upload(storage_key, expected_size, opts),
     {:ok, session} <- persist_resumable_session(repo, adapter, seed, resumable, opts) do
  {:ok, %{session: session, resumable: resumable}}
else
  {:error, reason} -> {:error, reason}
end
```

### Pattern 3: Treat Status as Observational, Not as a Lifecycle Advance

**What:** `resumable_session_status/2` should read the session row, call the adapter status helper, update offset/expiry/region fields if needed, emit resumable telemetry, and leave `state` unchanged unless a later phase adds an explicit resume action. [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:74-80] [VERIFIED: lib/rindle/domain/upload_session_fsm.ex:6-29] [VERIFIED: lib/rindle/upload/resumable_telemetry.ex:6-63]

**When to use:** Use for ordinary polling and uncertain-completion inspection. Do not spend the `"resuming"` state on routine probes. [VERIFIED: .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md] [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:74-80]

### Anti-Patterns to Avoid

- **Second completion truth:** Do not call `verify_resumable_completion/3` from broker promotion code. `verify_completion/2` already trusts `head/2`, and tests should prove that remains true. [VERIFIED: lib/rindle/upload/broker.ex:274-291] [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:47-63]
- **Protocol drift to `PATCH`:** Do not build the proof fixture or adapter docs around `PATCH`; the official GCS JSON API resumable flow uses `PUT` for chunk upload and status checks. [VERIFIED: .planning/ROADMAP.md:220-223] [CITED: https://docs.cloud.google.com/storage/docs/performing-resumable-uploads]
- **Status probing mutates lifecycle:** Do not advance `"signed"` to `"resuming"` or `"uploading"` merely because status was queried. [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:74-80]
- **Stub Local/S3 into fake resumable support:** Optional callbacks plus capability gating are the intended shape; silent fallback is explicitly forbidden. [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:36-39] [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:115-119]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Broker completion | A second resumable-only completion verb | Existing `verify_completion/2` + `head/2` | The broker already converges upload families through storage metadata, and the context locks that invariant. [VERIFIED: lib/rindle/upload/broker.ex:224-291] [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:53-63] |
| GCS transport stack | A second SDK/client module outside `GCS.Client` | Extend `Rindle.Storage.GCS.Client` | The repo already owns auth, base URL, rescue, and Bypass seams there. [VERIFIED: lib/rindle/storage/gcs/client.ex:13-286] |
| Local/S3 resumable emulation | Fake resumable support or multipart masquerading | `Capabilities.require_upload/2` + explicit unsupported errors | This preserves capability honesty and avoids undefined semantics. [VERIFIED: lib/rindle/storage/capabilities.ex:47-63] [VERIFIED: test/rindle/storage/storage_adapter_test.exs:437-449] |
| Test proof | Emulator-only happy path | Bypass for units + real GCS bucket for end-to-end | Status 308/404/410 behavior and session-URI semantics are the actual risk. [VERIFIED: test/rindle/storage/gcs/client_test.exs:26-205] [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:121-134] [CITED: https://docs.cloud.google.com/storage/docs/performing-resumable-uploads] |

**Key insight:** The cheapest correct Phase 39 is the one that changes as little as possible outside the already-shipped multipart and GCS seams. The repo already contains the broker pattern, the GCS client shell, the resumable schema fields, and the telemetry redaction helper; the plan should extend those pieces rather than create new abstractions. [VERIFIED: lib/rindle/upload/broker.ex:103-149] [VERIFIED: lib/rindle/storage/gcs/client.ex:13-286] [VERIFIED: lib/rindle/domain/media_upload_session.ex:47-112] [VERIFIED: lib/rindle/upload/resumable_telemetry.ex:1-63]

## Common Pitfalls

### Pitfall 1: `@optional_callbacks` Changes the Meaning of the Existing Behaviour Test

**What goes wrong:** `test/rindle/storage/storage_adapter_test.exs` currently iterates `behaviour_info(:callbacks)` and asserts that Local, S3, and GCS export every callback. Once resumable callbacks become optional, that test will fail even if the design is correct. [VERIFIED: test/rindle/storage/storage_adapter_test.exs:40-50] [CITED: https://hexdocs.pm/elixir/Module.html]

**Why it happens:** In Elixir, `behaviour_info(:callbacks)` still includes optional callbacks. [CITED: https://hexdocs.pm/elixir/Module.html]

**How to avoid:** Split the test into required callbacks versus `behaviour_info(:optional_callbacks)`, then assert GCS exports the resumable set and Local/S3 do not need to. [CITED: https://hexdocs.pm/elixir/typespecs.html]

**Warning signs:** Compile/test failures that claim Local or S3 “forgot” the new resumable functions even though the context explicitly says they should not implement them. [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:32-39]

### Pitfall 2: The Official GCS Follow-Up Method Is `PUT`, Not `PATCH`

**What goes wrong:** A planner or implementer may copy the roadmap wording and build the fixture around `PATCH`. [VERIFIED: .planning/ROADMAP.md:220-223]

**Why it happens:** The roadmap text drifts from the official JSON API docs. [VERIFIED: .planning/ROADMAP.md:220-223] [CITED: https://docs.cloud.google.com/storage/docs/performing-resumable-uploads]

**How to avoid:** Make `PUT` the explicit method for chunk upload and for zero-byte status probes in both tests and docs. [CITED: https://docs.cloud.google.com/storage/docs/performing-resumable-uploads]

**Warning signs:** 405/400 responses from GCS in the live-bucket proof, or an implementation that invents a separate `PATCH` helper while the official docs only show `PUT`. [CITED: https://docs.cloud.google.com/storage/docs/performing-resumable-uploads]

### Pitfall 3: Status Probing Accidentally Consumes the `"resuming"` State

**What goes wrong:** `resumable_session_status/2` starts mutating `state` to `"resuming"` or `"uploading"` on ordinary polls. [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:74-80]

**Why it happens:** The repo now has a new `"resuming"` state, but its semantics were intentionally kept narrow in Phase 38. [VERIFIED: lib/rindle/domain/upload_session_fsm.ex:6-17] [VERIFIED: .planning/phases/38-resumable-persistence-fsm/38-RESEARCH.md]

**How to avoid:** Restrict status to durable bookkeeping updates only, and add a broker test that asserts the session state remains unchanged after a successful status poll. [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:74-80]

**Warning signs:** A session moves from `"signed"` to `"resuming"` without an explicit resume action or storage-side error. [VERIFIED: lib/rindle/domain/upload_session_fsm.ex:6-17]

### Pitfall 4: Region-Pinning Error Drift

**What goes wrong:** Tests or typespecs ship `:region_pinned_initiation` as a public error because older docs still list it that way. [VERIFIED: .planning/REQUIREMENTS.md:78-82] [VERIFIED: .planning/ROADMAP.md:230-236]

**Why it happens:** `39-CONTEXT.md` supersedes the earlier candidate/roadmap wording, but the older wording still exists elsewhere in the repo. [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:84-105]

**How to avoid:** Treat region pinning as `{:ok, ...}` plus telemetry and persisted `region_hint`, and add a note in the plan that requirements/docs drift exists. [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:97-105]

**Warning signs:** A broker API consumer is forced to branch on region pinning despite a successful initiation. [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:99-105]

### Pitfall 5: Leaking the Session URI Through Tests, Logs, or Telemetry

**What goes wrong:** New status/cancel code logs raw session URIs or adds them to metadata. [VERIFIED: lib/rindle/domain/media_upload_session.ex:97-112] [VERIFIED: lib/rindle/upload/resumable_telemetry.ex:6-63]

**Why it happens:** The status/cancel surface is new, and GCS follow-up requests no longer need auth headers, which can tempt direct session-URI logging while debugging. [CITED: https://docs.cloud.google.com/storage/docs/resumable-uploads]

**How to avoid:** Keep all emit/log helpers on the existing `MediaUploadSession` and `ResumableTelemetry` redaction seams, and add parity tests for every new broker/adaptor emit site. [VERIFIED: test/rindle/upload/resumable_telemetry_test.exs] [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs]

**Warning signs:** Any test failure or warning log containing `upload_id=` or `https://storage.googleapis.com/upload/...`. [CITED: https://docs.cloud.google.com/storage/docs/resumable-uploads]

## Code Examples

Verified patterns from repo and official docs:

### GCS Status Probe Mapping
```elixir
# Source: GCS resumable JSON API docs + current Client error mapping style
req =
  Finch.build(
    :put,
    session_uri,
    [{"content-length", "0"}, {"content-range", "bytes */*"}]
  )

case Finch.request(req, finch) do
  {:ok, %Finch.Response{status: 308, headers: headers}} ->
    {:ok, %{state: :in_progress, committed_bytes: committed_bytes_from_range(headers)}}

  {:ok, %Finch.Response{status: status}} when status in [200, 201] ->
    {:ok, %{state: :complete, committed_bytes: expected_size || 0}}

  {:ok, %Finch.Response{status: 410}} ->
    {:error, :session_uri_expired}

  {:ok, %Finch.Response{status: 404}} ->
    {:error, :session_uri_unknown}
end
```
[CITED: https://docs.cloud.google.com/storage/docs/performing-resumable-uploads] [VERIFIED: lib/rindle/storage/gcs/client.ex:17-44] [VERIFIED: test/rindle/storage/gcs/client_test.exs:26-205]

### Multipart-Style Compensation Pattern for Resumable Initiation
```elixir
# Source: lib/rindle/upload/broker.ex:392-440
case persist_resumable_session(repo, adapter, seed, resumable, opts) do
  {:ok, session} ->
    {:ok, session}

  {:error, reason} ->
    _ = adapter.cancel_resumable_upload(seed.storage_key, resumable.session_uri, opts)
    {:error, reason}
end
```
[VERIFIED: lib/rindle/upload/broker.ex:392-440]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| GCS adapter only handled `store/download/delete/head/url` and explicitly rejected upload-session behavior. [VERIFIED: lib/rindle/storage/gcs.ex:81-109] | Phase 39 promotes resumable callbacks on GCS only, while S3 and Local stay non-resumable. [VERIFIED: .planning/ROADMAP.md:202-239] [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:32-39] | 2026-05-07 planning lock. [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:1-4] | Test and capability assertions must be rewritten around optional callbacks and honest capability advertisement. [VERIFIED: test/rindle/storage/storage_adapter_test.exs:40-88] |
| Candidate/requirements listed `:region_pinned_initiation` like a public returned error. [VERIFIED: .planning/REQUIREMENTS.md:78-82] [VERIFIED: .planning/ROADMAP.md:230-236] | Phase 39 context demotes region pinning to advisory telemetry/metadata and successful initiation. [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:84-105] | 2026-05-07 discussion output. [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:1-4] | Planner should not create returned-error tests for region pinning. [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:89-105] |
| Existing roadmap wording says the live proof should stream chunked `PATCH` requests. [VERIFIED: .planning/ROADMAP.md:220-223] | Official GCS JSON API uses `PUT` for chunk upload and status probes. [CITED: https://docs.cloud.google.com/storage/docs/performing-resumable-uploads] | Official docs retrieved 2026-05-07. [VERIFIED: web lookup 2026-05-07] | The end-to-end test fixture and adapter docs should use `PUT`, or the live proof will be aimed at the wrong protocol. [CITED: https://docs.cloud.google.com/storage/docs/performing-resumable-uploads] |

**Deprecated/outdated:**

- `PATCH` as the resumable session upload verb for the JSON API is outdated for this phase and should not appear in the plan. [VERIFIED: .planning/ROADMAP.md:220-223] [CITED: https://docs.cloud.google.com/storage/docs/performing-resumable-uploads]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `lib/rindle.ex` should add resumable facade delegates for parity with the existing multipart public API. [ASSUMED] | Architecture Patterns / plan split | Low. If omitted, Phase 39 can still ship via broker-only entrypoints, but the public API will feel asymmetric. |
| A2 | The broker should persist newly initiated resumable sessions directly as `"signed"` rather than `"initialized"` because the session credential has already been minted. [ASSUMED] | Architecture Patterns / broker slice | Medium. If the team prefers `"initialized"` plus a second “issue credential” step, more public surface and FSM churn would be needed. |

## Open Questions (RESOLVED)

1. **Should `REQUIREMENTS.md` and `ROADMAP.md` be patched later to remove `:region_pinned_initiation` from returned errors?**
   - Resolution: Phase 39 execution and tests should follow `39-CONTEXT.md` as the operative decision lock. `:region_pinned_initiation` is advisory-only metadata/telemetry, not a returned public error, even if older roadmap text still contains the superseded wording. [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:84-105]
   - Planning consequence: No Phase 39 plan may assert returned-error behavior for region pinning. If docs are updated later, that is documentation alignment work, not a blocker for this phase. [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-01-PLAN.md] [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-02-PLAN.md] [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-04-PLAN.md]

2. **Is the roadmap’s `media_provider_assets` wording in the Phase 39 success criterion a typo?**
   - Resolution: Treat it as roadmap drift for planning purposes. The implemented broker completion path today promotes `MediaUploadSession` and `MediaAsset`, and the Phase 39 proof should assert those terminal states rather than inventing a `media_provider_assets` dependency. [VERIFIED: lib/rindle/upload/broker.ex:295-340]
   - Planning consequence: The real-bucket proof in Phase 39 should validate `MediaUploadSession` + `MediaAsset` outcomes and the existing `verify_completion/2` promotion path. Any roadmap wording cleanup can happen separately without changing the execution plan. [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-04-PLAN.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | compile/test/run | ✓ | `1.19.5` | — [VERIFIED: `elixir --version`] |
| Mix | test commands | ✓ | `1.19.5` | — [VERIFIED: `mix --version`] |
| Node.js | no direct Phase 39 runtime need; incidental tooling only | ✓ | `22.14.0` | — [VERIFIED: `node --version`] |
| `GOOGLE_APPLICATION_CREDENTIALS_JSON` | live GCS proof | ✗ | — | secret-gated CI or manual live run [VERIFIED: shell env check] |
| `RINDLE_GCS_BUCKET` | live GCS proof | ✗ | — | secret-gated CI or manual live run [VERIFIED: shell env check] |

**Missing dependencies with no fallback:**

- Local execution of the real-bucket resumable proof is blocked on absent GCS credentials and bucket env vars. The phase can still be implemented and unit-tested locally, but the live proof must run in CI or a manually provisioned environment. [VERIFIED: shell env check] [VERIFIED: test/rindle/storage/gcs_test.exs:6-10]

**Missing dependencies with fallback:**

- Live GCS proof is unavailable locally, but `Bypass` + Mox cover the protocol/control-plane slices before the secret-gated lane runs. [VERIFIED: test/rindle/storage/gcs/client_test.exs:8-205] [VERIFIED: test/rindle/upload/broker_test.exs:252-450]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit + Mox + Bypass + existing repo integration harness. [VERIFIED: test/rindle/upload/broker_test.exs:1-520] [VERIFIED: test/rindle/storage/gcs/client_test.exs:1-205] |
| Config file | `mix.exs` + current `test/` layout; no separate Phase 39 config file. [VERIFIED: repo layout] |
| Quick run command | `mix test test/rindle/storage/storage_adapter_test.exs test/rindle/storage/gcs/client_test.exs test/rindle/storage/gcs_test.exs test/rindle/upload/broker_test.exs -x` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| RESUMABLE-04 | Storage behaviour exposes optional resumable callbacks and does not force Local/S3 exports. [VERIFIED: .planning/REQUIREMENTS.md:60-63] | unit/contract | `mix test test/rindle/storage/storage_adapter_test.exs -x` | ✅ existing file, needs extension [VERIFIED: test/rindle/storage/storage_adapter_test.exs] |
| RESUMABLE-05 | GCS adapter/client initiate/status/cancel/verify match official protocol and error mappings. [VERIFIED: .planning/REQUIREMENTS.md:64-67] | unit + live integration | `mix test test/rindle/storage/gcs/client_test.exs test/rindle/storage/gcs_test.exs -x` | ✅ existing files, need new cases [VERIFIED: test/rindle/storage/gcs/client_test.exs] |
| RESUMABLE-06 | Broker initiate/status/cancel use persist-after-storage + compensation and leave `verify_completion/2` unchanged. [VERIFIED: .planning/REQUIREMENTS.md:68-72] | unit/integration | `mix test test/rindle/upload/broker_test.exs -x` | ✅ existing file, needs new cases [VERIFIED: test/rindle/upload/broker_test.exs] |
| RESUMABLE-07 | Non-resumable adapters fail with tagged unsupported errors and no fallback. [VERIFIED: .planning/REQUIREMENTS.md:73-77] | unit/contract | `mix test test/rindle/storage/storage_adapter_test.exs test/rindle/upload/broker_test.exs -x` | ✅ existing files [VERIFIED: test/rindle/storage/storage_adapter_test.exs] |
| RESUMABLE-08 | All locked error atoms are returnable from real paths and the live resumable flow converges through `verify_completion/2`. [VERIFIED: .planning/REQUIREMENTS.md:78-82] | unit + live integration | `mix test --only gcs` | ⚠️ file set exists, but resumable live proof cases still need to be added [VERIFIED: test/rindle/storage/gcs_test.exs:62-124] |

### Sampling Rate

- **Per task commit:** `mix test test/rindle/storage/storage_adapter_test.exs test/rindle/storage/gcs/client_test.exs test/rindle/upload/broker_test.exs -x`
- **Per wave merge:** `mix test test/rindle/storage/gcs_test.exs test/rindle/upload/broker_test.exs test/rindle/upload/lifecycle_integration_test.exs`
- **Phase gate:** `mix test` plus the secret-gated live GCS resumable lane before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] Extend `test/rindle/storage/storage_adapter_test.exs` for `@optional_callbacks` semantics and truthful GCS-only resumable exports. [VERIFIED: test/rindle/storage/storage_adapter_test.exs:40-88]
- [ ] Add Bypass coverage for resumable initiation/status/cancel in `test/rindle/storage/gcs/client_test.exs`, including `308`, missing `Range`, `404`, `410`, and `499`. [VERIFIED: test/rindle/storage/gcs/client_test.exs:26-205] [CITED: https://docs.cloud.google.com/storage/docs/performing-resumable-uploads]
- [ ] Add broker tests for resumable initiation compensation, status-as-observation, non-resumable session rejection, and “broker does not call `verify_resumable_completion/3`”. [VERIFIED: test/rindle/upload/broker_test.exs:252-450]
- [ ] Add a live resumable integration proof, either by extending `test/rindle/upload/lifecycle_integration_test.exs` or by adding a dedicated GCS resumable integration file. [VERIFIED: test/rindle/upload/lifecycle_integration_test.exs:1-320]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Upload-session auth is delegated to GCS bearer session URIs, not Rindle user auth. [CITED: https://docs.cloud.google.com/storage/docs/resumable-uploads] |
| V3 Session Management | yes | Treat `session_uri` as a bearer secret, redact it in inspect/log/telemetry, and persist it only on the adopter-owned session row. [VERIFIED: lib/rindle/domain/media_upload_session.ex:97-112] [VERIFIED: lib/rindle/upload/resumable_telemetry.ex:6-63] [CITED: https://docs.cloud.google.com/storage/docs/resumable-uploads] |
| V4 Access Control | yes | Broker capability gates and adapter honesty prevent unsupported backends from entering resumable flows. [VERIFIED: lib/rindle/storage/capabilities.ex:47-63] [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:107-119] |
| V5 Input Validation | yes | Broker should normalize stored offsets, session-row strategy, and multipart-style metadata before any adapter call. [VERIFIED: lib/rindle/upload/broker.ex:231-253] [VERIFIED: lib/rindle/domain/media_upload_session.ex:74-95] |
| V6 Cryptography | no | Phase 39 adds no new crypto beyond the existing GCS signing and bearer-token handling from earlier phases. [VERIFIED: lib/rindle/storage/gcs.ex:65-70] |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Session URI leak in logs or telemetry | Information Disclosure | Central redaction in `MediaUploadSession` inspect + resumable telemetry metadata allowlist. [VERIFIED: lib/rindle/domain/media_upload_session.ex:97-112] [VERIFIED: lib/rindle/upload/resumable_telemetry.ex:6-63] |
| Unsupported adapter silently falls back to another upload family | Elevation of Privilege / Tampering | `Capabilities.require_upload/2` before any adapter-specific call, with tagged unsupported errors. [VERIFIED: lib/rindle/storage/capabilities.ex:47-63] |
| Dual completion semantics let clients claim success without object existence | Tampering | Keep `verify_completion/2` on `head/2` only. [VERIFIED: lib/rindle/upload/broker.ex:274-291] |
| Offset confusion after interrupted upload | Tampering / Integrity | Status probes should parse `Range` and compare against stored/client offsets, returning `{:offset_mismatch, ...}` instead of guessing. [CITED: https://docs.cloud.google.com/storage/docs/performing-resumable-uploads] [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:84-88] |

## Sources

### Primary (HIGH confidence)

- Official GCS resumable upload guide: https://docs.cloud.google.com/storage/docs/performing-resumable-uploads - initiation/status/resume/cancel verbs, status codes, `Range` semantics, chunk-size guidance.
- Official GCS resumable overview: https://docs.cloud.google.com/storage/docs/resumable-uploads - session URI secrecy, one-week expiry, region pinning, resumed-upload behavior.
- Elixir typespec/behaviour docs: https://hexdocs.pm/elixir/typespecs.html and https://hexdocs.pm/elixir/Module.html - `@optional_callbacks` and `behaviour_info/1` semantics.
- Finch docs: https://hexdocs.pm/finch/Finch.html and https://hexdocs.pm/finch/Finch.Request.html - streamed request bodies via `{:stream, body_stream}`.
- Repo seams:
  - `lib/rindle/storage.ex`
  - `lib/rindle/storage/capabilities.ex`
  - `lib/rindle/storage/gcs.ex`
  - `lib/rindle/storage/gcs/client.ex`
  - `lib/rindle/upload/broker.ex`
  - `lib/rindle/domain/media_upload_session.ex`
  - `lib/rindle/domain/upload_session_fsm.ex`
  - `lib/rindle/upload/resumable_telemetry.ex`
  - `test/rindle/storage/storage_adapter_test.exs`
  - `test/rindle/storage/gcs_test.exs`
  - `test/rindle/storage/gcs/client_test.exs`
  - `test/rindle/upload/broker_test.exs`

### Secondary (MEDIUM confidence)

- `mix hex.info goth`
- `mix hex.info finch`
- `mix hex.info gcs_signed_url`
- `mix hex.info ecto`
- `mix hex.info ecto_sql`

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - the phase reuses already-shipped GCS libraries, and current package versions were reverified on 2026-05-07. [VERIFIED: mix hex.info goth] [VERIFIED: mix hex.info finch] [VERIFIED: mix hex.info gcs_signed_url]
- Architecture: HIGH - the broker and adapter seams already exist in repo code, and the phase context locks the completion and compensation posture. [VERIFIED: lib/rindle/upload/broker.ex:103-149] [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:47-80]
- Pitfalls: HIGH - the main hazards are directly visible in current repo tests/docs and current official GCS protocol docs. [VERIFIED: test/rindle/storage/storage_adapter_test.exs:40-50] [VERIFIED: .planning/ROADMAP.md:220-236] [CITED: https://docs.cloud.google.com/storage/docs/performing-resumable-uploads]

**Research date:** 2026-05-07 [VERIFIED: system date]
**Valid until:** 2026-06-06 for repo-specific planning, but re-check official GCS docs before execution if the phase starts later than 30 days from this date. [CITED: https://docs.cloud.google.com/storage/docs/performing-resumable-uploads]

## RESEARCH COMPLETE

**Primary recommendation:** keep Phase 39 at **5 plans / slices**, because that is the smallest split that isolates compile-time contract churn, live GCS protocol mechanics, public adapter honesty, broker lifecycle risk, and real-bucket proof into independently reviewable changes. [VERIFIED: .planning/ROADMAP.md:241-244] [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:121-134]

1. **Slice 39-01: Storage contract + tests.** Add resumable typedocs/callbacks to `Rindle.Storage`, mark them optional, rewrite `storage_adapter_test.exs` around optional-callback semantics, and freeze the public error/type vocabulary. [VERIFIED: lib/rindle/storage.ex:10-198] [VERIFIED: test/rindle/storage/storage_adapter_test.exs:40-88] [CITED: https://hexdocs.pm/elixir/Module.html]
2. **Slice 39-02: GCS client protocol primitives.** Extend `Rindle.Storage.GCS.Client` with resumable initiate/status/cancel helpers, Bypass coverage for `308`/`404`/`410`/`499`, and strict `PUT` semantics. [VERIFIED: lib/rindle/storage/gcs/client.ex:13-286] [CITED: https://docs.cloud.google.com/storage/docs/performing-resumable-uploads]
3. **Slice 39-03: GCS adapter wiring + capability promotion.** Wire the new client helpers into `Rindle.Storage.GCS`, promote capabilities to `[:signed_url, :head, :resumable_upload, :resumable_upload_session]`, and keep Local/S3 non-resumable without stubs or fallback. [VERIFIED: lib/rindle/storage/gcs.ex:81-145] [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:107-119]
4. **Slice 39-04: Broker and facade lifecycle surface.** Add `initiate_resumable_session/2`, `resumable_session_status/2`, and `cancel_resumable_session/2`, mirror multipart compensation on persist failure, optionally add `Rindle` facade delegates for parity, and prove `verify_completion/2` still uses `head/2` only. [VERIFIED: lib/rindle/upload/broker.ex:103-149] [VERIFIED: lib/rindle/upload/broker.ex:274-291] [VERIFIED: lib/rindle.ex:61-103] [ASSUMED: facade parity delegate addition]
5. **Slice 39-05: Real-bucket proof + error-lane closure.** Add the end-to-end GCS resumable integration case, prove broker convergence through `verify_completion/2`, and exhaust the public error vocabulary except the superseded `:region_pinned_initiation` returned-error shape. [VERIFIED: .planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md:84-105] [VERIFIED: test/rindle/storage/gcs_test.exs:62-124] [CITED: https://docs.cloud.google.com/storage/docs/resumable-uploads]
