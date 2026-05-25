# Phase 42 — Deferred / Out-of-Scope Items

Out-of-scope discoveries logged during plan execution (not fixed — unrelated to
the current task's changes per the executor SCOPE BOUNDARY rule).

## Pre-existing environmental test failures (full `mix test`)

Observed during 42-01 execution on 2026-05-22. None reference the tus /
capability / migration / broker surface changed in 42-01; all are
environment-dependent and pre-existing.

| Test(s) | Failure | Root cause | Disposition |
|---------|---------|------------|-------------|
| `Rindle.Processor.AVTest` (av_test.exs:128/173/215) | `** (EXIT ...) :epipe` during real FFmpeg transcode | FFmpeg subprocess broken-pipe flakiness in this dev environment (ffmpeg 8.0.1 present, >= 6.0) | Out of scope — environmental, not caused by 42-01 |
| `Rindle.Ops.RuntimeChecksTest` (runtime_checks_test.exs:35) | `report.success? == false` (the `doctor.ffmpeg_runtime` check is non-pass) | Same FFmpeg-runtime-probe flakiness | Out of scope — environmental |
| `Rindle.DoctorTest` (doctor_test.exs:45) | profile-aware success output assertion | Same FFmpeg-runtime-probe flakiness | Out of scope — environmental |
| `Rindle.Upload.LifecycleIntegrationTest` (lifecycle_integration_test.exs:191/293) | `:econnrefused` to `localhost:9000` / `{:error, :econnrefused}` | No MinIO server running locally (these are MinIO-backed integration tests) | Out of scope — requires live MinIO; tagged integration |

Note: the set of FFmpeg `:epipe` failures is non-deterministic across runs (3–5
AVTest failures depending on subprocess timing), confirming an environmental
(subprocess/pipe) cause rather than a code regression.

## Pre-existing credo refactoring opportunities (42-04 / POLISH-01)

Observed during 42-04 (POLISH-01) execution on 2026-05-22. Confirmed pre-existing
on HEAD (present before any 42-04 edit) and NOT caused by the WR-02/WR-03 changes.
Out of scope per the executor SCOPE BOUNDARY rule (pre-existing, unrelated to the
selective POLISH-01 fixes).

| Location | Credo finding | Disposition |
|----------|---------------|-------------|
| `lib/rindle/streaming/provider/mux.ex:165` `create_asset_with_retry_hint/3` | cyclomatic complexity 10 (max 9) | Out of scope — pre-existing on HEAD |
| `lib/rindle/streaming/provider/mux.ex:~310` `verify_webhook/3` | function body nested too deep (4, max 2) | Out of scope — pre-existing on HEAD (the multi-secret `Enum.find_value` + nested `case` predates 42-04) |
| `lib/rindle/workers/mux_sync_provider_asset.ex:~209` `apply_state_transition/4` | function body nested too deep (3, max 2) | Out of scope — pre-existing on HEAD (the WR-04 `case`/`reconcile` shape predates 42-04) |

The plan-mandated gates are green:
- `mix test test/rindle/storage/local_tus_test.exs` — 7/7 pass.
- `mix test test/rindle/storage/` — 54 pass, 1 skipped, 0 failures.
- `mix compile --warnings-as-errors` — clean.
- `mix ecto.migrate` / `mix ecto.rollback` — additive + reversible.
