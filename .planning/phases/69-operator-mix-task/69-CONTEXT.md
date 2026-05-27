# Phase 69: Operator mix task - Context

**Gathered:** 2026-05-27 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Ship a documented `mix rindle.*` operator surface for batch owner-erasure preview
and execute (**OPS-02**). Phase 69 delivers the Mix task, `@moduledoc` CLI
contract (input format, dry-run default, exit codes), and public-boundary test
registration — not batch orchestration logic (Phase 68), not hermetic proof
matrix (Phase 70), and not guide body updates beyond cross-links in `@moduledoc`
(Phase 70 / TRUTH-03).

</domain>

<decisions>
## Implementation Decisions

### Task naming & architecture
- **D-01:** Ship `Mix.Tasks.Rindle.BatchOwnerErasure` as
  `mix rindle.batch_owner_erasure`.
- **D-02:** The Mix task is a thin CLI wrapper over the shipped facade — call
  `Rindle.preview_batch_owner_erasure/2` or `Rindle.erase_batch_owner_erasure/2`
  directly. Do **not** introduce a new `Rindle.Ops.*` service module; batch
  orchestration already lives on `Rindle` (Phase 68 D-02).

### Owner identity input
- **D-03:** Require `--owners-file PATH` pointing to a JSON array of owner
  identities. Each entry uses the frozen `owner_ref/0` shape:
  `{"owner_type": "<module string>", "owner_id": "<uuid>"}`.
- **D-04:** Parse each entry into a lightweight owner struct `%Module{id: uuid}`
  where `Module` is resolved via `String.to_existing_atom/1` (same atom-safety
  pattern as `Mix.Tasks.Rindle.CleanupOrphans` and `BackfillMetadata`). No DB
  owner-row fetch — `OwnerErasure.owner_info/1` only needs `__struct__` and
  `id`.
- **D-05:** Invalid JSON, unknown modules, malformed UUIDs, or empty owner lists
  fail fast with operator-oriented CLI errors before calling the facade.

### Dry-run default & execute opt-in
- **D-06:** Default mode is preview (dry-run): call
  `preview_batch_owner_erasure/2` when no destructive flag is given.
- **D-07:** Destructive execute requires explicit opt-in via `--no-dry-run` or
  `--execute` (alias), mirroring `cleanup_orphans` (`--dry-run` /
  `--no-dry-run` / `--live`). Explicit `--dry-run` remains valid and matches the
  default.

### Output format & exit codes
- **D-08:** Default output is a human-readable text summary: mode banner
  (`[DRY RUN]` when preview), owner count, and aggregate bucket counts from
  `owner_erasure_batch_report/0` (`attachments_to_detach`,
  `assets_to_purge`, `retained_shared_assets`).
- **D-09:** `--format json` emits the full `owner_erasure_batch_report` map
  (Jason-encoded, pretty-printed) for compliance/CI pipelines — same text/json
  split precedent as `mix rindle.runtime_status`.
- **D-10:** Exit `0` on `{:ok, _}`. Exit `1` on any `{:error, _}` including
  `:empty_batch`, `{:batch_too_large, _}`, and
  `{:batch_owner_failed, partial_report}` — print the partial report (when
  present) before exiting non-zero so operators can audit completed owners.
- **D-11:** Forward optional `--max-owners N` to batch opts (Phase 67 D-08).

### Documentation & public boundary
- **D-12:** `@moduledoc` is the canonical CLI reference: usage, options, JSON
  input schema with example, exit codes, safety default, and links to
  `guides/operations.md` and `guides/user_flows.md`.
- **D-13:** Add `Mix.Tasks.Rindle.BatchOwnerErasure` to the public modules list
  in `test/rindle/api_surface_boundary_test.exs`.
- **D-14:** Defer guide body updates (operations index section, user_flows batch
  lane, docs parity) to Phase 70 (TRUTH-03). Phase 69 may cross-link from
  `@moduledoc` only.

### Claude's Discretion
- Exact text summary field ordering and per-owner detail level in default text
  output (aggregate-only vs brief per-owner lines)
- Whether `--execute` alone or `--no-dry-run` is the primary documented flag
  (both supported; pick one as the headline in moduledoc examples)
- Mix task test file naming and whether to reuse batch test fixtures from
  `owner_erasure_batch_test.exs`
- Error message wording for invalid `--owners-file` entries

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and requirements
- `.planning/ROADMAP.md` — Phase 69 goal, success criteria, phase boundaries 69–70
- `.planning/REQUIREMENTS.md` — OPS-02
- `.planning/PROJECT.md` — v1.14 operator-surface wedge, dry-run safety defaults
- `.planning/phases/68-batch-erasure-implementation/68-CONTEXT.md` — batch orchestration decisions, partial-failure tuple
- `.planning/phases/67-bulk-erasure-policy-contract/67-CONTEXT.md` — owner_ref shape, batch limits, operator mix precedent reference

### Shipped batch API (delegation target)
- `lib/rindle.ex` — `preview_batch_owner_erasure/2`, `erase_batch_owner_erasure/2`, `owner_erasure_batch_report/0`, `validate_batch_owners/2`, `owner_ref/1`
- `lib/rindle/internal/owner_erasure.ex` — `owner_info/1` struct contract (`__struct__` + `id`)
- `lib/rindle/error.ex` — `Rindle.Error.message/1` branches for batch errors

### Operator Mix task patterns (follow these)
- `lib/mix/tasks/rindle.cleanup_orphans.ex` — dry-run default, `--no-dry-run`/`--live`, exit codes, `@moduledoc` depth
- `lib/mix/tasks/rindle.runtime_status.ex` — `--format text|json` output split
- `lib/mix/tasks/rindle.backfill_metadata.ex` — thin wrapper, `String.to_existing_atom/1` module resolution
- `test/rindle/api_surface_boundary_test.exs` — public mix task registration

### Support truth (Phase 70 updates body; Phase 69 cross-links only)
- `guides/operations.md` — thin task index; `@moduledoc` is authoritative per D-18
- `guides/user_flows.md` — single-owner erasure story; batch lane deferred to Phase 70

### Batch behavior tests (reference for CLI test fixtures)
- `test/rindle/owner_erasure_batch_test.exs` — preview/execute/idempotency integration
- `test/rindle/owner_erasure_batch_boundary_test.exs` — empty/over-limit/dedupe
- `test/rindle/owner_erasure_batch_error_test.exs` — operator error messaging

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Rindle.preview_batch_owner_erasure/2` and `Rindle.erase_batch_owner_erasure/2` — sole delegation targets
- `owner_erasure_batch_report/0` type and aggregate bucket shape — JSON/text output source
- `Mix.Tasks.Rindle.CleanupOrphans` — dry-run default + destructive opt-in UX template
- `Mix.Tasks.Rindle.RuntimeStatus` — `--format text|json` CLI output pattern
- `owner_erasure_batch_test.exs` `%User{id: uuid}` fixtures — lightweight struct pattern for task tests

### Established Patterns
- Mix tasks use `@requirements ["app.start"]` and `OptionParser.parse/2` with strict opts
- Operator module strings resolved via `String.to_existing_atom/1` to prevent atom table exhaustion
- `@moduledoc` is canonical CLI contract; `guides/operations.md` is a thin cross-link index
- Public mix tasks registered in `api_surface_boundary_test.exs` compiled-docs boundary

### Integration Points
- New file: `lib/mix/tasks/rindle.batch_owner_erasure.ex`
- Update: `test/rindle/api_surface_boundary_test.exs` — add task to `@public_modules`
- New task tests (e.g. `test/mix/tasks/rindle.batch_owner_erasure_test.exs` or under `test/rindle/`)
- Phase 70 adds guide sections and docs parity — not Phase 69 scope

</code_context>

<specifics>
## Specific Ideas

- JSON owners file keeps DSAR/compliance export pipelines simple — one audited input artifact per run
- Partial batch failure must still print `partial_report` before exit 1 so operators know which owners completed
- Safety default matches cleanup_orphans: preview unless operator explicitly opts into execute

</specifics>

<deferred>
## Deferred Ideas

- Guide body updates for batch erasure lane in `guides/operations.md` and `guides/user_flows.md` — Phase 70 (TRUTH-03)
- Hermetic proof matrix for batch CLI + API — Phase 70 (PROOF-05)
- Stdin/NDJSON owner input (file-only is sufficient for v1.14 OPS-02)
- DB-backed owner resolution (load full Ecto schemas from repo) — host-app structs are sufficient
- Cron/worker equivalent for batch erasure — out of scope; host-app concern
- Force-delete policy, admin LiveView erasure UI — separate milestones

</deferred>

---

*Phase: 69-operator-mix-task*
*Context gathered: 2026-05-27*
