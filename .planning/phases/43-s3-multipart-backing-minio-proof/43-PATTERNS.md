# Phase 43: S3 Multipart Backing + MinIO Proof - Pattern Map

**Mapped:** 2026-05-23
**Files analyzed:** 12 (5 lib modified, 1 lib test-mock surface, 2 NEW tests, 3 extended tests, 1 schema cast reference)
**Analogs found:** 12 / 12 (every target has a same-repo analog; no RESEARCH.md-only fallback needed)

> Source of file list: `43-RESEARCH.md` §Recommended Project Structure (lines 175-191) + the per-pattern source anchors (Patterns 1-4, Code Examples, §Validation Architecture). No `43-CONTEXT.md`; constraints inherited from Phase-42 D-01..D-13 (copied into RESEARCH §User Constraints).

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/rindle/storage.ex` (MODIFY) | behaviour contract | streaming (callback decl) | self — existing `@callback`/`@optional_callbacks` block (`storage.ex:217-286`) | exact (in-file precedent) |
| `lib/rindle/storage/s3.ex` (MODIFY) | storage adapter | streaming / file-I/O → S3 multipart | self — `complete_multipart_upload/4` (s3.ex:105-117), `abort_multipart_upload/3` (s3.ex:119-127), `handle_head_response` header-normalize (s3.ex:136-144) | exact |
| `lib/rindle/storage/local.ex` (MODIFY) | storage adapter | file-I/O (append) | self — `tus_append/3` (local.ex:131-143), `tus_complete/3` (local.ex:154-163), `tus_part_path/2` (local.ex:119-122) | exact |
| `lib/rindle/storage/capabilities.ex` (REFERENCE — likely no change) | capability registry | n/a | self — `:tus_upload` already in `@known` (capabilities.ex:29) | exact (already present) |
| `lib/rindle/upload/tus_plug.ex` (MODIFY) | Plug edge | streaming / request-response | self — `stream_append/4` + `drain/6` PATCH loop (tus_plug.ex:213-265), `complete_upload/3` (tus_plug.ex:290-301) | exact |
| `lib/rindle/upload/broker.ex` (REFERENCE — DO NOT MODIFY `verify_completion`) | service | request-response / CRUD | self — `verify_completion/2` (broker.ex:470-489), `initiate_tus_upload/2` (broker.ex:246-277), `persist_tus_session/3` (broker.ex:694-721) | exact (convergence target, frozen) |
| `lib/rindle/ops/upload_maintenance.ex` (MODIFY) | reaper / batch worker | batch / event-driven (cron) | self — `expire_session/2` (upload_maintenance.ex:386-392), `attempt_storage_delete` multipart clause (upload_maintenance.ex:324-349), `resumable_abort_session?/1` (upload_maintenance.ex:551-555) | exact |
| `test/rindle/storage/s3_tus_test.exs` (NEW) | unit test | streaming (tail-buffer math) | `test/rindle/storage/s3_test.exs` (missing-bucket pure-unit block s3_test.exs:20-27) + `storage_adapter_test.exs` Mox profile (`upload_maintenance_test.exs` Mox harness) | role-match |
| `test/rindle/storage/s3_test.exs` (EXTEND) | integration test (`@tag :minio`) | streaming → S3 round-trip | self — multipart round-trip test (s3_test.exs:29-82), `put_part_to_presigned_url` ETag-from-headers (s3_test.exs:128-152) | exact |
| `test/rindle/storage/storage_adapter_test.exs` (EXTEND) | unit test (capability honesty) | n/a | self — `capability lists are truthful` (storage_adapter_test.exs:98-108), optional-callbacks assertions (storage_adapter_test.exs:67-80) | exact |
| `test/rindle/ops/upload_maintenance_test.exs` (EXTEND) | unit test (reaper branch) | batch | self — Mox + `TestRepoProbe` harness (upload_maintenance_test.exs:1-101) | exact |
| `test/rindle/upload/tus_s3_integration_test.exs` (NEW) | integration test (`@tag :minio`) | streaming → S3 ≥1 GiB drop+resume | `lifecycle_integration_test.exs` env setup (lifecycle_integration_test.exs:47-99) + `s3_test.exs` MinIO module attrs (s3_test.exs:8-18) + `tus_plug_test.exs` route/create helpers (tus_plug_test.exs:46-119) | role-match (composite) |

## Pattern Assignments

### `lib/rindle/storage.ex` (behaviour contract, streaming callback decl) — TUS-06 / D-01

**Analog:** self — the existing optional-callback block.

**Type + callback decl pattern** (mirror the resumable callbacks at `storage.ex:209-274` for `@typedoc` + `@doc` + `@callback` shape). RESEARCH §Pattern 1 gives the recommended shape verbatim (RESEARCH lines 200-224): add `@type tus_part_state`, then `@callback upload_part_stream(key, read_chunk|temp_path, base_offset, state, opts) :: {:ok, tus_part_state()} | {:error, term()}`.

**Optional-callbacks pattern — the exact edit site** (`storage.ex:283-286`):
```elixir
@optional_callbacks initiate_resumable_upload: 3,
                    resumable_upload_status: 3,
                    cancel_resumable_upload: 3,
                    verify_resumable_completion: 3
```
Append `upload_part_stream: 5` (and `complete_part_stream: 4` if the planner picks the symmetric-completion option from RESEARCH Open Question 1). Note `:tus_upload` is ALREADY in the `@type capability` union at `storage.ex:17-25` — no type edit needed there.

**Why this is the analog:** the four resumable callbacks are the precedent for "OPTIONAL adapter callback gated by a capability atom, only some adapters implement it" — exactly the `upload_part_stream/5` shape. Copy their `@doc` voice ("Adapters expose this callback only when they advertise the `:tus_upload` capability").

---

### `lib/rindle/storage/s3.ex` (storage adapter, streaming → S3 multipart) — TUS-06 core

**Analog:** self — three existing private/public patterns.

**`@impl true` + `with` + `bucket(opts)` adapter pattern** (every S3 callback uses it; e.g. `complete_multipart_upload/4` at s3.ex:105-117):
```elixir
@impl true
def complete_multipart_upload(key, upload_id, parts, opts) do
  with {:ok, bucket} <- bucket(opts),
       {:ok, %{body: body}} <-
         request(
           S3.complete_multipart_upload(bucket, key, upload_id, normalize_parts(parts)),
           opts
         ) do
    {:ok, Map.merge(%{upload_id: upload_id, upload_key: key, bucket: bucket}, body)}
  else
    {:error, reason} -> {:error, reason}
  end
end
```
`upload_part_stream/5` follows the same `with {:ok, bucket} <- bucket(opts), ...` spine. Reuse the existing `request/2` (s3.ex:180-184, wraps `ExAws.request` + rescues), `bucket/1` (s3.ex:173-178, opts-or-app-env fallback — the Pitfall-4 opts-flow lever), `s3_config/1` (s3.ex:186-188), `object_opts/1` (s3.ex:190-195), and `normalize_parts/1` (s3.ex:165-171, already accepts `%{part_number:, etag:}` maps AND `{n, etag}` tuples — the persisted `multipart_parts` shape feeds it directly).

**ETag-from-headers pattern — THE Pitfall-2 fix** (mirror `handle_head_response` header-normalize at s3.ex:136-144). RESEARCH §Code Examples (lines 350-368) gives the exact helper:
```elixir
defp etag_from_headers(%{headers: headers}) do
  headers
  |> Enum.into(%{}, fn {k, v} -> {String.downcase(k), v} end)
  |> Map.get("etag")
end
```
This is byte-identical normalization to the proven `handle_head_response` (s3.ex:137-138). `S3.upload_part/6` has NO body parser (RESEARCH §Pitfall 2) — the ETag is ONLY in `response.headers`.

**Abort pattern for the reaper's tus branch** (s3.ex:119-127): `abort_multipart_upload/3` already exists and returns `{:ok, %{...}}`; the reaper calls it unchanged.

**`list_multipart_uploads` helper (NEW, for the leak-proof assertion):** `ExAws.S3.list_multipart_uploads/2` (verified `deps/ex_aws_s3/lib/ex_aws/s3.ex:360`). The integration test can call `ExAws.S3.list_multipart_uploads(bucket) |> ExAws.request(cfg)` directly (RESEARCH Code Example lines 416-418) — a dedicated S3-adapter wrapper is optional.

**Capability advertisement — the one-line TUS-07 edit** (s3.ex:151-152):
```elixir
@impl true
def capabilities, do: [:presigned_put, :head, :signed_url, :multipart_upload]
```
Add `:tus_upload` (once `upload_part_stream/5` lands — capability honesty, D-09). The matching assertion lives in `storage_adapter_test.exs:100`.

**Tail-buffer location:** use `Rindle.AV.TempRunDir.root_dir/0` (temp_run_dir.ex:26 → `<tmp>/Rindle.tmp`); recommend `Path.join([TempRunDir.root_dir(), "tus", session_id <> ".tail"])` (RESEARCH Pattern 2, lines 234-250). `@s3_min_part_size 5 * 1024 * 1024` module attr.

---

### `lib/rindle/storage/local.ex` (storage adapter, file-I/O append) — TUS-06 Local impl

**Analog:** self — the Phase-42 tus helpers.

**Append helper to wrap** (local.ex:131-143):
```elixir
def tus_append(session_id, chunk, opts) when is_binary(session_id) do
  part_path = tus_part_path(session_id, opts)

  with :ok <- File.mkdir_p(Path.dirname(part_path)),
       {:ok, file} <- File.open(part_path, [:append, :binary]) do
    try do
      IO.binwrite(file, chunk)
    after
      File.close(file)
    end
  end
end
```

**Completion helper (atomic rename — Local's "complete")** (local.ex:154-163): `tus_complete/3` does the same-filesystem `File.rename`. Local's `upload_part_stream/5` wraps `tus_append/3` and returns `%{offset: new_offset}` with NO `:upload_id`/`:parts` keys (RESEARCH Pitfall 5, lines 342-346). `part_number` arg is ignored — Local has no part semantics. `tus_part_path/2` (local.ex:119-122) is the traversal-proof path keyed on server-issued `session_id`.

**Capability — already done** (local.ex:83): `def capabilities, do: [:local, :presigned_put, :tus_upload]`. No edit. The `multipart_*` callbacks return `{:error, {:upload_unsupported, :multipart_upload}}` (local.ex:51-69) — keep that idiom if a Local stub for `complete_part_stream`/abort is needed.

---

### `lib/rindle/upload/tus_plug.ex` (Plug edge, streaming) — TUS-06/08 adapter dispatch

**Analog:** self — the Phase-42 hard-wired PATCH/completion path that must become polymorphic.

**The hard-wiring to GENERALIZE (current `stream_append/4`, tus_plug.ex:213-230):**
```elixir
defp stream_append(conn, session, payload, opts) do
  part_path = Local.tus_part_path(session.id, root: opts[:root])   # ← Local hard-wire
  File.mkdir_p!(Path.dirname(part_path))
  ...
  case File.open(part_path, [:append, :binary]) do
    {:ok, file} -> ... drain(conn, file, session.last_known_offset, 0, ceiling, upload_length)
  ...
```
Replace with a call into `opts[:adapter].upload_part_stream(session.upload_key, <read_chunk|temp_path>, session.last_known_offset, prior_state, call_opts)`. RESEARCH §Pattern 3 (lines 252-255) and §Pattern 1 Note (lines 232) recommend the **temp-path variant**: the Plug drains the PATCH body to a temp file first (keep the existing `drain/6` + `write_chunk/7` loop at tus_plug.ex:232-265 verbatim — it already enforces the 1 MiB `@read_length`, the per-PATCH ceiling → 413, and the `Upload-Length` bound), then hands the path to the adapter. Do NOT special-case `if adapter == Local` — dispatch through the behaviour (anti-pattern, RESEARCH line 255).

**The completion to generalize** (`complete_upload/3`, tus_plug.ex:290-301):
```elixir
defp complete_upload(conn, session, opts) do
  with {:ok, _path} <- Local.tus_complete(session.id, session.upload_key, root: opts[:root]),   # ← Local hard-wire
       {:ok, %{session: _completed}} <- Broker.verify_completion(session.id, root: opts[:root]) do
    ...
```
S3 path: call `adapter.complete_multipart_upload(session.upload_key, multipart_upload_id, parts, opts)` (flushing the tail as the final part) BEFORE `Broker.verify_completion/2`. Local path: keep `tus_complete`. Branch on whether persisted state has `:upload_id` OR add `complete_part_stream/4` (RESEARCH Open Question 1 — planner's call). The `Broker.verify_completion(session.id, ...)` convergence line stays (D-08).

**`init/1` capability gate — already shipped, keep** (tus_plug.ex:78-86): raises `ArgumentError` on missing `:tus_upload`. `init/1` already binds `adapter: profile.storage_adapter()` (tus_plug.ex:76) and `root:` (tus_plug.ex:88). Pitfall 4 (lines 336-340): for S3, `bucket`/`aws_config` must reach the adapter — either resolve from `Application.get_env(:rindle, adapter)` at `init/1` and merge into call opts, OR rely on S3's app-env fallback (`bucket/1` at s3.ex:174). RESEARCH recommends app-env fallback for v1 but says EXPLICITLY DECIDE AND TEST it (A4, MEDIUM risk).

**State persistence between PATCHes:** persist `multipart_upload_id` + `multipart_parts` via `MediaUploadSession.changeset/2` (the existing `persist_offset/2` at tus_plug.ex:267-271 is the template — same `changeset |> Config.repo().update()` shape; just add the multipart keys). Columns are already cast (media_upload_session.ex:85-86).

---

### `lib/rindle/ops/upload_maintenance.ex` (reaper, batch) — TUS-09 load-bearing fix

**Analog:** self — the existing expire/abort lanes.

**The branch point to extend** (`expire_session/2`, upload_maintenance.ex:386-392):
```elixir
defp expire_session(session, acc) do
  if resumable_abort_session?(session) do
    expire_resumable_session(session, acc)
  else
    expire_standard_session(session, acc)
  end
end
```
RESEARCH §Pattern 4 (lines 259-278) converts this to a `cond` adding `tus_session?(session) -> expire_tus_session(session, acc)` FIRST. `tus_session?/1` matches `%MediaUploadSession{upload_strategy: "resumable", resumable_protocol: "tus"}`.

**The multipart-abort pattern to copy for `expire_tus_session`** (existing `attempt_storage_delete` multipart clause, upload_maintenance.ex:324-349):
```elixir
defp attempt_storage_delete(
       %MediaUploadSession{upload_strategy: "multipart", multipart_upload_id: multipart_upload_id} = session,
       storage_mod)
     when is_binary(multipart_upload_id) and multipart_upload_id != "" do
  case storage_mod.abort_multipart_upload(session.upload_key, multipart_upload_id, []) do
    {:ok, _} -> {:ok, 1}
    {:error, :not_found} -> {:ok, 0}          # idempotent
    {:error, reason} -> Logger.warning(...); :storage_error
  end
end
```
This is the EXACT idempotent-abort idiom `expire_tus_session` reuses (RESEARCH §Code Example lines 374-402): resolve adapter, `adapter.abort_multipart_upload(upload_key, multipart_upload_id, [])`, treat `{:error, :not_found}` as `:ok`, else leave row for retry.

**Persist-expired pattern** (`do_expire_session/2`, upload_maintenance.ex:423-446): the `MediaUploadSession.changeset(session, %{state: "expired"}) |> repo.update()` + report-counter idiom — copy for the tus branch's post-abort persist.

**Adapter resolution** (`resolve_resumable_adapter/1`, upload_maintenance.ex:522-536): the profile-name → module → adapter chain. `expire_tus_session`'s `resolve_tus_adapter` copies it but gates on `:tus_upload` (not `:resumable_upload_session`) — that capability mismatch is the EXACT TUS-09 bug (RESEARCH Pitfall 1, lines 318-322).

**Tighten the predicate** (`resumable_abort_session?/1`, upload_maintenance.ex:551-555): exclude `resumable_protocol: "tus"` so a future query expansion can't double-route (RESEARCH line 279). Query `fetch_incomplete_timed_out_sessions/1` (upload_maintenance.ex:135-155) needs NO change — tus sessions sit in `"signed"`, already matched at line 142.

**Report counters:** `increment_abort_strategy/2` (upload_maintenance.ex:557-567) and the `@type abort_report` (upload_maintenance.ex:26-33) — add a tus counter if the planner wants the report to distinguish tus aborts (cheap, matches existing `multipart_aborts`/`resumable_aborts`).

---

### `lib/rindle/upload/broker.ex` (service — convergence target, FROZEN) — TUS-08

**Analog / contract:** self. `verify_completion/2` (broker.ex:470-489) and its `execute_verify_completion/5` `Ecto.Multi` (broker.ex:491-537, with `Oban.insert(:promote_job, PromoteAsset.new(...))` at broker.ex:517) are **byte-for-byte UNCHANGED** (D-08). The TusPlug completion path calls `Broker.verify_completion(session.id, opts)` — already does (tus_plug.ex:292). `verify_completion` resolves the adapter from the profile and calls `adapter.head/2` (broker.ex:477-479) — S3's `head/2` returns `:size` + `:content_type` (s3.ex:136-144), so the verify lane gets a real `content_type` for free. **Verification gate:** `git diff lib/rindle/upload/broker.ex` must show NO change to `verify_completion/2` or `execute_verify_completion/5`. `initiate_tus_upload/2` (broker.ex:246-277) and `persist_tus_session/3` (broker.ex:694-721, stamps `resumable_protocol: "tus"`, `last_known_offset: 0`, `upload_strategy: "resumable"`, `state: "signed"`) are reused as-is.

---

## Shared Patterns

### Adapter call spine (`with {:ok, bucket} <- bucket(opts)` + `request/2`)
**Source:** `lib/rindle/storage/s3.ex` (every callback; canonical at s3.ex:105-127)
**Apply to:** the new S3 `upload_part_stream/5` and any `list_multipart_uploads` helper.
```elixir
with {:ok, bucket} <- bucket(opts),
     {:ok, response} <- request(ExAws.S3.<op>(bucket, ...), opts) do
  {:ok, %{...}}
else
  {:error, reason} -> {:error, reason}
end
```
`request/2` (s3.ex:180-184) wraps `ExAws.request(operation, Keyword.get(opts, :aws_config, []))` and rescues exceptions into `{:error, exception}`. `bucket/1` (s3.ex:173-178) is opts-or-app-env — the Pitfall-4 resolution lever.

### Header normalization (lowercase map lookup)
**Source:** `lib/rindle/storage/s3.ex:136-138` (`handle_head_response`)
**Apply to:** ETag extraction in S3 `upload_part_stream/5` (Pitfall 2).
```elixir
Enum.into(headers, %{}, fn {k, v} -> {String.downcase(k), v} end) |> Map.get("etag")
```

### Idempotent remote abort (`{:error, :not_found}` → success)
**Source:** `lib/rindle/ops/upload_maintenance.ex:332-348` + `lib/rindle/storage/s3.ex:119-127`
**Apply to:** reaper `expire_tus_session` and the `complete_upload` failure compensation.

### Capability honesty (advertise → implement)
**Source:** `lib/rindle/storage/capabilities.ex` (`require_upload/2` at capabilities.ex:51-59); enforced at `lib/rindle/upload/tus_plug.ex:78-86`.
**Apply to:** S3 `capabilities/0` gains `:tus_upload` ONLY when `upload_part_stream/5` exists; `init/1` raise is unchanged.

### Changeset-update persistence (no DB transaction around storage I/O)
**Source:** `lib/rindle/upload/tus_plug.ex:267-271` (`persist_offset/2`); `lib/rindle/ops/upload_maintenance.ex:423-446` (`do_expire_session/2`)
**Apply to:** persisting `multipart_upload_id`/`multipart_parts` mid-PATCH and `state: "expired"` in the reaper. `MediaUploadSession.changeset/2` casts both multipart columns (media_upload_session.ex:85-86).

### Tmp root resolution
**Source:** `lib/rindle/av/temp_run_dir.ex:26` (`root_dir/0` → `<tmp>/Rindle.tmp`)
**Apply to:** the S3 tail-buffer path (`<root_dir>/tus/<session_id>.tail`); the orphan reaper already sweeps `Rindle.tmp/`.

---

## Test Pattern Assignments

### `test/rindle/storage/s3_tus_test.exs` (NEW, unit) — TUS-06 tail-buffer math
**Analog harness:** the pure-unit (no-MinIO) block in `s3_test.exs:20-27` (asserts `{:error, :missing_bucket}` with no network) + the Mox profile pattern from `upload_maintenance_test.exs:14-22` (`storage: Rindle.StorageMock`). `Rindle.StorageMock` is defined at `test/support/mocks.ex:1` (`Mox.defmock(Rindle.StorageMock, for: Rindle.Storage)`). Test the 5-MiB slice/accumulate logic by extracting it into a pure helper, OR stub `request/2` via Mox. `use ExUnit.Case, async: true`.

### `test/rindle/storage/s3_test.exs` (EXTEND, `@tag :minio`) — TUS-06 UploadPart round-trip
**Analog:** self. The MinIO module attrs + skip-reason guard (s3_test.exs:8-18), the `@tag :minio` + `@tag skip: @minio_skip_reason` pair (s3_test.exs:29-30), the `opts = [bucket:, aws_config: [...]]` MinIO config (s3_test.exs:35-46), and `put_part_to_presigned_url/2` ETag-from-headers reader (s3_test.exs:128-152) are the exact harness. Add a test driving the NEW `S3.upload_part_stream/5` callback against MinIO (server-mediated, not presigned).

### `test/rindle/storage/storage_adapter_test.exs` (EXTEND, unit) — TUS-07 capability honesty
**Analog:** self. `capability lists are truthful for all adapters` (storage_adapter_test.exs:98-108) — update the S3 assertion at line 100 to include `:tus_upload`:
```elixir
assert [:presigned_put, :head, :signed_url, :multipart_upload, :tus_upload] == S3.capabilities()
```
And mirror the optional-callbacks assertion block (storage_adapter_test.exs:67-80) to assert `{:upload_part_stream, 5} in optional_callbacks`. `:tus_upload in Capabilities.known()` already passes (storage_adapter_test.exs:90).

### `test/rindle/ops/upload_maintenance_test.exs` (EXTEND, unit) — TUS-09 reaper branch
**Analog:** self. The full Mox + `TestRepoProbe` harness (upload_maintenance_test.exs:1-101): `setup :set_mox_from_context` / `:verify_on_exit!` (lines 11-12), `TestProfile` with `storage: Rindle.StorageMock` (lines 14-22), `TestRepoProbe` (lines 24-52), the repo/probe swap setup (lines 54-82), and `create_asset/1` + `create_session/2` builders (lines 88-110+). Add a test stamping `resumable_protocol: "tus"` + `multipart_upload_id`, expecting `StorageMock.abort_multipart_upload` (NOT `cancel_resumable_upload`); a `gcs_native` test (existing path); a legacy-nil test (unchanged).

### `test/rindle/upload/tus_s3_integration_test.exs` (NEW, `@tag :minio`) — TUS-09 ≥1 GiB drop+resume + zero-leak
**Analog (composite):**
- Env setup: `lifecycle_integration_test.exs:47-99` — `:inets.start()`, the `RINDLE_MINIO_*` reads with localhost/minioadmin defaults (lines 61-66), `Application.put_env(:rindle, Rindle.Storage.S3, bucket: ...)` + `Application.put_env(:ex_aws, :s3, [...])` (lines 68-78), and the `on_exit` restore (lines 80-97).
- MinIO attrs/skip guard: `s3_test.exs:8-18`.
- tus driving: `tus_plug_test.exs:46-119` — `TusRouter` `forward` (lines 46-60), `route/1` (line 89), `create_session/1` token extraction (lines 91-101), `opts_for/1` via `TusPlug.init` (lines 105-112). Use `import Plug.Test` + `import Plug.Conn`.
- Skeleton from RESEARCH §Code Example lines 405-419: POST → PATCH ~600 MiB (assert 204 + `Upload-Offset` advances + `multipart_upload_id` persisted) → drop → HEAD authoritative offset → resume → final PATCH (offset==length) → assert session `"completed"`, asset `"validating"`, `byte_size == 1 GiB`; then second session → one PATCH → expire + run reaper → `ExAws.S3.list_multipart_uploads(bucket) |> ExAws.request(cfg)` returns no entry for the abandoned key (ZERO LEAK). `@tag timeout: 600_000`.

---

## No Analog Found

None. Every Phase-43 target maps to an in-repo analog (most are self-extensions of Phase-42 substrate; the two NEW tests compose three existing harnesses). RESEARCH.md §Code Examples supply the exact new-code shapes where the analog is a *pattern to mirror* rather than code to copy verbatim (`etag_from_headers`, `expire_tus_session`, the MinIO proof skeleton).

## Metadata

**Analog search scope:** `lib/rindle/storage/`, `lib/rindle/upload/`, `lib/rindle/ops/`, `lib/rindle/av/`, `lib/rindle/domain/`, `test/rindle/storage/`, `test/rindle/upload/`, `test/rindle/ops/`, `test/support/`
**Files scanned (read for excerpts):** storage.ex, storage/s3.ex, storage/local.ex, storage/capabilities.ex, upload/tus_plug.ex, upload/broker.ex (3 targeted ranges), ops/upload_maintenance.ex, av/temp_run_dir.ex, domain/media_upload_session.ex (cast block), s3_test.exs, storage_adapter_test.exs, tus_plug_test.exs (setup), upload_maintenance_test.exs (setup), lifecycle_integration_test.exs (env setup), test/support/mocks.ex (grep)
**Skills/CLAUDE.md:** no `./CLAUDE.md`, no `.claude/skills/` or `.agents/skills/` present — no project-skill rules to apply.
**Pattern extraction date:** 2026-05-23
