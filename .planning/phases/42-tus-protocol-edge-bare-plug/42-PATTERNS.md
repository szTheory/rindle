# Phase 42: tus Protocol Edge (bare Plug) - Pattern Map

**Mapped:** 2026-05-22
**Files analyzed:** 9 tus-scope (2 new lib, 1 new migration, 5 modified, 2 new tests) + POLISH-01 Mux set (6 source, 3 test)
**Analogs found:** 9 / 9 (every tus seam has a verified in-repo analog; POLISH-01 is in-place edits, no analog needed)

> All analog file/line anchors below were re-verified live against the working tree on 2026-05-22.
> This is a translation, not a derivation — the architecture is LOCKED (TUS-RESEARCH.md + D-01..D-13).
> Planner: copy the excerpts; do not re-design.

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/rindle/upload/tus_plug.ex` (NEW) | bare Plug edge | streaming + request-response | `lib/rindle/delivery/webhook_plug.ex` (skeleton) + `lib/rindle/delivery/local_plug.ex` (HMAC/exp/traversal) | exact (two-analog composite) |
| `lib/rindle/upload/broker.ex` (MODIFY: `+initiate_tus_upload/2`) | broker entrypoint | CRUD (session create + compensation) | `initiate_resumable_session/2` + `persist_resumable_session/5` + compensation (same file) | exact (sibling fn) |
| `lib/rindle/storage/capabilities.ex` (MODIFY) | capability registration | config/static | `@known` list + `@type capability` (same file) | exact (add one atom) |
| `lib/rindle/storage.ex` (MODIFY) | capability type union | config/static | `@type capability` `:17-24` (same file) | exact (add one atom) |
| `lib/rindle/storage/local.ex` (MODIFY: `capabilities/0` + tmp-append helper) | storage backing | file-I/O (append + atomic rename) | `path_for/2` `:106-109`, `head/2` `:72-80`, `root/1` `:88-101` (same file) | role-match (new file-append helper; no exact analog — see No Analog) |
| `priv/repo/migrations/<ts>_add_resumable_protocol_to_media_upload_sessions.exs` (NEW) | migration | schema DDL | `priv/repo/migrations/20260507160000_extend_media_upload_sessions_for_resumable.exs` | exact |
| `lib/rindle/domain/media_upload_session.ex` (MODIFY: cast `resumable_protocol`) | schema/changeset | CRUD | schema `:48-65`, cast `:78-92`, redacting `Inspect` `:104-113` (same file) | exact |
| `test/rindle/upload/tus_plug_test.exs` (NEW) | test | request-response/streaming | `test/rindle/delivery/local_plug_test.exs` + `test/rindle/delivery/webhook_plug_test.exs` | exact (composite) |
| `test/rindle/upload/tus_local_backing_test.exs` (NEW) | test | file-I/O + DataCase | `test/rindle/delivery/local_plug_test.exs` (Local + tmp root setup) | role-match |
| POLISH-01 Mux files (6 src + 3 test, see § POLISH-01) | in-place fix | n/a | n/a (selective edits per D-13) | in-place |

---

## Pattern Assignments

### `lib/rindle/upload/tus_plug.ex` (NEW — bare Plug edge, streaming + request-response)

**Primary analog (skeleton):** `lib/rindle/delivery/webhook_plug.ex`
**Secondary analog (HMAC/exp/traversal):** `lib/rindle/delivery/local_plug.ex`

**Module header + behaviour + imports pattern** (copy from `webhook_plug.ex:70-78` and `local_plug.ex:21-27`):
```elixir
@behaviour Plug
import Plug.Conn
require Logger
# salt is a code constant (NOT a secret), mirroring local_plug.ex:27
@tus_url_salt "rindle:tus:url"      # D-04 discretion, recommended
```

**`init/1` fail-fast raise (capability honesty, D-09)** — compose `webhook_plug.ex:86-102` (fetch! + raise) with `local_plug.ex:30-45` (profile→adapter resolution + opts return). The Plug wraps the *tuple* `Capabilities.require_upload/2` returns (`capabilities.ex:49-57`) into a raise:
```elixir
# webhook_plug.ex:86-102 shape — fetch! required opts, raise ArgumentError on misconfig
@impl true
def init(opts) do
  profile = Keyword.fetch!(opts, :profile)               # cf. local_plug.ex:31
  secret_key_base = Keyword.fetch!(opts, :secret_key_base) # cf. local_plug.ex:32
  adapter = profile.storage_adapter()                    # cf. local_plug.ex:34
  # D-09: require_upload/2 returns {:error, {:upload_unsupported, cap}} — wrap into a raise
  case Rindle.Storage.Capabilities.require_upload(adapter, :tus_upload) do
    :ok -> :ok
    {:error, {:upload_unsupported, :tus_upload}} ->
      raise ArgumentError,
            "Rindle.Upload.TusPlug requires an adapter advertising :tus_upload; #{inspect(adapter)} does not"
  end
  [profile: profile, adapter: adapter, secret_key_base: secret_key_base,
   max_size: Keyword.get(opts, :max_size, ...), root: Rindle.Storage.Local.root(opts)]
end
```

**Method-dispatched `call/2` (D-06)** — exactly the `webhook_plug.ex:104-124` guard-clause shape, but dispatch on the tus verb set instead of POST-only:
```elixir
# webhook_plug.ex:104-111 — the non-allowed-method 405 guard, generalized to the tus verb set
@impl true
def call(%Plug.Conn{method: m} = conn, _opts)
    when m not in ~w(OPTIONS POST HEAD PATCH DELETE) do
  conn |> send_resp(405, "method not allowed") |> halt()
end
def call(%Plug.Conn{method: "OPTIONS"} = conn, opts), do: handle_options(conn, opts)
def call(%Plug.Conn{method: "POST"} = conn, opts),    do: handle_post(conn, opts)
# HEAD/PATCH/DELETE first verify the token (below), then dispatch.
```

**HMAC verify + manual `exp` check (D-03)** — copy `local_plug.ex:63-80` verbatim; the ONLY change is the extraction site (D-04: path segment, not query param) and the failure→status mapping (404/401, never 200):
```elixir
# Source: local_plug.ex:63-80 (verified 2026-05-22). Adapt: token from path_info; map to 404/401.
defp verify_token(conn, opts) do
  token = List.last(conn.path_info)   # D-04: NOT conn.query_params["token"]
  case Plug.Crypto.verify(opts[:secret_key_base], @tus_url_salt, token) do
    {:ok, %{"exp" => exp} = payload} ->
      if exp >= System.system_time(:second), do: {:ok, payload}, else: {:error, :expired_token}
    {:error, :expired} -> {:error, :expired_token}
    {:error, _reason} -> {:error, :invalid_token}
  end
end
# Map: :invalid_token -> 404 (do not leak existence); :expired_token -> 401 (or 404). NEVER 200.
```

**HMAC sign on POST (D-03/D-05)** — mirror the payload-with-`actor_subject` shape (`local_plug.ex:122` reads `payload["actor_subject"]`):
```elixir
# Sign side (POST). Payload mirrors local_plug.ex's actor_subject discipline (D-05).
token = Plug.Crypto.sign(opts[:secret_key_base], @tus_url_salt,
          %{session_id: session.id, actor: actor_subject, exp: unix_exp})
# Location: "/uploads/tus/" <> token  (D-04 — opaque REST resource)
```

**Path-traversal defensive guard (Landmine 8)** — reuse `local_plug.ex:232-235` `within_root?/2` verbatim when building the tmp path from the (server-issued, HMAC-verified) `session_id`:
```elixir
# Source: local_plug.ex:232-235 (verified). session_id is a server UUID from the verified token.
defp within_root?(path, root) do
  normalized_root = Path.join(root, "")
  path == root or String.starts_with?(path, normalized_root)
end
```

**PATCH read loop (D-07)** — `Plug.Conn.read_body/2` with `read_length: 1_048_576` + a per-PATCH ceiling; append per chunk, never buffer. The `{:more, ...}`/`{:ok, ...}` contract is verified at `deps/plug/lib/plug/conn.ex:1140-1194`. Loop shape (from RESEARCH §Code Examples, grounded in that conn.ex range):
```elixir
defp drain(conn, file, written, ceiling) do
  case Plug.Conn.read_body(conn, length: ceiling, read_length: 1_048_576) do
    {:more, chunk, conn} ->
      written = written + byte_size(chunk)
      if written > ceiling, do: {:too_large, conn},
        else: (IO.binwrite(file, chunk); drain(conn, file, written, ceiling))
    {:ok, chunk, conn} ->
      written = written + byte_size(chunk)
      if written > ceiling, do: {:too_large, conn},
        else: (IO.binwrite(file, chunk); {:done, written, conn})
    {:error, reason} -> {:error, reason, conn}
  end
end
```
Offset gate FIRST (409 without reading body — Anti-Pattern). Content-Type gate -> 415.

**Telemetry/halt discipline:** every response ends `|> send_resp(code, "") |> halt()` (webhook_plug.ex uses this on every branch). 204 responses MUST have an empty body. The tus URL is NEVER logged/inspected/in telemetry metadata (invariant 14) — it lives only in `session_uri` (redacted).

---

### `lib/rindle/upload/broker.ex` (MODIFY — `+initiate_tus_upload/2`, CRUD + compensation)

**Analog:** `initiate_resumable_session/2` (`:182-225`) + `persist_resumable_session/5` (`:566-596`) + `compensate_failed_resumable_persist/4` (`:619-640`), all in the same file. Builds on `create_upload_session/7` (`:494-528`).

**Entrypoint shape** (copy `:182-225`, drop the `adapter.initiate_resumable_upload` call per D-02 — Local has no multipart):
```elixir
# Source: broker.ex:182-225 (verified). For tus/Local: NO adapter.initiate_* call (D-02).
@spec initiate_tus_upload(module(), keyword()) :: ...
def initiate_tus_upload(profile_module, opts \\ []) do
  repo = Config.repo()
  profile_name = profile_module_to_name(profile_module)   # :747
  filename = Keyword.get(opts, :filename, "unknown")
  asset_id = Ecto.UUID.generate()
  storage_key = StorageKey.generate(profile_name, asset_id, Path.extname(filename))
  expires_at = DateTime.add(DateTime.utc_now(), Keyword.get(opts, :expires_in, 3600), :second)
  adapter = profile_module.storage_adapter()

  with :ok <- Capabilities.require_upload(adapter, :tus_upload),   # cf. :195 (was :resumable_upload)
       {:ok, session} <- persist_tus_session(repo, adapter, %{
            asset_id: asset_id, profile_name: profile_name, storage_key: storage_key,
            filename: filename, expires_at: expires_at}, opts) do
    emit_upload_start(profile_name, adapter, session.id)          # :211, helper at :735
    {:ok, %{session: session}}
  else
    {:error, reason} -> {:error, reason}
  end
end
```

**Persist + session_attrs** (copy `persist_resumable_session/5` `:566-596`; ADD `resumable_protocol: "tus"`, keep `upload_strategy: "resumable"` per D-10/D-11):
```elixir
# Source: broker.ex:566-596 (verified). Reuse create_upload_session/7; add resumable_protocol.
defp persist_tus_session(repo, adapter, seed, opts) do
  case create_upload_session(repo, seed.asset_id, seed.profile_name, seed.storage_key,
         seed.filename, seed.expires_at, %{
           state: "signed",                # D-10/Pitfall-7: stay in signed (signed->verifying is legal)
           upload_strategy: "resumable",   # REUSE the resumable strategy (D-10)
           resumable_protocol: "tus",      # the ONE new column (D-10)
           last_known_offset: 0            # IS the tus Upload-Offset
           # session_uri set to the signed tus URL by the Plug edge (redacted by Inspect)
         }) do
    {:ok, session} -> {:ok, session}
    {:error, reason} ->
      compensate_failed_tus_persist(adapter, seed.storage_key, opts)  # Local: File.rm_rf tmp dir (D-11)
      {:error, reason}
  end
end
```

**Compensation** (model on `compensate_failed_resumable_persist/4` `:619-640`; for Local there is no remote multipart to abort — `File.rm_rf` the tmp dir, log-and-`:ok` on failure exactly like the analog):
```elixir
# Source: broker.ex:619-640 (verified) — same log-and-return-:ok shape, Local-flavored body.
defp compensate_failed_tus_persist(_adapter, storage_key, _opts) do
  # File.rm_rf(tus tmp dir for this session); on error: Logger.warning(...); :ok
end
```

**Completion convergence (D-08) — UNCHANGED `verify_completion/2`** (`:418-485`): the final-PATCH handler atomic-renames tmp -> `session.upload_key`, then calls `Broker.verify_completion(session.id, opts)`. Do NOT touch this function. Note `head/2` for Local returns `%{size: ...}` with no `:content_type` (`local.ex:72-80`), so `content_type:` lands `nil` at `broker.ex:461-463` — known Local limitation (Pitfall 6), NOT a Phase 42 change.

---

### `lib/rindle/storage/capabilities.ex` (MODIFY — capability registration, static)

**Analog:** same file, `@type capability` `:11-18` + `@known` `:20-28`. Add exactly `:tus_upload` to BOTH (D-09):
```elixir
# Source: capabilities.ex:11-28 (verified). Append :tus_upload to the type union AND @known.
@type capability ::
        :presigned_put | :multipart_upload | :signed_url | :head
        | :local | :resumable_upload | :resumable_upload_session
        | :tus_upload                                            # ADD
@known [
  :presigned_put, :multipart_upload, :signed_url, :head,
  :local, :resumable_upload, :resumable_upload_session,
  :tus_upload                                                    # ADD
]
```
`require_upload/2` (`:49-57`) needs NO change — it already returns `{:error, {:upload_unsupported, cap}}` for any unsupported atom; the Plug wraps it (see TusPlug `init/1`).

---

### `lib/rindle/storage.ex` (MODIFY — capability type union, static)

**Analog:** same file, `@type capability` `:17-24`. Add `:tus_upload` to the union (mirror the `capabilities.ex` edit — keep the two type unions in sync, D-09):
```elixir
# Source: storage.ex:17-24 (verified). Append :tus_upload to the @type capability union.
@type capability ::
        :presigned_put | :multipart_upload | :signed_url | :head
        | :local | :resumable_upload | :resumable_upload_session
        | :tus_upload                                            # ADD
```

---

### `lib/rindle/storage/local.ex` (MODIFY — advertise `:tus_upload` + tmp-append/rename helper, file-I/O)

**Analog for the capability edit:** `capabilities/0` `:82-83`:
```elixir
# Source: local.ex:82-83 (verified). Local advertises :tus_upload (D-09); GCS/S3 do NOT.
@impl true
def capabilities, do: [:local, :presigned_put, :tus_upload]   # ADD :tus_upload
```

**Analogs for the new tmp-append helper (D-01)** — there is no existing append/rename helper, so model the *style* on the public non-callback helpers already in this file: `path_for/2` `:106-109` (key->path), `root/1` `:88-101` (root resolution), `head/2` `:72-80` (existence + size). The helper(s) are NOT `@behaviour` callbacks — they are public functions like `path_for/2`/`root/1`:
```elixir
# Style analog: local.ex:106-109 path_for/2 + :88-101 root/1 (public non-callback helpers).
# New (D-01): tmp-append + atomic rename. Append-open, IO.binwrite per chunk, File.rename on completion.
@spec tus_part_path(String.t(), keyword()) :: String.t()
def tus_part_path(session_id, opts), do: Path.join([root(opts), "tus", session_id <> ".part"])
# append: File.open(tus_part_path(...), [:append, :binary])  -> IO.binwrite(file, chunk)
# complete: File.rename(tmp_part, path_for(upload_key, opts))   # atomic same-FS (Pitfall 5)
```
**Pitfall 5 (atomic rename):** tmp dir and storage root MUST be the same filesystem (both under `root/1`); `:exdev` = misconfig, not a fallback. **Pitfall 6 (no content_type):** do NOT add content_type sniffing to `head/2` in Phase 42 (out of scope).

---

### `priv/repo/migrations/<ts>_add_resumable_protocol_to_media_upload_sessions.exs` (NEW — schema DDL)

**Analog:** `priv/repo/migrations/20260507160000_extend_media_upload_sessions_for_resumable.exs` (verified). Same `alter table` + `create index` shape; ONE column + ONE covering index (D-10):
```elixir
# Source pattern: 20260507160000_extend_..._for_resumable.exs (verified). One additive column + index.
defmodule Rindle.Repo.Migrations.AddResumableProtocolToMediaUploadSessions do
  use Ecto.Migration
  def change do
    alter table(:media_upload_sessions) do
      add :resumable_protocol, :string   # "gcs_native" | "tus"; nil for legacy rows (no backfill)
    end
    create index(:media_upload_sessions, [:upload_strategy, :resumable_protocol, :state])
  end
end
```
Note: the analog uses `null: false, default: 0` for `last_known_offset` and a partial `where:` index; the tus column is **nullable, no default** (nil = legacy) and the index is a plain covering index per D-10 — do not copy the partial-index `where:` clause.

---

### `lib/rindle/domain/media_upload_session.ex` (MODIFY — changeset cast, CRUD)

**Analog:** same file. Add `:resumable_protocol` to the schema (`:48-65`) and the `cast/3` allowlist (`:78-92`). Do NOT add it to `validate_required` (it is nullable). The redacting `Inspect` (`:104-113`) is reused VERBATIM — `session_uri` already carries the signed tus URL and is already redacted; no change needed there.
```elixir
# Source: media_upload_session.ex:48-92 (verified). Add field + cast entry; nullable (no validate_required).
# schema (near :57):
field :resumable_protocol, :string        # ADD — "gcs_native" | "tus" | nil
# cast list (within :78-92):
|> cast(attrs, [ ..., :resumable_protocol ])   # ADD to the existing allowlist
```
```elixir
# Source: media_upload_session.ex:104-113 (verified) — REUSED VERBATIM, no change.
# The custom Inspect redacts session_uri (the signed tus URL) — invariant 14 already enforced.
defimpl Inspect, for: Rindle.Domain.MediaUploadSession do
  def inspect(session, opts) do
    redacted = %{session | session_uri:
      Rindle.Domain.MediaUploadSession.redact_session_uri(session.session_uri)}
    Inspect.Any.inspect(redacted, opts)
  end
end
```

---

### `test/rindle/upload/tus_plug_test.exs` (NEW — protocol contract test, composite)

**Analogs:** `test/rindle/delivery/webhook_plug_test.exs` (Plug.Test conn-builder + `init/1`/`call/2` driving + telemetry attach + `Oban.Testing`) and `test/rindle/delivery/local_plug_test.exs` (Local tmp-root setup + test profile + `on_exit` cleanup).

**DataCase + Oban.Testing + test-profile preamble** (copy `webhook_plug_test.exs:1-20`):
```elixir
# Source: webhook_plug_test.exs:1-20 (verified).
use Rindle.DataCase, async: false
use Oban.Testing, repo: Rindle.Repo
defmodule TusProfile do
  use Rindle.Profile, storage: Rindle.Storage.Local, variants: [...]   # advertises :tus_upload
end
```
(For the `init/1` capability-raise test, also define a profile whose adapter LACKS `:tus_upload`, e.g. `Rindle.StorageMock`-backed, mirroring `webhook_plug_test.exs:13-20`.)

**Local tmp-root setup + cleanup** (copy `local_plug_test.exs:15-38`):
```elixir
# Source: local_plug_test.exs:15-20 (verified).
root = Path.join(System.tmp_dir!(), "rindle-tus-plug-#{System.unique_integer([:positive])}")
File.mkdir_p!(root)
on_exit(fn -> File.rm_rf(root) end)
```

**Synthetic conn driving** (copy the `Plug.Test` idiom at `webhook_plug_test.exs:69-83`) — build a conn with `PlugTest.conn(method, path, body)`, set headers via `Conn.put_req_header/3`, then `TusPlug.call(conn, TusPlug.init(...))`:
```elixir
# Source: webhook_plug_test.exs:72-82 (verified).
conn = :patch |> PlugTest.conn("/uploads/tus/" <> token, chunk)
       |> Conn.put_req_header("content-type", "application/offset+octet-stream")
       |> Conn.put_req_header("upload-offset", "0")
conn = TusPlug.call(conn, TusPlug.init(profile: TusProfile, secret_key_base: skb, max_size: ...))
assert conn.status == 204
```
**Landmine 1 (de-risk FIRST):** assert `extract_token/1` resolves the final `conn.path_info` segment after `forward` prefix strip — the highest-value first test.

**Contract spine assertions:** 409 on offset mismatch (body NOT consumed), 410 on expired session, 404/401 on tampered/expired token (never 200), full POST->HEAD->PATCH(drop)->HEAD->PATCH(resume)->completion->`ready` MediaAsset flow.

---

### `test/rindle/upload/tus_local_backing_test.exs` (NEW — tmp-append + rename + verify path, file-I/O)

**Analog:** `test/rindle/delivery/local_plug_test.exs` (Local + tmp-root + DataCase). Asserts: append helper grows the `.part` file per chunk; atomic `File.rename` moves it to the final `upload_key`; `Broker.verify_completion/2` promotes (head size set). May be folded into `tus_plug_test.exs` (RESEARCH §Wave-0).

---

## Shared Patterns

### Capability honesty (deploy-time raise, no silent downgrade)
**Source:** `lib/rindle/storage/capabilities.ex:49-57` (`require_upload/2` returns a tuple) + `lib/rindle/delivery/webhook_plug.ex:91-99` (the `init/1` `ArgumentError` raise shape).
**Apply to:** `TusPlug.init/1` and `Broker.initiate_tus_upload/2`. The tuple is wrapped into a raise at the Plug edge; the broker propagates the tuple via `with`. (D-09)

### HMAC bearer token (sign/verify + manual exp)
**Source:** `lib/rindle/delivery/local_plug.ex:63-80` (verify + exp), `:122` (`actor_subject` payload field).
**Apply to:** every `HEAD`/`PATCH`/`DELETE` in `TusPlug` (verify) and `POST` (sign). Salt `"rindle:tus:url"`; extraction from `conn.path_info` (D-04), not query params. Never hand-roll HMAC.

### Bearer-URL redaction (invariant 14)
**Source:** `lib/rindle/domain/media_upload_session.ex:104-113` (custom `Inspect` redacting `session_uri`).
**Apply to:** the signed tus URL — store ONLY in `session_uri`; never `Logger`, never telemetry metadata, never `inspect`. Reused verbatim; no code change.

### Path-traversal defensive guard
**Source:** `lib/rindle/delivery/local_plug.ex:232-235` (`within_root?/2`).
**Apply to:** the tmp-path build in `TusPlug`/`Local.tus_part_path`. `session_id` is a server UUID from the verified token, so traversal is structurally impossible — the guard + test is belt-and-suspenders (Landmine 8).

### Completion convergence (single trusted lane)
**Source:** `lib/rindle/upload/broker.ex:418-485` (`verify_completion/2`, `Oban.insert(:promote_job, ...)` at `:465`, all inside one `Ecto.Multi`).
**Apply to:** the final-PATCH handler. UNCHANGED — do not add a tus-specific completion path or best-effort hook (D-08).

### FSM transition discipline (no new state)
**Source:** `lib/rindle/domain/upload_session_fsm.ex:6-17`. `signed -> verifying` IS legal (`:8`); `resuming -> verifying` is NOT.
**Apply to:** keep the tus session in `"signed"` (or `signed -> uploading`) at completion so `verify_completion`'s `-> "verifying"` transition is legal. Do NOT park it in `"resuming"` (Pitfall 7).

---

## No Analog Found

| File / element | Role | Data Flow | Reason → planner action |
|----------------|------|-----------|--------------------------|
| `Local` tmp-append + atomic-rename helper (in `local.ex`) | storage backing | file-I/O (append) | No append/rename helper exists in `local.ex` (it has `store/cp`, `head`, `path_for`, `root` only). Model the *style* on `path_for/2` `:106-109` + `root/1` `:88-101`; the append/rename body is net-new per D-01 (TUS-RESEARCH §3c). This is the only genuinely-new primitive in the phase. |
| tus protocol mechanics (verb dispatch bodies, header parse/shape, status codes) inside `tus_plug.ex` | bare Plug edge | request-response | The *skeleton* (init-raise, method dispatch, halt discipline) maps exactly to `webhook_plug.ex`; the tus 1.0 header/status semantics (Upload-Offset/Length/Metadata, 409/410/415/413, Tus-Resumable, Cache-Control: no-store) have NO in-repo analog — use RESEARCH.md §Code Examples + §Protocol/Header Contract (verified against tus.io 1.0.0) verbatim. |

---

## POLISH-01 (D-13 selective triage — tus-UNRELATED, keep isolated)

In-place edits per D-13; no analog mapping. All files verified present (line counts in parens):

**FIX (8):**
- WR-01 `lib/rindle/streaming/provider/mux/http.ex` (72 ln) — `fetch_required/2` instead of `Keyword.fetch!`.
- WR-02 `lib/rindle/streaming/provider/mux.ex` (458 ln) — downcase header map once, `Map.fetch("mux-signature")`.
- WR-04 `lib/rindle/workers/mux_sync_provider_asset.ex` (235 ln) — catch `{:error, {:invalid_transition, _, _}}` → `:cancel`.
- WR-05 `lib/rindle/streaming/provider/mux.ex` + `lib/rindle/streaming/provider/mux/event.ex` (117 ln) — allowlist `~w(preparing ready errored)`, unknown → warn + `nil`.
- WR-06 `lib/rindle/workers/mux_sync_provider_asset.ex` — persist `last_sync_error` (truncate 4096) before `{:error, _}`.
- WR-08 `lib/rindle/workers/mux_sync_coordinator.ex` (136 ln) — distinguish fresh/dedup/failed `Oban.insert`; log errors.
- WR-09 `lib/rindle/workers/mux_ingest_variant.ex` (492 ln) — `safe_reason/1` redaction in `:exception` telemetry (invariant-14-adjacent).
- IN-02 `test/rindle/workers/mux_sync_coordinator_test.exs` — `Keyword.merge` env (test hygiene; cf. the `Keyword.merge` pattern at `webhook_plug_test.exs:42-46`).

**WAIVE (3, one-line rationale each):** WR-07 (`mux_sync_coordinator.ex` — documented v1.7 deferral), IN-01 (`mux/event.ex` — no live caller), IN-03 (`mux.ex` — documented URL-safe input contract).

**FIX-OR-DOCUMENT (1):** WR-03 (`mux_sync_provider_asset.ex` — telemetry `age_ms` semantics; planner's call, (a) moduledoc doc = smaller diff).

**Scope fence:** zero overlap with tus files. Tests: `test/rindle/workers/mux_ingest_variant_test.exs`, `test/rindle/workers/mux_sync_provider_asset_test.exs`, `test/rindle/workers/mux_sync_coordinator_test.exs`.

---

## Metadata

**Analog search scope:** `lib/rindle/delivery/` (webhook_plug, local_plug), `lib/rindle/upload/` (broker), `lib/rindle/storage/` (storage, capabilities, local), `lib/rindle/domain/` (media_upload_session, upload_session_fsm), `priv/repo/migrations/`, `test/rindle/delivery/`, `lib/rindle/streaming/provider/mux*` + `lib/rindle/workers/mux_*` (POLISH-01).
**Files scanned:** 14 source/test analogs + 9 POLISH-01 files, all line anchors re-verified live.
**Pattern extraction date:** 2026-05-22
