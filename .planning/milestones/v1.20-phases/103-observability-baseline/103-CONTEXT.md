# Phase 103: Observability / Baseline - Context

**Gathered:** 2026-06-20 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Make the existing `.github/workflows/ci.yml` pipeline **self-reporting** and capture a
**committed baseline** so every later v1.20 restructuring decision (Phases 104–107) is
evidence-backed — with **zero gate-behavior change and zero topology change**.

This phase runs against the current ~14-job `ci.yml` **as-is**. It adds observability and
produces missing data; it does **not** restructure, rename, split, or re-gate anything.

**In scope:** OBS-01 (per-job/per-step timing + cache hit/miss in `$GITHUB_STEP_SUMMARY`),
OBS-02 (`mix test --slowest 20`, compile profile, `schedulers_online`, ExUnit seed; JUnit +
coverage artifacts), OBS-03 (committed baseline table + captured *live* branch-protection
required-check names — captured **before** any restructuring).

**Out of scope (later phases):** composite `setup-elixir` action and cache-key correctness
(Phase 104); `CI Summary` aggregate + branch-protection flip (Phase 105); lane/trigger split
(Phase 106); async/partition/supply-chain/`mix ci` (Phase 107).
</domain>

<decisions>
## Implementation Decisions

### Timing + cache hit/miss surfacing (OBS-01)
- **D-01:** Surface per-job/per-step timing and cache hit/miss into `$GITHUB_STEP_SUMMARY`
  using the append idiom already established in this repo (`branch-protection-apply.yml:28-33`).
  Additions are purely additive — no `run:` command or gate logic is modified.
- **D-02:** Add an `id:` to the existing `actions/cache@v4` restore steps so `cache-hit` is
  readable in the summary. Today only the PLT cache step sets one (`ci.yml:122`); the
  deps/`_build` restore steps (e.g. `ci.yml:65-77`, `228-240`) currently expose nothing.
- **D-03 (researcher-resolved):** The per-step *timing mechanism* is left to the
  phase-researcher: choose between (a) inline `date +%s%N`/`SECONDS` timestamps wrapped around
  existing steps, or (b) a single aggregator job (`needs: [all jobs]`, `if: always()`) that
  pulls authoritative native durations once via `gh api .../runs/{id}/jobs`. Constraint: if (b),
  it may add `actions: read` **only on that observability job** (least-privilege, additive) —
  it must NOT widen the workflow-level `permissions: contents: read` (`ci.yml:18-19`).

### Slowest-tests / compile / schedulers / seed (OBS-02)
- **D-04:** Surface `mix test --slowest 20` and per-step timing in the **representative
  `quality` job AND the real long-pole jobs (`integration`, `package-consumer`)** — NOT
  quality-only. Rationale: ROADMAP line 228 explicitly names per-step `package-consumer` timing
  + slowest-test evidence as the *input* to the Phase 106 lane split; measuring only `quality`
  would under-measure the actual bottleneck and starve the later decisions of evidence.
- **D-05:** Surface `System.schedulers_online()` (runner cores), a `mix compile --profile time`
  (or equivalent wrap of the existing compile step), and the **ExUnit seed** in the run summary.
  The seed is currently implicit — `test/test_helper.exs:31` is a bare `ExUnit.start(exclude: …)`
  with no seed pin/echo, so the seed must be captured from `mix test` output.

### JUnit + coverage artifacts (OBS-02)
- **D-06:** Add a **test-only** JUnit formatter dependency `{:junit_formatter, "~> 3.4",
  only: :test}` to `mix.exs` and wire it in `test/test_helper.exs` (config + `formatters:` on
  `ExUnit.start`). This satisfies "zero `lib/` change": test-only deps are excluded from the Hex
  package `files:` allowlist (`mix.exs:278-280`) and never ship. (Chosen over a hand-rolled
  custom formatter — standard ecosystem approach, less to own.) *Exact version compat with the
  1.15/OTP26 + 1.17/OTP27 matrix → confirm in research.*
- **D-07:** Produce a coverage artifact via ExCoveralls — already the coverage tool
  (`test_coverage: [tool: ExCoveralls]` `mix.exs:43`; `mix coveralls` `ci.yml:118`) with
  `coveralls.json`/`coveralls.html` already `preferred_envs`-mapped (`mix.exs:50-53`). Emit the
  artifact and upload JUnit + coverage via `actions/upload-artifact@v4`. No gate change — the
  pass/fail check stays exactly as today.

### Baseline + live required-check capture (OBS-03)
- **D-08:** Produce the baseline (per-job avg + p95 + rerun/flake rate) via a **committed helper
  script under `scripts/ci/`** that pulls recent `ci.yml` run/job timings via `gh`/`gh api`
  (matching the existing `scripts/ci/` pattern — `cohort_demo_smoke.sh`, `install_ffmpeg.sh`,
  `adoption_demo_e2e.sh`). A scripted/reproducible baseline (not eyeballed reruns) is required so
  the Phase 107 "regression vs baseline" check has a real reference.
- **D-09:** Read the **actual live** branch-protection required-check names via the
  branch-protection API and **diff them against the static expected list in
  `scripts/setup_branch_protection.sh`**. The repo already encodes the *expected* list there
  (incl. `--print-expected`); OBS-03's job is to verify the *live* protection matches it and
  record the live names verbatim — the authoritative input the Phase 105 flip depends on.
- **D-10:** Commit the baseline table + captured live required-check names to an **internal
  `.planning/` doc** (e.g. `103-BASELINE.md` in this phase dir) — deliberately NOT into
  shipped/adopter-visible docs (`RUNNING.md`/`README`/HexDocs `extras`), to keep internal CI
  noise out of the published Hex package (`files:`/`extras` allowlists, `mix.exs:154-172,278-280`).
- **D-11:** This must be captured **before any restructuring change** (Phases 104+). It is the
  load-bearing gate for the rest of v1.20.

### No-composite invariant for this phase
- **D-12:** All observability stays inline in `ci.yml` (+ `scripts/ci/` helper). Do **not**
  create the `.github/actions/setup-elixir` composite action here — that is explicitly Phase 104.
  Creating it now would violate this phase's topology-freeze.

### Hard invariants (highest blast radius — do not break)
- **D-13:** Never rename `ci.yml`'s file or its `name: CI` — release-train coupling via
  `release-please-automerge.yml` + `gate-ci-green` (which filters `data.workflow_runs` by
  `workflow_id: 'ci.yml'` + head_sha). Confirmed in `release.yml` (~line 180).
- **D-14:** Zero gate-behavior change: the same checks are required and the same PRs pass/fail
  as on the pre-phase baseline. Every addition is advisory/observational only.

### Claude's Discretion
- D-03 timing mechanism (inline timestamps vs aggregator job) — researcher/planner choice within
  the stated permission constraint.
- Exact artifact naming, retention days, and summary-table formatting — planner choice.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/REQUIREMENTS.md` — OBS-01, OBS-02, OBS-03 (authoritative acceptance criteria) +
  "Out of Scope" anti-features.
- `.planning/ROADMAP.md` — Phase 103 detail (Goal, Success criteria 1–4, Research flag) and the
  load-bearing dependency-order note.
- `.github/workflows/ci.yml` — the ~14-job pipeline being instrumented (quality, optional-
  dependencies, integration, contract, proof, package-consumer, adoption-demo-unit,
  cohort-demo-smoke, adopter, mux-soak, gcs-soak, package-consumer-gcs-live, …).
- `scripts/setup_branch_protection.sh` — static *expected* required-check list (+
  `--print-expected`); diff target for OBS-03.
- `.github/workflows/release-please-automerge.yml` + `release.yml` (`gate-ci-green`) — the
  release-train coupling that pins `ci.yml`'s filename + `name: CI`.
- `test/test_helper.exs` — current bare `ExUnit.start(exclude: …)`; no seed pin, no formatters.
- `mix.exs` — `ExCoveralls` config (`:43`, `:50-53`), Hex `files:` allowlist (`:278-280`),
  HexDocs `extras` (`:154-172`); where the test-only `junit_formatter` dep lands.
- `scripts/ci/` — existing CI helper-script pattern (home for the new baseline collector).

**Research flags carried forward for the phase-researcher** (ROADMAP flags this phase as
data-producing — these are unknowns, not patterns):
- Exact JSON shape/field names of the branch-protection `required_status_checks` API
  (`contexts` vs `checks[].context` differs across GitHub API versions) — needed to diff live
  names against `setup_branch_protection.sh`.
- Whether `gh run list`/`gh api .../runs/{id}/jobs` exposes rerun count directly, or whether the
  rerun/flake rate must be derived from `run_attempt` across runs.
- `junit_formatter` version compatible with the 1.15/OTP26 + 1.17/OTP27 matrix (`ci.yml:29-32`)
  and its required ExUnit config.
- Actual runner vCPU / `schedulers_online`, real p95/rerun, per-step `package-consumer` timing,
  slowest tests — produced *by* this phase.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `$GITHUB_STEP_SUMMARY` append idiom already used in `branch-protection-apply.yml:28-33`.
- `scripts/ci/` already holds CI helper scripts → home for the baseline collector.
- ExCoveralls already wired (`mix.exs:43,50-53`; `mix coveralls` at `ci.yml:118`) — coverage
  artifact needs no new tooling, just a task swap/sibling step + upload.
- `scripts/setup_branch_protection.sh` already encodes the expected required-check list → OBS-03
  verifies live-vs-expected rather than inventing names.
- PLT cache step already sets `id: plt-cache` (`ci.yml:122`) — pattern to replicate on the
  deps/`_build` restore steps for `cache-hit`.

### Established Patterns
- Workflow-level `permissions: contents: read` (`ci.yml:18-19`) is intentionally tight; any
  `actions: read` for native-timing API reads must be scoped to a single observability job, not
  widened globally.
- Test-only deps (`only: :test`) are excluded from the shipped Hex package via `files:`
  (`mix.exs:278-280`) — the basis for adding `junit_formatter` without a `lib/`/package change.
- `gate-ci-green` filters `data.workflow_runs` by `workflow_id: 'ci.yml'` + head_sha — the reason
  the filename and `name: CI` are immovable.

### Integration Points
- New summary steps + cache `id:`s land inline across instrumented jobs in `ci.yml`.
- `junit_formatter` lands in `mix.exs` deps + `test/test_helper.exs` config.
- Baseline collector lands in `scripts/ci/`; its output + live required-check names commit to a
  `.planning/` baseline doc in this phase dir.
</code_context>

<specifics>
## Specific Ideas

- Maintainer chose **quality + long-pole (`integration`, `package-consumer`)** instrumentation
  scope over quality-only, explicitly to feed the Phase 106 lane-split evidence.
- Maintainer chose the **test-only `junit_formatter` dep** over a hand-rolled formatter.
</specifics>

<deferred>
## Deferred Ideas

- Composite `setup-elixir` action + cache-key correctness → **Phase 104** (CACHE-01..05).
- `CI Summary` aggregate + branch-protection flip → **Phase 105** (GATE-01..02).
- Lane/trigger split, concurrency groups, scoped package-consumer → **Phase 106** (LANE-01..04).
- async/partitioning, action SHA-pinning, `mix ci`, Linux-Chromium repro → **Phase 107**
  (HARD-01..04).
- Making the baseline adopter-visible in `RUNNING.md` — declined (would ship internal CI noise
  via the Hex `files:`/`extras` allowlists). Kept internal in `.planning/`.

### Reviewed Todos (not folded)
- `2026-06-19-fix-docker-demo-startup-warnings.md` (tooling) — score 0.2, keyword-only match
  ("yml"); unrelated to CI observability. Not folded into Phase 103.
</deferred>
