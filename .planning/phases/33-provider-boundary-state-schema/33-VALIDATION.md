---
phase: 33
slug: provider-boundary-state-schema
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-06
---

# Phase 33 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Sourced from RESEARCH.md `## Validation Architecture` (lines 1785–1846) — see RESEARCH for rationale and analog references.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir built-in) + Mox `~> 1.2`, ExMachina `~> 2.7`, Bypass `~> 2.1` |
| **Config file** | `test/test_helper.exs` (existing — no new framework needed) |
| **Quick run command** | `mix test test/rindle/<focused_dir>/ --color` |
| **Full suite command** | `mix test --color` |
| **Estimated runtime** | ~30 seconds (focused) / ~2–3 minutes (full suite, includes ecto.create/migrate per `mix.exs:231` test alias) |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/rindle/<focused_dir>/ --color` for the module(s) being touched. Per `mix.exs:231`, the test alias auto-runs `ecto.create --quiet` and `ecto.migrate --quiet` so the new migration is always applied first.
- **After every plan wave:** Run `mix test --color` (full suite). Must remain green at every wave-merge boundary — particularly for STREAM-06 because it modifies a core delivery callsite with 8+ existing tests.
- **Before `/gsd-verify-work`:** `mix test --color` + `mix credo --strict --color` + `mix dialyzer` + `mix format --check-formatted` all green.
- **Max feedback latency:** ~30 seconds (focused) — full suite ≤ 3 minutes.

---

## Per-Task Verification Map

> Filled at plan time by `gsd-planner`. Wave / task IDs derive from generated PLAN.md frontmatter.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | STREAM-01 | — | `Capabilities.known/0` returns locked 5-atom list; `safe/1` filters; `supports?/2` agrees | unit | `mix test test/rindle/streaming/capabilities_test.exs --color` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | STREAM-02 | — | `Provider` declares 6 required + 1 optional callbacks; `behaviour_info(:callbacks)` correct arities | unit | `mix test test/rindle/streaming/provider_test.exs --color` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | STREAM-03 | T-33-* (D-14 redaction) | Migration creates `media_provider_assets` 14 columns + partial-where unique index + 3 indexes; idempotent | integration (Repo) | `mix test test/rindle/domain/media_provider_asset_test.exs --color` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | STREAM-04 | — | Schema changeset `validate_inclusion` accepts 6 states; FSM `transition/3` matches D-13 matrix; emits `[:rindle, :provider_asset, :state_change]` telemetry; `Inspect` redacts `provider_asset_id` + `raw_provider_metadata` (invariant 14) | unit + property | `mix test test/rindle/domain/media_provider_asset_test.exs test/rindle/domain/provider_asset_fsm_test.exs --color` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | STREAM-05 | — | `validate!/1` accepts locked `:streaming` shape; raw Mux knobs raise `ArgumentError`; image/AV profiles compile unchanged; `source_variant` must exist in `variants/0`; per-variant `kind:` deferred to Phase 34 | unit | `mix test test/rindle/profile/validator_test.exs --color` | ✅ extends | ⬜ pending |
| TBD | TBD | TBD | STREAM-06 | — | All 8 D-19 dispatch branches return correct atom / `:ok`; `[:rindle, :delivery, :streaming, :resolved]` telemetry preserved on v1.4 paths (steps 1, 6); `:strict` flips step 6 to `:provider_asset_not_ready` | integration (Repo + Mox) | `mix test test/rindle/delivery_test.exs test/rindle/delivery/streaming_dispatch_test.exs --color` | ✅ extends + optional W0 split | ⬜ pending |
| TBD | TBD | TBD | STREAM-07 | — | Each of 5 new atoms produces non-empty `Rindle.Error.message/1`; `:streaming_not_configured` clause unchanged | unit | `mix test test/rindle/error_streaming_freeze_test.exs --color` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | STREAM-08 | T-33-* (D-30 secret redaction) | `Capability.report/0` locked top-level shape; `signed_playback_configured?` correct truthiness; does NOT crash when `:mux` dep absent | unit | `mix test test/rindle/capability_test.exs --color` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | STREAM-09 | — | 5 new variants render byte-for-byte identical message text under AV-06-05 freeze pattern; `@public_streaming_reasons` locked verbatim | unit (parity gate) | `mix test test/rindle/error_streaming_freeze_test.exs --color` | ❌ W0 (same as STREAM-07) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Test scaffolding files that must exist (or be created) before STREAM-XX implementation work begins. All gaps live inside `test/rindle/`; existing infrastructure (Repo sandbox, Mox, ExMachina, Bypass) is sufficient — no framework install needed.

- [ ] `test/rindle/streaming/capabilities_test.exs` — covers STREAM-01
- [ ] `test/rindle/streaming/provider_test.exs` — covers STREAM-02 (asserts `behaviour_info(:callbacks)`)
- [ ] `test/rindle/domain/media_provider_asset_test.exs` — covers STREAM-03 + STREAM-04 (schema, changeset, Inspect redaction)
- [ ] `test/rindle/domain/provider_asset_fsm_test.exs` — covers STREAM-04 (FSM matrix, telemetry)
- [ ] `test/rindle/error_streaming_freeze_test.exs` — covers STREAM-07 + STREAM-09 (parity freeze)
- [ ] `test/rindle/capability_test.exs` — covers STREAM-08
- [ ] (Optional split) `test/rindle/delivery/streaming_dispatch_test.exs` — STREAM-06; or extend `test/rindle/delivery_test.exs` in place

**No new fixture, no new framework install.** Existing factories at `test/support/` may be extended for `MediaProviderAsset` as a Wave 0 task in the migration/schema plan.

**Existing tests that MUST remain green** (regression tripwires):

- `test/rindle/delivery_test.exs:352-380` — STREAM-06 must not break existing `streaming_url/3` telemetry assertion.
- `test/rindle/delivery_test.exs:382-391` — STREAM-06 must not break the "does NOT emit when url resolution fails" assertion.
- `test/rindle/contracts/telemetry_contract_test.exs:74, 277` — STREAM-06 telemetry-preservation contract.
- `test/rindle/error_test.exs` (entire file) — STREAM-07 additions must NOT alter any existing AV reason-atom message text (D-26).
- `test/rindle/profile/validator_test.exs` — STREAM-05 must not regress existing image/AV/waveform variant validation.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| — | — | All phase behaviors have automated verification. | — |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify entries or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags in test commands
- [ ] Feedback latency < 30s for focused runs
- [ ] `nyquist_compliant: true` set in frontmatter once plans assign Task IDs

**Approval:** pending
