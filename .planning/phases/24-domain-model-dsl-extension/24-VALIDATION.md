---
phase: 24
slug: domain-model-dsl-extension
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-02
---

# Phase 24 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.15+/Erlang 26+, Hex `mix.exs`) |
| **Config file** | `config/test.exs`, `test/test_helper.exs` |
| **Quick run command** | `mix test --include focus --exclude integration` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~120 seconds (full suite incl. MinIO lifecycle test) |

---

## Sampling Rate

- **After every task commit:** Run `mix test path/to/touched_test.exs`
- **After every plan wave:** Run `mix test` (full suite)
- **Before `/gsd-verify-work`:** Full suite must be green; `mix compile --warnings-as-errors` clean
- **Max feedback latency:** 30 seconds for per-task; 120 seconds for full suite

---

## Per-Task Verification Map

> Populated by the planner from each PLAN.md frontmatter `requirements` and per-task `<verify>` block.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 24-01-T1 | 24-01 | 0 | AV-02-11 | T-24-26 | v1.3 :thumb digest snapshot captured BEFORE any validator edits land (load-bearing for D-14, D-22, D-23 — prevents silent stale-flip of every adopter's image variants) | unit (snapshot) | `mix test test/rindle/backward_compat/v13_digest_snapshot_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 24-01-T2 | 24-01 | 0 | AV-02-05 | T-24-23 | Rindle.Probe behaviour declares probe/1 + accepts?/1 callbacks; behaviour module compiles and dispatches | unit (behaviour contract) | `mix test test/rindle/probe_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 24-01-T3 | 24-01 | 0 | AV-02-10 | T-24-23, T-24-24 | MetadataSanitizer.sanitize/1 truncates strings to 1024 bytes (codepoint-aligned UTF-8 rewind) and strips control chars \x00-\x1F except \t (D-19) | unit (boundary coverage) | `mix test test/rindle/av/metadata_sanitizer_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 24-02-T1 | 24-02 | 1 | AV-02-01 | T-24-06 | Additive Ecto migration adds :kind, :width, :height, :duration_ms, :has_video_track, :has_audio_track, :error_reason to media_assets AND :output_kind, :duration_ms, :width, :height to media_variants; both kind enums default to "image" so existing rows remain valid pre-deploy | integration (DB schema introspection) | `mix ecto.reset && mix test test/rindle/domain/migration_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 24-02-T2 | 24-02 | 1 | AV-02-02 | T-24-07, T-24-08, T-24-10 | MediaAsset.changeset enforces @kinds ~w(image video audio) (3 values; waveform rejected — Pitfall 4); per-kind field consistency rejects width/height on audio, duration_ms/has_video_track on image (D-11); "transcoding" recognized in @states; error_reason castable for quarantine path | unit (changeset validation) | `mix test test/rindle/domain/media_schema_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 24-02-T3 | 24-02 | 1 | AV-02-02 | T-24-10 | MediaVariant.changeset enforces @output_kinds ~w(image video audio waveform) (4 values; waveform IS valid here); "cancelled" terminal state recognized in @states (Plan 03 + Phase 27 prerequisite) | unit (changeset validation) | `mix test test/rindle/domain/media_schema_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 24-03-T1 | 24-03 | 1 | AV-02-03 | T-24-22 | AssetFSM @allowed_transitions extended additively: available→transcoding, transcoding→ready/degraded/quarantined, AND analyzing→quarantined (researcher-flagged D-09 deviation required by AV-02-09); all existing v1.3 edges still pass; transcoding→deleted REJECTED | unit (FSM regression + new edges) | `mix test test/rindle/domain/lifecycle_fsm_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 24-03-T2 | 24-03 | 1 | AV-02-04 | T-24-22 | VariantFSM @allowed_transitions extended additively: planned/queued/processing→cancelled (terminal); cancelled→queued/purged/ready REJECTED | unit (FSM terminal-state coverage) | `mix test test/rindle/domain/lifecycle_fsm_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 24-04-T1 | 24-04 | 1 | AV-02-06, AV-02-07, AV-02-08 | T-24-26 | Validator dispatches to per-kind NimbleOptions schemas (image/video/audio/waveform) via pop_kind!/2 + schema_for_kind/1; image-default omits :kind from validated map (D-14, maybe_put_kind/3); :from_variant compile-time guard rejects with mix-style fix-hint; per-kind schemas enforce SYNTHESIS §2.4 in/out scope (h264+mp4+aac for video; aac/mp3+m4a/mp3 for audio; :json for waveform) | unit (digest stability + dispatch) | `mix test test/rindle/backward_compat/v13_digest_snapshot_test.exs test/rindle/profile/profile_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 24-04-T2 | 24-04 | 1 | AV-02-06, AV-02-07, AV-02-08 | T-24-26 | validator_test.exs covers per-kind dispatch + default-kind behavior + from_variant guard; un-skips Plan 01's two skip-tagged digest snapshot tests (now load-bearing on the post-validator codebase) | unit (dispatch coverage) | `mix test test/rindle/profile/validator_test.exs test/rindle/backward_compat/v13_digest_snapshot_test.exs test/rindle/profile/profile_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 24-05-T1 | 24-05 | 2 | AV-02-05, AV-02-10 | T-24-23, T-24-24 | Rindle.Probe.Image (libvips) and Rindle.Probe.AVProbe (FFprobe + sanitizer) implement Rindle.Probe behaviour; AVProbe applies MetadataSanitizer.sanitize/1 BEFORE returning (D-20); Phase 23 ffprobe.ex untouched (D-21) | unit (probe adapter) | `mix test test/rindle/probe/ --warnings-as-errors --exclude integration` | yes | ⬜ pending |
| 24-05-T2 | 24-05 | 2 | AV-02-09 | T-24-21, T-24-22, T-24-25, T-24-29, T-24-31 | PromoteAsset.advance_to_promoting/2 analyzing-clause body inserts MIME-dispatched probe step (D-16, D-17, D-18) with try/after tempfile cleanup; idempotent across Oban retries (re-probe overwrites typed cols when :kind is nil); probe failure → analyzing→quarantined transition with error_reason set; uses Rindle.download/3 (NOT Rindle.Config.storage()/storage.fetch) | unit (worker integration) + integration (full lifecycle) | `mix test test/rindle/workers/promote_asset_test.exs --warnings-as-errors --exclude integration` | yes | ⬜ pending |
| 24-05-T3 | 24-05 | 2 | AV-02-11 | T-24-26 | Canonical adopter parity test: image-only Profile compiles unchanged on v1.4; Profile.variants()[:thumb] omits :kind (D-14 + D-22 condition 2); Profile.recipe_digest(:thumb) byte-equal to v1.3 snapshot (D-22 condition 3 — THE load-bearing assertion); existing happy-path lifecycle test unedited (D-22 condition 4) | unit (parity) + integration (MinIO lifecycle) | `mix test test/adopter/canonical_app/lifecycle_test.exs test/rindle/backward_compat/v13_digest_snapshot_test.exs --warnings-as-errors` | yes | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/rindle/backward_compat/v13_digest_snapshot_test.exs` — captures v1.3 `:thumb` recipe digest BEFORE any validator edits (D-23, load-bearing for D-14)
- [x] `test/rindle/profile/per_kind_validator_test.exs` — stubs for AV-02-04 (NimbleOptions per-kind dispatch) [covered by Plan 04 task 2 — `test/rindle/profile/validator_test.exs`]
- [x] `test/rindle/probe/probe_behaviour_test.exs` — stubs for AV-02-05 (probe behaviour contract) [covered by Plan 01 task 2 — `test/rindle/probe_test.exs`]
- [x] `test/rindle/av/metadata_sanitizer_test.exs` — stubs for AV-02-10 (1024-byte truncation, control-char strip)

*Existing ExUnit infrastructure covers all phase requirements; no framework install needed.*

*Wave 0 plan (24-01) is fully designed; planning artifacts complete and committed (Wave 0 task execution gates the rest of the phase per Plan 04's dependency on Plan 01's snapshot value).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| End-to-end MinIO lifecycle for video upload | AV-02-09 | Requires running MinIO container + sample MP4 fixture | `docker compose up minio && mix test test/adopter/canonical_app/lifecycle_test.exs --include integration` |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s per task (per-task commands target a single test file each; full-suite ~120s gates wave/PR boundaries)
- [x] `nyquist_compliant: true` set in frontmatter once planner populates verification map

**Approval:** approved (planner sign-off — execution proceeds against this validation contract)
