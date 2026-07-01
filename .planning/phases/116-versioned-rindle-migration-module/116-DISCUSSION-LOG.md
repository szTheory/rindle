# Phase 116: versioned-rindle-migration-module - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md - this log preserves the alternatives considered.

**Date:** 2026-07-01
**Phase:** 116-versioned-rindle-migration-module
**Areas discussed:** Migration API surface, Packaged migration history, Doctor/runtime compatibility, Docs and proof depth

---

## Method

The user requested one-shot recommendations for all four gray areas, researched by subagents, with Elixir/Ecto/Phoenix idioms, external ecosystem lessons, DX/JTBD, SRE/DevOps, architecture, documentation UX, and local prompt/brand context considered.

Four read-only subagents were dispatched:

- Kepler - Migration API surface.
- Carson - Packaged migration history.
- Meitner - Doctor/runtime compatibility.
- Volta - Docs and proof depth / developer experience.

The orchestrator also read local project context, Phase 115/116 artifacts, current code/docs/tests, `prompts/`, `brandbook/`, and official primary docs for Ecto, Oban, and Rails Active Storage.

---

## Migration API Surface

| Option | Description | Selected |
|--------|-------------|----------|
| Strict Oban-style `Rindle.Migration.up(opts)` / `down(opts)` with docs-pinned `version: 1` | Matches Oban's proven wrapper pattern, normal host `mix ecto.migrate`, deterministic migration files, future upgrade path, prefix-ready, excludes `oban_jobs`. | yes |
| Literal Oban defaults with unpinned snippets | Familiar and concise, but old generated migrations can change meaning after dependency upgrades. | no |
| Keep packaged `priv/repo/migrations` and wrap `Ecto.Migrator.run/4` | Minimal code and preserves current inspection model, but does not really replace the raw 15-file path or fix Oban ownership. | no |
| Public Mix/Igniter install generator | Strong onboarding DX, but explicitly out of scope and adds generator drift. | no |

**User's choice:** The user delegated the decision and asked for a perfect coherent recommendation.

**Notes:** Recommendation is a consumer-first Oban-style module with docs-pinned `version: 1`, validated keyword opts, `prefix: "public"` default, no public install task, and no `oban_jobs` ownership.

---

## Packaged Migration History

| Option | Description | Selected |
|--------|-------------|----------|
| Freeze legacy files, stub bundled Oban migration, make `Rindle.Migration` source of truth | Preserves old `schema_migrations` visibility and avoids file-not-found drift while stopping fresh Rindle installs from creating `oban_jobs`. | yes |
| Delete or move `priv/repo/migrations` | Clean future package surface, but breaks legacy inspection and violates non-breaking scope. | no |
| Keep all 15 files executable as the primary path | Lowest rewrite effort, but preserves the host Oban collision and raw package-path install. | no |
| Add public generator/copy task | Familiar from other ecosystems, but out of phase and conflicts with the current UI-SPEC. | no |

**User's choice:** The user delegated the decision and asked for coherent recommendations.

**Notes:** Freeze filenames, make `CreateObanTables` non-authoritative/no-op, implement current Rindle-owned schema in `lib/` behind `Rindle.Migration`, and keep package files for legacy compatibility only.

---

## Doctor/runtime Compatibility

| Option | Description | Selected |
|--------|-------------|----------|
| Keep `Ecto.Migrator.migrations/2` authoritative | Smallest change, but breaks fresh `Rindle.Migration` installs and keeps file-history too strict. | no |
| Schema/table introspection only | Works for new and legacy installs, but can miss semantic version drift. | no |
| `Rindle.Migration` version marker only | Clean Oban-like model, but marker can lie and legacy installs need inference. | no |
| Hybrid health model | Version marker + catalog checks + legacy Ecto compatibility + Oban preflight. | yes |

**User's choice:** The user delegated the decision and asked for coherent recommendations.

**Notes:** Doctor should error on incomplete Rindle-owned schema or missing required Oban readiness, warn for healthy legacy file-history drift, and accept both new module installs and valid legacy installs.

---

## Docs and Proof Depth

| Option | Description | Selected |
|--------|-------------|----------|
| Docs parity only | Fast but does not prove runtime behavior. | no |
| Greenfield generated-app proof | Proves a host migration calling `Rindle.Migration`, but does not lock legacy/runtime compatibility by itself. | no |
| Contract lock: docs + generated app + legacy compatibility + rollback copy | Locks public install path, Oban ownership, generated app behavior, legacy validity, and rollback copy. | yes |
| Release/public proof lock | Useful for package/source drift, but too broad unless packaging risk appears. | no |

**User's choice:** The user delegated the decision and asked for coherent recommendations.

**Notes:** README, getting-started, upgrading, docs parity, generated-app smoke, doctor/runtime tests, and migration API tests should all move together.

---

## Claude's Discretion

- Exact internal helper/module decomposition for `Rindle.Migration`.
- Exact marker table name and private query helpers.
- Exact copy transitions in docs, within the UI-SPEC terminology and rollback safety copy.
- Exact test helper structure, as long as docs/proof semantics are locked.

## Deferred Ideas

- Public `mix rindle.*` or Igniter installer for future onboarding.
- v1.23 breaking default schema isolation.
- Docker demo startup warnings todo, unrelated to Phase 116 migration scope.
