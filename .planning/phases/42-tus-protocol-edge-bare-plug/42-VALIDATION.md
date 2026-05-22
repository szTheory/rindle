---
phase: 42
slug: tus-protocol-edge-bare-plug
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-22
---

# Phase 42 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `42-RESEARCH.md` § Validation Architecture. Per-task IDs in the
> map below are keyed by requirement until plans bind them to `{42-NN-MM}` task IDs.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir built-in) + `Plug.Test` (synthetic conns) + `Oban.Testing` (job assertions) |
| **Config file** | `test/test_helper.exs` (existing); `Rindle.DataCase` for DB-backed tests |
| **Quick run command** | `mix test test/rindle/upload/tus_plug_test.exs` |
| **Full suite command** | `mix test` (alias runs `ecto.create --quiet` + `ecto.migrate --quiet` + `test`) |
| **Estimated runtime** | ~30 seconds (contract test); full suite per project norm |

No framework install needed — ExUnit + `Plug.Test` + `Oban.Testing` are present
(`webhook_plug_test.exs` and `local_plug_test.exs` demonstrate every idiom).

---

## Sampling Rate

- **After every task commit:** Run `mix test test/rindle/upload/tus_plug_test.exs` (the load-bearing protocol contract test)
- **After every plan wave:** Run `mix test test/rindle/upload/ test/rindle/storage/`
- **Before `/gsd:verify-work`:** `mix test` full suite green (+ `mix credo` / `mix dialyzer` per project norms)
- **Max feedback latency:** ~30 seconds (quick), full suite at wave/phase gates

---

## Per-Task Verification Map

> Keyed by requirement (load-bearing behaviors get dedicated deterministic tests;
> incidental behaviors are asserted inside the contract flow, not separately).
> Task IDs (`42-NN-MM`) bind during planning.

| Requirement | Wave | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|-------------|------|------------|-----------------|-----------|-------------------|-------------|--------|
| TUS-05 / Landmine 1 | 0 | T-PATH | Token resolves from `conn.path_info` final segment after `forward` prefix strip (**de-risk FIRST**) | unit | `mix test test/rindle/upload/tus_plug_test.exs` | ❌ W0 | ⬜ pending |
| TUS-01 | 1 | — | `init/1` raises `ArgumentError` when adapter lacks `:tus_upload` (no silent downgrade) | unit | same file | ❌ W0 | ⬜ pending |
| TUS-01 | 1 | — | `init/1` succeeds for Local-backed profile (advertises `:tus_upload`); non-tus method → `405` | unit | same file | ❌ W0 | ⬜ pending |
| TUS-01 / D-09 | 1 | — | `Local.capabilities/0` + `Capabilities.@known` include `:tus_upload`; `GCS` does NOT | unit | `test/rindle/storage/` | partial | ⬜ pending |
| TUS-02 | 1 | T-FORGE | `POST` (`Upload-Length` + opaque `Upload-Metadata`) → `201` + signed `Location`; session row `resumable_protocol: "tus"` | integration | same file | ❌ W0 | ⬜ pending |
| TUS-02 | 1 | T-DOS | `POST` with `Upload-Length > max_size` → `413` | unit | same file | ❌ W0 | ⬜ pending |
| TUS-02 / D-10 | 1 | — | Migration adds `resumable_protocol` + covering index; legacy rows nil | migration | `mix test` (Ecto introspection) | ❌ W0 | ⬜ pending |
| TUS-03 | 1 | T-REPLAY | `HEAD` → `204` + `Upload-Offset` (== `last_known_offset`) + `Cache-Control: no-store` + `Tus-Resumable: 1.0.0` | integration | same file | ❌ W0 | ⬜ pending |
| TUS-03 | 1 | T-DOS | `PATCH` happy → `204` + advanced `Upload-Offset`; tmp file grown; `read_length` 1 MiB + per-PATCH ceiling | integration | same file | ❌ W0 | ⬜ pending |
| TUS-03 | 1 | T-META | `PATCH` wrong `Content-Type` → `415` (no body read) | unit | same file | ❌ W0 | ⬜ pending |
| TUS-03 | 1 | T-RACE | **`PATCH` offset mismatch → `409`, body NOT consumed, offset unchanged** (the contract spine) | integration | same file | ❌ W0 | ⬜ pending |
| TUS-03 | 1 | — | **Full resume flow:** POST → HEAD → PATCH(partial) → drop → HEAD → PATCH(rest) → completion → `ready` MediaAsset | integration | same file | ❌ W0 | ⬜ pending |
| TUS-03 / D-08 | 1 | T-XFS | Local tmp-append → atomic `File.rename` (same-FS) → `verify_completion/2` promotes | integration | `test/rindle/upload/tus_local_backing_test.exs` | ❌ W0 | ⬜ pending |
| TUS-04 | 1 | — | `OPTIONS` → `204` advertising `Tus-Version: 1.0.0`, `Tus-Extension: creation,expiration,termination`, `Tus-Max-Size` | unit | same file | ❌ W0 | ⬜ pending |
| TUS-05 | 1 | T-FORGE | Valid HMAC token resolves session on HEAD/PATCH/DELETE; **tampered/forged → `404` (never 200)** | unit | same file | ❌ W0 | ⬜ pending |
| TUS-05 | 1 | T-REPLAY | **Expired token (`exp` past) → `401`/`404` (never 200)**; expired session (`expires_at`) → `410 Gone` | unit + integration | same file | ❌ W0 | ⬜ pending |
| TUS-05 | 1 | T-LEAK | `session_uri` redacted in `inspect`; tus URL absent from logs/telemetry | unit | same file | ❌ W0 | ⬜ pending |
| TUS-01 (Termination) | 1 | — | `DELETE` (valid token) → `204`, session aborted, tmp file removed | integration | same file | ❌ W0 | ⬜ pending |
| POLISH-01 | 2 | T-LEAK | Selective Mux fixes (WR-01/02/04/05/06/08/09, IN-02) carry regression tests; waivers documented | unit | `mix test test/rindle/streaming/ test/rindle/workers/` | extend | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/rindle/upload/tus_plug_test.exs` — protocol contract test + all unit cases (TUS-01..05). **Build the `conn.path_info` token-extraction test FIRST (Landmine 1 de-risk).**
- [ ] `test/rindle/upload/tus_local_backing_test.exs` — tmp-append + atomic-rename + `verify_completion` promotion (or fold into the Plug test).
- [ ] Test profile backed by `Rindle.Storage.Local` advertising `:tus_upload` (model on `LocalPlugTest.LocalProfile`, `local_plug_test.exs:9-13`), plus a profile whose adapter LACKS `:tus_upload` for the `init/1` raise test.
- [ ] Migration assertion (column + covering index) — dedicated test or introspection assertion in contract setup.
- [ ] Extend existing capability tests for `:tus_upload` honesty (Local yes, GCS no).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live `tus-js-client` (Node) interop against a running endpoint | TUS-03 | Live Node client + browser proof are LOCKED to Phase 44; Phase 42 proves the wire contract via `Plug.Test` synthetic conns | Deferred — Phase 42 contract is the Elixir wire simulation; live client proof is Phase 44 |

*All Phase 42 in-scope behaviors have automated verification via `Plug.Test`.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (quick) / full suite at gates
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
