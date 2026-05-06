# Phase 26: Delivery Surface - Research

**Researched:** 2026-05-05 [VERIFIED: system date]
**Domain:** Delivery URL resolution, local range delivery, filename/header safety, and delivery telemetry for AV playback [VERIFIED: .planning/ROADMAP.md; .planning/REQUIREMENTS.md]
**Confidence:** HIGH [VERIFIED: repo grep] [CITED: https://hexdocs.pm/plug/Plug.Conn.html] [CITED: https://www.rfc-editor.org/rfc/rfc7233] [CITED: https://www.rfc-editor.org/rfc/rfc6266]

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Add `Rindle.Delivery.streaming_url/3` as a separate additive public
  function. Do not overload `url/3` with streaming flags or alternate return
  shapes.
- **D-02:** In v1.4, `streaming_url/3` delegates to `url/3` and returns
  `{:ok, %{url: url, kind: :progressive, mime: mime}}`.
- **D-03:** Keep `url/3` as the stable plain delivery primitive returning
  `{:ok, binary}`. Existing image/private/public delivery call sites must not
  churn.
- **D-04:** Do not introduce a provider/protocol abstraction in Phase 26 beyond
  reserving the streaming surface. Real provider behaviour can land once an
  actual non-progressive adapter exists and can prove the abstraction.
- **D-05:** `streaming_url/3` must share the same authorization, TTL, and error
  behaviour as `url/3` so the only public difference is the return shape.
- **D-06:** For v1.4, callers may pass `:mime` explicitly; otherwise the
  default progressive fallback may be `"video/mp4"`. Phase 27 helpers should
  pass the mime they already know from the variant/profile context rather than
  relying on guesswork inside delivery.
- **D-07:** Ship a narrow core `Rindle.Delivery.LocalPlug` in the main library.
  Do not extend `Rindle.Storage.Local.url/2` into an HTTP-routing abstraction,
  and do not split the plug into a separate package.
- **D-08:** `LocalPlug` is dev-parity-only by default and must say so loudly in
  `@moduledoc`. Production signed redirect remains the normative posture.
- **D-09:** `LocalPlug` verifies a signed token over `key + expiry +
  actor_subject`, resolves a path under the configured local root, and serves
  the file with `Plug.Conn.send_file/5`.
- **D-10:** Support single-range `Range:` requests only. Multi-range and
  unparseable `Range` headers fall back to `200 + full body` per the locked
  Phase 26 requirements.
- **D-11:** `LocalPlug` must fail fast at init/boot if mounted against any
  adapter other than `Rindle.Storage.Local`.
- **D-12:** Path handling in `LocalPlug` must validate the resolved path stays
  under the configured local root; no path-traversal-by-key allowance.
- **D-13:** Delivery-time download behaviour is explicit, not inferred from
  container metadata. Public API should accept caller intent (`filename`,
  `disposition` or equivalent delivery opts), and the library sanitizes and
  encodes it.
- **D-14:** Container metadata and tags are never a trusted source for
  download filenames. This follows the v1.4 security invariant that container
  metadata is untrusted UGC end-to-end.
- **D-15:** When Rindle emits `Content-Disposition`, it uses RFC 5987 /
  `filename*=` encoding with a sanitized basename.
- **D-16:** If a caller requests attachment-style delivery but omits a
  filename, a narrow internal fallback may derive one from trusted app-provided
  context or sanitized storage/upload naming. Raw storage keys must never be the
  preferred public-facing naming strategy.
- **D-17:** The same filename/disposition policy should work across both
  `LocalPlug` responses and signed-redirect adapter flows so adopters do not
  learn two delivery models.
- **D-18:** Keep the existing single profile-level
  `signed_url_ttl_seconds` policy surface in code for v1.4. Do not add
  per-content TTL config to the profile DSL in this phase.
- **D-19:** Document per-content TTL guidance only:
  image `900s`, audio `3600s`, video VOD `7200s`, and long-form playback should
  use a refresh strategy at the adopter layer.
- **D-20:** The library should continue to steer adopters toward separate
  profiles when materially different delivery policies are needed, rather than
  widening the delivery DSL prematurely.
- **D-21:** Preserve existing `[:rindle, :delivery, :signed]` telemetry and add
  `[:rindle, :delivery, :streaming, :resolved]` for the new streaming API seam.
- **D-22:** Keep `[:rindle, :delivery, :range_request]` because the locked
  Phase 26 requirements require it, but scope it narrowly to
  `Rindle.Delivery.LocalPlug`. Treat it as a local/dev-parity signal, not the
  primary production delivery KPI.
- **D-23:** Reinforce the standing project preference from `.planning/STATE.md`:
  downstream agents should front-load research, make coherent defaults, and
  escalate only for very high-impact decisions (public semver reshapes,
  destructive data/ops, security/compliance, or similarly irreversible moves).

### Claude's Discretion
- Exact option names/arity for `streaming_url/3` and delivery-time filename
  opts, so long as the public semantics above remain intact
- Whether to keep existing request-time `expires_in` override behaviour as an
  undocumented escape hatch vs document it narrowly
- Precise `LocalPlug` route shape, token serializer details, and helper wiring
  in Phase 27

### Deferred Ideas (OUT OF SCOPE)
- Real `Rindle.Streaming.Provider` abstraction once a non-progressive provider
  adapter exists and can prove the right boundary
- Per-content-type TTL configuration in the profile DSL
- Rich delivery metadata object beyond `%{url, kind, mime}`
- Any production proxy-streaming posture for remote adapters

None of the above belong in Phase 26.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AV-04-01 | `streaming_url/3` returns `{:ok, %{url, kind: :progressive, mime}}` as a no-op delegate today [VERIFIED: .planning/REQUIREMENTS.md] | `Rindle.Delivery.streaming_url/3` should wrap `url/3`, reuse auth/TTL/error flow, and emit a dedicated telemetry event [VERIFIED: lib/rindle/delivery.ex] |
| AV-04-02 | Reserve `Rindle.Streaming.Provider` behaviour without v1.4 implementation [VERIFIED: .planning/REQUIREMENTS.md] | Use a callback-only module with no config lookup, no adapter registry, and no runtime branching in `Rindle.Delivery` [VERIFIED: .planning/phases/26-delivery-surface/26-CONTEXT.md] |
| AV-04-03 | Add `Rindle.Delivery.LocalPlug` with signed token verification and single-range `send_file/5` delivery [VERIFIED: .planning/REQUIREMENTS.md] | Build a new Plug around `Rindle.Storage.Local.head/2`, a public local-root/path seam, and RFC 7233 single-range handling [VERIFIED: lib/rindle/storage/local.ex] [CITED: https://hexdocs.pm/plug/Plug.Conn.html] [CITED: https://www.rfc-editor.org/rfc/rfc7233] |
| AV-04-04 | Refuse to mount `LocalPlug` unless storage adapter is `Rindle.Storage.Local` [VERIFIED: .planning/REQUIREMENTS.md] | Require `profile:` or equivalent init opts and validate `profile.storage_adapter() == Rindle.Storage.Local` inside `init/1` [VERIFIED: lib/rindle/profile.ex] |
| AV-04-05 | Mark `LocalPlug` dev-parity-only in moduledoc [VERIFIED: .planning/REQUIREMENTS.md] | Put the warning in `@moduledoc` and avoid any production proxy guidance beyond caveats [VERIFIED: .planning/phases/26-delivery-surface/26-CONTEXT.md] |
| AV-04-06 | Add `:streaming :resolved` and `:range_request` telemetry contracts [VERIFIED: .planning/REQUIREMENTS.md] | Extend the existing delivery telemetry pattern and cover it with the contract lane under `test/rindle/contracts/telemetry_contract_test.exs` [VERIFIED: lib/rindle/delivery.ex] [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] |
| AV-04-07 | Document per-content TTL guidance without widening the DSL [VERIFIED: .planning/REQUIREMENTS.md] | Keep `signed_url_ttl_seconds` at profile/global scope and place guidance in docs plus moduledocs, not in `Rindle.Profile.Validator` [VERIFIED: lib/rindle/delivery.ex] [VERIFIED: lib/rindle/profile/validator.ex] |
| AV-04-08 | Emit RFC 5987 / `filename*=` attachment filenames, never raw container metadata [VERIFIED: .planning/REQUIREMENTS.md] | Reuse `Rindle.Security.Filename.sanitize/1`, add a delivery header builder, and keep filenames opt-in via delivery opts [VERIFIED: lib/rindle/security/filename.ex] [CITED: https://www.rfc-editor.org/rfc/rfc6266] |
</phase_requirements>

## Summary

Phase 26 should stay centered in `Rindle.Delivery` and remain additive. The current module already owns private/public mode selection, authorization, profile-level TTL injection, and `[:rindle, :delivery, :signed]` telemetry, so the lowest-risk implementation is to build `streaming_url/3` on top of `url/3` instead of introducing a second delivery pipeline. [VERIFIED: lib/rindle/delivery.ex]

The only new transport surface that needs real byte delivery logic is local-development playback. `Rindle.Storage.Local` already exposes `head/2` and computes a root-backed filesystem path internally, but it currently returns `file://` URLs and keeps path/root resolution private, so `LocalPlug` needs one small supporting seam in the local adapter: a public root/path resolver that stays local-adapter-specific rather than becoming a storage-behaviour concern. [VERIFIED: lib/rindle/storage/local.ex] [VERIFIED: lib/rindle/storage.ex]

The standards-sensitive pieces are narrow. `Plug.Conn.send_file/5` is the right primitive because Plug documents offset/length support and OS `sendfile` use when available, RFC 7233 explicitly allows servers to ignore problematic `Range` headers, and RFC 6266 shows `filename*=` with RFC 5987 encoding for non-ASCII filenames while warning that filenames are advisory and path segments must not be trusted. [CITED: https://hexdocs.pm/plug/Plug.Conn.html] [CITED: https://www.rfc-editor.org/rfc/rfc7233] [CITED: https://www.rfc-editor.org/rfc/rfc6266]

**Primary recommendation:** Implement Phase 26 as three additive seams only: `Rindle.Delivery.streaming_url/3`, `Rindle.Delivery.LocalPlug`, and a delivery-header utility for disposition/filename, while keeping TTL policy and adapter dispatch exactly where they are today. [VERIFIED: lib/rindle/delivery.ex] [VERIFIED: lib/rindle/profile/validator.ex]

## Project Constraints (from CLAUDE.md)

No project-root `CLAUDE.md` exists in `/Users/jon/projects/rindle`, so there are no additional repo-local directives beyond the planning artifacts and required phase context. [VERIFIED: repo grep]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Delivery URL resolution (`url/3`, `streaming_url/3`) | API / Backend | CDN / Static | The library issues signed or public URLs and leaves byte serving to the storage backend or CDN. [VERIFIED: lib/rindle/delivery.ex] |
| Local dev playback bytes (`LocalPlug`) | Frontend Server (SSR) | Database / Storage | The Plug terminates HTTP locally, but the bytes originate from the filesystem owned by `Rindle.Storage.Local`. [VERIFIED: lib/rindle/storage/local.ex] |
| Range parsing and `206` responses | Frontend Server (SSR) | Database / Storage | Range handling is HTTP response logic around a local file, not storage-behaviour negotiation. [CITED: https://www.rfc-editor.org/rfc/rfc7233] [CITED: https://hexdocs.pm/plug/Plug.Conn.html] |
| Download filename/disposition policy | API / Backend | Frontend Server (SSR) | The backend owns sanitization and signed-redirect/header generation so helpers and plugs share one policy. [VERIFIED: lib/rindle/security/filename.ex] [VERIFIED: .planning/phases/26-delivery-surface/26-CONTEXT.md] |
| TTL guidance | Docs / API contract | — | The code path stays profile/global, but the adopter guidance belongs in docs and moduledocs rather than new runtime config. [VERIFIED: lib/rindle/delivery.ex] [VERIFIED: lib/rindle/profile/validator.ex] |
| Delivery telemetry | API / Backend | Frontend Server (SSR) | `streaming_url/3` telemetry belongs in `Rindle.Delivery`; range telemetry belongs in `LocalPlug`. [VERIFIED: lib/rindle/delivery.ex] [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] |

## Standard Stack

### Core

| Library / Module | Version | Purpose | Why Standard |
|------------------|---------|---------|--------------|
| `Rindle.Delivery` | repo-local | Central delivery auth, TTL, mode, and telemetry seam. [VERIFIED: lib/rindle/delivery.ex] | Extending the existing seam preserves the current API contract and avoids parallel delivery logic. [VERIFIED: test/rindle/delivery_test.exs] |
| `Plug.Conn.send_file/5` | `plug 1.19.1` [VERIFIED: mix.lock] | Local file responses with offset/length support. [CITED: https://hexdocs.pm/plug/Plug.Conn.html] | Plug documents direct `sendfile` use when available, which is the right primitive for local range playback. [CITED: https://hexdocs.pm/plug/Plug.Conn.html] |
| `Plug.Crypto` / `Plug.Crypto.MessageVerifier` | `plug_crypto 2.1.1` transitive [VERIFIED: mix.lock] | Signed local-playback token verification without adding Phoenix-only dependencies. [VERIFIED: deps/plug_crypto/lib/plug/crypto/message_verifier.ex] | The repo already ships Plug and plug_crypto transitively, so this keeps the token seam inside the existing stack. [VERIFIED: mix.lock] |
| `Rindle.Security.Filename` | repo-local | Sanitized basename generation for delivery filenames. [VERIFIED: lib/rindle/security/filename.ex] | The sanitizer already strips control chars and path separators, which matches RFC 6266’s advisory-filename posture. [VERIFIED: lib/rindle/security/filename.ex] [CITED: https://www.rfc-editor.org/rfc/rfc6266] |
| `:telemetry` | `1.4.1` [VERIFIED: mix.lock] | Public contract for delivery events. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] | The repo already treats telemetry names and metadata as locked public API. [VERIFIED: .planning/PROJECT.md] |

### Supporting

| Library / Module | Version | Purpose | When to Use |
|------------------|---------|---------|-------------|
| `Rindle.Storage.Local` | repo-local | Local adapter root/path and file-size lookups. [VERIFIED: lib/rindle/storage/local.ex] | Use only as the storage seam behind `LocalPlug`; do not turn it into a routing abstraction. [VERIFIED: .planning/phases/26-delivery-surface/26-CONTEXT.md] |
| `Rindle.Storage.Capabilities` | repo-local | Existing capability-style error tagging. [VERIFIED: lib/rindle/storage/capabilities.ex] | Reuse the tagged-error style for mount validation and unsupported delivery paths; do not add a new generic capability layer for streaming in Phase 26. [VERIFIED: lib/rindle/storage/capabilities.ex] |
| `Rindle.HTML` / `Rindle.LiveView` | repo-local | Thin Phoenix-facing consumers of delivery APIs. [VERIFIED: lib/rindle/html.ex] [VERIFIED: lib/rindle/live_view.ex] | Keep them unchanged in Phase 26 and let Phase 27 adopt `streaming_url/3`. [VERIFIED: .planning/ROADMAP.md] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `send_file/5` local serving | `send_chunked/2` or proxy streaming | Avoid this; current Rindle scope wants local dev parity, not a BEAM byte proxy, and `send_file/5` has the exact offset/length seam already documented by Plug. [CITED: https://hexdocs.pm/plug/Plug.Conn.html] |
| Minimal reserved behaviour | Full provider registry/config lookup in v1.4 | Avoid this; the phase context explicitly forbids premature abstraction beyond reserving the surface. [VERIFIED: .planning/phases/26-delivery-surface/26-CONTEXT.md] |
| Profile-level TTL docs | New per-kind TTL DSL options | Avoid this; current validator only knows one delivery TTL surface and locked decisions keep it that way for v1.4. [VERIFIED: lib/rindle/profile/validator.ex] [VERIFIED: .planning/phases/26-delivery-surface/26-CONTEXT.md] |

**Version verification:** `plug 1.19.1`, `plug_cowboy 2.8.0`, `phoenix_live_view 1.1.28`, `telemetry 1.4.1`, and `oban 2.21.1` are verified from `mix.lock`, which is the authoritative dependency snapshot for this repo. [VERIFIED: mix.lock]

## Code Seams

| Seam | Current State | Required Phase 26 Change |
|------|---------------|--------------------------|
| `lib/rindle/delivery.ex` | Owns `url/3`, `variant_url/4`, auth, TTL injection, and `[:rindle, :delivery, :signed]`. [VERIFIED: lib/rindle/delivery.ex] | Add `streaming_url/3`, shared disposition/filename option handling, and `[:rindle, :delivery, :streaming, :resolved]` emission here. [VERIFIED: .planning/REQUIREMENTS.md] |
| `lib/rindle/storage/local.ex` | Has `head/2` and private `storage_path/2` / `local_root/1`. [VERIFIED: lib/rindle/storage/local.ex] | Expose a narrow public resolver such as `root/1` plus `path_for/2` so `LocalPlug` can validate root containment without duplicating adapter config logic. [VERIFIED: lib/rindle/storage/local.ex] |
| `lib/rindle/security/filename.ex` | Already sanitizes basename/path/control characters. [VERIFIED: lib/rindle/security/filename.ex] | Reuse it for attachment filenames and add a percent-encoding helper for `filename*=` generation instead of inventing a second sanitizer. [VERIFIED: lib/rindle/security/filename.ex] [CITED: https://www.rfc-editor.org/rfc/rfc6266] |
| `lib/rindle/profile.ex` + `lib/rindle/profile/validator.ex` | Delivery policy exposes `public`, `signed_url_ttl_seconds`, and `authorizer` only. [VERIFIED: lib/rindle/profile.ex] [VERIFIED: lib/rindle/profile/validator.ex] | Leave DSL untouched; Phase 26 guidance belongs in docs and moduledocs, not new validator keys. [VERIFIED: .planning/phases/26-delivery-surface/26-CONTEXT.md] |
| `lib/rindle/html.ex` | Helpers are intentionally thin and call `Rindle.Delivery.variant_url/4`. [VERIFIED: lib/rindle/html.ex] | Do not change now; Phase 27 should switch AV helpers to `streaming_url/3` while image helpers remain on existing URLs. [VERIFIED: .planning/ROADMAP.md] |

## Test Seams

| Test File | Existing Contract | Phase 26 Addition |
|-----------|-------------------|-------------------|
| `test/rindle/delivery_test.exs` | Locks private/public delivery behavior and `[:rindle, :delivery, :signed]` emission. [VERIFIED: test/rindle/delivery_test.exs] | Add coverage for `streaming_url/3` return shape, shared auth/TTL behavior, `:mime` default/override, and disposition option normalization. [VERIFIED: .planning/REQUIREMENTS.md] |
| `test/rindle/html_test.exs` | Proves helpers stay thin and preserve explicit variant ordering. [VERIFIED: test/rindle/html_test.exs] | No direct Phase 26 change needed beyond ensuring existing image helper behavior does not churn. [VERIFIED: .planning/phases/26-delivery-surface/26-CONTEXT.md] |
| `test/rindle/contracts/telemetry_contract_test.exs` | Locks the public telemetry allowlist and metadata shape. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] | Extend the allowlist and add exact-shape assertions for `[:rindle, :delivery, :streaming, :resolved]` and `[:rindle, :delivery, :range_request]`. [VERIFIED: .planning/REQUIREMENTS.md] |
| New `test/rindle/delivery/local_plug_test.exs` | Missing today. [VERIFIED: repo grep] | Add request-level tests for single-range `206`, suffix/open-ended ranges, multi-range fallback to `200`, invalid token, missing file, and root-containment rejection. [VERIFIED: .planning/REQUIREMENTS.md] [CITED: https://www.rfc-editor.org/rfc/rfc7233] |

## Architecture Patterns

### System Architecture Diagram

```text
Caller / Helper
  |
  | streaming_url/3 or url/3
  v
Rindle.Delivery
  |
  | authorize -> choose mode -> inject TTL/disposition -> emit telemetry
  v
+-------------------------------+
| private/public URL backends   |
| storage adapter url/2         |
+-------------------------------+
  |
  +--> signed redirect / direct URL returned to browser
  |
  +--> local dev path only:
         Rindle.Delivery.LocalPlug
           -> verify signed token
           -> resolve local path under root
           -> parse Range header
           -> send_file(206/200, offset, length)
           -> emit range telemetry
```

### Recommended Project Structure

```text
lib/rindle/
├── delivery.ex              # Existing delivery policy and URL API
├── delivery/
│   ├── local_plug.ex        # New dev-parity HTTP endpoint
│   ├── content_disposition.ex # Optional small utility for header building
│   └── streaming/provider.ex  # Reserved behaviour only, no runtime dispatch
└── storage/local.ex         # Narrow public root/path seam for LocalPlug
```

### Pattern 1: `streaming_url/3` as a thin wrapper over `url/3`

**What:** Keep authorization, capability gates, TTL injection, and error tuples in `url/3`; add only a response wrapper plus new telemetry. [VERIFIED: lib/rindle/delivery.ex]

**When to use:** For all AV helper call sites that need a future-stable playback surface but do not yet differentiate progressive vs manifest URLs. [VERIFIED: .planning/ROADMAP.md]

**Prescriptive shape:** Return `{:ok, %{url: url, kind: :progressive, mime: mime}}`, default `mime` to `Keyword.get(opts, :mime, "video/mp4")`, and accept the same `:actor` / `:expires_in` escape-hatch options that `url/3` already forwards today. [VERIFIED: lib/rindle/delivery.ex] [VERIFIED: .planning/phases/26-delivery-surface/26-CONTEXT.md]

### Pattern 2: Reserve `Rindle.Streaming.Provider` as a callback-only namespace

**What:** Create a minimal behaviour module with `@callback streaming_url(profile, key, opts) :: {:ok, %{url: String.t(), kind: atom(), mime: String.t()}} | {:error, term()}` and `@callback capabilities() :: [atom()]`, plus moduledoc stating it is reserved for post-v1.4 providers. [VERIFIED: .planning/REQUIREMENTS.md]

**When to use:** Only to reserve the public namespace required by AV-04-02. [VERIFIED: .planning/REQUIREMENTS.md]

**Do not do:** Do not add profile config keys, adapter lookup, registry resolution, or any `Rindle.Delivery` branching on this behaviour in Phase 26. That would contradict D-04’s no-premature-abstraction rule. [VERIFIED: .planning/phases/26-delivery-surface/26-CONTEXT.md]

### Pattern 3: Mount-time validation in `LocalPlug.init/1`

**What:** Require `profile:` in plug opts and perform validation during `init/1`, not request time. [VERIFIED: lib/rindle/profile.ex] [VERIFIED: .planning/REQUIREMENTS.md]

**When to use:** Always; this is the only way to satisfy AV-04-04’s boot-time failure requirement in a standard Plug mount. [VERIFIED: .planning/REQUIREMENTS.md]

**Validation checklist:** Confirm the profile module exports `storage_adapter/0`, confirm it equals `Rindle.Storage.Local`, resolve the effective local root once, and fail with `ArgumentError` if any condition is false. [VERIFIED: lib/rindle/profile.ex] [VERIFIED: lib/rindle/storage/local.ex]

### Pattern 4: `send_file/5` for single-range only

**What:** Parse only one byte range and convert it to `offset` and `length` for `send_file/5`. [CITED: https://hexdocs.pm/plug/Plug.Conn.html] [CITED: https://www.rfc-editor.org/rfc/rfc7233]

**When to use:** Local adapter playback requests carrying `Range: bytes=N-M`, `bytes=N-`, or `bytes=-M`. [CITED: https://www.rfc-editor.org/rfc/rfc7233]

**Policy:** For multi-range or unparseable headers, intentionally ignore the range and return `200` with the full body. RFC 7233 says a server may ignore a `Range` header and may ignore or reject problematic multi-range sets. [CITED: https://www.rfc-editor.org/rfc/rfc7233]

### Pattern 5: Shared disposition builder

**What:** Normalize explicit delivery opts such as `disposition: :attachment | :inline` and `filename: binary`, sanitize the basename with `Rindle.Security.Filename`, then emit `filename*=` percent-encoded UTF-8. [VERIFIED: lib/rindle/security/filename.ex] [CITED: https://www.rfc-editor.org/rfc/rfc6266]

**When to use:** Both when `LocalPlug` sets response headers and when signed-redirect adapters need response-content-disposition query params or equivalent adapter options. [VERIFIED: .planning/phases/26-delivery-surface/26-CONTEXT.md]

### Anti-Patterns to Avoid

- **Do not overload `url/3` with map returns or streaming flags.** The current return contract is already covered by tests and locked decisions. [VERIFIED: lib/rindle/delivery.ex] [VERIFIED: test/rindle/delivery_test.exs]
- **Do not proxy remote S3/R2/GCS playback through BEAM.** Phase 26 scope is dev-parity-only local serving. [VERIFIED: .planning/ROADMAP.md]
- **Do not derive download names from container metadata or raw storage keys.** Container metadata is explicitly untrusted UGC in the project security invariants. [VERIFIED: .planning/PROJECT.md]
- **Do not duplicate local-root path logic in the plug.** Put one narrow public helper on `Rindle.Storage.Local` instead. [VERIFIED: lib/rindle/storage/local.ex]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Local byte serving | Custom chunk loop over file IO | `Plug.Conn.send_file/5` [CITED: https://hexdocs.pm/plug/Plug.Conn.html] | Plug already supports offset/length and OS `sendfile` when available. [CITED: https://hexdocs.pm/plug/Plug.Conn.html] |
| Token signing | Ad hoc HMAC serializer | `Plug.Crypto` / `MessageVerifier` [VERIFIED: deps/plug_crypto/lib/plug/crypto/message_verifier.ex] | The dependency is already present and gives a reviewed signed-token primitive. [VERIFIED: mix.lock] |
| Filename sanitation | New regex stack | `Rindle.Security.Filename.sanitize/1` [VERIFIED: lib/rindle/security/filename.ex] | The repo already has the exact basename/control-character cleanup needed for delivery-time filenames. [VERIFIED: test/rindle/security/utilities_test.exs] |
| Generic streaming provider framework | Registry, behaviour dispatch, config DSL | Callback-only reserved module [VERIFIED: .planning/REQUIREMENTS.md] | v1.4 has no non-progressive provider to validate the abstraction, and D-04 forbids premature abstraction. [VERIFIED: .planning/phases/26-delivery-surface/26-CONTEXT.md] |

**Key insight:** The hard parts in this phase are policy reuse and contract stability, not inventing new transport infrastructure. The repo already has the right central seam in `Rindle.Delivery`; Phase 26 should add small adapters around it. [VERIFIED: lib/rindle/delivery.ex]

## Common Pitfalls

### Pitfall 1: `LocalPlug` duplicates `Rindle.Storage.Local` root logic

**What goes wrong:** The plug and adapter drift on root resolution, so request-time path checks no longer match where uploads are stored. [VERIFIED: lib/rindle/storage/local.ex]

**Why it happens:** `storage_path/2` and `local_root/1` are private today, so the easiest implementation path is copy-paste. [VERIFIED: lib/rindle/storage/local.ex]

**How to avoid:** Publish one narrow helper on `Rindle.Storage.Local` and treat it as `LocalPlug`’s only path-entry seam. [VERIFIED: lib/rindle/storage/local.ex]

**Warning signs:** Tests pass only when the plug uses hard-coded `root:` opts or bypasses profile config entirely. [VERIFIED: repo grep]

### Pitfall 2: Mount validation happens on first request instead of at boot

**What goes wrong:** Adopters mount the plug against S3 and only see failure when a video element loads. [VERIFIED: .planning/REQUIREMENTS.md]

**Why it happens:** Plug authors often leave validation in `call/2` because request conn data is available there. [ASSUMED]

**How to avoid:** Require `profile:` in init opts and raise from `init/1` when `profile.storage_adapter/0` is not `Rindle.Storage.Local`. [VERIFIED: lib/rindle/profile.ex] [VERIFIED: .planning/REQUIREMENTS.md]

**Warning signs:** `LocalPlug` accepts opts without a profile module or pattern-matches the adapter inside `call/2`. [VERIFIED: repo grep]

### Pitfall 3: Multi-range requests accidentally emit broken `206` responses

**What goes wrong:** The plug sees a comma-separated `Range` header, parses only the first piece, and returns `206` with incorrect headers. [CITED: https://www.rfc-editor.org/rfc/rfc7233]

**Why it happens:** Multi-range `206` responses require multipart/byteranges semantics and per-part `Content-Range`. [CITED: https://www.rfc-editor.org/rfc/rfc7233]

**How to avoid:** Treat any comma in the range spec as unsupported and fall back to `200` full-body. [VERIFIED: .planning/phases/26-delivery-surface/26-CONTEXT.md] [CITED: https://www.rfc-editor.org/rfc/rfc7233]

**Warning signs:** Tests assert `206` for multi-range or produce a single `Content-Range` header for a multi-range request. [VERIFIED: repo grep]

### Pitfall 4: Disposition logic leaks untrusted metadata

**What goes wrong:** A future AV helper passes container title/artist/comment into the download filename path. [VERIFIED: .planning/PROJECT.md]

**Why it happens:** Delivery-time filenames are often treated as a presentation concern instead of a security boundary. [ASSUMED]

**How to avoid:** Accept explicit filename intent only, sanitize it, and use narrow trusted fallbacks when absent. [VERIFIED: .planning/phases/26-delivery-surface/26-CONTEXT.md] [VERIFIED: lib/rindle/security/filename.ex]

**Warning signs:** Code references `asset.metadata`, probe tags, or raw `storage_key` while building `Content-Disposition`. [VERIFIED: repo grep]

### Pitfall 5: TTL guidance turns into new config surface

**What goes wrong:** The phase adds `video_ttl_seconds`, `audio_ttl_seconds`, or per-variant delivery config to the DSL. [VERIFIED: .planning/phases/26-delivery-surface/26-CONTEXT.md]

**Why it happens:** The docs guidance is mistaken for a runtime policy requirement. [VERIFIED: .planning/REQUIREMENTS.md]

**How to avoid:** Keep `signed_url_ttl_seconds` as the only code-level setting and place the content-type matrix in guides/moduledocs. [VERIFIED: lib/rindle/profile/validator.ex] [VERIFIED: lib/rindle/delivery.ex]

**Warning signs:** Changes to `@delivery_schema` in `lib/rindle/profile/validator.ex` beyond existing keys. [VERIFIED: lib/rindle/profile/validator.ex]

## Code Examples

Verified patterns adapted to this repo:

### `streaming_url/3` wrapper pattern

```elixir
# Source: repo seam + locked Phase 26 decisions
@spec streaming_url(module(), String.t(), keyword()) ::
        {:ok, %{url: String.t(), kind: :progressive, mime: String.t()}} | {:error, term()}
def streaming_url(profile, key, opts \\ []) do
  mime = Keyword.get(opts, :mime, "video/mp4")

  with {:ok, url} <- url(profile, key, opts) do
    metadata = %{
      profile: profile,
      adapter: profile.storage_adapter(),
      mode: if(public_delivery?(profile), do: :public, else: :private),
      kind: :progressive,
      mime: mime
    }

    :telemetry.execute(
      [:rindle, :delivery, :streaming, :resolved],
      %{system_time: System.system_time()},
      metadata
    )

    {:ok, %{url: url, kind: :progressive, mime: mime}}
  end
end
```

### `LocalPlug` range dispatch pattern

```elixir
# Source: Plug.Conn.send_file/5 docs + RFC 7233 + current local adapter seam
defp serve_file(conn, path, size, [range_header]) do
  case parse_single_range(range_header, size) do
    {:ok, offset, length, content_range} ->
      conn
      |> Plug.Conn.put_resp_header("accept-ranges", "bytes")
      |> Plug.Conn.put_resp_header("content-range", content_range)
      |> Plug.Conn.put_resp_header("content-length", Integer.to_string(length))
      |> Plug.Conn.send_file(206, path, offset, length)

    :ignore ->
      conn
      |> Plug.Conn.put_resp_header("accept-ranges", "bytes")
      |> Plug.Conn.send_file(200, path)
  end
end
```

### RFC 5987 / `filename*=` header builder pattern

```elixir
# Source: RFC 6266 filename* examples + existing filename sanitizer
def build_content_disposition(disposition, filename) do
  safe_name = Rindle.Security.Filename.sanitize(filename)
  encoded = URI.encode_www_form(safe_name)
  "#{disposition}; filename*=UTF-8''#{encoded}"
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Plain asset URL helpers only | Reserve a distinct `streaming_url/3` seam even before manifest providers exist. [VERIFIED: .planning/REQUIREMENTS.md] | Locked for v1.4 on 2026-05-05. [VERIFIED: .planning/phases/26-delivery-surface/26-CONTEXT.md] | Future Mux/Cloudflare-style adapters can swap in without helper/template churn. [VERIFIED: .planning/ROADMAP.md] |
| Local adapter returns `file://` URLs only | Add a dedicated local HTTP plug for browser playback parity. [VERIFIED: lib/rindle/storage/local.ex] [VERIFIED: .planning/REQUIREMENTS.md] | Required in Phase 26. [VERIFIED: .planning/ROADMAP.md] | Browser media elements can seek in dev without teaching adopters a second production delivery model. [VERIFIED: .planning/phases/26-delivery-surface/26-CONTEXT.md] |
| Attachment names treated informally | Use RFC 6266 `Content-Disposition` with RFC 5987-style `filename*=` encoding and sanitized basenames. [CITED: https://www.rfc-editor.org/rfc/rfc6266] | Mature HTTP practice reflected in RFC 6266. [CITED: https://www.rfc-editor.org/rfc/rfc6266] | Eliminates raw metadata/path leakage and handles non-ASCII safely. [VERIFIED: lib/rindle/security/filename.ex] [CITED: https://www.rfc-editor.org/rfc/rfc6266] |

**Deprecated/outdated:**
- Returning `file://` paths for browser playback as the only local-delivery story is outdated for AV because HTML media seeking depends on HTTP range support, not filesystem URLs. [VERIFIED: lib/rindle/storage/local.ex] [VERIFIED: .planning/REQUIREMENTS.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Plug authors often leave adapter validation in `call/2` because request data is available there. [ASSUMED] | Common Pitfalls - Pitfall 2 | Low; this only explains a likely implementation trap and does not change the prescribed fix. |
| A2 | Delivery-time filenames are often treated as presentation instead of security policy. [ASSUMED] | Common Pitfalls - Pitfall 4 | Low; the implementation recommendation still stands because project security invariants already forbid trusting metadata. |

## Open Questions

1. **Resolved: signed-redirect adapters receive normalized disposition data, not a prebuilt header string.**
   - What we know: `url/3` already forwards opts to storage adapters, and S3-style presigned URLs often encode response disposition via adapter-specific query params. [VERIFIED: lib/rindle/delivery.ex] [VERIFIED: lib/rindle/storage/s3.ex]
   - Locked Phase 26 choice: normalize `filename:` and `disposition:` into one internal delivery map/struct in `Rindle.Delivery`, then let adapter-specific code translate that normalized data into headers or response-query params. Keep the public API as `filename:` and `disposition:` opts, and reserve any adapter-specific translation as an internal concern. [VERIFIED: .planning/phases/26-delivery-surface/26-CONTEXT.md]
   - Consequence for planning: `Rindle.Delivery.ContentDisposition` owns normalization plus RFC 5987 encoding, while redirect and local-delivery consumers each adapt the same normalized representation to their transport. [VERIFIED: .planning/phases/26-delivery-surface/26-CONTEXT.md]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit with Mox and Oban testing helpers. [VERIFIED: test/rindle/delivery_test.exs] [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] |
| Config file | none in repo root; tests are driven by Mix/ExUnit conventions. [VERIFIED: repo grep] |
| Quick run command | `mix test test/rindle/delivery_test.exs test/rindle/contracts/telemetry_contract_test.exs` [VERIFIED: repo grep] |
| Full suite command | `mix test` [VERIFIED: repo grep] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AV-04-01 | `streaming_url/3` wraps `url/3` and returns `%{url, kind, mime}` | unit | `mix test test/rindle/delivery_test.exs` | ✅ |
| AV-04-02 | Reserved `Rindle.Streaming.Provider` behaviour does not alter runtime dispatch | unit | `mix test test/rindle/delivery_test.exs` | ❌ Wave 0 |
| AV-04-03 | `LocalPlug` handles signed token, single range, and fallback full-body | integration | `mix test test/rindle/delivery/local_plug_test.exs` | ❌ Wave 0 |
| AV-04-04 | `LocalPlug` init fails on non-local adapter | unit | `mix test test/rindle/delivery/local_plug_test.exs` | ❌ Wave 0 |
| AV-04-05 | `LocalPlug` moduledoc/dev-only posture | manual/doc parity | `mix test` | ❌ manual review |
| AV-04-06 | New telemetry event names and metadata are locked | contract | `mix test test/rindle/contracts/telemetry_contract_test.exs --only contract` | ✅ |
| AV-04-07 | TTL guidance stays docs-only and DSL unchanged | unit/doc parity | `mix test test/rindle/profile/profile_test.exs` | ✅ |
| AV-04-08 | `Content-Disposition` uses sanitized `filename*=` posture | unit | `mix test test/rindle/delivery_test.exs` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `mix test test/rindle/delivery_test.exs test/rindle/contracts/telemetry_contract_test.exs`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/rindle/delivery/local_plug_test.exs` — request-level coverage for AV-04-03 and AV-04-04. [VERIFIED: repo grep]
- [ ] Delivery disposition assertions in `test/rindle/delivery_test.exs` — covers AV-04-08. [VERIFIED: test/rindle/delivery_test.exs]
- [ ] Telemetry contract entries for `[:rindle, :delivery, :streaming, :resolved]` and `[:rindle, :delivery, :range_request]` — covers AV-04-06. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Phase 26 relies on existing optional authorizer hooks rather than introducing auth state. [VERIFIED: lib/rindle/delivery.ex] |
| V3 Session Management | no | Local playback uses signed request tokens, not long-lived server sessions. [VERIFIED: .planning/REQUIREMENTS.md] |
| V4 Access Control | yes | Reuse `authorize_delivery/4` for `streaming_url/3` and signed-token verification for `LocalPlug`. [VERIFIED: lib/rindle/delivery.ex] [VERIFIED: .planning/phases/26-delivery-surface/26-CONTEXT.md] |
| V5 Input Validation | yes | Validate `Range`, `filename`, and local-path containment explicitly. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: lib/rindle/security/filename.ex] |
| V6 Cryptography | yes | Use `Plug.Crypto` HMAC signing/verification for local-playback tokens; never invent a custom signature format. [VERIFIED: deps/plug_crypto/lib/plug/crypto/message_verifier.ex] |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Path traversal through key-based local file lookup | Tampering / Information Disclosure | Resolve against the configured local root and reject any resolved path escaping that root. [VERIFIED: .planning/phases/26-delivery-surface/26-CONTEXT.md] |
| Token tampering on local playback URLs | Spoofing | Sign `key + expiry + actor_subject` payloads with `Plug.Crypto` and reject invalid/expired tokens. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: deps/plug_crypto/lib/plug/crypto/message_verifier.ex] |
| Metadata-driven filename injection | Tampering / Information Disclosure | Keep filenames explicit, sanitize basenames, and emit `filename*=` only from trusted values. [VERIFIED: .planning/PROJECT.md] [VERIFIED: lib/rindle/security/filename.ex] [CITED: https://www.rfc-editor.org/rfc/rfc6266] |
| Range-header abuse | Denial of Service | Support one range only and ignore problematic multi-range/unparseable requests. [CITED: https://www.rfc-editor.org/rfc/rfc7233] |

## Sources

### Primary (HIGH confidence)

- `lib/rindle/delivery.ex` - current delivery ownership, auth flow, TTL injection, and telemetry seam. [VERIFIED: repo grep]
- `lib/rindle/storage/local.ex` - current local adapter semantics and missing public path/root seam. [VERIFIED: repo grep]
- `lib/rindle/security/filename.ex` - existing filename sanitizer. [VERIFIED: repo grep]
- `test/rindle/delivery_test.exs` - current delivery contract coverage. [VERIFIED: repo grep]
- `test/rindle/contracts/telemetry_contract_test.exs` - public telemetry contract precedent. [VERIFIED: repo grep]
- Plug `send_file/5` docs - offset/length support and OS `sendfile` note. [CITED: https://hexdocs.pm/plug/Plug.Conn.html]
- RFC 7233 - range semantics, allowance to ignore `Range`, and multipart requirements. [CITED: https://www.rfc-editor.org/rfc/rfc7233]
- RFC 6266 - `Content-Disposition` semantics, advisory filename rules, and `filename*=` examples. [CITED: https://www.rfc-editor.org/rfc/rfc6266]

### Secondary (MEDIUM confidence)

- none

### Tertiary (LOW confidence)

- none

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - everything recommended is either already in the repo or documented by primary sources. [VERIFIED: mix.lock] [CITED: https://hexdocs.pm/plug/Plug.Conn.html]
- Architecture: HIGH - the existing repo seams strongly constrain the correct implementation path. [VERIFIED: lib/rindle/delivery.ex] [VERIFIED: lib/rindle/storage/local.ex]
- Pitfalls: MEDIUM - most are directly grounded in the current repo and RFCs, but two root-cause descriptions are implementation-pattern inferences. [VERIFIED: repo grep] [CITED: https://www.rfc-editor.org/rfc/rfc7233]

**Research date:** 2026-05-05 [VERIFIED: system date]
**Valid until:** 2026-06-04 for repo-seam guidance; re-check official HTTP/Plug docs sooner only if dependencies change. [VERIFIED: mix.lock]

## RESEARCH COMPLETE
