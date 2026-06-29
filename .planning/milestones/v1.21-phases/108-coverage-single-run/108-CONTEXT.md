# Phase 108: Coverage single-run - Context

**Gathered:** 2026-06-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Make every **default-suite CI lane** run the ExUnit suite **exactly once** per matrix
cell, with the single run emitting **both** the merge-blocking console coverage gate
**and** `cover/excoveralls.json` for artifact upload. Today each lane runs the entire
suite twice (gate run + separate `mix coveralls.json` run), which doubles test
wall-clock and **doubles `:epipe` (broken-pipe) flake exposure** on the PR critical
path — the SEED-004 (a) win.

**Scope:** `.github/workflows/ci.yml` (3 lanes) + `mix.exs` config + `RUNNING.md` docs only.
**Hard out of scope:** zero `lib/` change; no `ci.yml` / `name: CI` rename; `CI Summary`
aggregate untouched; release full-verification gate unchanged; the *remaining* single
run's broken-pipe race is **Phase 109's** job (EPIPE), not this phase's.

</domain>

<decisions>
## Implementation Decisions

### Mechanism (locked by research — `v1.21-COVERAGE-SINGLE-RUN.md`, HIGH confidence)
- **D-01:** Use `mix coveralls.multiple --type local --type json --slowest 20` for
  single-run dual-output. `--type local` routes through `ExCoveralls.Local.execute/2`
  which still calls `ensure_minimum_coverage` → `exit({:shutdown,1})` — i.e. the gate is
  **byte-identical** to today's `mix coveralls`. `--type json` writes
  `cover/excoveralls.json` as a side-output of the *same* test execution.
- **D-02:** The merge-blocking gate's pass/fail is **never** derived from
  `coveralls.json`'s exit code (`ExCoveralls.Json.execute/2` does NOT enforce
  `minimum_coverage` — proven in vendored 0.18.5 source). The ci.yml invariant comment's
  *intent* (don't let the non-gating JSON formatter become the gate) is **preserved**;
  only the literal task name changes from `coveralls` → `coveralls.multiple` (still the
  `local` analyzer). Update the comment to say so.
- **Rejected paths (do not revisit):** (b) `coveralls.json`-as-gate — non-gating, silently
  drops threshold enforcement; (c) `mix test --cover` + separate JSON — still 2 runs;
  (d) `--export-coverage`/`--import-cover` bridge — viable fallback only, strictly more
  moving parts than (a). Hold (d) as contingency only if `coveralls.multiple` proves
  insufficient.

### Per-lane changes (decision: **2b — drop redundant JSON**, user-confirmed 2026-06-27)
- **D-03 — `quality` lane** (`ci.yml` ~184–211, the PR gate, matrix 1.15/26 + 1.17/27):
  replace the gating step's `mix coveralls --slowest 20` with
  `mix coveralls.multiple --type local --type json --slowest 20` (keep the `tee` +
  `$GITHUB_STEP_SUMMARY` run-timing block verbatim — OBS-02). **Delete** the standalone
  `Generate coverage JSON artifact` step (~198–202). Update the leading invariant comment.
- **D-04 — `integration` lane** (`ci.yml` ~370–399): gate **stays plain `mix test <files>
  --include integration/minio --slowest 20`** (no coverage). **Delete** the redundant
  standalone `mix coveralls.json` step (~387–389) — it was a 100% redundant full suite
  re-run feeding an artifact nobody consumes. No fold to `coveralls.multiple` here.
- **D-05 — `adoption-demo` / install-smoke lane** (`ci.yml` ~646–662): **delete** the
  standalone `MIX_ENV=test mix coveralls.json` step (~649–651) — a full redundant suite
  run with no gate and no consumer. This job's gate is install-smoke/version checks, not
  the unit suite.
- **D-06 — Upload steps preserved:** keep all three `Upload JUnit + coverage artifacts`
  steps (`if: always()`, `if-no-files-found: warn`). They still upload the JUnit XML
  (independently valuable); for `integration`/`adoption` the now-absent
  `cover/excoveralls.json` is tolerated by the existing `warn` behavior. Only the
  `quality` lane will actually carry coverage JSON going forward — and that is the only
  lane anything could ever want it from.

### Rationale for 2b (drop, not fold)
- **D-07:** Codebase scout confirmed **no `download-artifact`, no Codecov, no
  Coveralls.io, no aggregate-merge consumer** anywhere in `.github/`. The integration +
  adoption coverage JSON artifacts are produced but never read. Dropping them loses
  nothing and maximises `:epipe`-surface reduction. If a Codecov/aggregate consumer is
  ever introduced later, revisit by folding those lanes via `coveralls.multiple` (2a).

### mix.exs config
- **D-08:** Add `"coveralls.multiple": :test` to `cli/0` `preferred_envs` as a one-line
  explicitness add (harmless, additive — the task already inherits `:test` via the
  existing `coveralls`/`coveralls.json` entries, but naming it documents intent). No other
  `mix.exs` change; `mix ci`'s final `test` task is **unchanged** (the simple
  merge-blocking gate alias stays simple; dual-output is a CI-only concern).

### Documentation parity (COV-04, user-confirmed: RUNNING.md)
- **D-09:** Document the exact CI coverage command —
  `mix coveralls.multiple --type local --type json --slowest 20` — in **RUNNING.md near
  the existing coverage / merge-blocking lane table** (the `quality` row at RUNNING.md:62).
  Note that the *gate alone* is still reproduced by `mix coveralls` (unchanged). This gives
  local↔CI parity in one documented command.

### Claude's Discretion
- Exact wording of the updated ci.yml invariant comment (must convey: `--type local` =
  console gate incl. `minimum_coverage`; `--type json` = artifact; one suite execution;
  cite `Mix.Tasks.Coveralls.Multiple`).
- Exact RUNNING.md phrasing/placement within the coverage section.
- Whether to keep the `MIX_ENV=test` prefix anywhere (preferred_envs already supplies it;
  belt-and-suspenders is fine to drop or keep).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase research (locked recommendation — read first)
- `.planning/research/v1.21-COVERAGE-SINGLE-RUN.md` — the LOCKED option-(a) recommendation
  with vendored-source proof of gate semantics, the exact 3-lane change list, and the
  requirement-ready bullets. §7 is the authoritative change spec.

### Requirements
- `.planning/REQUIREMENTS.md` §COV (COV-01..04) — the merge-blocking acceptance bullets.

### Files to change
- `.github/workflows/ci.yml` — lanes at ~184–211 (`quality`), ~370–399 (`integration`),
  ~646–662 (`adoption-demo`/install-smoke).
- `mix.exs` — `cli/0` `preferred_envs` (~47–59); `test_coverage: [tool: ExCoveralls]`
  (line 43); `aliases` `ci`/`test` (~289+) — read but `ci` stays unchanged.
- `RUNNING.md` — coverage / merge-blocking lane table (~line 62).

### ExCoveralls source (authoritative gate-semantics proof — vendored 0.18.5)
- `deps/excoveralls/lib/mix/tasks.ex` — `Coveralls.Multiple` (repeated `--type` parsing),
  `do_run`, `parse_common_options` (forwards `--slowest`/`--include` to `mix test`).
- `deps/excoveralls/lib/excoveralls.ex` — `execute/3` formatter fan-out over one stat set.
- `deps/excoveralls/lib/excoveralls/local.ex` — `ensure_minimum_coverage` (the gate).
- `deps/excoveralls/lib/excoveralls/json.ex` — proves `coveralls.json` does NOT gate.

### Milestone constraints (do not violate)
- `.planning/PROJECT.md` — security invariants; v1.20 CI invariants (no `ci.yml`/`name: CI`
  rename; `CI Summary` is the SOLE required check, `skipped`==pass; release gate
  unchanged); decide-by-default decision contract.

### Out of scope (confirmed not double-running — do not touch)
- `.github/workflows/nightly.yml` ~115 — already single-run `mix coveralls` (gate only, no
  JSON step). NOT a default-suite PR lane; leave as-is.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `mix coveralls.multiple` (ExCoveralls 0.18.5, already in `mix.lock` / vendored in
  `deps/`) — purpose-built "many formatters, one run" task; no new dependency, no version
  bump.
- The existing `tee /tmp/test.out` + `$GITHUB_STEP_SUMMARY` run-timing block in the
  `quality` lane (OBS-02 from v1.20) — preserve verbatim, just change the `run:` command.
- The three `Upload JUnit + coverage artifacts` steps already use
  `if-no-files-found: warn`, so they tolerate a missing `cover/excoveralls.json` with no
  edit needed.

### Established Patterns
- `mix.exs cli/0` `preferred_envs` already wires `coveralls*` tasks to `MIX_ENV=test`, so
  `coveralls.multiple` inherits the right env automatically.
- `mix ci` alias mirrors ONLY the merge-blocking set and ends in the gating unit suite;
  HARD-03 (D-07) keeps it `:test`. Do not add coverage-JSON concerns to `mix ci`.

### Integration Points
- The merge-blocking signal is the `quality` lane's console gate feeding `CI Summary`
  (the SOLE required check). Coverage JSON is a pure side-artifact — changing how it's
  produced must not alter the gate's red/green semantics.

</code_context>

<specifics>
## Specific Ideas

- Collapsing to one run makes the red/green signal **honest**: today a job can show "gate
  passed but job is red" when the flake lands on the *second* (JSON) run — observed twice
  on 2026-06-26 (`ffmpeg_test.exs:32`, `lifecycle_repair_test.exs:122`, both cleared on
  rerun). The single visible contributor-facing change is "tests run once now."
- Inline ci.yml comment is mandatory because `coveralls.multiple` is README-undocumented
  (exists + tested upstream, but a maintainer reading only HexDocs may not recognize it).

</specifics>

<deferred>
## Deferred Ideas

- **Re-add coverage JSON to integration/adoption lanes via `coveralls.multiple` (2a)** —
  only if a future Codecov / Coveralls.io / aggregate-merge consumer is introduced. No
  consumer exists today (D-07), so deferred, not done.
- **`minimum_coverage` threshold enforcement** — there is currently NO coveralls config and
  `minimum_coverage` defaults to `0`, so the "gate" today is just "tests pass + coverage
  computed." Introducing a real threshold is a separate decision/phase, out of scope here.
  (This phase keeps the *machinery* that would enforce it — the `local` analyzer — intact.)
- **The remaining single run's broken-pipe `:epipe` race** — that is **Phase 109** (EPIPE,
  `lib/rindle/av/subprocess.ex`). This phase only removes the *redundant* exposure.

</deferred>

---

*Phase: 108-coverage-single-run*
*Context gathered: 2026-06-27*
