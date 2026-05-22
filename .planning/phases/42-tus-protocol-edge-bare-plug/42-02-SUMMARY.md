---
phase: 42-tus-protocol-edge-bare-plug
plan: 02
subsystem: upload
tags: [tus, plug, hmac, plug-crypto, security-invariant-14, resumable]

# Dependency graph
requires:
  - phase: 42-tus-protocol-edge-bare-plug
    plan: 01
    provides: ":tus_upload capability, resumable_protocol column, Broker.initiate_tus_upload/2, Local tmp-append helpers"
provides:
  - "Rindle.Upload.TusPlug bare @behaviour Plug: init/1 capability raise, method dispatch, OPTIONS, POST creation (HMAC-signed Location), HEAD authoritative offset, token verify (404/401/410 never 200)"
  - "Path-segment token extraction proven under forward prefix-strip (Landmine 1 de-risked)"
affects:
  - phase: 42-tus-protocol-edge-bare-plug
    plan: 03
    note: "Plan 03 fills the PATCH/DELETE dispatch stubs and the completion convergence; reuses verify_token/2, extract_token/1, the signed-token length, and the Local backing root resolved in init/1"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Bare @behaviour Plug mounted via forward (Phoenix Router OR Plug.Router) — no Phoenix dependency"
    - "HMAC-signed bearer URL as the final path segment (Plug.Crypto.sign/verify, salt rindle:tus:url), resolved from conn.path_info after forward strips the mount prefix"
    - "Upload-Length carried inside the signed (tamper-proof) token payload instead of a new column — preserves D-10's one-column budget"
    - "Location derived from conn.script_name so the URL reflects the actual mount point"

key-files:
  created:
    - lib/rindle/upload/tus_plug.ex
    - test/rindle/upload/tus_plug_test.exs
  modified: []

key-decisions:
  - "D-04 discretion: token payload = %{session_id, actor, exp, length} (string keys, matching the LocalPlug convention + the plan's verify acceptance). length rides in the token so HEAD/PATCH read it back without a schema column."
  - "Location built from conn.script_name (the forward-consumed prefix) rather than a hardcoded /uploads/tus, so the URL is correct under any mount path."
  - "Inline executor delivery: the plan's 3 TDD tasks were delivered in one cohesive feat commit (the create/read half is a single interdependent unit; switched to inline after repeated subagent-spawn instability this session). All per-task acceptance criteria are covered by the 14-test contract suite."
  - "PATCH/DELETE are dispatch stubs that verify the token then return 404 — they do NOT 405 (valid tus methods); their real bodies land in Plan 03."

patterns-established:
  - "tus token discipline: extract_token/1 = List.last(path_info) (nil-safe); verify_token/2 maps every failure to 404/401 and load_active_session/1 adds 410 for expired sessions — never 200"

requirements-completed: [TUS-04]
requirements-reinforced: [TUS-01, TUS-02, TUS-05]

# Metrics
completed: 2026-05-23
---

# Phase 42 Plan 02: TusPlug Create/Read Half Summary

**Stood up the tus protocol edge's auth + create + read surface as a bare `@behaviour Plug` on the Plan-01 foundation: `init/1` capability raise, OPTIONS advertisement, POST Creation (HMAC-signed Location), HEAD authoritative offset, and HMAC verify that maps every failure to 404/401/410 — never 200. The path-segment token extraction under `forward` (Landmine 1) is proven end-to-end via a real `Plug.Router`.**

## Accomplishments

- **`Rindle.Upload.TusPlug`** — bare `@behaviour Plug` (`init/1` + `call/2`), mountable via `forward` in a Phoenix Router OR `Plug.Router`, adding no Phoenix dependency.
- **Capability honesty (TUS-01, D-09):** `init/1` wraps `Capabilities.require_upload(adapter, :tus_upload)` and raises `ArgumentError` when the adapter does not advertise `:tus_upload` — deploy-time failure, no silent downgrade.
- **Landmine 1 de-risked (proven, not assumed):** a real `Plug.Router` `forward "/uploads/tus"` strips the mount prefix into `script_name`, leaving the token in `path_info`; `extract_token/1 = List.last(path_info)` resolves it. A valid HEAD through the router returns `204`; a missing token (`path_info == []`) returns `404`.
- **OPTIONS (TUS-04):** `204` advertising `Tus-Version: 1.0.0`, `Tus-Resumable: 1.0.0`, `Tus-Extension: creation,expiration,termination` (exactly the implemented extensions, D-06), `Tus-Max-Size`.
- **POST Creation (TUS-02):** parses `Upload-Length` (`400` on missing/non-integer, `413` over `Tus-Max-Size`); treats `Upload-Metadata` as opaque (never parsed for filename/MIME/path — invariants 1/10); calls `Broker.initiate_tus_upload/2`; HMAC-signs `%{session_id, actor, exp, length}` via `Plug.Crypto.sign` (salt `"rindle:tus:url"`); persists the signed `Location` **only** into the redacting `session_uri`; returns `201` + `Location: <mount>/<token>` + `Tus-Resumable` + `Upload-Expires`.
- **HMAC verify (TUS-05):** tampered/forged/missing token → `404` (no existence leak), validly-signed-but-expired token → `401`, session past `expires_at` → `410 Gone` — **never 200**; `Tus-Resumable: 1.0.0` on every error response.
- **HEAD authoritative offset (TUS-03 read half):** `204` + `Upload-Offset` (== `last_known_offset`, integer-formatted) + `Upload-Length` (from the token) + `Cache-Control: no-store` + `Tus-Resumable` + `Upload-Expires`.
- **Bearer-URL redaction (invariant 14):** the signed URL lives only in `session_uri`; `inspect(session)` shows `[REDACTED]` and the raw token never appears.

## Task Commits

1. **All three plan tasks** — `5ff0549` feat(42-02): TusPlug create/read half (init/OPTIONS/POST/HEAD + HMAC auth). Delivered as one cohesive commit (interdependent single-file unit; inline execution). The 14-test contract suite covers each task's acceptance criteria: Task 1 (init-raise, init-success, path_info de-risk, 405), Task 2 (OPTIONS, POST 201/400/413, opaque metadata), Task 3 (HEAD 204, tampered→404, missing→404, expired-token→401, expired-session→410, redaction).

## Verification

- `mix compile --warnings-as-errors` — clean.
- `mix test test/rindle/upload/tus_plug_test.exs` — **14 tests, 0 failures**.
- `mix test test/rindle/upload/` — 46 tests, 0 failures, 3 skipped (no regressions).
- `mix format --check-formatted` (changed files) — clean.
- `mix credo` (changed files) — no issues (flattened `verify_token/2` nesting to satisfy the depth check).
- Leak grep: the signed URL is never `Logger`'d or `inspect`'d; the only `inspect` is of the adapter module in the `init/1` error message.

## Threat Model Coverage (from PLAN <threat_model>)

| Threat | Mitigation | Proven by |
|--------|-----------|-----------|
| T-42-FORGE | `Plug.Crypto.verify` HMAC; forged/tampered → 404 | tampered-token test |
| T-42-REPLAY | manual `exp` check → 401; `expires_at` past → 410 | expired-token + expired-session tests |
| T-42-LEAK | signed URL only in redacting `session_uri` | inspect-redaction test |
| T-42-META | `Upload-Metadata` opaque, not parsed for path/MIME | hostile-metadata test (upload_key has no `..`/`passwd`) |
| T-42-DOWNGRADE | `init/1` raises on missing `:tus_upload` | init-raise test |
| T-42-PATH | `session_id` only from verified HMAC payload (server UUID) | tampered → 404 before any path build |
| T-42-DOS-POST | `Upload-Length > max_size` → 413 | over-max-size test |

## Deviations from Plan

- **Tasks committed together (procedural, not scope):** the plan's 3 TDD tasks were delivered in one feat commit rather than three. The create/read half is a single interdependent module; this run switched to inline execution after repeated subagent-spawn instability earlier in the session. Every per-task acceptance criterion is covered by the contract suite.
- **`Plug.Router forward init_opts` escape constraint:** the `:identity_fn` default is a remote capture (`&__MODULE__.default_actor/1`, with `default_actor/1` made public `@doc false`) because `Plug.Router`'s compile-time `init_opts` cannot escape an anonymous-function capture. Documented inline.

## Next Phase Readiness

- Plan 03 fills the PATCH/DELETE dispatch stubs and the completion convergence (`tus_complete/3` → unchanged `verify_completion/2`), reusing `verify_token/2`, `extract_token/1`, the token's `length`, and the Local `root` resolved in `init/1`.
- TUS-03 (full HEAD→PATCH→409→completion flow) and the Termination DELETE remain for Plan 03.

---
*Phase: 42-tus-protocol-edge-bare-plug*
*Completed: 2026-05-23*
