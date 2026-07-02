# Phase 116: versioned-rindle-migration-module - Context

**Gathered:** 2026-07-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 116 delivers the non-breaking migration substrate Rindle needs before v1.23 schema isolation:

1. A public, versioned, idempotent `Rindle.Migration.up/1` and `Rindle.Migration.down/1` module for Rindle-owned database tables.
2. A greenfield install path where adopters create normal host-app Ecto migrations that call `Rindle.Migration`, then run their standard `mix ecto.migrate` flow.
3. Removal of Rindle's greenfield responsibility for the shared `oban_jobs` table. Host apps install and own Oban through `Oban.Migration`.
4. README, getting-started, upgrading, generated-app proof, docs parity, doctor, and runtime-status updates so the new path is the documented and tested path.

The phase is non-breaking. The default schema remains `public`; existing adopters that already applied the legacy packaged migrations remain valid and should not rewrite history. v1.23 owns the breaking default flip to a dedicated `rindle` Postgres schema.

The approved `116-UI-SPEC.md` is a locked documentation UX/copy contract, not a numbered requirements SPEC. Downstream agents must read it before editing README or guides.

</domain>

<decisions>
## Implementation Decisions

### Discussion Outcome

- **D-01:** The user requested one-shot research-backed recommendations for every gray area. No further user questions are needed before planning. Four subagents researched the gray areas independently, and their recommendations converged.
- **D-02:** Treat `116-UI-SPEC.md` as a locked documentation UX/design contract. It governs Markdown hierarchy, terminology, callout copy, rollback language, docs dependency boundaries, and the "no frontend UI/component dependency" constraint.
- **D-03:** Treat Phase 115's context as load-bearing. `guides/upgrading.md` is already the newest-first upgrade home; Phase 116 must add its migration note there instead of inventing another upgrade surface.

### Migration API Surface

- **D-04:** Expose an Oban-style `Rindle.Migration.up/1` and `Rindle.Migration.down/1` as the public migration API. This is the only public migration surface authorized for Phase 116.
- **D-05:** Public docs and generated-app proof must pin the migration version:

  ```elixir
  defmodule MyApp.Repo.Migrations.InstallRindle do
    use Ecto.Migration

    def up, do: Rindle.Migration.up(version: 1)
    def down, do: Rindle.Migration.down(version: 1)
  end
  ```

  This keeps host migrations deterministic if a project runs old generated migration code after upgrading the `rindle` dependency.
- **D-06:** The implementation may allow omitted `:version` to mean latest for developer ergonomics, but the greenfield docs must not teach the unpinned form. Deterministic adopter migrations matter more than saving a few characters.
- **D-07:** Accept a small validated keyword option schema. Required shape for planning: `:version` and `:prefix`, with `prefix: "public"` as the default. Consider `:create_schema` only if planning confirms it is needed to prepare v1.23 prefix work without widening Phase 116.
- **D-08:** Unknown options and invalid versions must fail loudly with clear `ArgumentError` or existing local validation-pattern errors. Prefer `NimbleOptions` because this repo already uses it as a public-contract validator.
- **D-09:** Do not add a public `mix rindle.*` install task, Igniter installer, or migration generator in Phase 116. Those are valid future onboarding ideas, but the approved UI-SPEC explicitly rejects a new public install task for this phase.
- **D-10:** `Rindle.Migration.up/1` must create or upgrade only Rindle-owned tables. It must not call `Oban.Migration`, create `oban_jobs`, or mutate host-owned Oban state.
- **D-11:** `Rindle.Migration.down/1` is destructive but scoped. It may drop only Rindle-owned tables and marker objects, in reverse dependency order, and must not drop `oban_jobs`. Docs must pair it with backup language from the UI-SPEC.
- **D-12:** Idempotency means the migration module can run against a database that already has the current Rindle-owned schema without failing or duplicating objects. Use Ecto helpers and/or catalog guards intentionally; do not wrap or invoke `Ecto.Migrator.run/4` over `priv/repo/migrations` from inside the new module.
- **D-13:** Keep public API perspective consumer-first: adopters should think "create a normal migration in my app" rather than "learn Rindle's internal migration file layout."

### Packaged Migration History

- **D-14:** Freeze the existing `priv/repo/migrations/*.exs` filenames in the Hex package for legacy compatibility and historical inspection. Do not delete or move them in this non-breaking phase.
- **D-15:** The legacy packaged migration directory is no longer the greenfield install path. README, getting-started, upgrading, and generated-app proof must stop teaching raw `Application.app_dir(:rindle, "priv/repo/migrations")` plus `Ecto.Migrator.run/4` for fresh installs.
- **D-16:** Convert `priv/repo/migrations/20260424205942_create_oban_tables.exs` into a no-op compatibility stub or otherwise make it non-authoritative so fresh Phase 116 installs no longer create `oban_jobs` on Rindle's behalf. Do not remove the filename, because existing adopters may have that version in `schema_migrations`.
- **D-17:** Preserve all other legacy packaged migration files as compatibility artifacts unless planning discovers a test or Hex package constraint that requires a narrower stub approach. They remain for already-applied legacy history and old package-path inspection, not as the recommended new path.
- **D-18:** Implement Rindle-owned schema changes in `lib/` behind `Rindle.Migration`, not by teaching adopters to copy or run package migration files. This mirrors Oban's successful pattern while avoiding a new generator support surface.
- **D-19:** The new module should make primary key and table options explicit. Do not depend on host Repo migration defaults such as binary-id settings, because this is a library-owned schema contract.
- **D-20:** Include an internal Rindle migration version marker so doctor/runtime can distinguish a fresh `Rindle.Migration` install from legacy file-history installs. Keep marker/query helpers private unless planning finds a strong reason to expose them.

### Doctor And Runtime Compatibility

- **D-21:** Replace "packaged migration file status is authoritative" with a hybrid health model:
  - Rindle migration version marker for fresh installs.
  - Postgres catalog/table/column/index checks for actual Rindle-owned schema readiness.
  - Legacy Ecto packaged migration compatibility for existing adopters.
  - Oban preflight that checks host-owned Oban configuration and `oban_jobs` readiness without claiming Rindle owns that table.
- **D-22:** `mix rindle.doctor` should return `OK` when either the new `Rindle.Migration` path or the legacy 15-file path yields a current, healthy Rindle-owned schema.
- **D-23:** `mix rindle.doctor` should return `ERROR` for incomplete/missing Rindle-owned tables, failed migration inspection, missing default Oban config where required, or missing `oban_jobs` when the runtime needs Oban.
- **D-24:** Healthy legacy file-history drift should be downgraded from hard failure to a warning/history-only diagnostic when catalog checks prove the Rindle-owned schema is complete. Existing adopters must not be told to delete or replay legacy migrations.
- **D-25:** `runtime_status` should preflight required Rindle-owned tables and host-owned `oban_jobs`, then return actionable setup failures rather than raw `undefined_table` crashes or empty reports. The user-facing message should say, in substance: install Oban with a host-owned `Oban.Migration`; Rindle no longer manages `oban_jobs`.
- **D-26:** Prefix-aware catalog query design should be prepared now, even though the default remains `public`, so v1.23 can build on this substrate instead of replacing it.
- **D-27:** Keep existing stable doctor check IDs where practical. If a status taxonomy changes, tests must lock the new semantics rather than simply weakening current assertions.

### Documentation And Proof Depth

- **D-28:** Use a full contract lock, not docs-only proof. Required proof surfaces: README, `guides/getting_started.md`, `guides/upgrading.md`, docs parity tests, generated Phoenix app smoke helpers/tests, doctor/runtime tests, and focused migration API tests.
- **D-29:** README `## Migrations` must show a compact host-owned migration module calling `Rindle.Migration.up/1` and `down/1`. It must also state that the default schema remains `public`.
- **D-30:** `guides/getting_started.md` step 3 must be renamed/reworked around normal host-app migration ownership, `Rindle.Migration`, separate host-owned `Oban.Migration`, and `mix rindle.doctor` verification.
- **D-31:** `guides/upgrading.md` `## Unreleased / Next` must add the Phase 116 note newest-first with `Applies to`, `What changed`, `Upgrade steps`, and `Verification`. Fresh installs use `Rindle.Migration`; existing legacy installs remain valid.
- **D-32:** Docs must explicitly separate Rindle-owned tables from `oban_jobs`. `Oban.Migration` is the host app's responsibility, and Rindle must not create `oban_jobs` for adopters going forward.
- **D-33:** Docs parity must reject the old greenfield raw package-path snippet in README/getting-started/upgrading while still allowing legacy compatibility copy where intentionally scoped.
- **D-34:** Generated-app smoke proof should create and run real host migrations: one for host app proof data, one for host-owned Oban setup, and one for Rindle setup calling `Rindle.Migration`. It should assert Rindle's path does not create `oban_jobs`.
- **D-35:** Add migration API tests for idempotent `up/1`, scoped/destructive `down/1`, invalid options, explicit UUID/schema choices, version marker behavior, and absence of Oban table creation.
- **D-36:** Verification should stay focused: run docs parity and migration/runtime focused tests during plan execution; phase gate remains the repo checks named in `RUNNING.md` / `CONTRIBUTING.md`.

### Developer Experience And Copy

- **D-37:** Optimize for the adopter's job to be done: "install Rindle tables in my Phoenix/Ecto app without losing control of my Repo, Oban, migrations, or rollback." Avoid exposing internal package migration layout unless explaining legacy compatibility.
- **D-38:** Copy tone should follow the brand system: calm, explicit, production-aware, no magic, no fear. Use the UI-SPEC labels `Migration:`, `Oban ownership:`, `Upgrade note:`, `Rollback:`, and `Verification:` when callouts are useful.
- **D-39:** Use portable Markdown only. Do not add docs CSS, shadcn/Radix/Tailwind, JS, custom admonition plugins, icons, or rendered documentation styling in this phase.
- **D-40:** If rendered docs styling is touched unexpectedly, use the current `brandbook/` tokens over older prompt material: Atkinson Hyperlegible for body, Space Grotesk for headings, JetBrains Mono for code, WCAG AA pairs, status labels paired with color, and no Rindle Green as small text on light surfaces.

### Rejected Alternatives And Footguns

- **D-41:** Reject deleting legacy packaged migration files in Phase 116. That would make existing applied versions look unresolved and turns a non-breaking phase into a breaking cleanup.
- **D-42:** Reject keeping `CreateObanTables` as normal greenfield behavior. It fails MIGRATE-02 by preserving the host-Oban collision.
- **D-43:** Reject keeping `Ecto.Migrator.migrations/2` as the sole doctor source of truth. Fresh `Rindle.Migration` installs will not mark all legacy package versions as applied.
- **D-44:** Reject hiding setup behind a public install task. It contradicts the UI-SPEC and adds generator drift as a new contract surface.
- **D-45:** Reject unpinned docs snippets (`Rindle.Migration.up()` only) for greenfield migration files. They are convenient but make old host migrations change meaning after dependency upgrades.

### Claude's Discretion

- Exact internal module decomposition under `Rindle.Migration` and helper modules.
- Exact marker table name, as long as it is clearly Rindle-owned, prefix-aware, not Ecto's `schema_migrations`, and covered by tests.
- Exact warning/error struct shape in doctor/runtime, as long as the semantics above are locked and existing stable IDs are preserved where practical.
- Exact prose transitions in docs, as long as the UI-SPEC terminology, labels, ordering, and safety copy are preserved.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Scope And Locked Decisions

- `.planning/ROADMAP.md` section "Phase 116: Versioned `Rindle.Migration` Module" - phase goal, Phase 115 dependency, requirements, and success criteria.
- `.planning/REQUIREMENTS.md` - MIGRATE-01, MIGRATE-02, and future v1.23 ISO23 requirements that Phase 116 prepares but must not implement.
- `.planning/STATE.md` - current v1.22 posture, hard release-coupling invariants, and Phase 116 status.
- `.planning/phases/116-versioned-rindle-migration-module/116-UI-SPEC.md` - locked documentation UX/copy contract; MUST read before docs changes.
- `.planning/phases/115-versioning-readme-positioning/115-CONTEXT.md` - Phase 115 docs structure and upgrade-guide decisions that Phase 116 must build on.
- `.planning/phases/113-evaluation-baseline-release-hygiene/113-CONTEXT.md` - host-app respectfulness and versioning/README weakness mapping that led to Phase 116.
- `.planning/seeds/SEED-005-software-quality-consolidation.md` - host-app respectfulness rationale and v1.22 -> v1.23 arc.

### Prompt And Brand Research

- `prompts/gsd-rindle-elixir-oss-dna.md` - public API discipline, NimbleOptions contracts, docs-contract verification, installer/adopter truth, and footguns.
- `prompts/phoenix-media-uploads-lib-deep-research.md` - Rindle domain model, adopter personas/JTBD, library ergonomics, and external ecosystem lessons.
- `prompts/gsd-rindle-research-index.md` - provenance for prompt research and sibling library evidence.
- `prompts/rindle-brand-book.md` - historical brand/voice seed; use only where newer `brandbook/` does not supersede it.
- `brandbook/README.md` - current brand system provenance and rule hierarchy.
- `brandbook/tokens/tokens.json` - current source of truth for colors, typography, spacing, focus, motion, and contrast rules if rendered docs styling is unexpectedly touched.

### Existing Migration And Runtime Code

- `lib/rindle/config.ex` - current `migrations_path/0`; keep for legacy compatibility unless planning proves it can be narrowed safely.
- `lib/rindle/ops/runtime_checks.ex` - current doctor migration status checks and Postgres catalog checks; primary integration point for hybrid migration health.
- `lib/mix/tasks/rindle.doctor.ex` - user-facing doctor task.
- `lib/mix/tasks/rindle.runtime_status.ex` - user-facing runtime status task.
- `lib/rindle/ops/runtime_status.ex` - runtime-status integration surface.
- `priv/repo/migrations/` - legacy packaged migration filenames; keep frozen for compatibility.
- `priv/repo/migrations/20260424205942_create_oban_tables.exs` - current bundled Oban migration; make non-authoritative/stubbed for Phase 116.

### Documentation Surfaces

- `README.md` - update `## Migrations` to the host-owned `Rindle.Migration` path and Oban ownership note.
- `guides/getting_started.md` - update step 3 around host migration ownership, `Rindle.Migration`, `Oban.Migration`, and doctor verification.
- `guides/upgrading.md` - add Phase 116 note under `## Unreleased / Next` using the Phase 115 section structure.
- `guides/operations.md` - preserve or adjust upgrade troubleshooting sequencing if migration wording changes.
- `guides/troubleshooting.md` - preserve or adjust migration/doctor troubleshooting language if statuses change.
- `RUNNING.md` - final verification source for local command choices.
- `CONTRIBUTING.md` - CI and release gate source of truth.

### Verification Surfaces

- `test/install_smoke/docs_parity_test.exs` - docs contract lock for README/getting-started/upgrading migration snippets and rejection of the old raw path.
- `test/install_smoke/support/generated_app_helper.ex` - generated Phoenix app migration runner and legacy upgrade preparer.
- `test/install_smoke/generated_app_smoke_test.exs` - generated-app proof that host Oban and Rindle migrations run correctly.
- `test/rindle/ops/runtime_checks_test.exs` - doctor migration health and status taxonomy tests.
- `test/rindle/doctor_test.exs` - CLI-facing doctor output tests.
- `test/rindle/runtime_status_task_test.exs` - runtime-status CLI behavior tests.
- `test/rindle/ops/runtime_status_test.exs` - runtime-status behavior tests.
- `test/rindle/domain/migration_test.exs` - existing schema proof; extend or supplement for `Rindle.Migration`.
- `mix.exs` - package `:files` includes `priv/repo/migrations`; update only if planning proves package semantics require it.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `test/install_smoke/docs_parity_test.exs` already asserts docs order and migration language. It has helpers suited for rejecting the old raw install path and proving README/getting-started/upgrading converge.
- `test/install_smoke/support/generated_app_helper.ex` already creates host migration files and migration runner scripts. It is the right place to shift generated-app proof from package-path `Ecto.Migrator.run/4` to real host migrations calling `Oban.Migration` and `Rindle.Migration`.
- `lib/rindle/ops/runtime_checks.ex` already has stable check IDs, migration pending/unresolved checks, and catalog checks for resumable schema. Reuse that shape for hybrid migration health rather than creating a separate diagnostics subsystem.
- `NimbleOptions` is already a direct dependency and used in `lib/rindle/profile/validator.ex`; it is appropriate for validating `Rindle.Migration` keyword options.

### Established Patterns

- Rindle locks adopter-facing docs claims with ExUnit docs parity tests.
- Rindle values adopter-proof over package-only proof: generated Phoenix app smoke tests are a contract surface, not incidental fixtures.
- Planning truth favors explicit non-goals and named footguns. Phase 116 must name legacy packaged migrations as compatibility only.
- The current release-train invariants remain hard boundaries: do not rename `ci.yml` / `name: CI`; do not weaken `CI Summary`; do not weaken full release verification.

### Integration Points

- `Rindle.Migration` should live under `lib/rindle/` and be included in public docs/API allowlists if such tests exist.
- The module must reproduce the Rindle-owned table schema currently represented by all non-Oban packaged migrations.
- Doctor/runtime should bridge old file-history installs and new module installs without asking users to replay or delete old migrations.
- Docs and generated app helpers should use the same compact host migration snippet so examples and proof cannot drift.

</code_context>

<specifics>
## Specific Ideas

- Recommended greenfield Rindle migration snippet:

  ```elixir
  defmodule MyApp.Repo.Migrations.InstallRindle do
    use Ecto.Migration

    def up, do: Rindle.Migration.up(version: 1)
    def down, do: Rindle.Migration.down(version: 1)
  end
  ```

- Recommended Oban ownership snippet:

  ```elixir
  defmodule MyApp.Repo.Migrations.AddObanJobs do
    use Ecto.Migration

    def up, do: Oban.Migration.up()
    def down, do: Oban.Migration.down(version: 1)
  end
  ```

- Required reader path: host owns Repo and Oban config -> host migration calls `Oban.Migration` -> host migration calls `Rindle.Migration` -> `mix ecto.migrate` -> `mix rindle.doctor`.
- Required legacy copy: existing apps that already applied Rindle's packaged migrations can leave them in place; the new module is the documented install path going forward and does not require replaying or deleting legacy migration files.
- Required rollback copy: `Rindle.Migration.down/1` is destructive, backup first, removes Rindle-owned tables only, and does not manage `oban_jobs`.
- Official ecosystem analogs consulted during discussion: Ecto migrations and `schema_migrations`, Oban's versioned migration module and prefix support, Rails Active Storage's explicit install/migration path, and Rindle prompt research on Active Storage/Shrine/Spatie footguns.

</specifics>

<deferred>
## Deferred Ideas

- Public `mix rindle.*` or Igniter install generator - potentially good future onboarding DX, but out of scope for Phase 116 and explicitly rejected by the UI-SPEC for this phase.
- Breaking default Postgres schema isolation (`rindle` schema default, `prefix: "public"` opt-out, table move migration) - v1.23 / 0.4.0.
- Release/public HexDocs proof lock beyond source docs parity and generated-app smoke - useful if package/source drift reappears, but not required for this phase unless planning discovers release packaging risk.

### Reviewed Todos (not folded)

- `2026-06-19-fix-docker-demo-startup-warnings.md` - deferred as unrelated tooling/Docker demo polish. It matched Phase 116 only through broad `yml`/`lib` keywords and does not clarify migration API, Oban ownership, docs, or runtime compatibility.

</deferred>

---

*Phase: 116-versioned-rindle-migration-module*
*Context gathered: 2026-07-01*
