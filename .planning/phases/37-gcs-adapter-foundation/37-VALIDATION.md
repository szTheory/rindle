---
phase: 37
slug: gcs-adapter-foundation
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-05-07
approved: 2026-05-07
---

# Phase 37 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test --exclude gcs` |
| **Full suite command** | `mix test` |
| **GCS integration command** | `mix test --only gcs` (requires `GOOGLE_APPLICATION_CREDENTIALS_JSON` + `RINDLE_GCS_BUCKET`) |
| **Estimated runtime** | ~30 s (excluded) / ~90 s (full + Bypass) / ~3–4 min (live `--only gcs`) |

---

## Sampling Rate

- **After every task commit:** Run `mix test --exclude gcs path/to/touched/file_test.exs` (single-file fast feedback)
- **After every plan wave:** Run `mix test --exclude gcs` (full unit suite without live-bucket lane)
- **Before `/gsd-verify-work`:** `mix test --exclude gcs` must be green; if `GOOGLE_APPLICATION_CREDENTIALS_JSON` is present locally, `mix test --only gcs` must be green too
- **CI proof lane:** `gcs-soak` job runs `mix test --only gcs` against the real bucket on PR (when secret present) and on release (always)
- **Max feedback latency:** ~30 s (unit-only `mix test --exclude gcs`)

---

## Per-Task Verification Map

> Tasks are placeholders pending PLAN.md generation. Each row maps a planned task to its automated verification command. Status starts ⬜ pending and flips to ✅ as commits land.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 37-01-XX | 01 (Client) | 1 | GCS-01 | — | hand-rolled Finch JSON-API client returns shape-stable `{:ok, _}` / `{:error, atom}`; no Tesla coupling; 404 → `:not_found`; non-2xx → `{:gcs_http_error, %{status, body}}` | unit | `mix test test/rindle/storage/gcs/client_test.exs` | ❌ W0 | ⬜ pending |
| 37-02-XX | 02 (Signer) | 2 | GCS-03 | — | V4 signed URL respects `Rindle.Config.signed_url_ttl_seconds/0`; private-key auth; signing key parsed cleanly (PEM or service-account JSON); URL is wrapped in `{:ok, _}` | unit | `mix test test/rindle/storage/gcs/signer_test.exs` | ❌ W0 | ⬜ pending |
| 37-03-XX | 03 (Adapter + capabilities + parity) | 3 | GCS-01, GCS-02 | — | `head/2` shape `{:ok, %{size: integer, content_type: binary \| nil}}` matches S3; `capabilities/0 == [:signed_url, :head]`; `:resumable_upload`/`:resumable_upload_session` NOT advertised; `Content-Type` + `Content-Disposition` written as object metadata at `store/3` (not URL params); `Code.ensure_loaded?(Goth)` guard returns `{:error, :goth_unconfigured}` | unit | `mix test test/rindle/storage/gcs_test.exs test/rindle/storage/storage_adapter_test.exs` | ❌ W0 | ⬜ pending |
| 37-04-XX | 04 (CI lane + doctor) | 4 | GCS-04 | — | `gcs-soak` job in `.github/workflows/ci.yml` is gated on `secrets.GOOGLE_APPLICATION_CREDENTIALS_JSON != ''`; fork PRs skip cleanly; `mix rindle.doctor` reports GCS health (Goth running, bucket reachable, signing key parseable) ONLY when adopter profile declares `storage: Rindle.Storage.GCS` | integration | `mix test --only gcs` (live bucket) + `mix rindle.doctor` (smoke) | ❌ W0 | ⬜ pending |

> The cross-adapter parity test at `test/rindle/storage/storage_adapter_test.exs:41-51, 77-83` MUST stay green after Plan 03 lands. Add it to Plan 03's Wave 0 if explicit registration is required.

---

## Wave 0 Requirements

- [ ] `test/rindle/storage/gcs/client_test.exs` — Bypass-driven JSON-API fixture stubs for head/store/download/delete + GCS-shaped error envelopes (404, 403, malformed JSON, 5xx)
- [ ] `test/rindle/storage/gcs/signer_test.exs` — V4 signed URL TTL/expires_in, signing-key dispatch (PEM string vs service-account JSON map vs file path)
- [ ] `test/rindle/storage/gcs_test.exs` — `@tag :gcs` + `@gcs_skip_reason` module attribute, env-var nil-checks (`GOOGLE_APPLICATION_CREDENTIALS_JSON`, `RINDLE_GCS_BUCKET`); mirrors `test/rindle/storage/s3_test.exs:13-18, 29-30`
- [ ] `test/rindle/storage/storage_adapter_test.exs` — extend with GCS adapter row in cross-adapter parity test (lines 41-51, 77-83); confirm head-shape parity assertion at S3 line 117 covers GCS
- [ ] `test/support/gcs_bypass_fixture.ex` (or similar) — shared Bypass fixture module for unit-level JSON-API stubs (per CONTEXT D-12, Bypass alone — no fakegcs dep)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Image-only S3 adopter sees no new noise in `mix rindle.doctor` output | GCS-04 (D-13) | Profile-aware doctor must NOT emit GCS check rows when adopter profile uses S3 only; integration with profile DSL is hard to assert in unit tests without a full adopter fixture | Run `mix rindle.doctor` on the rindle repo (S3-only profile in test/dummy or equivalent) and visually confirm zero GCS-related output rows |
| Fork-PR safety of `gcs-soak` lane | GCS-04 | GitHub Actions only resolves secrets on the source repo; fork-PR `secrets.X != ''` short-circuits the lane. Cannot reproduce in `act` reliably | Open a fork PR after Plan 04 lands; confirm `gcs-soak` job shows `Skipped` (not failed) in checks |
| Live-bucket round-trip for `Content-Disposition` and `Content-Type` object metadata | GCS-03 (D-03) | The Active Storage CVE-adjacent lesson: GCS V4 signed URLs do NOT enforce `response-content-disposition`. Must verify metadata round-trips via real GCS bucket because Bypass cannot prove server-side enforcement | After Plan 03, with `GOOGLE_APPLICATION_CREDENTIALS_JSON` set locally, run `mix test --only gcs` and confirm a test asserts that uploading an object with `:content_disposition` opt produces an object whose `head/2` returns the expected metadata |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies (each PLAN.md task ships a `<verify>` block + Wave 0 stub registration)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (every plan's first task RED, second GREEN, third refactor — `mix test` runs after every commit)
- [x] Wave 0 covers all MISSING references (Wave 0 list above maps 1:1 to the new test files referenced by Plans 01–04)
- [x] No watch-mode flags (`mix test` is one-shot; sampling rate above explicitly excludes `--listen-on-stdin`)
- [x] Feedback latency < 30 s (`mix test --exclude gcs` median runtime measured at ~20 s; live `--only gcs` lane is out-of-band CI only)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-05-07
