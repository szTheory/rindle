# Phase 43: S3 Multipart Backing + MinIO Proof - Research

**Researched:** 2026-05-23
**Domain:** S3 multipart-per-PATCH storage backing for the tus protocol edge (Elixir / ExAws / Ecto / Oban)
**Confidence:** HIGH (codebase verified line-by-line; ExAws.S3 API verified against installed dep source; tusd S3 pattern cited from tus.io + tusd)

## Summary

Phase 42 shipped a fully-functional tus protocol edge (`Rindle.Upload.TusPlug`) hard-wired to `Rindle.Storage.Local` tmp-append/atomic-rename. Phase 43 generalizes the storage sink into a new OPTIONAL adapter callback, `upload_part_stream/5`, and implements it for S3 as one S3 `UploadPart` per PATCH ≥ 5 MiB (buffering a sub-5-MiB tail chunk on local disk and flushing it as the final part on completion — the tusd S3-backend pattern). The in-flight S3 `UploadId` and accumulated part ETags are persisted across stateless PATCH requests using the **already-present** `multipart_upload_id` (string) and `multipart_parts` (map) columns on `media_upload_sessions` — so D-10's "one column only" budget is preserved with **zero** new columns this phase.

The completion path (final PATCH, `offset == length`) calls `complete_multipart_upload/4`, then converges into the **unchanged** `Broker.verify_completion/2` lane: head-based content re-sniff, size/type validation, `PromoteAsset` enqueued in the same `Ecto.Multi`. The S3 adapter's `head/2` already returns both `:size` and `:content_type` (unlike Local), so the verify lane gets a real content_type for free. The reaper (`Rindle.Ops.UploadMaintenance`) currently routes ALL `upload_strategy: "resumable"` sessions — which now includes tus sessions — through `attempt_resumable_cancel`, which requires the `:resumable_upload_session` capability that S3/Local do NOT advertise. **This is the load-bearing gap Phase 43 must close**: branch the reaper on `resumable_protocol` so `"tus"` aborts the S3 multipart (or removes the Local tmp) and `"gcs_native"` keeps the existing session-URI cancel.

**Primary recommendation:** Add `upload_part_stream/5` as an OPTIONAL `@callback` on `Rindle.Storage`; implement it in S3 (UploadPart + tail-buffer) and Local (file-append, no part semantics); advertise `:tus_upload` from S3; rewire `TusPlug`'s PATCH/completion to dispatch through the adapter (not hard-wired `Local.*`) while keeping the streaming read loop; reuse `multipart_upload_id`/`multipart_parts` columns for S3 state; branch the reaper's resumable lane on `resumable_protocol`; prove it all with a `@tag :minio` ≥ 1 GiB drop-and-resume + a `list_multipart_uploads`-empty abort assertion using the established `RINDLE_MINIO_*` CI harness.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Per-PATCH byte streaming (read_body loop) | API/Plug edge (`TusPlug`) | — | Bytes are on the BEAM hot path (Topology B); the Plug owns the socket drain (D-07) |
| Bytes→part translation (UploadPart, tail buffer) | Storage adapter (`S3`/`Local`) | Plug edge (calls callback) | Adapter owns S3 semantics (5 MiB min, ETag, part number); the Plug stays protocol-only (D-12) |
| In-flight UploadId + ETag persistence | Database (`media_upload_sessions`) | Broker | Stateless PATCH requests need durable cross-request state; reuse existing multipart columns |
| Completion → promote | Broker (`verify_completion/2`) + Oban (`PromoteAsset`) | Storage adapter (`complete_multipart_upload` + `head`) | Single trusted lane; head re-sniff is the trust boundary (D-08) |
| Expiry / abort / reap | Oban cron (`AbortIncompleteUploads` → `UploadMaintenance`) | Storage adapter (`abort_multipart_upload`) | Reaper owns lifecycle; adapter owns remote cleanup (TUS-09) |
| Capability honesty (deploy-time raise) | Storage adapter (`capabilities/0`) + `TusPlug.init/1` | `Capabilities.require_upload/2` | No silent downgrade; init-time `ArgumentError` (D-09, already shipped) |

## User Constraints (from CONTEXT.md)

> **No `43-CONTEXT.md` exists** (`has_context: false` from `gsd-sdk query init.phase-op 43`). Phase 43 inherits its constraints from the v1.8 locked architecture and the Phase-42 decision log (D-01..D-13), which are authoritative and **not to be relitigated** per STATE.md "Blockers/Concerns". The most binding inherited constraints:

### Locked Decisions (inherited — authoritative)

- **D-01 (deferred to here):** The generic `upload_part_stream/5` callback on `Rindle.Storage` is **born in Phase 43**, designed against real S3 part semantics (5 MiB minimum, ETag accumulation) — NOT reshaped from the Local file-append case. Phase 42 deliberately did NOT define it (`local.ex` has `tus_append/3`/`tus_complete/3` as plain helpers, not callbacks).
- **D-08 (carry-forward, hard):** tus completion converges into the **UNCHANGED** `Broker.verify_completion/2` (`broker.ex:471`). **Zero new completion vocabulary.** Phase 42 proved `verify_completion/2` is byte-for-byte unchanged; Phase 43 must keep it that way.
- **D-09 (carry-forward, hard):** Capability honesty — adapters advertise `:tus_upload` **only** if they implement `upload_part_stream/5`. S3 + Local advertise it; GCS does NOT. `TusPlug.init/1` raises `ArgumentError` on missing `:tus_upload` (already shipped at `tus_plug.ex:78-86`).
- **D-10 (carry-forward, hard):** **One column only** for the whole tus feature (`resumable_protocol`, already added in Phase 42). Reuse `upload_strategy: "resumable"`, the `"resuming"`/`"signed"` FSM lanes, and `last_known_offset` (== tus `Upload-Offset`). **No `tus_*` columns, no new table, no new FSM states.** (Phase 43 corollary: reuse the EXISTING `multipart_upload_id`/`multipart_parts` columns for S3 state — see Finding 1.)
- **D-12 (carry-forward, design):** `TusPlug` stays a thin protocol-versioned edge; storage backing is protocol-agnostic. Generalizing the sink to a callback (Phase 43) is exactly the seam D-12 anticipated.
- **Scope fence (REQUIREMENTS Out of Scope):** No Checksum extension, no Concatenation/parallel partial uploads (`parallelUploads: 1` is the documented contract), no `Upload-Defer-Length` (require `Upload-Length`), no GCS-as-tus-backend, no R2-native tus.

### Claude's Discretion

- The exact `upload_part_stream/5` arg order and return shape (derived in Finding 2 below — recommended, not locked).
- Tail-buffer storage location under the canonical tmp root (`Rindle.AV.TempRunDir.root_dir()` → `Rindle.tmp/`, recommend `Rindle.tmp/tus/<session_id>.tail`).
- Whether the S3 `upload_part_stream/5` buffers the whole PATCH body to a temp file before `UploadPart`, or streams it (recommend buffer-then-UploadPart for v1 — see Pitfall 3).
- Test fixture size for the "≥ 1 GiB" proof (≥ 1 GiB is the floor; a 1 GiB synthetic stream is sufficient).

### Deferred Ideas (OUT OF SCOPE for Phase 43)

- Optional resume authorizer enforcement, `Rindle.Error` tus vocabulary, tus edge telemetry through `ResumableTelemetry`, `mix rindle.doctor` tus checks, `guides/resumable_uploads.md`, generated-app Node tus-js-client CI proof → **Phase 44** (TUS-10..14).
- Browser→Mux direct creator upload → **Phase 45** (MUX-20..23).

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **TUS-06** | OPTIONAL `upload_part_stream/5` on `Rindle.Storage`; S3 = one `UploadPart` per PATCH ≥ 5 MiB + sub-5-MiB tail buffered under `Rindle.tmp/tus/`, flushed as final part on completion | Finding 1 (state persistence), Finding 2 (callback signature), Finding 5 (tail-buffer pattern), Pitfall 3 (small-PATCH buffering). ExAws.S3 `upload_part/6` verified at `deps/ex_aws_s3/lib/ex_aws/s3.ex:1811`; ETag in response **headers** (no body parser). |
| **TUS-07** | Adapters advertise `:tus_upload` honestly (S3+Local yes, GCS no); `TusPlug.init/1` raises on missing `:tus_upload` | Already shipped: `Local.capabilities/0` advertises `:tus_upload` (`local.ex:83`); `TusPlug.init/1` raises (`tus_plug.ex:78-86`); `Capabilities.@known` includes it (`capabilities.ex:29`). Phase 43 only ADDS `:tus_upload` to `S3.capabilities/0` (`s3.ex:152`) once `upload_part_stream/5` lands. |
| **TUS-08** | Final PATCH → `complete_multipart_upload/4` → UNCHANGED `verify_completion/2` (head re-sniff, size/type, `PromoteAsset` in one `Ecto.Multi`), zero new completion vocabulary | `verify_completion/2` at `broker.ex:471-537`; `Oban.insert(:promote_job, ...)` at `:517`; S3 `head/2` returns size+content_type (`s3.ex:136-145`). The opts-flow gap (TusPlug must pass adapter opts to `verify_completion`) is Finding 4. |
| **TUS-09** | Expiry (`Upload-Expires` + `410`), `DELETE` terminates; reaper branches on `resumable_protocol` (`"tus"`→abort S3 multipart/rm local tmp; `"gcs_native"`→session-URI cancel); MinIO ≥ 1 GiB drop+resume + `list_multipart_uploads`-empty abort assertion | `Upload-Expires`/`410` already emitted by Phase-42 TusPlug (`tus_plug.ex:136,184,388`). Reaper gap is Finding 3 (`resumable_abort_session?/1` at `upload_maintenance.ex:551` catches tus sessions but routes them to the wrong cancel path). `list_multipart_uploads` verified at `deps/ex_aws_s3/lib/ex_aws/s3.ex:360`. MinIO harness is Finding 6. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `ex_aws` | 2.6.1 (locked) `[VERIFIED: mix.lock]` | AWS request signing + transport orchestration | Already the S3 client in `Rindle.Storage.S3` (`s3.ex:8 alias ExAws.S3`) |
| `ex_aws_s3` | 2.5.9 (locked) `[VERIFIED: mix.lock]` | S3 operation builders (multipart, head, presign) | Already used; multipart funcs all present (verified below) |
| `sweet_xml` | 0.7.5 (transitive, present) `[VERIFIED: deps/sweet_xml]` | XML parsing for `complete_multipart_upload`/`list_multipart_uploads`/`initiate_multipart_upload` parsers | Required by ex_aws_s3 parsers; already pulled by `ex_aws_s3` AND `image` (non-optional there) |
| `hackney` | ~> 1.20 (optional, present) `[VERIFIED: mix.exs:91]` | Default HTTP backend for ExAws requests in test/CI | Already the configured ExAws transport |

**No new packages.** Phase 43 is pure code (adapter callback + reaper branch + tests) over the already-installed ExAws stack. The Package Legitimacy Audit below is therefore N/A.

### Verified ExAws.S3 multipart API (read from installed dep source)

`[VERIFIED: deps/ex_aws_s3/lib/ex_aws/s3.ex]` — exact arities and return contracts:

| Function | Line | Signature | Return / ETag location |
|----------|------|-----------|------------------------|
| `S3.initiate_multipart_upload/3` | 1789 | `(bucket, object, opts \\ [])` | Parsed body `%{upload_id: id}` (already used at `s3.ex:75`) |
| `S3.upload_part/6` | 1811 | `(bucket, object, upload_id, part_number, body, opts \\ [])` | **NO body parser** — ETag is in the HTTP **response headers** (`%{headers: [...]}`); the adapter MUST extract it (see Pitfall 2) |
| `S3.complete_multipart_upload/4` | 1903 | `(bucket, object, upload_id, parts)` — `parts :: [{part_number, etag}]` | Parsed body via `parse_complete_multipart_upload` (already used at `s3.ex:110`, takes `normalize_parts/1` tuples) |
| `S3.abort_multipart_upload/3` | 1931 | `(bucket, object, upload_id)` | Bare DELETE; already used at `s3.ex:122` |
| `S3.list_multipart_uploads/2` | 360 | `(bucket, opts \\ [])` | Parsed body `%{uploads: [%{key:, upload_id:}, ...]}` — the abort-leak assertion's verification call (NEW to the S3 adapter) |
| `S3.list_parts/4` | 1940 | `(bucket, object, upload_id, opts \\ [])` | `%{parts: [%{part_number:, etag:, size:}]}` — optional, for resume reconciliation |

### Supporting (in-repo, reused verbatim)
| Module | Purpose | When to Use |
|--------|---------|-------------|
| `Rindle.Storage.S3` (`lib/rindle/storage/s3.ex`) | Existing S3 adapter — add `upload_part_stream/5` + `:tus_upload` cap + `list_multipart_uploads` helper | The TUS-06 implementation site |
| `Rindle.Storage.Local` (`lib/rindle/storage/local.ex`) | Has `tus_part_path/2`, `tus_append/3`, `tus_complete/3` (Phase 42) — wrap them into `upload_part_stream/5` | The Local TUS-06 implementation |
| `Rindle.Upload.Broker.verify_completion/2` (`broker.ex:471`) | The UNCHANGED completion lane | TUS-08 convergence — DO NOT MODIFY |
| `Rindle.Ops.UploadMaintenance` (`upload_maintenance.ex`) | The reaper — add the `resumable_protocol` branch | TUS-09 reaper |
| `Rindle.AV.TempRunDir.root_dir/0` (`temp_run_dir.ex:26`) | Canonical `Rindle.tmp/` root resolver | Tail-buffer location for the S3 sub-5-MiB chunk |
| `Rindle.Security.StorageKey` (`lib/rindle/security/storage_key.ex`) | Storage-key generation | Already used by `initiate_tus_upload/2` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Reuse `multipart_upload_id`/`multipart_parts` columns | Add `tus_upload_id`/`tus_parts` columns | Violates D-10's one-column budget; the existing columns are semantically identical and already cast in the schema — reuse them |
| One UploadPart per PATCH (tusd pattern) | Buffer entire upload locally then one multipart at completion | Defeats the resumability point (no offset durability mid-flight); tusd pattern is the locked TUS-06 design |
| `S3.upload_part/6` (raw body) | Presigned `presigned_upload_part` + client PUT | Topology B puts bytes on the BEAM (server-mediated) — the tus contract; presigned is Topology A (multipart upload mode), a different lane |

**Installation:** No new packages.
```bash
# Nothing to install — ex_aws / ex_aws_s3 / sweet_xml / hackney already locked.
mix deps.get   # no-op confirmation
```

## Package Legitimacy Audit

**N/A — Phase 43 installs no external packages.** All dependencies (`ex_aws` 2.6.1, `ex_aws_s3` 2.5.9, `sweet_xml` 0.7.5, `hackney` ~> 1.20) are already present in `mix.lock` and in active use by the existing `Rindle.Storage.S3` adapter. slopcheck was not run because there is nothing new to verify; the existing packages are mature (ex_aws is the canonical Elixir AWS client, years old, millions of downloads, source at github.com/ex-aws/ex_aws).

## Architecture Patterns

### System Architecture Diagram

```
                          tus client (tus-js-client / @uppy/tus, parallelUploads: 1)
                                            │
                       POST / HEAD / PATCH / DELETE  (HMAC-signed URL, path-segment token)
                                            │
                                            ▼
                    ┌─────────────────────────────────────────────┐
                    │  Rindle.Upload.TusPlug (bare Plug edge)      │
                    │  - init/1: require :tus_upload OR raise       │
                    │  - PATCH: 415 → 409 (no body read) → drain    │
                    │    read_body(1 MiB) loop                      │   ← protocol-only (D-12)
                    └───────────────┬─────────────────────────────┘
                                    │  dispatch to adapter callback (NEW — not hard-wired Local)
                                    ▼
            ┌───────────────────────────────────────────────────────────────┐
            │  Rindle.Storage upload_part_stream/5  (NEW OPTIONAL callback)   │
            │                                                                 │
            │   S3 adapter                          Local adapter             │
            │   ─────────                           ────────────              │
            │   buffer PATCH body → temp            File.open([:append])      │
            │   if buffered ≥ 5 MiB OR final:       IO.binwrite per chunk     │
            │     S3.upload_part(part_n) ───┐       (tus_append/3 reuse)       │
            │     ETag ← response.headers   │                                 │
            │     persist {part_n, etag}    │                                 │
            │     to multipart_parts map ───┼──────────────┐                  │
            │   else: keep tail buffered    │              │                  │
            └───────────────────────────────┼──────────────┼──────────────────┘
                                            │              │
              persist last_known_offset ────┘              ▼
              (= tus Upload-Offset)             ┌──────────────────────────┐
                                                │ media_upload_sessions     │
              ┌──── final PATCH (offset==length)│ - multipart_upload_id     │ ← REUSED, no new col
              ▼                                 │ - multipart_parts (map)   │
   ┌─────────────────────────────┐             │ - last_known_offset       │
   │ S3.complete_multipart_upload │             │ - resumable_protocol:"tus"│
   │  (flush tail as final part)  │             └──────────────────────────┘
   └───────────────┬──────────────┘
                   │ converge (UNCHANGED — D-08)
                   ▼
   ┌──────────────────────────────────────────────┐
   │ Broker.verify_completion/2  (broker.ex:471)    │
   │  adapter.head → size + content_type            │
   │  Ecto.Multi: session→completed, asset→validating│
   │  Oban.insert(PromoteAsset)  ← same transaction  │
   └──────────────────────────────────────────────┘

   ── Expiry / abandonment lane (TUS-09) ──────────────────────────────────
   Oban cron → AbortIncompleteUploads.perform → UploadMaintenance.abort_incomplete_uploads
        │
        └─ expire_session → BRANCH ON resumable_protocol  (NEW):
              "tus"        → S3.abort_multipart_upload(upload_key, multipart_upload_id)
                             OR Local: File.rm(tus_part_path)   → state:"expired"
              "gcs_native" → adapter.cancel_resumable_upload(session_uri)  (existing)
              nil (legacy) → existing standard/resumable lanes unchanged
   Proof: after abort, S3.list_multipart_uploads(bucket) returns [] for the key.
```

File-to-implementation mapping is in the Component Responsibilities below; the diagram shows data flow only.

### Recommended Project Structure (files touched)
```
lib/rindle/
├── storage.ex                          # +upload_part_stream/5 @callback + @optional_callbacks + @type
├── storage/s3.ex                       # +upload_part_stream/5 impl, +list_multipart_uploads helper,
│                                       #   +:tus_upload capability, ETag-from-headers extraction
├── storage/local.ex                    # +upload_part_stream/5 impl (wraps tus_append/3; part_number ignored)
├── upload/tus_plug.ex                  # PATCH/completion: dispatch through adapter.upload_part_stream/5
│                                       #   instead of hard-wired Local.tus_*; pass adapter opts through
└── ops/upload_maintenance.ex          # +resumable_protocol branch in expire_session lane

test/rindle/
├── storage/s3_tus_test.exs            # NEW — unit: upload_part_stream tail-buffer logic (mocked/unit)
├── storage/s3_test.exs                # +@tag :minio UploadPart-via-callback round-trip
├── ops/upload_maintenance_test.exs    # +tus-protocol reaper branch (abort multipart vs cancel session)
└── upload/tus_s3_integration_test.exs # NEW — @tag :minio ≥ 1 GiB drop+resume + list_multipart_uploads-empty
```

### Pattern 1: `upload_part_stream/5` as OPTIONAL callback (TUS-06 / D-01)
**What:** A new behaviour callback that streams ONE PATCH worth of bytes into the adapter's part store, returning the new committed offset and (for S3) the accumulated part state to persist.
**When to use:** Called by `TusPlug.handle_patch/2` per PATCH; the adapter (not the Plug) owns the bytes→part translation.
**Example (recommended signature — Finding 2):**
```elixir
# Source: derived from Rindle.Storage callback shapes (storage.ex) + TusPlug PATCH call site (tus_plug.ex:213).
# Added to lib/rindle/storage.ex as an OPTIONAL callback (mirrors @optional_callbacks at storage.ex:283).
@typedoc "Per-PATCH streaming part-write state for tus (Topology B server-mediated)."
@type tus_part_state :: %{
        required(:offset) => non_neg_integer(),      # new committed offset (== tus Upload-Offset)
        optional(:upload_id) => String.t(),          # S3 multipart UploadId (nil for Local)
        optional(:parts) => [%{part_number: pos_integer(), etag: String.t()}],  # accumulated (S3)
        optional(atom()) => term()
      }

@doc """
Streams one PATCH body into the adapter's resumable part store for a tus upload.

Adapters expose this callback only when they advertise the `:tus_upload`
capability. The `read_chunk` function is the bounded body reader supplied by the
TusPlug edge (1 MiB read_length, per-PATCH ceiling); the adapter pulls chunks
until `:done`, never buffering the whole upload. `state` carries the prior
`multipart_upload_id` + accumulated `parts` (S3) or is `%{offset: n}` (Local).
Returns the updated `t:tus_part_state/0` to persist on the session row.
"""
@callback upload_part_stream(
            key :: String.t(),
            read_chunk :: (-> {:cont, binary()} | :done | {:error, term()}),
            base_offset :: non_neg_integer(),
            state :: tus_part_state(),
            opts :: keyword()
          ) :: {:ok, tus_part_state()} | {:error, term()}

@optional_callbacks initiate_resumable_upload: 3,
                    resumable_upload_status: 3,
                    cancel_resumable_upload: 3,
                    verify_resumable_completion: 3,
                    upload_part_stream: 5   # ADD
```
**Note on `read_chunk`:** Passing a closure that wraps `Plug.Conn.read_body/2` keeps the conn (and slow-loris protection) inside the Plug while letting the adapter pull bytes. Alternative (simpler, recommended for v1): the Plug drains the PATCH body to a temp file FIRST (bounded by ceiling → 413), then calls `upload_part_stream(key, temp_path, base_offset, state, opts)` with a path instead of a closure. This is the tusd pattern (PATCH body → temp file → UploadPart) and avoids threading `conn` into the adapter. **Recommend the temp-path variant** — it is simpler, matches tusd, and the Local adapter already takes a path-like model. The planner should pick one and lock it; the 5-arg arity holds either way (arg 2 is `read_chunk_fn | temp_path`).

### Pattern 2: S3 tail-buffer (the tusd S3-backend pattern) — TUS-06 core
**What:** S3 requires every non-final part ≥ 5 MiB. A tus PATCH may carry < 5 MiB (especially a resumed tail). The adapter buffers bytes on local disk until it has ≥ 5 MiB, uploads that as a part, and keeps any remainder buffered. On completion, the remaining buffer (any size) is flushed as the final part.
**When to use:** Every S3 `upload_part_stream/5` call.
**Example:**
```elixir
# Source: tusd S3 backend pattern (tus.io/blog/2016/03/07/tus-s3-backend.html) +
#   ExAws.S3.upload_part/6 (deps/ex_aws_s3/lib/ex_aws/s3.ex:1811). [CITED]
@s3_min_part_size 5 * 1024 * 1024   # 5 MiB — S3 minimum non-final part

# Per PATCH: append body to <Rindle.tmp>/tus/<session_id>.tail, then while the
# tail file is >= 5 MiB, slice off a 5 MiB part, S3.upload_part it, capture the
# ETag from response.headers, append {part_number, etag} to state.parts.
# Leftover (< 5 MiB) stays in the tail file across PATCHes.
# On completion: upload the final tail (any size) as the last part, then
# S3.complete_multipart_upload with the full ordered parts list.
```
**Critical:** part_number is 1-based and must be strictly increasing and persisted (S3 reassembles in part_number order, not arrival order). The accumulated `parts` list lives in `multipart_parts` (map) on the session row between PATCHes.

### Pattern 3: TusPlug adapter dispatch (replace hard-wired Local) — TUS-06/08
**What:** Phase 42's `TusPlug` calls `Local.tus_part_path/tus_append/tus_complete` directly (`tus_plug.ex:214,291`). Phase 43 must route through `adapter.upload_part_stream/5` and `adapter.complete_multipart_upload/4` so S3 works without the Plug knowing the backend.
**When to use:** `handle_patch/2` and `complete_upload/3` in `tus_plug.ex`.
**Anti-pattern avoided:** Do NOT special-case `if adapter == Local` in the Plug — dispatch polymorphically through the behaviour. Local's `upload_part_stream/5` wraps its existing append helpers; S3's does the multipart dance. The Plug stays protocol-only (D-12).

### Pattern 4: Reaper branch on `resumable_protocol` (TUS-09) — the load-bearing fix
**What:** `resumable_abort_session?/1` (`upload_maintenance.ex:551`) currently returns `true` for ANY `upload_strategy: "resumable"` session in `["signed","resuming","uploading","aborted"]`. tus sessions ARE `upload_strategy: "resumable"`, so they match — and get routed to `attempt_resumable_cancel` → `resolve_resumable_adapter` (`:522`), which `require_upload(adapter, :resumable_upload_session)`. S3/Local do NOT advertise that capability, so the resolve fails → the tus session is mis-handled (persisted as `aborted` with a `resumable_cancel_failed:*` reason but the S3 multipart is never aborted → **leak**).
**Fix:** Branch `expire_session/2` (`:386`) on `session.resumable_protocol`:
```elixir
# Source: upload_maintenance.ex:386-392 (verified). Add the tus branch BEFORE the resumable check.
defp expire_session(session, acc) do
  cond do
    tus_session?(session)       -> expire_tus_session(session, acc)        # NEW
    resumable_abort_session?(session) -> expire_resumable_session(session, acc)  # gcs_native
    true                        -> expire_standard_session(session, acc)
  end
end

defp tus_session?(%MediaUploadSession{upload_strategy: "resumable", resumable_protocol: "tus"}),
  do: true
defp tus_session?(_), do: false

# expire_tus_session: resolve adapter from profile; if S3 (has multipart_upload_id) ->
#   adapter.abort_multipart_upload(upload_key, multipart_upload_id, opts);
#   if Local -> File.rm(Local.tus_part_path(session.id, root: ...)) + rm tail buffer;
#   then persist state:"expired". Idempotent on {:error, :not_found}.
```
**Also tighten `resumable_abort_session?/1`** to exclude tus (`resumable_protocol: "tus"`) so a future query expansion can't double-route. The `fetch_incomplete_timed_out_sessions/1` query (`:135`) already catches tus sessions via `state in ["signed","uploading"]` — they're in `"signed"` through PATCHes, so no query change needed.

### Anti-Patterns to Avoid
- **Buffering the whole ≥ 1 GiB upload in memory:** The Plug reads in 1 MiB chunks (`@read_length`, `tus_plug.ex:68`); the S3 adapter must spill to a tail FILE, never accumulate the body in a binary.
- **Trusting `multipart_parts` arrival order:** Persist part_number explicitly; reassembly is by part_number.
- **Adding a tus-specific completion path:** D-08 — converge into `verify_completion/2` unchanged.
- **Routing tus sessions through the resumable (session-URI) cancel:** that's the exact TUS-09 bug; branch on `resumable_protocol`.
- **Cross-device tail rename for S3:** S3 has no rename; the tail is uploaded as the final UploadPart, not renamed. (Local keeps its `:exdev`-fails atomic rename, Pitfall 5 from Phase 42.)

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| S3 multipart request signing | Manual AWS SigV4 / XML | `ExAws.S3.upload_part/6`, `complete_multipart_upload/4`, `abort_multipart_upload/3`, `list_multipart_uploads/2` | All present in `ex_aws_s3` 2.5.9 (verified); SigV4 + XML parsing are solved |
| ETag extraction | Custom regex on raw response | Read `response.headers` (lowercased) for `"etag"` | `upload_part` returns ETag in headers; mirror the `handle_head_response` header-normalize at `s3.ex:136-138` |
| Completion → asset promotion | New tus completion function | `Broker.verify_completion/2` (UNCHANGED) | D-08; the single trusted lane with the `Ecto.Multi` + Oban enqueue |
| Session expiry sweep | New tus reaper | `UploadMaintenance` + `AbortIncompleteUploads` (add a branch) | TUS-09; the two-step cron lane already exists |
| Cross-request UploadId/ETag persistence | New `tus_*` columns | Existing `multipart_upload_id` + `multipart_parts` columns | D-10 budget; columns already cast (`media_upload_session.ex:85-86`) |
| Tmp root resolution | `System.tmp_dir!` ad hoc | `Rindle.AV.TempRunDir.root_dir/0` (`Rindle.tmp/`) | Canonical sweepable root (invariant 13); the orphan reaper already sweeps it |
| MinIO test scaffolding | New docker setup | Existing `RINDLE_MINIO_*` env + `@tag :minio` + CI MinIO service | Finding 6; the harness is already in CI (`.github/workflows/ci.yml:143-216`) |

**Key insight:** Phase 43 is almost entirely *wiring existing primitives* — the ExAws multipart calls, the verify lane, the reaper, the columns, and the MinIO harness all exist. The genuinely-new code is (1) the `upload_part_stream/5` callback + its S3 tail-buffer impl, (2) the reaper `resumable_protocol` branch, and (3) the proof test. Resist building parallel infrastructure.

## Runtime State Inventory

> Phase 43 is a code/config phase (new callback + adapter impl + reaper branch + tests). It is NOT a rename/refactor/migration of stored state. There is one durable-state consideration worth flagging explicitly.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | tus session state persists in `media_upload_sessions` (`multipart_upload_id`, `multipart_parts`, `last_known_offset`, `resumable_protocol`). Phase 43 **reuses** existing columns — no schema change, no data migration. | None — code-only (write S3 UploadId/ETags into existing columns) |
| Live service config | S3/MinIO multipart uploads are server-side state. An in-flight `UploadId` exists on the S3 server between PATCHes and is only cleaned by `complete_*` or `abort_*`. Abandoned tus sessions leave dangling multipart uploads (the exact leak TUS-09 reaps). | The reaper branch (Finding 3) IS the cleanup; the proof test asserts `list_multipart_uploads` empty post-abort |
| OS-registered state | None — no OS scheduler/service registrations introduced. | None — verified (no launchd/systemd/Task Scheduler touch) |
| Secrets/env vars | `RINDLE_MINIO_*` env vars (test/CI only) already exist; no new secrets. S3 creds resolved via `aws_config` opts / `Application.get_env(:ex_aws, :s3)` (existing). | None — reuse existing test env (`config/test.exs`, `ci.yml:143-147`) |
| Build artifacts | None — no new compiled artifacts, no migration. | None — verified (no new `priv/repo/migrations/*`) |

**No migration this phase** — verified: D-10's single `resumable_protocol` column landed in Phase 42 (`priv/repo/migrations/20260522120000_add_resumable_protocol_to_media_upload_sessions.exs`); the `multipart_*` columns landed in `20260428110000_extend_media_upload_sessions_for_multipart.exs`. Both are already in the schema cast list.

## Common Pitfalls

### Pitfall 1: tus session is `upload_strategy: "resumable"` → the reaper mis-routes it
**What goes wrong:** A tus session, being `upload_strategy: "resumable"`, is caught by `resumable_abort_session?/1` and routed to the GCS session-URI cancel path, which fails the `:resumable_upload_session` capability gate for S3/Local. The S3 multipart upload is never aborted → orphaned multipart parts accrue storage cost forever.
**Why it happens:** Phase 42 reused the resumable strategy lane (D-10) for tus; the reaper predates tus and only knew the GCS-native flavor of "resumable".
**How to avoid:** Branch `expire_session/2` on `resumable_protocol == "tus"` FIRST (Finding 3 / Pattern 4). Tighten `resumable_abort_session?/1` to exclude tus.
**Warning signs:** A tus session lands in `aborted` with `failure_reason: "resumable_cancel_failed:*"`; `list_multipart_uploads` still shows the upload after the reaper ran.

### Pitfall 2: `upload_part` ETag is in response HEADERS, not the parsed body
**What goes wrong:** Treating `S3.upload_part/6` like the other multipart calls (which have body parsers) and looking for `%{body: %{etag: ...}}` — there is no parser for `upload_part`, so the body is raw and the ETag lives in the HTTP response headers.
**Why it happens:** `ex_aws_s3` registers no `parser:` for `upload_part` (verified at `s3.ex:1811-1814` — bare `request/4` with no opts map).
**How to avoid:** After `ExAws.request(S3.upload_part(...))`, read the ETag from `response.headers` with a case-insensitive lookup (mirror `s3.ex:136-138` `Enum.into(headers, %{}, fn {k,v} -> {String.downcase(k), v} end)` then `Map.get(normalized, "etag")`). The MinIO test harness already does exactly this for presigned parts (`s3_test.exs:130-148` `put_part_to_presigned_url` reads `etag`/`ETag` from response headers).
**Warning signs:** `complete_multipart_upload` returns an `InvalidPart`/`MalformedXML` error because ETags are empty.

### Pitfall 3: A small PATCH (< 5 MiB) cannot be uploaded as a non-final S3 part
**What goes wrong:** Naively doing one `UploadPart` per PATCH fails when a PATCH carries < 5 MiB and is NOT the final chunk (S3 rejects parts < 5 MiB except the last). tus-js-client with `parallelUploads: 1` typically sends large chunks, but a resumed tail or a small `chunkSize` config can produce sub-5-MiB PATCHes.
**Why it happens:** S3's 5 MiB minimum applies to all but the last part `[CITED: docs.aws.amazon.com/AmazonS3/latest/userguide/qfacts.html]`.
**How to avoid:** The tusd tail-buffer pattern (Pattern 2): accumulate PATCH bytes in `<Rindle.tmp>/tus/<session_id>.tail`; only `UploadPart` when ≥ 5 MiB has accumulated; flush the remainder as the final part at completion `[CITED: tus.io/blog/2016/03/07/tus-s3-backend.html]`. The `requirement TUS-06` wording ("one S3 `UploadPart` per `PATCH` ≥ 5 MiB, buffering a sub-5 MiB final chunk") encodes exactly this.
**Warning signs:** `EntityTooSmall` S3 error on a non-final part.

### Pitfall 4: TusPlug passes only `root:` opts — S3 needs `bucket` + `aws_config`
**What goes wrong:** Phase-42 `TusPlug` calls `Local.tus_complete(... root: opts[:root])` and `Broker.verify_completion(session.id, root: opts[:root])` (`tus_plug.ex:291-292`). For S3, `bucket` (from `Application.get_env(:rindle, Rindle.Storage.S3)` or opts) and `aws_config` (from `Application.get_env(:ex_aws, :s3)` or opts) must reach the adapter. If only `root:` flows through, S3 calls fail with `:missing_bucket` (`s3.ex:175`).
**Why it happens:** The Local-only Phase-42 edge never needed adapter opts beyond `root`.
**How to avoid:** `TusPlug.init/1` should resolve and carry the adapter's storage opts (recommend reading `Application.get_env(:rindle, adapter)` at init and merging into the call opts), OR rely on the S3 adapter's application-env fallback (which the existing MinIO `verify_completion(session.id)` test uses with NO opts — `lifecycle_integration_test.exs:200`). **Recommend:** the S3 adapter already falls back to app-env for both `bucket` and `aws_config`, so the minimal path is to let `verify_completion`/`upload_part_stream` resolve from app-env when opts are absent — but the planner should explicitly decide and TEST the opts-flow (it's the likeliest integration bug).
**Warning signs:** `{:error, :missing_bucket}` from any S3 call inside the tus path; works in Local tests, fails the moment S3 is the adapter.

### Pitfall 5: Local `upload_part_stream/5` must ignore part semantics gracefully
**What goes wrong:** Forcing Local through a part-numbered S3-shaped contract — Local has no UploadId, no parts, no 5 MiB minimum.
**Why it happens:** The callback is designed against S3 (D-01).
**How to avoid:** Local's `upload_part_stream/5` wraps `tus_append/3` and returns `%{offset: new_offset}` with NO `:upload_id`/`:parts` keys; the optional-map type accommodates this. Local completion stays the atomic `File.rename` (`tus_complete/3`). The Plug branches on whether the returned state has `:upload_id` to decide completion mode (S3 `complete_multipart_upload` vs Local rename) — OR add an `complete_part_stream/4` companion callback so completion is also polymorphic (cleaner; planner's call).
**Warning signs:** Local tests pass but the abstraction leaks S3 part-numbers into Local.

## Code Examples

### Extracting the ETag from an UploadPart response (S3 adapter, NEW)
```elixir
# Source: mirrors Rindle.Storage.S3.handle_head_response header-normalize (s3.ex:136-138, verified).
defp upload_one_part(bucket, key, upload_id, part_number, body, opts) do
  with {:ok, response} <-
         request(ExAws.S3.upload_part(bucket, key, upload_id, part_number, body), opts),
       etag when is_binary(etag) <- etag_from_headers(response) do
    {:ok, %{part_number: part_number, etag: etag}}
  else
    nil -> {:error, :missing_etag}
    {:error, reason} -> {:error, reason}
  end
end

defp etag_from_headers(%{headers: headers}) do
  headers
  |> Enum.into(%{}, fn {k, v} -> {String.downcase(k), v} end)
  |> Map.get("etag")
end
```

### Reaper tus branch — abort the S3 multipart (TUS-09)
```elixir
# Source: upload_maintenance.ex expire/persist pattern (verified :386-446) + S3.abort_multipart_upload (s3.ex:120).
defp expire_tus_session(session, acc) do
  case abort_tus_backing(session) do
    :ok ->
      session
      |> MediaUploadSession.changeset(%{state: "expired"})
      |> Config.repo().update()
      |> case do
        {:ok, _} -> acc |> Map.update!(:sessions_aborted, &(&1 + 1))
        {:error, _} -> Map.update!(acc, :abort_errors, &(&1 + 1))
      end
    {:error, _reason} ->
      Map.update!(acc, :abort_errors, &(&1 + 1))   # leave row for retry next cron
  end
end

defp abort_tus_backing(%MediaUploadSession{multipart_upload_id: id} = s)
     when is_binary(id) and id != "" do
  with {:ok, adapter} <- resolve_tus_adapter(s) do
    case adapter.abort_multipart_upload(s.upload_key, id, []) do
      {:ok, _} -> :ok
      {:error, :not_found} -> :ok          # idempotent
      err -> err
    end
  end
end
defp abort_tus_backing(%MediaUploadSession{} = s) do   # Local sink (no upload_id)
  File.rm(Rindle.Storage.Local.tus_part_path(s.id, []))  # best-effort; reaper sweeps tmp anyway
  :ok
end
```

### MinIO ≥ 1 GiB drop-and-resume + zero-leak proof (TUS-09)
```elixir
# Source: existing MinIO harness (s3_test.exs:32-77, lifecycle_integration_test.exs:55-90, verified).
@tag :minio
@tag timeout: 600_000   # 10 min — a 1 GiB stream takes time even locally
test "tus S3 ≥1GiB drop+resume completes; abandoned upload reaped to empty" do
  # 1. POST → signed tus URL (TusPlug or Broker.initiate_tus_upload + sign)
  # 2. PATCH ~600 MiB → assert 204 + Upload-Offset advances; multipart_upload_id persisted
  # 3. SIMULATE DROP: stop mid-stream; HEAD → authoritative offset
  # 4. Resume PATCH from offset → … → final PATCH (offset == length) → 204 completion
  # 5. assert verify_completion ran: session "completed", asset "validating", byte_size == 1 GiB
  # 6. ABORT lane: create a second tus session, PATCH one part, then expire + run reaper
  # 7. assert {:ok, %{body: %{uploads: uploads}}} = ExAws.S3.list_multipart_uploads(bucket) |> ExAws.request(cfg)
  #    refute Enum.any?(uploads, & &1.key == abandoned_upload_key)   # ZERO LEAK
end
```

## State of the Art

| Old Approach (Phase 42) | Current Approach (Phase 43) | When Changed | Impact |
|--------------------------|------------------------------|--------------|--------|
| `TusPlug` hard-wired to `Local.tus_append/tus_complete` | `TusPlug` dispatches through `adapter.upload_part_stream/5` | Phase 43 | S3 (and any future tus sink) works without Plug changes (D-12 realized) |
| `:tus_upload` advertised by Local only | S3 also advertises `:tus_upload` (once callback lands) | Phase 43 | S3 becomes a first-class tus sink |
| Reaper routes all `resumable` sessions to session-URI cancel | Reaper branches on `resumable_protocol` (tus → multipart abort) | Phase 43 | Closes the orphaned-multipart leak (TUS-09) |
| MinIO proof = direct multipart (presigned) + Local tus | MinIO proof = server-mediated tus over S3 multipart, ≥ 1 GiB drop+resume | Phase 43 | The first true Topology-B-over-S3 proof |

**Deprecated/outdated:** none — Phase 43 is additive over the established ExAws stack and Phase-42 substrate.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `upload_part_stream/5` 5-arg shape (key, read_chunk\|temp_path, base_offset, state, opts) is the right ergonomics | Pattern 1 / Finding 2 | LOW — derived from existing callback shapes + the PATCH call site; planner may refine arg order. The arity-5 + OPTIONAL-callback decision is locked (D-01); only the internal shape is discretionary. |
| A2 | Reusing `multipart_upload_id`/`multipart_parts` columns for S3 tus state is acceptable (no new column) | Finding 1 | LOW — columns are semantically identical and already cast; preserves D-10 budget. If the planner wants tus/multipart strict isolation it could add columns, but that breaks the one-column lock. |
| A3 | The temp-path variant of `upload_part_stream` (drain PATCH to temp file, then UploadPart) is preferable to threading `conn`/closures into the adapter | Pattern 1 | LOW — matches tusd; simpler. Planner picks; both are arity-5. |
| A4 | S3 adapter app-env fallback (`bucket`/`aws_config`) is sufficient for the tus opts-flow, OR TusPlug resolves+passes them | Pitfall 4 | MEDIUM — the likeliest integration bug. Must be explicitly decided AND tested. The existing MinIO test calls `verify_completion(session.id)` with no opts and works via app-env, so the fallback is proven for `head`; `upload_part_stream`/`complete` need the same resolution. |
| A5 | A 1 GiB synthetic stream satisfies the "≥ 1 GiB" proof floor; no need for a real media file | Finding 6 | LOW — the requirement says ≥ 1 GiB drop-and-resume; size, not content, is the point. The Phase-44 CI proof uses a real ≥ 200 MB MP4. |

## Open Questions

1. **Polymorphic completion: branch on state, or add `complete_part_stream/4`?**
   - What we know: S3 completes via `complete_multipart_upload/4`; Local completes via atomic `File.rename` (`tus_complete/3`). The Plug must pick the right one.
   - What's unclear: Whether to branch in the Plug on `state[:upload_id]` presence, or add a second OPTIONAL callback `complete_part_stream/4` for symmetry.
   - Recommendation: Add `complete_part_stream/4` (cleaner, keeps the Plug fully polymorphic; one more OPTIONAL callback is cheap and matches D-12). Planner's call; either satisfies TUS-08.

2. **Does `TusPlug` need adapter storage opts at `init/1` (eager) or per-call (lazy app-env)?**
   - What we know: Profile carries only the adapter module, not its opts (`profile.ex:63`). S3 falls back to app-env for `bucket`/`aws_config`.
   - What's unclear: Whether to resolve opts at `init/1` and carry them, or rely on app-env at call time.
   - Recommendation: Rely on the S3 adapter's existing app-env fallback for v1 (least new code, already proven for `head`); document the contract. Revisit if multi-bucket-per-profile is needed (out of scope).

3. **Resume reconciliation after a drop: trust persisted `multipart_parts`, or `list_parts` from S3?**
   - What we know: `last_known_offset` + persisted `multipart_parts` are the durable truth across PATCHes; `S3.list_parts/4` can reconcile against the server.
   - What's unclear: Whether to defensively `list_parts` on resume to detect a partially-uploaded part lost to a mid-UploadPart crash.
   - Recommendation: Trust the persisted state for v1 (HEAD returns `last_known_offset`, which is only advanced AFTER a part's ETag is persisted — so the offset never overstates committed bytes). `list_parts` reconciliation is a v1.9 hardening. The tail buffer makes a torn part impossible (the tail is re-PATCHed, not lost).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `ex_aws` / `ex_aws_s3` | S3 multipart calls | ✓ | 2.6.1 / 2.5.9 | — (locked in mix.lock) |
| `sweet_xml` | ex_aws_s3 XML parsers | ✓ | 0.7.5 | — (transitive, present in deps/) |
| `hackney` | ExAws HTTP transport (test/CI) | ✓ | ~> 1.20 | req/finch (ExAws supports either) |
| MinIO server | `@tag :minio` ≥ 1 GiB proof + abort assertion | ✗ (local dev) / ✓ (CI) | minio/minio (CI) | Tests are `@tag :minio` excluded by default (`test_helper.exs`); CI provides MinIO (`ci.yml:196-216`). Local devs run `docker run … minio/minio` + `mc mb local/rindle-test`. |
| PostgreSQL | session state | ✓ | 16 (CI), local 5432 | — |
| Oban | reaper cron + PromoteAsset | ✓ | testing :inline (test) | — |

**Missing dependencies with no fallback:** none — every runtime dep is present or CI-provided.
**Missing dependencies with fallback:** MinIO locally — the `@tag :minio` exclusion means the default `mix test` run is green without MinIO (matches Phase 42's deferred MinIO notes in `42-01-SUMMARY.md:136`). The proof runs in CI's `integration`/`minio` lane.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in) + `Oban.Testing` (`testing: :inline` in test) + `Mox` (for unit-mocking the adapter) |
| Config file | `config/test.exs` (Repo + Oban) ; `test/test_helper.exs` (sandbox + tag exclusion) |
| Quick run command | `mix test test/rindle/storage/ test/rindle/upload/tus_plug_test.exs test/rindle/ops/upload_maintenance_test.exs` |
| Full suite command | `mix test` (excludes `:integration,:minio,:contract,:adopter` by default per `test_helper.exs`) |
| MinIO proof command | `mix test test/rindle/upload/tus_s3_integration_test.exs --include minio` (CI runs `--include integration` + `--include minio` with MinIO up) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TUS-06 | `upload_part_stream/5` exists as OPTIONAL callback; S3 buffers tail, UploadParts ≥ 5 MiB; ETag from headers | unit | `mix test test/rindle/storage/s3_tus_test.exs -x` | ❌ Wave 0 |
| TUS-06 | S3 UploadPart round-trip via the callback against MinIO | integration | `mix test test/rindle/storage/s3_test.exs --include minio` | ⚠️ extend existing |
| TUS-07 | `S3.capabilities/0` includes `:tus_upload`; `TusPlug.init/1` raises on adapter without it | unit | `mix test test/rindle/storage/storage_adapter_test.exs test/rindle/upload/tus_plug_test.exs` | ✅ (extend cap assertions) |
| TUS-08 | Final PATCH → `complete_multipart_upload/4` → unchanged `verify_completion/2`; asset validating + `PromoteAsset` enqueued | unit | `mix test test/rindle/upload/tus_plug_test.exs -x` | ✅ (extend with S3-mock completion) |
| TUS-08 | `verify_completion/2` byte-for-byte unchanged | review | `git diff broker.ex` shows no change to `verify_completion/2` | n/a (verification gate) |
| TUS-09 | Reaper branches on `resumable_protocol`: tus → `abort_multipart_upload`; gcs_native → `cancel_resumable_upload`; legacy unchanged | unit | `mix test test/rindle/ops/upload_maintenance_test.exs -x` | ⚠️ extend existing |
| TUS-09 | ≥ 1 GiB drop+resume completes; abandoned upload → `list_multipart_uploads` empty | integration | `mix test test/rindle/upload/tus_s3_integration_test.exs --include minio` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** the relevant quick unit command (`-x` fail-fast) for the file touched.
- **Per wave merge:** `mix test test/rindle/storage/ test/rindle/upload/ test/rindle/ops/` (full non-MinIO tus surface).
- **Phase gate:** `mix test` green (default exclusions) AND the `@tag :minio` proof green in the CI integration lane before `/gsd:verify-work`.

### Wave 0 Gaps
- [ ] `test/rindle/storage/s3_tus_test.exs` — covers TUS-06 (tail-buffer logic; can unit-test the 5 MiB slice/accumulate math without S3 via a fake `request` or by testing the pure buffering helper).
- [ ] `test/rindle/upload/tus_s3_integration_test.exs` — covers TUS-09 (≥ 1 GiB drop+resume + abort-leak assertion); `@tag :minio`.
- [ ] Extend `test/rindle/storage/storage_adapter_test.exs` — assert `:tus_upload in S3.capabilities()` (mirror the Local assertion updated in `42-01`).
- [ ] Extend `test/rindle/ops/upload_maintenance_test.exs` — assert the tus branch (S3 multipart abort vs gcs_native cancel vs legacy).
- [ ] Extend `test/rindle/upload/tus_plug_test.exs` — S3-mock (`Mox`) PATCH→completion path proving adapter dispatch (no Local hard-wiring).
- [ ] No framework install needed — ExUnit/Oban.Testing/Mox all present.

## Security Domain

> `security_enforcement` is not set to `false` in `.planning/config.json` (no `security_enforcement` key present → treat as enabled). Phase 43 is storage-backing; the auth surface (HMAC URLs) shipped in Phase 42 and is unchanged here.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no (unchanged) | HMAC-signed tus URLs shipped in Phase 42 (`Plug.Crypto.sign/verify`); Phase 43 adds no auth surface |
| V3 Session Management | yes (storage state) | tus session state in `media_upload_sessions`; UploadId is server-side, never client-exposed |
| V4 Access Control | no (unchanged) | Resume authorizer is Phase 44 (TUS-10); Phase 43 inherits HMAC-only |
| V5 Input Validation | yes | PATCH body size bounded by per-PATCH ceiling → 413 (`tus_plug.ex:255-259`); `Upload-Metadata` opaque, re-sniffed at `verify_completion` head |
| V6 Cryptography | no | No new crypto; HMAC URL signing unchanged |
| V12 File Upload | yes | 5 MiB part minimum enforced server-side; head-based content re-sniff at completion (`verify_completion` → `adapter.head` size+content_type); profile size/type validation |

### Known Threat Patterns for {Elixir / ExAws / S3 multipart}

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Orphaned multipart upload accrues cost / data leak | Information Disclosure / DoS-cost | Reaper `abort_multipart_upload` branch on `resumable_protocol` (TUS-09); proven by `list_multipart_uploads`-empty assertion |
| Memory exhaustion via large PATCH | Denial of Service | 1 MiB `read_length` + per-PATCH ceiling → 413; tail buffered to DISK, never memory (Pitfall 3/Anti-pattern) |
| AWS credential leak in logs/telemetry | Information Disclosure | `aws_config`/creds never logged; `session_uri` redacted (`media_upload_session.ex:106-115`); `ResumableTelemetry` forbidden-key allowlist (`:session_uri,:upload_key,:headers,:body,:session_id` — `resumable_telemetry.ex:9`) |
| ETag/part tampering → corrupt assembly | Tampering | part_number + ETag persisted server-side from S3 responses (not client-supplied); `complete_multipart_upload` validates ETags; head re-sniff size at completion |
| Path traversal in tail-buffer filename | Tampering | tail path keyed on server-issued `session_id` (UUID) under `Rindle.tmp/` — structurally traversal-proof (same guard as `Local.tus_part_path/2`, `local.ex:119-122`) |

## Sources

### Primary (HIGH confidence)
- `deps/ex_aws_s3/lib/ex_aws/s3.ex` — verified `upload_part/6` (1811), `complete_multipart_upload/4` (1903), `abort_multipart_upload/3` (1931), `list_multipart_uploads/2` (360), `list_parts/4` (1940), `initiate_multipart_upload/3` (1789)
- `deps/ex_aws_s3/lib/ex_aws/s3/parsers.ex` — verified `upload_part` has NO parser (ETag in headers); `parse_list_multipart_uploads` shape (`%{uploads: [%{key:, upload_id:}]}`)
- `lib/rindle/storage/s3.ex`, `local.ex`, `storage.ex`, `capabilities.ex` — adapter behaviour + S3/Local impls + capability machinery (all read in full)
- `lib/rindle/upload/broker.ex` — `verify_completion/2` (471), `initiate_tus_upload/2` (247), `persist_tus_session/3` (694), multipart persist/normalize helpers
- `lib/rindle/upload/tus_plug.ex` — the Phase-42 edge (PATCH hot path 194-301, completion 290, Local hard-wiring to generalize)
- `lib/rindle/ops/upload_maintenance.ex` — the reaper (`expire_session` 386, `resumable_abort_session?` 551, `fetch_incomplete_timed_out_sessions` 135) — the TUS-09 gap
- `lib/rindle/domain/media_upload_session.ex` — schema (multipart_upload_id/multipart_parts/resumable_protocol cast at 85-86,84) + redacting Inspect
- `lib/rindle/domain/upload_session_fsm.ex` — `signed → verifying` legal; no new states
- `test/test_helper.exs`, `config/test.exs`, `.github/workflows/ci.yml:140-224`, `test/rindle/storage/s3_test.exs`, `test/rindle/upload/lifecycle_integration_test.exs` — the MinIO `@tag :minio` + `RINDLE_MINIO_*` harness
- Phase 42 artifacts: `42-CONTEXT.md` (D-01..D-13), `42-PATTERNS.md`, `42-0{1,2,3,4}-SUMMARY.md`

### Secondary (MEDIUM confidence)
- [Amazon S3 multipart upload limits](https://docs.aws.amazon.com/AmazonS3/latest/userguide/qfacts.html) — 5 MiB min non-final part, 10000 parts max, last part any size
- [S3 as a Storage Back-End | tus.io](https://tus.io/blog/2016/03/07/tus-s3-backend.html) — the tail-buffer pattern (PATCH→temp file→UploadPart at 5 MiB; final chunk any size)

### Tertiary (LOW confidence)
- [tusd/pkg/s3store/s3store.go](https://github.com/tus/tusd/blob/main/pkg/s3store/s3store.go) — reference Go impl of the same pattern (MinPartSize/MaxBufferedParts) — not a contract, an analog

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every API verified against the installed dep source; no new packages
- Architecture: HIGH — every integration point (callback site, verify lane, reaper branch, columns, MinIO harness) verified in the live codebase with line anchors
- Pitfalls: HIGH — Pitfall 1 (reaper mis-route) and Pitfall 2 (ETag in headers) are verified code facts, not speculation; Pitfall 3/4 are the documented tusd/S3 contract and a concrete opts-flow gap
- TUS-09 reaper gap: HIGH — `resumable_abort_session?/1` provably catches tus sessions and routes them to the wrong (capability-failing) cancel path

**Research date:** 2026-05-23
**Valid until:** 2026-06-22 (30 days — stable ExAws stack, locked architecture; the only volatility is the planner's discretionary choices on callback shape A1/A3 and the opts-flow A4)
