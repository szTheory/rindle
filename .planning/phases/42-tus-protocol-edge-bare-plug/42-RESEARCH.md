# Phase 42: tus Protocol Edge (bare Plug) - Research

**Researched:** 2026-05-22
**Domain:** tus 1.0 HTTP resumable-upload protocol over the v1.7 resumable-session substrate; bare-`Plug` edge; HMAC-signed bearer URLs; Local tmp-append sink; convergence into `verify_completion/2`
**Confidence:** HIGH (architecture is LOCKED in TUS-RESEARCH.md; all code anchors verified live in-repo this pass; tus 1.0 protocol surface verified against tus.io)

> This is a TRANSLATION research, not a derivation. The architecture is LOCKED by
> `.planning/research/v1.8/TUS-RESEARCH.md` and the 13 decisions in `42-CONTEXT.md`.
> Everything below is grounded in verified file/line anchors and the verified tus 1.0
> wire spec. Where the architecture already decides something, it is cited, not re-opened.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01 (Storage-sink seam):** Phase 42 backs PATCH bytes to Local with a **Local-specific tmp-append path** (`File.open(.., [:append])` → atomic `File.rename/2` into the final key on completion), reachable from `TusPlug`/a thin Local helper. It does **NOT** define the generic `upload_part_stream/5` callback on `Rindle.Storage` — that callback is born in Phase 43 against real S3 part semantics. Rationale: `Rindle.Storage.Local` has no multipart machinery; the part-numbered signature fits S3, not file-append.
- **D-02 (Local initiation):** For the Local sink, `initiate_tus_upload/2` = create the `"resumable"` / `resumable_protocol: "tus"` session row + ensure the `Rindle.tmp/tus/<session_id>` path. It does **NOT** initiate any S3 multipart upload. TUS-02's "initiates the S3 multipart upload" wording is **stale S3-centric framing** and is reconciled here as backing-agnostic; S3-multipart initiation belongs to Phase 43.
- **D-03 (HMAC auth):** Every tus URL is HMAC-signed via `Plug.Crypto.sign/verify` against `secret_key_base` (reusing the `LocalPlug` primitive, `local_plug.ex:66`), verified on every `HEAD`/`PATCH`/`DELETE`; missing/tampered/expired → `404` (do not leak existence) or `401`, never `200`. Expiry is a manual `exp` check inside the payload, exactly as `local_plug.ex:67-72`. The signed URL is stored (already-redacted) in `session_uri`, never logged/telemetry/`inspect`.
- **D-04 (Token in path segment):** The signed token is the **final path segment** of the tus URL (`Location: /uploads/tus/<signed_token>`), resolved from `conn.path_info` after `forward` strips the mount prefix — **NOT** a `?token=` query param. Deliberate divergence from `LocalPlug`'s query-param token: tus clients treat `Location` as an opaque REST resource, and CORS-sensitive proxies can mangle query strings on cross-origin `HEAD`/`PATCH`. Same `Plug.Crypto.verify` primitive; only the extraction site changes.
- **D-05 (Capture-not-enforce identity):** Phase 42 captures-but-does-not-enforce creator identity by embedding `actor: <subject>` inside the HMAC token payload (alongside `session_id`, `exp`). Lives in the signed token (stored in redacted `session_uri`), **NOT a new DB column** — preserves the one-column budget. Mirrors `LocalPlug`'s `actor_subject` (`local_plug.ex:122`). Enforcement (rebind authorizer, TUS-10) is Phase 44.
- **D-06 (Protocol surface):** `TusPlug` pattern-matches on `conn.method` + path suffix, mirroring `WebhookPlug` (~345 lines). `POST` (`Upload-Length` + opaque `Upload-Metadata` → `201` + `Location`); `HEAD` (`204` + `Upload-Offset` from `last_known_offset` + `Cache-Control: no-store`); `PATCH` (`application/offset+octet-stream` → `204` + new `Upload-Offset`, **`409`** on offset mismatch); `OPTIONS` (`204` advertising `Tus-Version`, `Tus-Resumable`, `Tus-Extension` = creation, expiration, termination ONLY, `Tus-Max-Size`); `DELETE` (`204`). `Upload-Expires` header + `410 Gone` on expired (driven by `expires_at`).
- **D-07 (PATCH read loop):** `Plug.Conn.read_body` with **`read_length: 1_048_576` (1 MiB)** + a per-PATCH ceiling derived from the mount's `max_size`; a slow-loris PATCH cannot pin memory. Fixed safety constants, NOT adopter config — the only adopter-facing knob is `max_size` (mount opt). `Upload-Metadata` is untrusted/opaque, re-sniffed at `verify_completion` (invariants 1, 10).
- **D-08 (Completion):** Final PATCH (`offset == length`) atomic-renames the tmp file into the final key, then converges into the **unchanged** `verify_completion/2` (`broker.ex:418`): head-based re-sniff, size/type validation, `PromoteAsset` in the same `Ecto.Multi`. **Zero new completion vocabulary.**
- **D-09 (Capability):** Add exactly ONE atom `:tus_upload` to `Capabilities.@known` + `Storage.capability` type unions; `Local` advertises it, `GCS` does NOT, `S3` deferred to Phase 43. `init/1` calls `Capabilities.require_upload(adapter, :tus_upload)` and **raises `ArgumentError`** on `{:error, {:upload_unsupported, :tus_upload}}`. No silent downgrade. (`require_upload/2` returns a tuple — the Plug wraps it into a raise.)
- **D-10 (Migration):** Exactly ONE additive migration: `add :resumable_protocol, :string` (`"gcs_native" | "tus"`; nil for legacy) + covering index `[:upload_strategy, :resumable_protocol, :state]`. Reuse `upload_strategy: "resumable"` + the existing `"resuming"` FSM lane. **No `tus_*` columns, no new table, no new FSM states, no new completion vocabulary.** `last_known_offset` IS the tus `Upload-Offset`.
- **D-11 (Broker entrypoint):** `initiate_tus_upload/2` is a new broker entrypoint, sibling to `initiate_resumable_session/2` (`broker.ex:182`), reusing the `persist_resumable_session/5`-style persistence + compensation-on-failure pattern (`broker.ex:566-640`); sets `resumable_protocol: "tus"`.
- **D-12 (Protocol-versioned edge):** Architect `TusPlug` as a thin protocol-versioned edge: offset bookkeeping, HMAC auth, Local backing, and `verify_completion` convergence are protocol-agnostic; only header parsing / response shaping is tus-1.0-specific. Makes IETF RUFH an additive second handler, not a rewrite.
- **D-13 (POLISH-01):** Do **NOT** run a blanket `/gsd-code-review 34 --fix`. The 4 Blockers are already fixed. Of the 12 advisories: **fix** WR-01, WR-02, WR-04, WR-05, WR-06, WR-08, WR-09, IN-02; **waive with one-line rationale** WR-07, IN-01, IN-03; **WR-03** fix-or-document (planner's call). Net ≈ 8 fixes, ≈ 3 waivers, 1 either-way.

### Claude's Discretion

- D-04 token payload encoding details, exact path-segment format, and salt string (`"rindle:tus:url"` recommended) — implementer's call within D-03/D-04.
- D-07 read-loop constants tuning within the 1 MiB / `max_size` envelope.
- D-13 WR-03 fix-vs-document decision.

### Deferred Ideas (OUT OF SCOPE)

- Generic `upload_part_stream/5` adapter callback + S3 multipart-per-PATCH backing + MinIO proof — **Phase 43** (TUS-06..09).
- Rebind authorizer enforcement, `Rindle.Error` tus vocabulary, tus edge telemetry, `mix rindle.doctor` tus checks, `guides/resumable_uploads.md`, generated-app CI proof — **Phase 44** (TUS-10..14, POLISH-02).
- tus Checksum / Concatenation / `Upload-Defer-Length`, IETF RUFH (tus 2.0), GCS-as-tus-backend, R2-native tus proxy, Rindle-owned tus JS client, LiveView tus uploader — **v1.9+ / out of scope**.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description (paraphrased from REQUIREMENTS.md) | Research Support |
|----|-------------|------------------|
| TUS-01 | Adopter mounts `Rindle.Upload.TusPlug` (bare `@behaviour Plug`, `init/1`+`call/2`) via `forward`, under their own auth pipeline, NO Phoenix dep. | Reuse Map → WebhookPlug bare-Plug idiom (`webhook_plug.ex`). `init/1` fail-fast + `@behaviour Plug` + method dispatch verified. Plug 1.16 confirmed; no Phoenix in `mix.exs`. |
| TUS-02 | tus `POST` (`Upload-Length` + opaque `Upload-Metadata`) → `201` + `Location` (HMAC-signed URL bound to a broker session via `initiate_tus_upload/2`). **D-02 reconciles "initiates S3 multipart" as backing-agnostic — Phase 42 is Local-only.** | Broker `initiate_tus_upload/2` mirrors `initiate_resumable_session/2` (`broker.ex:182-225`) + `persist_resumable_session/5` (`broker.ex:566-596`). Token signing → `Plug.Crypto.sign` (`local_plug.ex:66` pattern). |
| TUS-03 | `HEAD` → `204` + `Upload-Offset` (from `last_known_offset`) + `Cache-Control: no-store`; resume via `PATCH` (`application/offset+octet-stream`) → `204` + new offset; **`409`** on offset mismatch (tus-js-client auto-retry contract). | `last_known_offset` column verified (`media_upload_session.ex:56`). `read_body` `{:more,...}` chunking semantics verified (`deps/plug/lib/plug/conn.ex:1140-1194`). |
| TUS-04 | `OPTIONS` advertises `Tus-Version`, `Tus-Resumable`, `Tus-Extension` (creation, expiration, termination only), `Tus-Max-Size`. | Exact header values verified against tus.io (`Tus-Resumable: 1.0.0`). Protocol Contract table below. |
| TUS-05 | tus URLs HMAC-signed via `Plug.Crypto.sign/verify`; verified on every `HEAD`/`PATCH`/`DELETE`; missing/tampered/expired → `404`/`401`, never `200`; stored redacted in `session_uri`, never logged/telemetry/`inspect`. | `Plug.Crypto.verify` + manual exp check verified (`local_plug.ex:63-80`). `session_uri` redaction verified (`media_upload_session.ex:98-113`). |
| POLISH-01 | Phase 34 advisory findings resolved via selective fix or waived with rationale. D-13 triage. | Full `34-REVIEW.md` findings surfaced below (WR-01..09, IN-01..03). |
</phase_requirements>

---

## Summary

Phase 42 ships `Rindle.Upload.TusPlug` — a bare `@behaviour Plug` (mirroring the in-repo `WebhookPlug`/`LocalPlug` idiom, no Phoenix, no tussle) that implements tus 1.0 **Core + Creation + Expiration + Termination** over the v1.7 resumable-session substrate, backed by a Local tmp-append sink, converging into the **unchanged** `verify_completion/2` lane. Every reusable seam exists in-repo and was verified live this pass: the broker resumable entrypoints, the `"resuming"` FSM lane, the `media_upload_sessions` columns (`session_uri`, `last_known_offset`, `expires_at`), the redacting `Inspect`, `Plug.Crypto` HMAC signing, and the `verify_completion/2` head-based trust lane. The only genuinely new code is (a) the Plug's protocol mechanics, (b) the Local tmp-append helper, (c) one broker entrypoint (`initiate_tus_upload/2`), (d) one capability atom (`:tus_upload`), and (e) one additive migration column (`resumable_protocol`).

The risk lives entirely in "does a hand-rolled Plug get the offset/409/expiry/header mechanics exactly right." The mitigation is a **protocol contract test** that drives the exact tus wire sequence (POST → HEAD → PATCH-with-drop → PATCH-resume → completion → DELETE) and asserts every status code and header. Note: the real Node **tus-js-client** generated-app proof is scoped to **Phase 44** (TUS-RESEARCH §12) — there is no Node/tus-js-client toolchain in the repo today (verified). Phase 42's contract test must therefore be an **Elixir-driven `Plug.Test` simulation of the exact tus-js-client wire behavior** (it auto-retries 409, sends `application/offset+octet-stream`, reads offset via HEAD), with the live-client proof deferred. This is the honest, in-repo-achievable validation for this phase.

POLISH-01 is a small, tus-unrelated Mux-file diff: ≈8 selective fixes + ≈3 documented waivers + 1 either-way, all confirmed against `34-REVIEW.md`. It must NOT touch tus code paths.

**Primary recommendation:** Build `TusPlug` by copying the `WebhookPlug` skeleton (`@behaviour Plug`, `init/1` fail-fast raise, method-dispatched `call/2`) and the `LocalPlug` HMAC verify/exp pattern; resolve the token from `conn.path_info` (D-04); add `initiate_tus_upload/2` as a `persist_resumable_session/5` sibling; add `:tus_upload` to two type unions + `@known` + `Local.capabilities`; add the `resumable_protocol` migration; back PATCH bytes with a Local tmp-append helper and atomic `File.rename/2`; converge completion into the unchanged `verify_completion/2`. Validate with one protocol contract test + targeted unit tests for HMAC/exp/tamper, the 409, the migration/index, and the capability-honesty raise.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| tus HTTP protocol mechanics (verb dispatch, header parse/shape, status codes) | `Rindle.Upload.TusPlug` (HTTP edge) | — | tus 1.0-specific; the only protocol-version-aware layer (D-12). |
| HMAC URL sign / verify / expiry | `Rindle.Upload.TusPlug` (`init/1` opts) + `Plug.Crypto` | `Rindle.Domain.MediaUploadSession` (redaction) | Reuses `local_plug.ex:66` primitive; bearer-cred discipline (invariant 14). |
| Session creation + offset bookkeeping (durable state) | `Rindle.Upload.Broker.initiate_tus_upload/2` | `MediaUploadSession` columns | Broker owns session lifecycle; protocol-agnostic (D-11, D-12). |
| PATCH byte sink (append + atomic rename) | Local tmp-append helper (`Rindle.Storage.Local` or thin module) | filesystem | D-01: Local-specific, NOT the generic callback (born Phase 43). |
| Completion verification + promotion | `Rindle.Upload.Broker.verify_completion/2` (UNCHANGED) | `Oban` (`PromoteAsset`) | Single trusted lane; head-based re-sniff (invariants 1, 2). |
| Capability honesty gate | `Rindle.Storage.Capabilities.require_upload/2` | `TusPlug.init/1` raise | Deploy-time failure, no silent downgrade (D-09). |
| Expiry-driven reaping (column ADD only) | migration (`resumable_protocol`) | `UploadMaintenance` (reaper branch is Phase 43/44) | Phase 42 adds the column; teaching the reaper to branch is later. |

---

## Standard Stack

This phase adds **NO new dependencies**. Every primitive already ships.

### Core (existing, reused verbatim)
| Module / Primitive | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `Plug` | `~> 1.16` (mix.exs:97) | `@behaviour Plug`, `Plug.Conn` (`read_body`, `get_req_header`, `put_resp_header`, `send_resp`, `halt`), `Plug.Crypto.sign/verify`, `Plug.Test` (tests) | Already the only HTTP dep; NO Phoenix (verified: `mix.exs` has `phoenix_live_view` optional, no `phoenix`). |
| `Plug.Crypto` | bundled with Plug | HMAC sign/verify against `secret_key_base` | Already used by `LocalPlug` (`local_plug.ex:66`); enforces invariant 14 with zero new code. |
| `Ecto` / `ecto_sql` | `~> 3.11` | migration + `MediaUploadSession` persistence | Existing migration system. |
| `Oban` | `~> 2.21` | `PromoteAsset` enqueue inside the `verify_completion` `Ecto.Multi` | Already the completion-promotion mechanism (`broker.ex:465`). |
| `:telemetry` | `~> 1.2` | (Phase 42 reuses `[:rindle, :upload, :start|:stop]`; tus edge events are Phase 44) | Existing. |

### Supporting (in-repo modules to extend)
| Module | Anchor | What changes in Phase 42 |
|--------|--------|--------------------------|
| `Rindle.Storage.Capabilities` | `@known` `:20-28` | Add `:tus_upload`. |
| `Rindle.Storage` | `@type capability` `:17-24` | Add `:tus_upload` to the type union. |
| `Rindle.Storage.Local` | `capabilities/0` `:83` | Add `:tus_upload`; add tmp-append + atomic-rename helper(s). |
| `Rindle.Upload.Broker` | new `initiate_tus_upload/2` near `:182` | Sibling to `initiate_resumable_session/2`. |
| `Rindle.Domain.MediaUploadSession` | schema `:48-60`, changeset cast `:78-92` | Add `resumable_protocol` field + cast. |

### Alternatives Considered (all REJECTED by LOCKED architecture — do not re-open)
| Instead of | Could Use | Why REJECTED |
|------------|-----------|--------------|
| bare `TusPlug` | `tussle ~> 0.3.1` | 2 stars / 104 downloads / bus-factor 1; forces Phoenix (its routes emit Phoenix.Router DSL); locked to tus 1.0 with no RUFH path (TUS-RESEARCH §3a). |
| reuse `"resumable"` strategy | new `"tus"` strategy / `tus_*` columns | v1.7's session model IS the resumable session; tus is a wire protocol over it (TUS-RESEARCH §6, D-10). |
| Local tmp-append (D-01) | generic `upload_part_stream/5` now | Local has no multipart; part-numbered signature fits S3, not file-append; designing it against Local first yields an API reshaped once S3 arrives (D-01, Phase 43). |
| token in path segment (D-04) | `?token=` query param | tus clients treat `Location` as opaque REST resource; CORS proxies mangle query strings on cross-origin HEAD/PATCH (D-04). |

**Installation:** None. No `mix.exs` change for dependencies. (`mix deps.get` unaffected.)

**Version verification:** No new packages → no registry verification needed. `plug ~> 1.16` already resolved in `deps/plug` (verified `read_body/2` and `Plug.Test.conn/3` present).

---

## Package Legitimacy Audit

> **Not applicable.** Phase 42 installs no external packages. The bare-Plug decision (TUS-RESEARCH §3a, D-09 family) explicitly avoids adding `tussle` or any tus dependency. All primitives come from already-resolved deps (`plug`, `ecto_sql`, `oban`, `telemetry`). No slopcheck/registry verification required.

---

## Architecture Patterns

### System Architecture Diagram

```
                        ADOPTER ROUTER (Phoenix Router OR Plug.Router)
                        ──────────────────────────────────────────────
   adopter's own auth pipeline (pipe_through / plug)  ──runs BEFORE──┐
                                                                     ▼
   forward "/uploads/tus", Rindle.Upload.TusPlug, profile:, secret_key_base:, max_size:
                                                                     │
                                                                     ▼
   ┌──────────────────────── Rindle.Upload.TusPlug.call/2 ───────────────────────┐
   │  dispatch on conn.method + conn.path_info (mount prefix already stripped)    │
   │                                                                              │
   │  OPTIONS ─────────────────────────────► 204 + Tus-Version/Extension/Max-Size │
   │                                                                              │
   │  POST ──► Broker.initiate_tus_upload/2 ──► session row (resumable_protocol:  │
   │           (sign HMAC token: %{session_id, actor, exp})   "tus", offset=0)    │
   │           ──► ensure Rindle.tmp/tus/<session_id> ──► 201 + Location          │
   │                                                                              │
   │  ┌── verify HMAC token from FINAL PATH SEGMENT (conn.path_info) ──┐          │
   │  │   missing/tampered → 404 ;  expired (exp) → 401/404 ; never 200 │          │
   │  └────────────────────────────────────────────────────────────────┘         │
   │                                                                              │
   │  HEAD ──► load session ──► (expires_at past? → 410) ──► 204 +                 │
   │           Upload-Offset=last_known_offset + Cache-Control: no-store          │
   │                                                                              │
   │  PATCH ──► require Content-Type application/offset+octet-stream (else 415)    │
   │           ──► Upload-Offset == last_known_offset?  NO → 409 (no body read)    │
   │           ──► read_body loop (read_length:1MiB, ceiling=max_size)             │
   │              │  {:more, chunk} → File append to tmp ; bump running offset     │
   │              │  {:ok, chunk}   → File append ; final                          │
   │              └─ enforce per-PATCH ceiling → 413 if exceeded                   │
   │           ──► persist new last_known_offset                                   │
   │           ──► new_offset == Upload-Length?                                    │
   │                 YES → atomic File.rename(tmp, final key)                      │
   │                       ──► Broker.verify_completion/2 (UNCHANGED)              │
   │                 NO  → 204 + Upload-Offset=new_offset                          │
   │                                                                              │
   │  DELETE ──► mark session aborted + rm tmp file ──► 204                        │
   └──────────────────────────────────────────────────────────────────────────────┘
                                          │ (on completion)
                                          ▼
   Broker.verify_completion/2 ─► adapter.head/2 ─► Ecto.Multi{session→completed,
        asset→validating, Oban.insert(PromoteAsset)} ─► [:rindle,:upload,:stop] ─► ready MediaAsset
```

### Recommended File Layout
```
lib/rindle/upload/
├── broker.ex                    # + initiate_tus_upload/2  (sibling of initiate_resumable_session/2)
└── tus_plug.ex                  # NEW — Rindle.Upload.TusPlug (the edge)
lib/rindle/storage/
├── capabilities.ex              # + :tus_upload in @known + @type
├── local.ex                     # + :tus_upload in capabilities/0 + tmp-append/rename helper(s)
└── (storage.ex)                 # + :tus_upload in @type capability
lib/rindle/domain/
└── media_upload_session.ex      # + field :resumable_protocol + cast
priv/repo/migrations/
└── 2026MMDDHHMMSS_extend_media_upload_sessions_for_tus.exs   # NEW (one column + index)
test/rindle/upload/
├── tus_plug_test.exs            # NEW — protocol contract test + unit cases
└── tus_local_backing_test.exs   # NEW (optional split) — tmp-append + atomic-rename + verify path
```
(The Local tmp-append helper MAY live inside `Rindle.Storage.Local` as a non-`@behaviour` public helper, or in a small `Rindle.Upload.TusLocalSink` — implementer's call within D-01. Keeping it in `Local` mirrors `Local.path_for/2`/`Local.root/1` which are already public non-callback helpers.)

### Pattern 1: bare-Plug `init/1` fail-fast + method-dispatched `call/2`
**What:** `@behaviour Plug`; `init/1` validates mount opts and **raises `ArgumentError`** on misconfiguration (deploy-time failure); `call/2` dispatches on `conn.method`.
**When to use:** Always — this is the in-repo idiom for mountable Plugs.
**Anchor:** `webhook_plug.ex:86-111` (init raise + method guard).
```elixir
# Source: lib/rindle/delivery/webhook_plug.ex:86-111 (verified 2026-05-22)
@impl true
def init(opts) do
  provider = Keyword.fetch!(opts, :provider)
  secrets = Keyword.fetch!(opts, :secrets)
  unless Code.ensure_loaded?(provider) and function_exported?(provider, :verify_webhook, 3) do
    raise ArgumentError, "Rindle.Delivery.WebhookPlug requires ..."
  end
  [provider: provider, secrets: secrets]
end

@impl true
def call(%Plug.Conn{method: method} = conn, _opts) when method != "POST" do
  conn |> send_resp(405, "method not allowed") |> halt()
end
def call(conn, opts), do: verify_and_dispatch(conn, ...)
```
**TusPlug application (D-06, D-09):** `init/1` does `Keyword.fetch!(:profile)`, `Keyword.fetch!(:secret_key_base)`, `Keyword.get(:max_size, ...)`, then `adapter = profile.storage_adapter()` and wraps `Capabilities.require_upload(adapter, :tus_upload)` — on `{:error, {:upload_unsupported, :tus_upload}}` it **raises `ArgumentError`** (no silent downgrade). `call/2` dispatches `OPTIONS|POST|HEAD|PATCH|DELETE`; any other method → `405`.

### Pattern 2: `Plug.Crypto` sign/verify with manual `exp` check (HMAC bearer token)
**What:** Sign an opaque token with a salt against `secret_key_base`; verify on read; manually check the `exp` field inside the payload.
**Anchor:** `local_plug.ex:63-80` (verify + exp), `:122` (`actor_subject` in payload).
```elixir
# Source: lib/rindle/delivery/local_plug.ex:63-80 (verified 2026-05-22)
defp verify_token(conn, opts) do
  token = conn.query_params["token"]   # TusPlug: read from conn.path_info instead (D-04)
  case Plug.Crypto.verify(opts[:secret_key_base], @local_playback_salt, token) do
    {:ok, %{"expires_at" => expires_at} = payload} ->
      if expires_at >= System.system_time(:second), do: {:ok, payload}, else: {:error, :expired_token}
    {:error, :expired} -> {:error, :expired_token}
    {:error, _reason} -> {:error, :invalid_token}
  end
end
```
**TusPlug application (D-03, D-04, D-05):**
- **Sign (POST):** `Plug.Crypto.sign(secret_key_base, "rindle:tus:url", %{session_id: id, actor: subject, exp: unix_ts})`. Salt `"rindle:tus:url"` (discretion, recommended).
- **Extract (HEAD/PATCH/DELETE):** the token is `List.last(conn.path_info)` — NOT `conn.query_params`. After `forward "/uploads/tus"`, Plug strips the mount prefix so `conn.path_info` for `/uploads/tus/<token>` is `["<token>"]`. **Verify this empirically in a test** (see Landmine 1).
- **Verify + exp:** same `Plug.Crypto.verify/3` + manual `exp` check. Map failures to `404` (unknown/tampered — do not leak existence) or `401` (expired). NEVER `200`.

### Pattern 3: broker resumable-session initiation + compensation-on-failure
**What:** Resolve profile/adapter/key, check capability, persist a `"resumable"` session row with the offset/uri columns, compensate (best-effort cleanup) on persist failure, emit `[:rindle, :upload, :start]` after commit.
**Anchor:** `broker.ex:182-225` (`initiate_resumable_session/2`), `:566-596` (`persist_resumable_session/5`), `:619-640` (compensation).
```elixir
# Source: lib/rindle/upload/broker.ex:566-596 (verified 2026-05-22)
defp persist_resumable_session(repo, adapter, session_seed, resumable, opts) do
  case create_upload_session(repo, session_seed.asset_id, ..., %{
         state: "signed",
         upload_strategy: "resumable",
         session_uri: resumable.session_uri,
         session_uri_expires_at: resumable.expires_at,
         last_known_offset: 0,
         region_hint: Map.get(resumable, :region_hint)
       }) do
    {:ok, session} -> {:ok, session}
    {:error, reason} -> compensate_failed_resumable_persist(adapter, ...); {:error, reason}
  end
end
```
**TusPlug/Broker application (D-02, D-11):** `initiate_tus_upload/2` mirrors this but:
- Does **NOT** call any adapter `initiate_*` (Local has no multipart; D-02). For Local it just creates the session row + ensures `Rindle.tmp/tus/<session_id>`.
- Sets `resumable_protocol: "tus"`, `upload_strategy: "resumable"`, `last_known_offset: 0`, `expires_at` (drives `Upload-Expires`/410).
- Stores the HMAC-signed tus URL in `session_uri` (redacted by construction). NOTE the signing happens at the Plug edge (it has `secret_key_base`); the broker may return the session and the Plug signs + persists the URL, OR the broker accepts the signed URL — implementer's call. **Persist the signed URL into `session_uri` so invariant-14 redaction applies.**
- Compensation on persist failure: for Local, `File.rm_rf` the tmp dir (no remote multipart to abort in Phase 42).

### Pattern 4: completion convergence into the UNCHANGED `verify_completion/2`
**What:** After the final byte lands, call `verify_completion(session_id, opts)` — it does `adapter.head/2`, FSM transitions, and enqueues `PromoteAsset` inside one `Ecto.Multi`.
**Anchor:** `broker.ex:418-485` (head-based trust + `Oban.insert(:promote_job, ...)` at `:465`); the existing `complete_multipart_upload/3` (`:324`) shows the "do adapter work, then call `verify_completion`" shape.
**TusPlug application (D-08):** the final-PATCH handler atomic-renames the tmp file into `session.upload_key`, then calls `Broker.verify_completion(session.id, opts)`. **`verify_completion/2` is UNCHANGED.** Do not add a new completion path.

### Anti-Patterns to Avoid
- **Buffering the whole PATCH body in memory.** Always loop `read_body` with `read_length: 1_048_576` and append to the tmp file per chunk; never `read_body(conn, length: :infinity)` or accumulate in a binary (TUS-RESEARCH §2; D-07).
- **Reading the PATCH body before the offset check.** Check `Upload-Offset == last_known_offset` FIRST; on mismatch return `409` WITHOUT consuming the body (saves bandwidth; matches tus-js-client's retry-and-re-HEAD contract).
- **Putting the tus URL anywhere observable.** No `inspect`, no `Logger`, no telemetry metadata (invariant 14). Store only in `session_uri` (redacted) (`media_upload_session.ex:98-113`).
- **A new completion vocabulary or a "best-effort hook."** Converge into `verify_completion/2`; the `PromoteAsset` job rides inside the txn (Rindle's differentiator vs tusd's non-retried hooks — TUS-RESEARCH §8).
- **A new FSM state.** The `"resuming"` lane already exists (`upload_session_fsm.ex:9`); reuse it (D-10).
- **Teaching the reaper to branch on `resumable_protocol` in Phase 42.** Phase 42 ADDS the column only; the reaper branch is Phase 43/44 (canonical_refs note). See Landmine 6.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HMAC token signing/verification | Custom `:crypto.mac` + base64 + constant-time compare | `Plug.Crypto.sign/3` + `Plug.Crypto.verify/3` | Already used (`local_plug.ex:66`); handles key derivation, encoding, timing-safe compare, and `{:error, :expired}` for free. |
| tus protocol routing | A new dependency (`tussle`) | bare Plug method dispatch | tussle forces Phoenix + bus-factor-1 + no RUFH (TUS-RESEARCH §3a). |
| Completion / promotion | A tus-specific finish path | `Broker.verify_completion/2` (UNCHANGED) | Single trusted lane; head-based re-sniff + `Oban`-in-txn (`broker.ex:418-485`). |
| Session state machine | A tus state enum | `UploadSessionFSM` `"resuming"` lane | Already covers `signed → resuming → uploading → uploaded → verifying → completed` (`upload_session_fsm.ex:6-17`). |
| Streaming body read | Manual socket reads | `Plug.Conn.read_body/2` with `:read_length` | Handles chunked + identity transfer-encoding, returns `{:more,...}`/`{:ok,...}` (`conn.ex:1140-1194`). |
| Redaction of bearer URL | Manual scrubbing at log sites | The schema's custom `Inspect` impl on `MediaUploadSession` | Already redacts `session_uri` (`media_upload_session.ex:104-113`). |

**Key insight:** Phase 42 is ~95% glue over existing seams. The discipline is to NOT introduce parallel machinery; the only net-new primitive is the Local tmp-append sink (D-01).

## Common Pitfalls

### Pitfall 1: HEAD/204 with a body, or missing `Cache-Control: no-store`
**What goes wrong:** A `204 No Content` MUST have no body; tus clients also require `Cache-Control: no-store` on HEAD so intermediaries don't serve a stale `Upload-Offset`.
**Why:** Without `no-store`, a CDN/proxy can cache the offset; a resumed PATCH then targets a stale offset → 409 loops.
**Avoid:** `put_resp_header(conn, "cache-control", "no-store")` + `put_resp_header("upload-offset", Integer.to_string(offset))` + `send_resp(conn, 204, "")`.
**Warning sign:** tus-js-client stuck in a 409 retry loop on resume.

### Pitfall 2: `Tus-Resumable` header omitted from responses
**What goes wrong:** Spec: `Tus-Resumable: 1.0.0` MUST be in every request and response **except OPTIONS**. Clients reject responses lacking it (`412 Precondition Failed` semantics on the client side).
**Avoid:** Add `Tus-Resumable: 1.0.0` to POST/HEAD/PATCH/DELETE responses (and error responses). OPTIONS advertises `Tus-Version` instead.
**Warning sign:** client errors immediately after a 201/204 that "looks correct."

### Pitfall 3: offset arithmetic off-by-one / type confusion
**What goes wrong:** `Upload-Offset` and `Upload-Length` are non-negative-integer **strings** in headers. Comparing a string to `last_known_offset` (integer) silently mismatches → spurious 409.
**Avoid:** `Integer.parse/1` the inbound `Upload-Offset`; compare integers; emit `Integer.to_string(new_offset)`.
**Warning sign:** every PATCH returns 409 even on a fresh upload.

### Pitfall 4: PATCH body length not enforced → memory/disk DoS
**What goes wrong:** A malicious client streams forever; without a per-PATCH ceiling the tmp file grows unbounded.
**Avoid:** Track running bytes in the `read_body` loop; if running total would exceed the per-PATCH ceiling (derived from `max_size`), stop and return `413`. Also enforce that `last_known_offset + patch_bytes <= Upload-Length`.
**Warning sign:** disk fills under load; `Rindle.tmp/tus/` grows without bound.

### Pitfall 5: completion atomic-rename across filesystems
**What goes wrong:** `File.rename/2` is atomic only **within the same filesystem**; across mounts it falls back to copy+delete (not atomic) or errors (`:exdev`).
**Avoid:** Ensure `Rindle.tmp/tus/<session_id>` and the Local storage root are on the **same filesystem** (both default under the configured Local root / `System.tmp_dir!`). Document this; the Local backing's atomicity (TUS-RESEARCH §3c "cheap same-filesystem rename, no copy") depends on it. If `File.rename` returns `{:error, :exdev}`, that is a misconfiguration, not a runtime fallback.
**Warning sign:** intermittent partial files; `:exdev` errors in logs.

### Pitfall 6: Local `head/2` returns no `content_type` → profile validation surprise
**What goes wrong:** `Rindle.Storage.Local.head/2` returns `{:ok, %{size: ...}}` with **no `:content_type`** (verified `local.ex:72-80`). `verify_completion/2` writes `content_type: Map.get(metadata, :content_type)` → `nil` on the asset (`broker.ex:461-463`). Any profile that validates `content_type` against `allow_mime` may behave differently for Local-backed tus than for S3.
**Avoid:** This is a known Local-adapter limitation, NOT a Phase 42 regression. The contract test should assert the promoted asset reaches `ready`/`validating` with the size set; if a test profile enforces `allow_mime`, either use a permissive test profile OR document that Local tus relies on the existing magic-byte analyzer downstream of `PromoteAsset` (re-sniff, invariant 1) rather than the head content_type. Flag for the planner: do NOT add content_type sniffing to Local in Phase 42 (out of scope; would be a `head/2` change).
**Warning sign:** asset stuck in `validating`/`failed` because `content_type` is nil and a profile gate rejects nil.

### Pitfall 7: FSM transition path for completion
**What goes wrong:** `verify_completion/2` transitions the session to `"verifying"` then `"completed"`. The transition to `"verifying"` is only legal from `signed`, `resuming`, `uploading`, or `uploaded` (`upload_session_fsm.ex:7-11`). `"resuming"` does NOT transition directly to `"verifying"` — it must reach `signed`/`uploading`/`uploaded` first... **except** `signed → verifying` IS allowed (`:8`) and `uploading → verifying` IS allowed (`:10`), and `uploaded → verifying` (`:11`). `resuming → verifying` is NOT in the allowlist.
**Avoid:** A tus session is created in `"signed"` (per `persist_resumable_session` `:575`). If the Plug never transitions it to `"resuming"`, the final PATCH can call `verify_completion` directly from `signed → verifying` (legal). If the Plug DOES move it to `"resuming"` on first PATCH, it must then move `resuming → uploading` before completion (`uploading → verifying` is legal). **Recommendation:** keep the tus session in `"signed"` (or transition `signed → uploading` on first PATCH) so the existing `verify_completion` FSM path works unchanged. Do NOT leave it in `"resuming"` at completion time. Verify with an explicit FSM test.
**Warning sign:** `{:error, {:invalid_transition, "resuming", "verifying"}}` at completion.

### Pitfall 8: path traversal via session_id → tmp path
**What goes wrong:** If the tmp path is built from any client-influenced value, `../` could escape `Rindle.tmp/tus/`.
**Avoid:** The session_id comes from the **verified HMAC token payload** (server-issued UUID), never from raw client input. Build the tmp path as `Path.join(tus_root, session_id <> ".part")` and reuse the `within_root?` guard pattern (`local_plug.ex:232-235`) defensively. Since `session_id` is a server-generated UUID, traversal is structurally impossible — but assert it in a test (tampered token → 404 before any path is built).
**Warning sign:** none at runtime if HMAC is enforced; the test is the guard.

## Runtime State Inventory

> Phase 42 is greenfield-additive (new Plug, new column, new capability advertisement, new tmp directory). It is NOT a rename/refactor/migration of existing runtime state. However, because it ADDS a column and a tmp-directory convention that later phases and the reaper interact with, the following is documented explicitly:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `media_upload_sessions` gains `resumable_protocol` (nullable, nil for all legacy rows). No backfill needed — nil is the legacy default. | migration adds column; no data migration. |
| Live service config | None — `TusPlug` is adopter-mounted; no Rindle-owned service registers tus state. | None. |
| OS-registered state | New tmp convention `Rindle.tmp/tus/<session_id>.part` under the sweepable root (invariant 13). | Ensure the tus root is created on POST; reaped by the existing sweeper (column-add only in Phase 42). |
| Secrets/env vars | `secret_key_base` is a **mount opt** (`Keyword.fetch!`), reusing the adopter's existing `SECRET_KEY_BASE`. No new secret key. The HMAC salt `"rindle:tus:url"` is a code constant, not a secret. | None — same `secret_key_base` as `LocalPlug`. |
| Build artifacts | None — no compiled artifacts, no package rename. | None. |

**Reaper interaction (verified, flagged for the planner):** the existing reaper query `fetch_incomplete_timed_out_sessions` (`upload_maintenance.ex:139-148`) already matches `state in ["signed","uploading"]` AND `(state == "resuming" and upload_strategy == "resumable")`. A Phase-42 tus session (`upload_strategy: "resumable"`, state `signed`/`uploading`/`resuming`) WILL be selected by this query, and `attempt_resumable_cancel` (`:452`) will try `adapter.cancel_resumable_upload(...)` on Local — which Local does NOT implement (it would `{:error, {:upload_unsupported, ...}}` via `resolve_resumable_adapter` requiring `:resumable_upload_session`, which Local lacks). `resolve_resumable_adapter` (`:522-536`) returns `{:error, ...}` → `resumable_failure_reason/1` → marks the session `"aborted"` with `failure_reason: "resumable_cancel_failed:transport"`. **This is the precise landmine TUS-RESEARCH §6 anticipated.** Phase 42 only ADDS the `resumable_protocol` column; teaching the reaper to branch on it (so tus sessions get tmp-file cleanup instead of a GCS-shaped cancel) is **Phase 43/44** (canonical_refs). The planner should: (a) confirm Phase 42 does NOT modify the reaper, and (b) note in the PLAN that until the reaper branch lands, an expired Phase-42 tus session is marked `aborted` (not silently broken — it just doesn't clean the tmp file optimally). Within the short Phase-42 horizon (Local dev, contract test) this is acceptable; the column is the forward-compat seam.

## Code Examples

### tus `OPTIONS` response (advertise capabilities)
```elixir
# Verified against tus.io/protocols/resumable-upload (1.0.0) 2026-05-22.
# OPTIONS is the ONLY verb that omits Tus-Resumable and instead sends Tus-Version.
defp handle_options(conn, opts) do
  conn
  |> put_resp_header("tus-resumable", "1.0.0")
  |> put_resp_header("tus-version", "1.0.0")
  |> put_resp_header("tus-extension", "creation,expiration,termination")
  |> put_resp_header("tus-max-size", Integer.to_string(opts[:max_size]))
  |> send_resp(204, "")
  |> halt()
end
```

### tus `HEAD` response (authoritative offset)
```elixir
# 204 + Upload-Offset + Cache-Control: no-store + Tus-Resumable. No body.
defp handle_head(conn, session) do
  conn
  |> put_resp_header("tus-resumable", "1.0.0")
  |> put_resp_header("upload-offset", Integer.to_string(session.last_known_offset))
  |> put_resp_header("upload-length", Integer.to_string(session_upload_length(session)))
  |> put_resp_header("cache-control", "no-store")
  |> maybe_put_upload_expires(session)        # Upload-Expires from expires_at
  |> send_resp(204, "")
  |> halt()
end
```

### tus `PATCH` offset gate + streaming append (the contract spine)
```elixir
# 1. Content-Type gate → 415; 2. offset gate → 409 WITHOUT reading body;
# 3. stream-append with read_length:1MiB + per-PATCH ceiling → 413;
# 4. completion → atomic rename → verify_completion/2.
defp handle_patch(conn, session, opts) do
  with :ok <- require_offset_octet_stream(conn),                       # else 415
       {inbound_offset, ""} <- Integer.parse(offset_header(conn)),
       true <- inbound_offset == session.last_known_offset do          # else 409
    append_stream(conn, session, opts)
  else
    :wrong_content_type -> send_status(conn, 415)
    false -> send_status(conn, 409)                                    # offset mismatch
    _ -> send_status(conn, 400)
  end
end

# read_body returns {:more, partial, conn} until the last chunk ({:ok, last, conn}).
# `:length` caps bytes returned per call; `:read_length` caps socket fill.
# Source: deps/plug/lib/plug/conn.ex:1140-1194 (verified 2026-05-22).
defp drain(conn, file, written, ceiling, opts) do
  case Plug.Conn.read_body(conn, length: opts.length, read_length: 1_048_576) do
    {:more, chunk, conn} ->
      written = written + byte_size(chunk)
      if written > ceiling, do: {:too_large, conn}, else: (IO.binwrite(file, chunk); drain(conn, file, written, ceiling, opts))
    {:ok, chunk, conn} ->
      written = written + byte_size(chunk)
      if written > ceiling, do: {:too_large, conn}, else: (IO.binwrite(file, chunk); {:done, written, conn})
    {:error, reason} -> {:error, reason, conn}
  end
end
```

### Token resolution from path segment (D-04)
```elixir
# After `forward "/uploads/tus"`, Plug strips the mount prefix; conn.path_info
# for /uploads/tus/<token> is ["<token>"]. VERIFY EMPIRICALLY (Landmine 1).
defp extract_token(conn), do: List.last(conn.path_info)   # may be nil → treat as 404
```

### Migration (D-10) — modeled on the resumable migration
```elixir
# Source pattern: priv/repo/migrations/20260507160000_extend_..._for_resumable.exs (verified).
defmodule Rindle.Repo.Migrations.ExtendMediaUploadSessionsForTus do
  use Ecto.Migration
  def change do
    alter table(:media_upload_sessions) do
      add :resumable_protocol, :string   # "gcs_native" | "tus"; nil for legacy rows
    end
    create index(:media_upload_sessions, [:upload_strategy, :resumable_protocol, :state])
  end
end
```

## Protocol / Header Contract (encode VERBATIM)

> Verified against https://tus.io/protocols/resumable-upload (1.0.0, 2016-03-25) on 2026-05-22, reconciled with CONTEXT D-06. `Tus-Resumable: 1.0.0` is the exact version string. HTTP header names are case-insensitive; Plug normalizes inbound to lowercase.

### Response by verb
| Verb | Success status | Required response headers | Error statuses |
|------|----------------|---------------------------|----------------|
| `OPTIONS` | `204` (or 200) | `Tus-Version: 1.0.0`, `Tus-Resumable: 1.0.0`, `Tus-Extension: creation,expiration,termination`, `Tus-Max-Size: <max_size>` | — |
| `POST` (Creation) | `201` | `Location: /uploads/tus/<signed_token>`, `Tus-Resumable: 1.0.0`, `Upload-Expires: <RFC9110 date>` | `400` (missing/invalid `Upload-Length`), `413` (`Upload-Length > Tus-Max-Size`) |
| `HEAD` | `204` | `Upload-Offset: <last_known_offset>`, `Upload-Length: <length>`, `Cache-Control: no-store`, `Tus-Resumable: 1.0.0`, `Upload-Expires` | `404` (unknown/tampered token), `401` (expired token), `410` (`expires_at` past — Gone) |
| `PATCH` | `204` | `Upload-Offset: <new_offset>`, `Tus-Resumable: 1.0.0`, `Upload-Expires` | `409` (offset mismatch — **no body read**), `415` (wrong Content-Type), `413` (per-PATCH ceiling / exceeds `Upload-Length`), `404`/`401` (token), `410` (expired) |
| `DELETE` (Termination) | `204` | `Tus-Resumable: 1.0.0` | `404`/`401` (token), `410` (expired) |

### Request headers consumed
| Header | Verb | Handling |
|--------|------|----------|
| `Upload-Length` | POST | Required (Phase 42; `Upload-Defer-Length` deferred). Non-negative integer string. `> max_size` → `413`. |
| `Upload-Metadata` | POST | **Opaque, untrusted** (invariant 1, 10). Comma-separated `key <base64value>` pairs. Store as-is (truncated); re-sniff at `verify_completion`. Do NOT trust filename/type. |
| `Upload-Offset` | PATCH | Required. Non-negative integer string. Must `== last_known_offset` else `409`. |
| `Content-Type` | PATCH | MUST be exactly `application/offset+octet-stream` else `415`. |
| `Tus-Resumable` | all (client sends `1.0.0`) | Spec allows rejecting mismatched versions with `412`; for Phase 42, accepting `1.0.0` (and treating absent as best-effort) is sufficient. |
| `X-HTTP-Method-Override` | any | Spec: server MUST interpret this as the request method if present (for clients/proxies that block PATCH/DELETE). **Recommended:** honor it — resolve effective method as `override || conn.method`. Low cost, real interop value (verified on tus.io). |

### Status-code semantics that are the contract test's spine (D-specifics, §specifics)
- **`409 Conflict`** — `Upload-Offset` ≠ `last_known_offset`. tus-js-client auto-retries (re-HEADs then re-PATCHes). Get this exact: return 409, do NOT read the body, keep `last_known_offset` unchanged.
- **`410 Gone`** — `expires_at` in the past. Driven by the Expiration extension.
- **`404` vs `401`** — missing/tampered token → `404` (do not leak existence); expired-but-validly-signed token → `401` (or `404`, implementer's call within D-03). Tampered/forged signature is ALWAYS non-200.

## State of the Art

| Old Approach (v1.6 plan) | Current Approach (LOCKED v1.8) | When Changed | Impact |
|--------------------------|--------------------------------|--------------|--------|
| `tussle ~> 0.3.1` runtime dep | bare `Rindle.Upload.TusPlug` (no dep) | TUS-RESEARCH §3a (2026-05-22) | No Phoenix dep; no bus-factor-1 dep; RUFH-additive. |
| five `tus_*` columns + `upload_strategy: "tus"` | one `resumable_protocol` column, reuse `"resumable"` | TUS-RESEARCH §6 / D-10 | Minimal schema; one FSM family. |
| `Rindle.Upload.Tus.Cache.Ecto` (tussle cache behaviour) | `media_upload_sessions` IS the state | TUS-RESEARCH §3a | Eliminated entirely. |
| S3 multipart backing in Phase 42 | Local tmp-append in Phase 42; S3 in Phase 43 | D-01 / TUS-RESEARCH §12 | Phase 42 proves the protocol without S3. |

**Deprecated/outdated for this phase:**
- `STRATEGY-SEQUENCING.md` §7's phase table (calls Phase 42 "tus Foundations", references `tussle`, different numbering) is **superseded** by TUS-RESEARCH.md §12 + REQUIREMENTS.md (Phase 42 = "tus Protocol Edge", bare Plug, TUS-01..05 + POLISH-01). Defer to TUS-RESEARCH.md + CONTEXT.md + REQUIREMENTS.md.
- IETF RUFH / tus 2.0 (draft-11, 2026-04-20, NOT an RFC) — architect for it (D-12) but do NOT implement.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | After `forward "/uploads/tus"`, `conn.path_info` for `/uploads/tus/<token>` is `["<token>"]` (prefix stripped). | Pattern 2 / D-04 / Landmine 1 | If `script_name`/`path_info` interaction differs (e.g., nested forwards), token extraction breaks. **MUST verify empirically in a test.** `[ASSUMED]` from Plug `forward` semantics; not run this session. |
| A2 | tus-js-client treats the `Location` as opaque and uses it directly for HEAD/PATCH/DELETE. | D-04 / Validation | If the client appends/transforms the URL, path-segment token must survive. `[CITED: tus-js-client docs via TUS-RESEARCH §8]`; not exercised against a live client this phase (Phase 44). |
| A3 | A test profile backed by Local can drive `verify_completion → ready` without a content_type from `head/2`. | Pitfall 6 | If the chosen test profile enforces `allow_mime` against the nil content_type, the contract test fails at promotion. Mitigate by using a permissive test profile OR relying on the downstream re-sniff. `[ASSUMED]` — depends on profile config the planner picks. |
| A4 | `Rindle.tmp/tus/` and the Local storage root are on the same filesystem (atomic `File.rename`). | Pitfall 5 | Cross-FS → `:exdev` / non-atomic. True by default (both under Local root / tmp); document the constraint. `[ASSUMED]` for non-default deployments. |
| A5 | Phase 42 does NOT modify `UploadMaintenance`; an expired tus session is marked `aborted` (acceptable for the phase horizon). | Runtime State Inventory | If the reaper errors hard (not just suboptimal cleanup) on a tus session, expiry tests could fail. Verified the reaper marks `aborted` rather than crashing (`upload_maintenance.ex:494-520`). `[VERIFIED: codebase grep]`. |
| A6 | The `"signed → verifying"` FSM edge (or `signed → uploading → verifying`) covers tus completion without a new state. | Pitfall 7 | If the Plug parks the session in `"resuming"` at completion, `resuming → verifying` is illegal. Keep it in `signed`/`uploading`. `[VERIFIED: upload_session_fsm.ex:6-17]`. |

**No `[ASSUMED]` package claims** — Phase 42 installs nothing.

## Open Questions

1. **Path-info token extraction under `forward` (A1).**
   - What we know: `forward` strips the mount prefix into `conn.script_name`, leaving the remainder in `conn.path_info` (Plug semantics).
   - What's unclear: exact `path_info` shape for `/uploads/tus/<token>` was not run live this session; nested-forward edge cases.
   - Recommendation: **Plan a Wave-0 test** that mounts `TusPlug` via `Plug.Router.forward` (or `Plug.Test` with an explicit `path_info`) and asserts `extract_token/1` returns the token. This is the single highest-value de-risking test; build it first.

2. **Where signing happens (broker vs Plug).**
   - What we know: the Plug holds `secret_key_base` (mount opt); the broker creates the session.
   - What's unclear: whether `initiate_tus_upload/2` returns an unsigned session (Plug signs + persists the URL) or accepts the signed URL.
   - Recommendation: Plug signs (it owns `secret_key_base` per `init/1`), then persists the URL into `session_uri` so redaction applies. Implementer's call within D-03/D-11; either works if the URL ends up redacted in `session_uri`.

3. **Phase 42 contract test = Elixir simulation, not live tus-js-client.**
   - What we know: no Node/tus-js-client toolchain exists in-repo (verified); the live-client generated-app proof is Phase 44 (TUS-RESEARCH §12).
   - What's unclear: how literally to read the objective's "a real tus-js-client must create→resume→complete→delete." The phase plan (and requirements TUS-01..05) describe protocol behaviors, not a Node harness.
   - Recommendation: Phase 42 ships an **Elixir `Plug.Test` contract test** that replays the exact tus wire sequence INCLUDING a simulated mid-PATCH drop + 409-driven resume (mimicking tus-js-client's retry). Defer the live Node tus-js-client run to Phase 44. State this reconciliation in the PLAN so the verifier doesn't expect a Node harness.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir/Mix | build/test | ✓ | `~> 1.15` (mix.exs) | — |
| `plug` | TusPlug, `Plug.Test` | ✓ | `~> 1.16` (resolved in `deps/plug`) | — |
| PostgreSQL (via `ecto_sql`/`postgrex`) | migration + session persistence in tests | ✓ (test alias runs `ecto.create`/`ecto.migrate`) | — | — |
| Oban | `verify_completion` promote enqueue (test uses `Oban.Testing`) | ✓ | `~> 2.21` | — |
| Node.js + tus-js-client | **NOT required in Phase 42** (live-client proof is Phase 44) | ✗ | — | Elixir `Plug.Test` contract simulation (Open Question 3) |
| MinIO / S3 | **NOT required in Phase 42** (Local backing only; S3 is Phase 43) | ✗ | — | Local tmp-append |

**Missing dependencies with no fallback:** None for Phase 42.
**Missing dependencies with fallback:** Node tus-js-client → Elixir `Plug.Test` simulation (deferred live proof to Phase 44); MinIO → Local backing (S3 deferred to Phase 43). Both are LOCKED phase boundaries, not gaps.

## Validation Architecture

> `workflow.nyquist_validation` is not set to `false` in `.planning/config.json` (the `workflow` block has no such key) → validation section REQUIRED.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir built-in) + `Plug.Test` (synthetic conns) + `Oban.Testing` (job assertions) |
| Config file | `test/test_helper.exs` (existing); `Rindle.DataCase` for DB-backed tests |
| Quick run command | `mix test test/rindle/upload/tus_plug_test.exs` |
| Full suite command | `mix test` (alias runs `ecto.create --quiet` + `ecto.migrate --quiet` + `test`) |

### Sampling/Coverage Rationale (load-bearing vs incidental)

The **load-bearing** behaviors — the ones a hand-rolled Plug most plausibly gets wrong, and the ones tus-js-client interop depends on — get dedicated, deterministic tests. **Incidental** behaviors (e.g., exact `Upload-Expires` date formatting) are asserted as part of the contract flow, not separately.

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TUS-01 | `init/1` raises `ArgumentError` when adapter lacks `:tus_upload` (capability honesty, no silent downgrade) | unit | `mix test test/rindle/upload/tus_plug_test.exs -o "init capability"` | ❌ Wave 0 |
| TUS-01 | `init/1` succeeds for a Local-backed profile (advertises `:tus_upload`) | unit | same file | ❌ Wave 0 |
| TUS-01 | Non-tus method → `405` | unit | same file | ❌ Wave 0 |
| TUS-02 | `POST` (`Upload-Length` + opaque `Upload-Metadata`) → `201` + `Location` (signed) + session row `resumable_protocol: "tus"` | integration (DataCase) | same file | ❌ Wave 0 |
| TUS-02 | `POST` with `Upload-Length > max_size` → `413` | unit | same file | ❌ Wave 0 |
| TUS-03 | `HEAD` → `204` + `Upload-Offset` (== `last_known_offset`) + `Cache-Control: no-store` + `Tus-Resumable: 1.0.0` | integration | same file | ❌ Wave 0 |
| TUS-03 | `PATCH` happy → `204` + new `Upload-Offset`; `last_known_offset` advanced; tmp file grown | integration | same file | ❌ Wave 0 |
| TUS-03 | `PATCH` wrong `Content-Type` → `415` (no body read) | unit | same file | ❌ Wave 0 |
| TUS-03 | **`PATCH` offset mismatch → `409`, body NOT consumed, offset unchanged** (the spine) | integration | same file | ❌ Wave 0 |
| TUS-03 | **Full resume flow: POST → HEAD → PATCH(partial) → simulated drop → HEAD → PATCH(rest at offset) → completion → `ready` MediaAsset** (tus-js-client-shaped contract) | integration (DataCase + Oban.Testing) | same file | ❌ Wave 0 |
| TUS-03 | `PATCH` exceeding per-PATCH ceiling / `Upload-Length` → `413` | unit | same file | ❌ Wave 0 |
| TUS-04 | `OPTIONS` → `204` advertising `Tus-Version: 1.0.0`, `Tus-Extension: creation,expiration,termination`, `Tus-Max-Size` | unit | same file | ❌ Wave 0 |
| TUS-05 | Valid HMAC token → resolves session on HEAD/PATCH/DELETE | unit | same file | ❌ Wave 0 |
| TUS-05 | **Tampered token → `404` (never 200); forged signature → non-200** | unit | same file | ❌ Wave 0 |
| TUS-05 | **Expired token (`exp` past) → `401`/`404` (never 200)** | unit | same file | ❌ Wave 0 |
| TUS-05 | Expired session (`expires_at` past) on HEAD/PATCH → `410 Gone` | integration | same file | ❌ Wave 0 |
| TUS-05 | `session_uri` redacted in `inspect`; tus URL absent from logs/telemetry | unit | same file | ❌ Wave 0 (reuse `media_upload_session` redaction; assert on inspect) |
| TUS-05/Landmine 1 | Token resolves from `conn.path_info` final segment after `forward` prefix strip | unit (de-risk FIRST) | same file | ❌ Wave 0 |
| TUS-03/D-08 | Local tmp-append → atomic `File.rename` → `verify_completion/2` promotes (head size set) | integration | `test/rindle/upload/tus_local_backing_test.exs` | ❌ Wave 0 |
| TUS-01 (Termination) | `DELETE` (valid token) → `204`, session aborted, tmp file removed | integration | same file | ❌ Wave 0 |
| TUS-02/D-10 | Migration adds `resumable_protocol` + covering index; legacy rows nil | migration test | `mix test` (schema cast + index presence) | ❌ Wave 0 (or assert via `Ecto` introspection) |
| TUS-01/D-09 | `Local.capabilities/0` includes `:tus_upload`; `Capabilities.@known` includes it; `GCS` does NOT | unit | `test/rindle/storage/...` | partial — extend existing capability tests |
| POLISH-01 | Selective Mux fixes (WR-01/02/04/05/06/08/09, IN-02) carry regression tests where they assert behavior; waivers (WR-07, IN-01, IN-03) documented | unit (Mux test files) | `mix test test/rindle/streaming/...` and `test/rindle/workers/...` | extend existing |

### Per-task / per-wave sampling
- **Per task commit:** `mix test test/rindle/upload/tus_plug_test.exs` (the protocol contract test — the load-bearing core).
- **Per wave merge:** `mix test test/rindle/upload/ test/rindle/storage/` (Plug + capability + backing).
- **Phase gate:** `mix test` full suite green (+ `mix credo`/`mix dialyzer` per project norms) before `/gsd:verify-work`.

### Wave 0 Gaps
- [ ] `test/rindle/upload/tus_plug_test.exs` — the protocol contract test + all unit cases above (TUS-01..05). **Build the path-info token-extraction test FIRST (Landmine 1 de-risk).**
- [ ] `test/rindle/upload/tus_local_backing_test.exs` — tmp-append + atomic-rename + `verify_completion` promotion (or fold into the Plug test).
- [ ] Test profile(s) backed by `Rindle.Storage.Local` advertising `:tus_upload` (model on `LocalPlugTest.LocalProfile`, `local_plug_test.exs:9-13`), plus a profile whose adapter LACKS `:tus_upload` for the `init/1` raise test.
- [ ] Migration assertion (column + index) — either a dedicated test or an introspection assertion in the contract setup.
- [ ] Extend existing capability tests for `:tus_upload` honesty (Local yes, GCS no).
- [ ] No framework install needed — ExUnit + `Plug.Test` + `Oban.Testing` are all present (`webhook_plug_test.exs` and `local_plug_test.exs` demonstrate every idiom).

## Security Domain

> `security_enforcement` is ON (objective states so). Section REQUIRED. This is the security-critical phase.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes (delegated) | Adopter's pipeline authenticates before `forward`; Rindle captures the identity into the HMAC token (`actor`, D-05). Rindle does NOT own authn. |
| V3 Session Management | yes | The HMAC-signed tus URL IS the upload session credential; expiry via `exp` in payload + `expires_at` (410). Bearer-cred discipline (invariant 14). |
| V4 Access Control | yes (capture in P42, enforce in P44) | D-05 captures `actor`; rebind enforcement is Phase 44. Phase 42: possession of a valid signed token authorizes resume (HMAC = the gate). |
| V5 Input Validation | yes | `Upload-Length`/`Upload-Offset` parsed as integers (reject non-numeric → 400/409); `Upload-Metadata` opaque + truncated + re-sniffed at completion (invariants 1, 10); `Content-Type` must be exact (415). |
| V6 Cryptography | yes | `Plug.Crypto.sign/verify` (HMAC, never hand-rolled); reuses `secret_key_base`; salt `"rindle:tus:url"`. |
| V12 File/Resource | yes | tmp under sweepable `Rindle.tmp/tus/` (invariant 13); path built from server-issued UUID (no traversal); per-PATCH ceiling (413). |

### Known Threat Patterns for {bare-Plug tus edge over BEAM}

> The planner MUST encode each of these in the relevant PLAN.md `<threat_model>` block.

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| **Signature forgery** (guess/craft a tus URL) | Spoofing / Elevation | `Plug.Crypto.verify` HMAC against `secret_key_base`; invalid signature → `404`, never `200` (D-03). Test: forged/tampered token → non-200. |
| **Replay / expiry** (use an old valid URL) | Elevation | Manual `exp` check in payload (`local_plug.ex:67-72` pattern) → `401`; `expires_at` past → `410`. Test: expired token + expired session. |
| **Path traversal** (`session_id` → tmp path escapes `Rindle.tmp/tus/`) | Tampering | `session_id` comes ONLY from the verified HMAC payload (server UUID), never raw input; `Path.join(tus_root, uuid <> ".part")`; defensive `within_root?` (`local_plug.ex:232-235`). Test: tampered token → 404 before path build. |
| **Slow-loris PATCH** (stream forever, pin memory/disk) | DoS | `read_body` `read_length: 1_048_576` + per-PATCH ceiling from `max_size`; `read_timeout` bounds socket stalls; 413 on exceed (D-07). Never buffer whole body. |
| **Offset-mismatch race** (concurrent PATCH at stale offset) | Tampering | Strict `Upload-Offset == last_known_offset` gate → `409` without body read; client re-HEADs and retries (tus-js-client contract). 1:1 session↔tmp file. |
| **Metadata injection** (`Upload-Metadata` filename/type abuse, header smuggling) | Tampering | `Upload-Metadata` treated opaque + truncated + NOT auto-rendered; re-sniff at `verify_completion` (invariants 1, 10). Never trust for path/MIME. |
| **Bearer-URL leakage** (tus URL in logs/telemetry/inspect) | Information Disclosure | Stored only in `session_uri` (redacted `Inspect`, `media_upload_session.ex:104-113`); forbidden in telemetry metadata; never `Logger`. Test: assert redaction in inspect. |
| **Unauthenticated mount** (adopter forwards under no auth → storage-cost DoS) | DoS | Documented red-flag (Phase 44 guide); Phase 42: identity captured from adopter conn assigns/`identity_fn`. Out-of-scope to enforce mount auth, but note in PLAN. |
| **Cross-FS rename non-atomic** (partial file becomes "final") | Tampering / Integrity | Tmp + storage root on same filesystem; `File.rename` atomic; `:exdev` = misconfig, not silent fallback (Pitfall 5). |

## POLISH-01 Guidance (D-13 selective triage)

> Source verified: `.planning/milestones/v1.6-phases/34-mux-rest-adapter-server-push-sync/34-REVIEW.md`. The 4 Blockers (BL-01..04) are ALREADY FIXED (commits in review front-matter: `1f29ec3`, `abd07f5`, `791e4c4`, `b18fc10`). POLISH-01 covers ONLY the 12 advisories (9 Warning + 3 Info). **This diff is tus-unrelated — it touches Mux files only. Keep it isolated from tus code paths.**

### FIX (8 — real correctness / observability / invariant-14-adjacent / test hygiene)

| ID | File | Issue (one-line) | Fix shape |
|----|------|------------------|-----------|
| WR-01 | `mux/http.ex:49-52` | `Keyword.fetch!` on missing config raises `KeyError` mid-request → Oban burns retries | `fetch_required/2` returning `{:error, {:missing_config, key}}`; propagate from each callback + signing config. |
| WR-02 | `mux.ex:298-304` | `fetch_sig_header/1` only handles 2 header casings (case-insensitive RFC 7230) | Downcase the whole header map once, then `Map.fetch("mux-signature")`. + mixed-case test. |
| WR-04 | `mux_sync_provider_asset.ex:155-187` | FSM rejection in `apply_state_transition/4` → noisy retries (same failure each attempt) | Catch `{:error, {:invalid_transition, _, _}}` → `:cancel` or `reconcile_to_errored`. |
| WR-05 | `mux.ex:307-311` / `event.ex:38-42` | `normalize_state/1` passes unknown statuses through → FSM rejects → retries burn | Allowlist `~w(preparing ready errored)`; unknown → `Logger.warning` + `nil`; downstream treats nil as "ignore". |
| WR-06 | `mux_sync_provider_asset.ex:148-150` | Adapter failure doesn't write `last_sync_error` → no operator breadcrumb | Persist `last_sync_error` (inspect-truncate to 4096) before returning `{:error, _}`. |
| WR-08 | `mux_sync_coordinator.ex:95-104` | Coordinator silently swallows individual `Oban.insert` failures | Distinguish `{:ok}` fresh / `{:ok, conflict?: true}` dedup / `{:error}` failed; log errors. |
| WR-09 | `mux_ingest_variant.ex:163-175` | `:exception` telemetry may carry unredacted error reasons (invariant-14-adjacent) | `safe_reason/1` — atoms pass; everything else `inspect |> String.slice(0,200)`. |
| IN-02 | `mux_sync_coordinator_test.exs:55-57,89-91,108-110` | Test setup replaces app env instead of `Keyword.merge` | Use `Keyword.merge(prev, ...)` consistently (test hygiene). |

### WAIVE (3 — defensive-only / deliberate deferral; one-line rationale each)

| ID | File | Why waive |
|----|------|-----------|
| WR-07 | `mux_sync_coordinator.ex:85-94` | **Explicitly documented v1.7 deferral** ("Phase 34 ships unbounded scan; add LIMIT in v1.7 if adopter feedback shows >1k stuck rows"). Blindly fixing reverts a deliberate roadmap decision. Rationale: documented deferral, no adopter pain signal. |
| IN-01 | `mux/event.ex:54-63` | Defensive-only: Unix-string `created_at` parsing — **no live caller feeds Mux REST `created_at` into Event normalization** (webhooks use ISO8601). Rationale: no live caller; asymmetry only. |
| IN-03 | `mux.ex:266` | Defensive-only: `playback_id` URL interpolation — Mux playback IDs are documented URL-safe alphanumerics; no malicious-input path. Rationale: documented input contract; belt-and-suspenders only. |

### FIX-OR-DOCUMENT (1 — planner's call, D-13 discretion)

| ID | File | The choice |
|----|------|-----------|
| WR-03 | `mux_sync_provider_asset.ex:155-163,193-205` | `:resolved` no-op emits stale `age_ms` (two events, same metric, two semantics). EITHER (a) document the telemetry-contract semantics in the moduledoc, OR (b) emit `no_change: true` + `last_synced_at_ms` separately. Both are valid; (a) is the smaller diff. Planner picks. |

**POLISH-01 scope fence:** ≈8 fixes + 3 documented waivers + 1 either-way. All in `lib/rindle/streaming/provider/mux*` and `lib/rindle/workers/mux_*` + their tests. **Zero overlap with tus files.** Locality note (surfaced, not actionable): the "natural locality with MUX-20..23" rationale is weak — that Mux work is Phase 45, not 42 — so these fixes stand alone here. Roadmap-locked.

## Sources

### Primary (HIGH confidence — verified live in-repo this pass, 2026-05-22)
- `.planning/research/v1.8/TUS-RESEARCH.md` — AUTHORITATIVE LOCKED architecture (§3a, §3c, §4, §5, §6, §7, §9, §10, §11, §12, §13).
- `.planning/phases/42-tus-protocol-edge-bare-plug/42-CONTEXT.md` — 13 LOCKED decisions D-01..D-13.
- `.planning/REQUIREMENTS.md` — TUS-01..05, POLISH-01 (lines 34-55, 142-145, 176-206); D-02 reconciliation of TUS-02 wording.
- `lib/rindle/delivery/webhook_plug.ex:86-111` — bare-Plug `init/1` raise + method dispatch.
- `lib/rindle/delivery/local_plug.ex:63-80,122,232-235` — `Plug.Crypto.verify` + manual exp + `actor_subject` payload + `within_root?` traversal guard.
- `lib/rindle/upload/broker.ex:182-225,418-485,566-596,619-640` — resumable initiation, `verify_completion/2` (Oban-in-Multi at :465), `persist_resumable_session/5`, compensation.
- `lib/rindle/storage.ex:17-24,282-285` — capability type union + `@optional_callbacks`.
- `lib/rindle/storage/capabilities.ex:20-28,49-57` — `@known` + `require_upload/2` (returns tuple).
- `lib/rindle/storage/local.ex:72-83,106-109` — `head/2` (no content_type), `capabilities/0`, `path_for/2`.
- `lib/rindle/domain/media_upload_session.ex:48-60,78-92,104-113` — schema, changeset cast, redacting `Inspect`.
- `lib/rindle/domain/upload_session_fsm.ex:6-17` — `"resuming"` lane + completion transitions.
- `lib/rindle/ops/upload_maintenance.ex:139-148,452-536` — reaper query + resumable cancel branch (the §6 landmine).
- `priv/repo/migrations/20260507160000_extend_media_upload_sessions_for_resumable.exs` — migration template.
- `deps/plug/lib/plug/conn.ex:1140-1194` — `read_body/2` `{:more,...}`/`{:ok,...}` chunking + `:length`/`:read_length`/`:read_timeout`.
- `mix.exs:50-111` — deps (`plug ~> 1.16`, NO phoenix), `test/adopter` + `test/install_smoke` paths.
- `test/rindle/delivery/local_plug_test.exs`, `test/rindle/delivery/webhook_plug_test.exs` — `Plug.Test` + `Rindle.DataCase` + `Oban.Testing` + test-profile idioms.
- `.planning/milestones/v1.6-phases/34-mux-rest-adapter-server-push-sync/34-REVIEW.md` — POLISH-01 findings (BL-01..04 fixed; WR-01..09, IN-01..03).

### Secondary (MEDIUM-HIGH — official protocol spec, verified this session)
- https://tus.io/protocols/resumable-upload (1.0.0) — exact headers (`Tus-Resumable: 1.0.0`), status codes (POST 201, HEAD 200/204, PATCH 204/409/415, DELETE 204, OPTIONS 204, 410 expired, 413 over-size), `application/offset+octet-stream`, `Upload-Metadata` base64 format, `Tus-Resumable` in every non-OPTIONS req/resp, `X-HTTP-Method-Override` MUST be honored.

### Tertiary (context only — superseded for this phase)
- `.planning/research/v1.8/STRATEGY-SEQUENCING.md` — older synthesis (references `tussle`, different phase numbering); SUPERSEDED by TUS-RESEARCH §12 for Phase 42 shape.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new deps; all primitives verified present in `deps/`/`lib/`.
- Architecture: HIGH — LOCKED by TUS-RESEARCH.md; every seam anchored to verified line numbers.
- Protocol contract: HIGH — verified against tus.io 1.0.0 spec this session.
- Pitfalls: HIGH — derived from verified code behavior (Local `head` no content_type; FSM transition allowlist; `read_body` semantics) + spec.
- Validation strategy: MEDIUM-HIGH — Elixir contract-test approach is sound and in-repo-achievable; the live tus-js-client proof is correctly deferred to Phase 44 (Open Question 3 flags the objective-wording reconciliation).
- POLISH-01: HIGH — full `34-REVIEW.md` read; D-13 triage confirmed line-by-line.

**Research date:** 2026-05-22
**Valid until:** ~2026-06-21 (stable: in-repo seams + a frozen 2016 protocol; the only fast-moving item — IETF RUFH — is explicitly deferred).
