# Phase 5: CI & 1.0 Readiness - Context

**Gathered:** 2026-04-26 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Make Rindle 1.0-publishable: every PR is gated by five CI lanes (quality, contract, integration, adopter, release), the public API is verified end-to-end against a real adopter shape, and documentation is complete enough for a Phoenix developer to ship media features on day one.

**Locked scope expansion (from discussion):** Phase 5 also backfills `:telemetry.execute/3` emission at the asset/variant/upload/delivery/cleanup boundaries, because Phase 3 marked TEL-01..08 complete in REQUIREMENTS.md but never wired the actual emission sites. The contract lane (CI-06) cannot exist without emission; bundling them keeps the contract test and its surface in the same PR.

</domain>

<decisions>
## Implementation Decisions

### Telemetry Emission Backfill (scope addition)
- **D-01:** Phase 5 ships actual `:telemetry.execute/3` calls at the locked event family boundaries before the contract lane is authored. Emission and contract verification ship together so the contract test asserts a real surface, not a hypothetical one.
- **D-02:** Emission sites map directly to existing modules — no new abstractions. Asset state change at `lib/rindle/domain/asset_fsm.ex`, variant state change at `lib/rindle/domain/variant_fsm.ex`, upload start/stop at `lib/rindle/upload/broker.ex`, signed delivery at `lib/rindle/delivery.ex`, cleanup runs at `lib/rindle/workers/*` and `lib/rindle/ops/upload_maintenance.ex`.
- **D-03:** Emission is additive only. No public API or state machine change. `profile` and `adapter` metadata fields are required; measurements stay numeric (the locked Phase 3 contract).

### Contract Lane (CI-06)
- **D-04:** Contract lane is implemented as ExUnit tests under `test/rindle/contracts/` tagged `:contract` and run as a separate `mix test --only contract` step in CI. Re-uses the pattern already established by `test/rindle/contracts/behaviour_contract_test.exs`.
- **D-05:** The contract test attaches `:telemetry.attach_many/4` handlers, exercises minimal in-process flows, and asserts: exact event-name allowlist, required `profile` + `adapter` metadata keys, and that all measurements are numeric. A name change or metadata-key drop breaks the lane (Phase 5 success criterion 5.2).
- **D-06:** No NimbleOptions schema DSL for the contract — the event family is small and stable enough that a flat assertion module is the right cost.

### Adopter Lane (CI-08)
- **D-07:** Canonical adopter integration lives **in-repo** at `test/adopter/canonical_app/` (or equivalent test-tree path). Atomically gated with the PR; no separate repo, no cross-repo CI triggering, no drift.
- **D-08:** Adopter fixture boots an **adopter-owned** Repo (distinct from `Rindle.Repo`) and exercises the full lifecycle — upload → promote → variant → signed URL → detach → purge — against MinIO + Postgres in CI.
- **D-09:** The adopter lane runs as a third CI job after `quality` and `integration` and exits non-zero on any lifecycle gap. Where `lib/rindle.ex` references `Rindle.Repo` directly today, the lane will surface the leak; planner decides whether to introduce config-driven repo resolution or document the constraint as a closed gap before 1.0.

### Release Lane (CI-09)
- **D-10:** Release lane runs **manually only** — `workflow_dispatch` and version-tag pushes (e.g., `v*`). It does not run on every PR. This protects fork PRs from any future need to handle Hex API secrets.
- **D-11:** Release lane runs `mix hex.publish --dry-run`, `mix hex.build` artifact inspection (assert `lib/**.ex`, `priv/repo/migrations/`, `mix.exs`, `README.md` are present; assert `_build/`, `.planning/`, `priv/plts/` are absent), and a post-publish parity diff between the built tarball and local `lib/`.
- **D-12:** Pre-1.0 the version is `0.1.0-dev`. The release lane is dry-run-only until the 1.0 cutover; the lane stays green by detecting metadata regressions. Whether `mix hex.publish --dry-run` accepts `-dev` versions is a planner concern (researcher should verify before the lane is wired).

### Coverage Threshold + libvips (CI-03)
- **D-13:** Use `excoveralls` with `coveralls.json` configured to fail below an 80% line threshold. `mix coveralls` (or `coveralls.github` in CI) replaces the bare `mix test` step in the quality lane.
- **D-14:** Quality lane installs `libvips-dev` via `apt-get install -y libvips-dev` before `mix deps.get` so the `:image` dep can be exercised. Without it, `lib/rindle/processor/image.ex` cannot be covered and the threshold becomes unreachable. (Resolves the STATE.md pending todo on libvips system-dep documentation.)

### Documentation Structure (DOC-01..08)
- **D-15:** Narrative guides live in `guides/` at repo root, one Markdown per DOC-01..07: `getting_started.md`, `core_concepts.md` (with state diagrams for asset/variant/upload-session FSMs), `profiles.md`, `secure_delivery.md`, `background_processing.md`, `operations.md`, `troubleshooting.md`. Wired into `mix.exs docs/0` via `extras:` and `groups_for_extras:`.
- **D-16:** DOC-01 (getting started) is verified as copy-pasteable by the adopter lane fixture itself — the canonical adopter snippet in the guide must match the working code path the adopter lane runs. If the snippet drifts, the lane fails (success criterion 5.5).
- **D-17:** DOC-08 audit fixes the seven public modules currently missing or hiding `@moduledoc`: `lib/rindle/domain/{media_asset,media_attachment,media_variant,media_upload_session,media_processing_run}.ex` get full `@moduledoc` documenting state values and the FSM module they pair with. `lib/rindle/repo.ex` gets `@moduledoc false` (test-harness-only) and the docstring on `Rindle` (or guides) explicitly states the adopter-repo-first stance. `lib/rindle/application.ex` keeps `@moduledoc false` (internal supervisor).
- **D-18:** Mix tasks in `lib/mix/tasks/` already have detailed `@moduledoc` blocks — DOC-06 is cross-linking from `guides/operations.md`, not re-authoring.

### Claude's Discretion
- Internal module split for any new test fixtures (contract assertions module, adopter Repo module, etc.).
- Exact ExDoc `groups_for_extras:` grouping labels.
- Coverage exclusion patterns (e.g., test support, Mix tasks) — pick conventional defaults; document in `coveralls.json`.
- Whether to run the contract lane inside the existing `quality` job or as its own job — decide on CI runtime impact during planning.
- Whether `phx_media_library v0.6.0` API study (STATE.md todo) materially changes any guide example. If a meaningful divergence is found, surface as a deferred item, not a Phase 5 blocker.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and locked requirements
- `.planning/ROADMAP.md` — Phase 5 goal, success criteria, dependency on Phase 3 + Phase 4
- `.planning/REQUIREMENTS.md` — CI-01..09 and DOC-01..08; locked telemetry contract (TEL-01..08)
- `.planning/PROJECT.md` — M5 quality/docs/CI checklist; adopter-repo-first stance; key decisions table
- `.planning/STATE.md` — Pending todos relevant to Phase 5 (libvips system dep, phx_media_library study, R2 presigned PUT semantics, capabilities/0 extensibility)

### Prior phase decisions that constrain Phase 5
- `.planning/phases/03-delivery-observability/03-CONTEXT.md` — D-07/D-08/D-09 lock the telemetry public contract: event family, required `profile`/`adapter` metadata, numeric measurements
- `.planning/phases/01-foundation/01-CONTEXT.md` — D-01 adopter-repo-first runtime ownership; D-03 storage-side-effects-outside-DB-transactions invariant
- `.planning/phases/03-delivery-observability/03-02-SUMMARY.md` — context on why Phase 3 stopped short of telemetry emission

### Existing CI surface to extend
- `.github/workflows/ci.yml` — current quality + integration jobs; Phase 5 extends with contract / adopter / release lanes and adds libvips install + coverage threshold to the quality job

### Existing code surface relevant to emission backfill
- `lib/rindle.ex` — public facade; signed URL boundary touches delivery telemetry
- `lib/rindle/delivery.ex` — signed delivery emission site
- `lib/rindle/domain/asset_fsm.ex` — asset state change emission site
- `lib/rindle/domain/variant_fsm.ex` — variant state change emission site
- `lib/rindle/upload/broker.ex` — upload start/stop emission site
- `lib/rindle/workers/*.ex` and `lib/rindle/ops/upload_maintenance.ex` — cleanup run emission sites

### Existing patterns to reuse
- `test/rindle/contracts/behaviour_contract_test.exs` — tagged-lane pattern for contract assertions
- `test/rindle/upload/lifecycle_integration_test.exs` — `@tag :integration` lifecycle test pattern that the adopter lane mirrors with an adopter-owned Repo
- `test/rindle/storage/storage_adapter_test.exs` — `@tag :minio` MinIO-gated test pattern

### Documentation references
- `mix.exs` (lines 77–85) — current `docs/0` config; extend `extras:` and add `groups_for_extras:` for guides
- `lib/mix/tasks/rindle.cleanup_orphans.ex` — existing Mix task `@moduledoc` style to follow for consistency
- `README.md` — current entry point; align with new `guides/getting_started.md`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/rindle/contracts/behaviour_contract_test.exs`: established tagged-lane test pattern for contracts; the telemetry contract test reuses this shape.
- `Rindle.Domain.AssetFsm`, `Rindle.Domain.VariantFsm`, `Rindle.Domain.UploadSessionFsm`: each has a single transition entry point — natural single-site location for emitting a `:state_change` event without scattering instrumentation.
- `Rindle.Delivery`: the locked policy boundary for signed delivery; emission for `[:rindle, :delivery, :signed]` happens here, not in storage adapters.
- `Rindle.Upload.Broker`: upload lifecycle entry point; emission for `[:rindle, :upload, :start | :stop]` lives here.
- `Rindle.Workers.*` and `Rindle.Ops.UploadMaintenance`: cleanup workers — single emission site per `[:rindle, :cleanup, :run]` event.
- `Mix.Tasks.Rindle.*`: already documented Mix tasks; DOC-06 is cross-link work, not re-authoring.

### Established Patterns
- Tagged ExUnit lanes (`:integration`, `:minio`) — extend with `:contract` and `:adopter`.
- Public APIs return tagged tuples; emission must be side-effect-only and never alter return shape.
- Profile-scoped configuration for delivery/storage — `profile` metadata on every emitted event has an obvious source.
- Public modules carry `@moduledoc`; internal supervision (`Rindle.Application`) carries `@moduledoc false`. Domain schemas currently break this pattern — Phase 5 fixes them.
- ExDoc `extras:` is already wired with `README.md` — `guides/*.md` plugs into the same slot.

### Integration Points
- `.github/workflows/ci.yml` extends with three new lanes (contract, adopter, release) plus libvips install + coverage in quality. No secrets used today; release lane is the first lane that needs a Hex API secret, scoped to the protected release context.
- `mix.exs` extends `deps` with `excoveralls` (test/dev only), and `docs/0` extends `extras:` to include all `guides/*.md` plus `groups_for_extras:` for navigation.
- `coveralls.json` is new at repo root and configures the 80% threshold and any test-support exclusions.
- The adopter lane fixture under `test/adopter/canonical_app/` connects to MinIO + Postgres using the same env vars the integration job already sets (`RINDLE_MINIO_*`, `PGUSER`, etc.).

</code_context>

<specifics>
## Specific Ideas

- The DOC-01 adopter snippet must be the same code path the adopter lane runs — drift is a CI failure, not a docs review concern.
- Keep the telemetry contract small. Whatever extra instrumentation we want internally stays internal; the public contract surface from Phase 3 is locked.
- Pre-1.0, the release lane's job is to fail loudly on packaging regressions, not to publish. Real publish gating waits for the 1.0 cutover.
- Adopter-repo-first must read as a feature in the docs, not as a caveat. The adopter lane is the proof.

</specifics>

<deferred>
## Deferred Ideas

- `phx_media_library v0.6.0` API ergonomics study (STATE.md pending todo). If the study surfaces material divergence in DX, file follow-up phases — do not block Phase 5 on it.
- Cloudflare R2 presigned PUT semantics verification (STATE.md pending todo). Belongs in the integration / adopter lane evolution after 1.0, unless the adopter lane discovers it surfaces in v1.
- A separate `rindle_adopter_example` external repo. Out of scope for 1.0 — the in-repo adopter fixture is the v1 contract; an external example repo is a v1.x marketing/onboarding asset.
- Running the release lane on every PR (dry-run only). Lower priority than tag-push gating; revisit after 1.0 if regressions are sneaking through.
- LiveDashboard integration (DASH-01/02 in REQUIREMENTS.md v2 section).

</deferred>

---

*Phase: 05-ci-1-0-readiness*
*Context gathered: 2026-04-26*
