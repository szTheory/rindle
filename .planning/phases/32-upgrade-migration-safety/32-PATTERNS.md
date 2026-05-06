# Phase 32: Upgrade & Migration Safety - Pattern Map

**Mapped:** 2026-05-06
**Files analyzed:** 12 planned seams
**Analogs found:** 12 / 12

## File Classification

| Planned File / Seam | Role | Data Flow | Closest Analog | Match Quality |
| --- | --- | --- | --- | --- |
| `test/install_smoke/support/generated_app_helper.ex` upgrade helpers | test support | request-response | `test/install_smoke/support/generated_app_helper.ex` | exact |
| `test/install_smoke/generated_app_smoke_test.exs` upgrade smoke | integration test | request-response | `test/install_smoke/generated_app_smoke_test.exs` | exact |
| legacy migration subset execution | migration orchestration | request-response | `priv/install_smoke/migrate.exs` written by helper | role-match |
| backward-compat guard around image defaults | regression test | transform | `test/rindle/backward_compat/v13_digest_snapshot_test.exs` | exact |
| deterministic repair proof inside generated app | integration test | request-response | Phase 30 repair tests + generated-app smoke assertions | role-match |
| `Rindle.requeue_variants/2` recovery surface | public facade | request-response | `lib/rindle.ex` + `lib/rindle/ops/lifecycle_repair.ex` | exact |
| `mix rindle.doctor` / `mix rindle.runtime_status` in upgrade lane | diagnostics | request-response | Phase 31 install/docs parity posture | role-match |
| CI wiring for upgrade lane | test entrypoint | request-response | current install smoke matrix | role-match |
| `guides/upgrading.md` | docs | linear runbook | `guides/getting_started.md` + `guides/operations.md` | partial |
| README upgrade discovery callouts | docs | linkout | `README.md` quickstart posture | exact |
| release-doc upgrade summary | docs | linkout | `guides/release_publish.md` | exact |
| docs parity assertions | docs test | transform | `test/install_smoke/docs_parity_test.exs` | exact |

## Pattern Assignments

### `test/install_smoke/support/generated_app_helper.ex`

**Analog:** `test/install_smoke/support/generated_app_helper.ex`

Why it fits: the helper already owns generation of a real Phoenix adopter app, patching configs, writing host migrations, running explicit Rindle migrations, and proving installed-package behavior. Phase 32 should extend this module rather than add a second adopter harness.

Planner note: add upgrade-specific helper paths such as `prove_upgrade_install!/1` or similarly named internal steps, but keep the same report-map style and cleanup lifecycle already used by `prove_package_install!/1`.

### `test/install_smoke/generated_app_smoke_test.exs`

**Analog:** `test/install_smoke/generated_app_smoke_test.exs`

Why it fits: the current smoke suite already splits image and AV lanes with shared assertions. Phase 32 can add one upgrade lane with the same `setup_all` plus report assertions shape.

Planner note: preserve the current “prove package source, explicit migrations, lifecycle success” pattern; add upgrade-specific assertions instead of inventing a new test harness.

### Legacy migration subset execution

**Analog:** the migration-runner script emitted by `GeneratedAppHelper.write_migration_runner!/3`

Why it fits: the helper already writes a generated-app script that resolves host and packaged migration paths and runs them explicitly.

Planner note: to simulate pre-v1.4, prefer a helper-driven migration runner variant that can stop before `20260502120000_extend_media_for_av.exs`, seed legacy rows, then resume the full public migration path.

### Backward-compat guard

**Analog:** `test/rindle/backward_compat/v13_digest_snapshot_test.exs`

Why it fits: this test already encodes the strongest “legacy image-only adopters must not silently drift” guarantee in the repo.

Planner note: Phase 32 should extend the same posture with generated-app/runtime assertions, not replace it with weaker docs-only evidence.

### Deterministic repair proof

**Analog:** `lib/rindle/ops/lifecycle_repair.ex` reports plus generated-app smoke assertions

Why it fits: Phase 30 already standardized structured repair reports and asset-scoped repair semantics; the generated-app lane already proves outside-in user paths.

Planner note: seed failure deterministically in the generated app, then assert operator-facing diagnosis and repair effects using existing report semantics.

### Public repair and diagnostics surfaces

**Analogs:** `lib/rindle.ex`, `lib/rindle/ops/lifecycle_repair.ex`, `lib/mix/tasks/rindle.doctor.ex`, `lib/mix/tasks/rindle.runtime_status.ex`

Why they fit: Phase 32’s recovery story must use the already-shipped public surfaces, not hidden helpers.

Planner note: treat these as fixed contract dependencies; Phase 32 should prove and document them in upgrade context, not redesign them.

### `guides/upgrading.md`

**Analogs:** `guides/getting_started.md` for linear adopter flow, `guides/operations.md` for operator-verbs and checkpoints

Why it fits: no existing dedicated upgrade guide exists, but the repo already has the right styles for a linear public guide and a separate ops reference.

Planner note: combine the explicit sequence discipline of getting-started with the terse command/checkpoint style of operations. Keep deep troubleshooting out of the main runbook.

### README / release doc cross-links

**Analogs:** `README.md` quickstart linkouts and `guides/release_publish.md` maintainer-only scope boundaries

Why they fit: the repo already keeps README narrow and release docs specialized.

Planner note: use linkouts and short upgrade warnings, not full procedure duplication.

### Docs parity tests

**Analog:** `test/install_smoke/docs_parity_test.exs`

Why it fits: this file already freezes exact phrases, surface boundaries, and guide discoverability.

Planner note: assert that README/getting-started/release docs point to `guides/upgrading.md`, and that the upgrade guide mentions explicit migrations, `mix rindle.doctor`, optional `mix rindle.runtime_status`, and `Rindle.requeue_variants/2` or its operator-facing equivalent language.

## Reuse Guidance

1. Reuse the generated-app report map pattern. Add upgrade-specific keys instead of inventing a second result shape.
2. Reuse explicit migration runner generation. Add a legacy cutoff or staged-run option rather than writing bespoke SQL-first setup.
3. Reuse existing public repair and diagnostics commands as fixed dependencies in the proof lane.
4. Reuse docs-parity tests for wording and link discovery. Avoid manual checklist-only validation.

## Anti-Patterns To Avoid

1. A frozen fixture Phoenix app for the main proof lane.
2. Timing-based “wait for job to get stuck” recovery tests.
3. A docs-only upgrade story with no executable generated-app proof.
4. Duplicating the full upgrade procedure in README or release docs.
