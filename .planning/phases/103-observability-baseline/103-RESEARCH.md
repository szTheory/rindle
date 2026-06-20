# Phase 103: Observability / Baseline - Research

**Researched:** 2026-06-20
**Domain:** GitHub Actions CI observability + GitHub REST API (Actions runs/jobs, branch protection) + ExUnit/ExCoveralls artifacts
**Confidence:** HIGH (all GitHub API shapes + junit_formatter version verified live against this repo and Hex.pm; mechanism recommendations grounded in the actual ci.yml topology)

## Summary

This phase makes the existing 16-job `ci.yml` self-reporting and captures a committed, scriptable baseline — with **zero gate-behavior change and zero topology change**. The research resolves the six open flags the locked decisions (D-01..D-14) defer to it. Every recommendation below is additive and advisory; none alters a `run:` command's pass/fail, renames anything, or widens workflow-level permissions.

Two findings are load-bearing and were **verified live against `szTheory/rindle`**:

1. **The branch-protection API on this repo already returns BOTH shapes** — legacy `required_status_checks.contexts[]` AND newer `required_status_checks.checks[].context` — so OBS-03's diff can read either; `.contexts[]` is the simpler, stable target. **Critical live discovery:** the live required-check list is **missing `brandbook-tokens`** that `scripts/setup_branch_protection.sh` lists as expected (line 30). OBS-03's whole purpose — capture *live-vs-expected drift before any restructuring* — is immediately validated: there is real drift to record today. [VERIFIED: live `gh api` on szTheory/rindle, 2026-06-20]

2. **The Actions jobs API gives authoritative per-job AND per-step durations** (`started_at`/`completed_at` on every job and every step), so D-03 option (b) — a single aggregator job reading `gh api .../runs/{run_id}/jobs` — is fully viable and is the **recommended** mechanism. It needs `actions: read` on that one job only, never widened globally. [VERIFIED: live `gh api` returned 16 jobs with per-step timing]

**Primary recommendation:** Use a **hybrid**: (a) lightweight inline `$GITHUB_STEP_SUMMARY` writes inside `quality` / `integration` / `package-consumer` for the human-facing per-step evidence OBS-02 requires (slowest tests, compile profile, schedulers, seed, cache hit/miss) — these are things the API can't surface (test internals) — plus (b) a single `ci-observability` aggregator job (`needs:` all jobs, `if: always()`, `permissions: actions: read`) that pulls authoritative native per-job durations once and writes the per-job timing table. The committed historical baseline (avg/p95/rerun) is a separate `scripts/ci/` collector run by a maintainer locally, committed to `.planning/`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Per-step timing + cache hit/miss surfacing (OBS-01) | CI / GitHub Actions (inline `$GITHUB_STEP_SUMMARY`) | — | Step-summary append is a runner-side concern; per-step `SECONDS` deltas + `steps.<id>.outputs.cache-hit` are only knowable inside the job |
| Authoritative per-job durations (OBS-01) | CI / GitHub Actions (aggregator job) | GitHub REST API | Native job durations are most accurate read once from the Actions API post-hoc, not hand-timed |
| Slowest tests / compile profile / schedulers / seed (OBS-02) | Test runtime (ExUnit / mix) → CI surface | — | These are emitted by `mix` at runtime; CI just captures stdout into the summary |
| JUnit + coverage artifacts (OBS-02) | Test runtime (junit_formatter + ExCoveralls) → CI upload | — | Formatter/coverage tool produces files; `actions/upload-artifact` ships them |
| Historical baseline (avg/p95/rerun) (OBS-03) | Maintainer tooling (`scripts/ci/` + `gh api`) | GitHub REST API | A reproducible script over recent runs, not an in-CI job — committed once before restructuring |
| Live required-check capture + drift diff (OBS-03) | Maintainer tooling (`gh api` branch protection) | GitHub REST API | Reads live protection, diffs vs `setup_branch_protection.sh` expected list |

## Project Constraints (from milestone + CONTEXT.md — treated as locked)

No `./CLAUDE.md` exists in the repo. Constraints come from `103-CONTEXT.md` D-01..D-14, REQUIREMENTS.md, and ROADMAP.md "Hard invariants":

- **Never** rename `ci.yml` filename or `name: CI` (D-13; coupling proven in `release-please-automerge.yml:5-6` `workflows: [CI]` and `release.yml:180` `workflow_id: 'ci.yml'` + `head_sha` filter).
- **Zero gate-behavior change** (D-14): same checks required, same PRs pass/fail. Every addition is advisory/observational. No `continue-on-error` flips, no new required checks.
- **No composite action** in this phase (D-12) — that is Phase 104. All observability inline in `ci.yml` + `scripts/ci/`.
- Workflow-level `permissions: contents: read` (`ci.yml:18-19`) stays tight; any `actions: read` is scoped to a single observability job (D-03 constraint).
- **Zero `lib/` change**: `junit_formatter` must be `only: :test`, excluded from the Hex `files:` allowlist (`mix.exs:278-280` ships only `lib priv/repo/migrations priv/static/rindle_admin mix.exs README.md RUNNING.md CHANGELOG.md LICENSE guides`) — test-only deps never ship.
- Baseline doc is **internal `.planning/`** only (D-10), never `RUNNING.md`/`README`/HexDocs `extras` (`mix.exs:154-172`).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Surface per-job/per-step timing and cache hit/miss into `$GITHUB_STEP_SUMMARY` using the append idiom from `branch-protection-apply.yml:28-33`. Additions are purely additive.
- **D-02:** Add an `id:` to the existing `actions/cache@v4` restore steps so `cache-hit` is readable. Only the PLT step sets one today (`ci.yml:122`); deps/`_build` restore steps expose nothing.
- **D-03 (researcher-resolved):** Choose per-step timing mechanism — (a) inline `date +%s%N`/`SECONDS` vs (b) aggregator job pulling native durations via `gh api .../runs/{id}/jobs`. If (b), `actions: read` only on that job; never widen workflow-level `permissions: contents: read`.
- **D-04:** Surface `mix test --slowest 20` + per-step timing in `quality` AND the real long-pole jobs (`integration`, `package-consumer`) — not quality-only (feeds Phase 106 lane split).
- **D-05:** Surface `System.schedulers_online()`, a `mix compile --profile time` (or equivalent), and the ExUnit seed in the summary. Seed is currently implicit (`test_helper.exs:31` bare `ExUnit.start`).
- **D-06:** Add test-only `{:junit_formatter, "~> 3.4", only: :test}` to `mix.exs`, wire in `test/test_helper.exs`. Confirm matrix compat in research.
- **D-07:** Produce a coverage artifact via ExCoveralls (already wired `mix.exs:43,50-53`, `mix coveralls` `ci.yml:118`). Emit + upload JUnit + coverage via `actions/upload-artifact@v4`. No gate change.
- **D-08:** Produce baseline (per-job avg + p95 + rerun/flake rate) via a committed `scripts/ci/` helper using `gh`/`gh api` (matching existing `scripts/ci/` pattern).
- **D-09:** Read live branch-protection required-check names via the API and diff against the static expected list in `scripts/setup_branch_protection.sh` (incl. `--print-expected`). Record live names verbatim.
- **D-10:** Commit baseline table + live required-check names to an internal `.planning/` doc (e.g. `103-BASELINE.md`), NOT shipped docs.
- **D-11:** Capture before any restructuring (Phases 104+). Load-bearing gate for the rest of v1.20.
- **D-12:** All observability inline in `ci.yml` + `scripts/ci/`. Do NOT create `.github/actions/setup-elixir` (Phase 104).
- **D-13:** Never rename `ci.yml`'s file or `name: CI` (release-train coupling).
- **D-14:** Zero gate-behavior change.

### Claude's Discretion
- D-03 timing mechanism (inline vs aggregator) — within the stated permission constraint.
- Exact artifact naming, retention days, and summary-table formatting.

### Deferred Ideas (OUT OF SCOPE)
- Composite `setup-elixir` + cache-key correctness → Phase 104 (CACHE-01..05).
- `CI Summary` aggregate + branch-protection flip → Phase 105 (GATE-01..02).
- Lane/trigger split, concurrency groups, scoped package-consumer → Phase 106 (LANE-01..04).
- async/partitioning, action SHA-pinning, `mix ci`, Linux-Chromium repro → Phase 107 (HARD-01..04).
- Making the baseline adopter-visible in `RUNNING.md` — declined; kept internal in `.planning/`.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| OBS-01 | CI surfaces per-job and per-step timing plus cache hit/miss in `$GITHUB_STEP_SUMMARY`, no gate change. | Hybrid mechanism (§Pattern 1/2): inline `SECONDS` deltas + cache-hit `id:`s for per-step; aggregator job reading `gh api .../runs/{id}/jobs` for authoritative per-job. `$GITHUB_STEP_SUMMARY` append idiom verified at `branch-protection-apply.yml:28-33`. |
| OBS-02 | CI surfaces `mix test --slowest 20`, compile profile, `System.schedulers_online()`, ExUnit seed; JUnit + coverage artifacts uploaded. | `--slowest 20` flag + seed echo (§Code Examples); `junit_formatter ~> 3.4` verified compatible (§Standard Stack); ExCoveralls `coveralls.json`/`.html` already mapped (`mix.exs:50-53`); `actions/upload-artifact@v4` wiring (§Pattern 3). |
| OBS-03 | Committed baseline table (per-job avg + p95 + rerun/flake rate) + actual live branch-protection required-check names captured before restructuring. | Branch-protection JSON shape verified live (`.contexts[]` present); `run_attempt`-derived rerun rate (§Pitfall 2); `scripts/ci/` collector skeleton (§Code Examples). Live drift already exists (`brandbook-tokens` missing) — OBS-03 immediately load-bearing. |
</phase_requirements>

## Standard Stack

### Core
| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| `junit_formatter` (Hex) | `~> 3.4` (latest 3.4.0) | ExUnit → JUnit XML formatter for CI artifact | Canonical ExUnit JUnit formatter in the Elixir ecosystem; 8+ years on Hex; zero version constraints so works on both matrix pairs. [VERIFIED: hex.pm API — 3.4.0, released 2024-04-02, `requirements: {}`] |
| `excoveralls` | `~> 0.18` (already in `mix.exs:133`) | Coverage; emits `coveralls.json` / `coveralls.html` | Already the repo's coverage tool (`test_coverage: [tool: ExCoveralls]` `mix.exs:43`); no new tooling needed. [VERIFIED: present in mix.exs] |
| `gh` CLI | 2.94.0 (local) | Read Actions runs/jobs + branch protection for baseline collector | Already used throughout `scripts/` and release workflows; authed maintainer session has the needed scope. [VERIFIED: `gh --version` local] |
| `actions/upload-artifact` | `@v4` (already used `ci.yml:754`, `1204`) | Ship JUnit XML + coverage artifacts | v4 already in this repo; v3 is deprecated/EOL. [VERIFIED: in-repo usage] |
| `actions/cache` | `@v4` (already used) | `cache-hit` output via step `id:` | Already in repo; `steps.<id>.outputs.cache-hit` is the documented output. [CITED: github.com/actions/cache] |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `mix test --slowest 20` | Prints the 20 slowest tests after the run | OBS-02 — wrap the existing `mix coveralls` / test steps OR a dedicated echo step |
| `mix test --slowest 20` seed | The run summary line `Randomized with seed N` carries the seed | OBS-02 — capture stdout; ExUnit prints seed regardless of formatter |
| `mix compile --profile time` | Per-module compile timing profile | OBS-02 compile profile (D-05) — run as an additive step or wrap existing compile |
| `System.schedulers_online()` | Runner online schedulers (≈ vCPU) | OBS-02 — `mix run --no-start -e 'IO.puts(System.schedulers_online())'` |
| `jq` | JSON shaping for `gh api` output in the collector | OBS-03 collector + live-check diff (already a dependency in `setup_branch_protection.sh:105`) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `junit_formatter` dep | Hand-rolled custom ExUnit formatter | Rejected by D-06 — more to own, reinvents a solved problem. Standard dep chosen. |
| Aggregator job (D-03 b) for per-job timing | Pure inline `date +%s%N` wrapping every step | Inline is noisy (every step edited), can't see the runner-queue/setup overhead the native API captures, and double-counts. Aggregator reads authoritative durations once. **Hybrid recommended** (see §Pattern 1/2). |
| In-CI baseline job | Committed `scripts/ci/` collector run locally | D-08 mandates a committed script; an in-CI historical-baseline job would re-run every PR and isn't the "captured before restructuring" snapshot OBS-03 wants. |

**Installation (test-only dep — D-06):**
```elixir
# mix.exs deps(), in the Dev/Test block (near mix.exs:126-135)
{:junit_formatter, "~> 3.4", only: :test},
```
Then `mix deps.get`. No `files:` change needed — `only: :test` deps are already excluded from the shipped package allowlist (`mix.exs:278-280`).

**Version verification performed:**
```
curl -fsS https://hex.pm/api/packages/junit_formatter            → latest 3.4.0 (then 3.3.1, 3.3.0, ...)
curl -fsS https://hex.pm/api/packages/junit_formatter/releases/3.4.0 → requirements: {}  (no elixir/otp constraint)
```
`requirements: {}` means no Elixir/OTP floor → compatible with both 1.15/OTP26 and 1.17/OTP27 matrix cells (`ci.yml:29-32`). [VERIFIED: hex.pm API, 2026-06-20]

## Package Legitimacy Audit

> The GSD `package-legitimacy` seam in this install does not support the `hex` ecosystem (fallback returned "Unknown command"). Verified directly against the authoritative Hex.pm registry API instead.

| Package | Registry | Age | Source Repo | Verdict | Disposition |
|---------|----------|-----|-------------|---------|-------------|
| `junit_formatter` | hex.pm | 3.4.0 published 2024-04-02; package ~8 yrs on Hex | github.com/victorolinasc/junit-formatter (canonical) | OK | Approved — `~> 3.4`, `only: :test` |
| `excoveralls` | hex.pm | already a repo dep (`~> 0.18`) | github.com/parroty/excoveralls | OK | Already installed — no new install |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
                         ┌─────────────────────────── ci.yml (name: CI — IMMUTABLE) ───────────────────────────┐
   PR / push:main  ─────▶│                                                                                       │
                         │  quality (matrix)   integration   package-consumer   ...12 more jobs                  │
                         │  ┌──────────────┐   ┌──────────┐   ┌──────────────┐                                   │
                         │  │ cache id:    │   │ inline   │   │ inline        │  ◀── OBS-01 inline:               │
                         │  │  ↳cache-hit  │   │ SECONDS  │   │ SECONDS delta │      • cache-hit per restore step │
                         │  │ inline       │   │ delta    │   │ + slowest 20  │      • per-step SECONDS deltas    │
                         │  │  SECONDS     │   │ + slowest│   │ + compile prof│  ◀── OBS-02 inline (D-04/D-05):   │
                         │  │ slowest 20   │   │   20     │   │ + schedulers  │      • mix test --slowest 20      │
                         │  │ compile prof │   └────┬─────┘   │ + seed echo   │      • compile --profile time     │
                         │  │ schedulers   │        │         │ + JUnit/cov   │      • schedulers_online + seed   │
                         │  │ seed echo    │        │         │   upload      │      • JUnit + coverage artifacts │
                         │  │ JUnit/cov ───┼────────┼─────────┴──────┬────────┘                                   │
                         │  └──────┬───────┘        │                │   ($GITHUB_STEP_SUMMARY + artifacts)       │
                         │         │                ▼                ▼                                            │
                         │         │       ┌────────────────────────────────────┐                               │
                         │         └──────▶│ ci-observability  (NEW aggregator)  │ ◀── OBS-01 per-job timing:    │
                         │                 │  needs: [ALL jobs]                  │     reads native durations    │
                         │                 │  if: always()                       │     once, writes job table    │
                         │                 │  permissions: actions: read  (ONLY) │                               │
                         │                 │  gh api runs/${run_id}/jobs ──┐      │                               │
                         │                 └───────────────────────────────┼──────┘                               │
                         └─────────────────────────────────────────────────┼──────────────────────────────────── ┘
                                                                            ▼
                                                         $GITHUB_STEP_SUMMARY (per-job avg table)

   ┌──── MAINTAINER, LOCAL (before any restructuring — D-08/D-09/D-11) ──────────────────────────────┐
   │  scripts/ci/collect_ci_baseline.sh                                                              │
   │    gh api workflows/ci.yml/runs ──▶ per-job avg + p95 + rerun(run_attempt) over last N runs     │
   │  gh api .../branches/main/protection/required_status_checks  ──▶ live contexts[]                │
   │    └─ diff vs scripts/setup_branch_protection.sh --print-expected                               │
   │                                       │                                                         │
   │                                       ▼                                                         │
   │            .planning/phases/103-observability-baseline/103-BASELINE.md  (committed, internal)   │
   └────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Recommended Structure (files touched)
```
.github/workflows/ci.yml         # + cache id:s, + inline summary steps (quality/integration/package-consumer),
                                 #   + ci-observability aggregator job (actions: read, job-level only)
mix.exs                          # + {:junit_formatter, "~> 3.4", only: :test}
test/test_helper.exs             # + config :junit_formatter, + formatters: list on ExUnit.start
scripts/ci/collect_ci_baseline.sh        # NEW — historical avg/p95/rerun collector (gh api)
scripts/ci/check_required_checks.sh      # NEW (or folded into above) — live-vs-expected required-check diff
.planning/phases/103-observability-baseline/103-BASELINE.md   # NEW — committed baseline + live check names
```

### Pattern 1: Aggregator job for authoritative per-job timing (D-03 recommendation = option b, for per-JOB)

**What:** One job that depends on all others, runs `if: always()`, and reads native durations once.
**When:** OBS-01 per-job timing. This is the accurate source — it captures queue/setup overhead and matches the GitHub UI's own per-job numbers.
**Least-privilege:** `permissions: actions: read` is declared **on this job only**. Job-level `permissions:` blocks override the workflow default for that job and do NOT widen any other job (verified pattern: `release.yml:101-103` already scopes `actions: read` to the single `gate-ci-green` job while the workflow default stays `contents: read`). [VERIFIED: release.yml in-repo]

```yaml
  ci-observability:
    name: CI Observability
    runs-on: ubuntu-22.04
    needs:
      - quality
      - optional-dependencies
      - integration
      - contract
      - proof
      - package-consumer
      - adoption-demo-unit
      - cohort-demo-smoke
      - adoption-demo-e2e
      - adopter
      - brandbook-tokens
      # NOTE: secret/label-gated jobs (mux-soak, gcs-soak, package-consumer-gcs-live)
      # are intentionally NOT in needs: — they often skip; this job is observational
      # and must not turn a skip into a failure. if: always() + omit-from-needs keeps it green.
    if: always()
    permissions:
      actions: read           # job-level ONLY — workflow default stays contents: read
    steps:
      - name: Summarize native per-job durations
        env:
          GH_TOKEN: ${{ github.token }}
          RUN_ID: ${{ github.run_id }}
          REPO: ${{ github.repository }}
        run: |
          set -euo pipefail
          {
            echo "## CI per-job timing (native)"
            echo ""
            echo "| Job | Duration (s) | Conclusion |"
            echo "| --- | ---: | --- |"
            gh api --paginate \
              -H "Accept: application/vnd.github+json" \
              "repos/${REPO}/actions/runs/${RUN_ID}/jobs?per_page=100" \
              --jq '.jobs[]
                    | select(.name != "CI Observability")
                    | [ .name,
                        (if .started_at and .completed_at
                         then ((.completed_at | fromdateiso8601) - (.started_at | fromdateiso8601))
                         else 0 end),
                        (.conclusion // "—") ]
                    | "| \(.[0]) | \(.[1]) | \(.[2]) |"'
          } >> "$GITHUB_STEP_SUMMARY"
```

Notes:
- `$GITHUB_TOKEN` with job-level `actions: read` can read the *current* run's jobs. [VERIFIED: jobs API returned 16 jobs with per-step timing for run 27883370831]
- Each job object also carries a `steps[]` array with per-step `started_at`/`completed_at` — so this same call can produce per-step timing for any job without editing that job. GitHub's own UI already shows per-step durations; `$GITHUB_STEP_SUMMARY` is needed only to make them durable/aggregated.

### Pattern 2: Inline per-step timing + cache-hit (D-01/D-02) — for things the API can't see

**What:** Inside `quality` / `integration` / `package-consumer`, add an `id:` to each `actions/cache@v4` restore step and emit cache-hit + lightweight `SECONDS`-based step deltas into the summary.
**Why inline (not API):** Cache hit/miss (`steps.<id>.outputs.cache-hit`) and test-internal evidence (slowest tests, seed, compile profile) are only knowable inside the job. The hybrid keeps inline edits minimal — one cache-hit summary block per instrumented job, not a wrapper around every step.

```yaml
      - name: Restore deps cache
        uses: actions/cache@v4
        id: deps-cache              # D-02 — was unset; add id so cache-hit is readable
        with:
          path: deps
          key: deps-${{ runner.os }}-${{ matrix.elixir }}-${{ matrix.otp }}-${{ hashFiles('**/mix.lock') }}
          restore-keys: deps-${{ runner.os }}-${{ matrix.elixir }}-${{ matrix.otp }}-

      # ... later, an additive summary step (after caches restored) ...
      - name: Summarize cache hit/miss
        if: always()
        run: |
          {
            echo "## Cache hit/miss — ${{ github.job }}"
            echo ""
            echo "| Cache | Hit |"
            echo "| --- | --- |"
            echo "| deps  | ${{ steps.deps-cache.outputs.cache-hit || 'false' }} |"
            echo "| build | ${{ steps.build-cache.outputs.cache-hit || 'false' }} |"
            echo "| plt   | ${{ steps.plt-cache.outputs.cache-hit || 'false' }} |"
          } >> "$GITHUB_STEP_SUMMARY"
```
`cache-hit` is `'true'` only on an exact key hit; on a `restore-keys` partial hit it is the empty string (hence `|| 'false'`). [CITED: github.com/actions/cache#outputs]

### Pattern 3: JUnit + coverage artifacts (OBS-02 / D-06 / D-07)

```yaml
      - name: Run tests with coverage          # existing step at ci.yml:118 — keep mix coveralls (no gate change)
        run: mix coveralls --slowest 20        # --slowest is additive; coveralls still the merge-blocking signal

      - name: Generate coverage JSON artifact   # ADDITIVE sibling — does NOT replace the gating run
        if: always()
        run: mix coveralls.json                 # writes cover/excoveralls.json (preferred_envs already maps it, mix.exs:52)

      - name: Upload JUnit + coverage artifacts
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: junit-coverage-${{ github.job }}-${{ matrix.elixir || 'na' }}
          path: |
            _build/test/lib/rindle/*.xml
            cover/excoveralls.json
          if-no-files-found: warn
          retention-days: 14        # planner discretion (D Claude's-discretion)
```
- JUnit XML path is controlled by junit_formatter config (see §Code Examples). Default report dir is `Mix.Project.compile_path()` (`_build/test/lib/<app>/`); set it explicitly to make the upload path deterministic.
- `coveralls.json` writes to `cover/excoveralls.json` by default. `coveralls.html` writes `cover/excoveralls.html`. Both are mapped to `:test` env already (`mix.exs:50-53`). Running `mix coveralls.json` a second time is an additive artifact-generation step and does not change the gating `mix coveralls` result. Confirm the exact output filename in Wave 0 (`mix coveralls.json` then `ls cover/`).

### Anti-Patterns to Avoid
- **Wrapping every step in `date +%s%N`** — noisy, edits the whole file, and the aggregator already has authoritative durations. Use inline timing only where the API can't reach (test internals).
- **Adding the aggregator/observability job to branch-protection required checks** — that would change gate behavior (D-14 violation). It stays advisory; nothing requires it.
- **Putting `actions: read` at workflow level** — violates D-03/D-14 least-privilege. Scope to the one job.
- **Including secret/label-gated jobs in the aggregator's `needs:`** — they skip on forks/unlabeled PRs and would block or fail the aggregator. Omit them; `if: always()` handles the rest.
- **Replacing `mix coveralls` with `mix coveralls.json`** as the test step — `coveralls.json` does not fail on coverage thresholds the same way; keep the existing gating run and add artifact generation as a sibling.
- **Committing the baseline into `RUNNING.md`/`extras`** — ships internal CI noise via the Hex `files:`/`extras` allowlists (D-10). Internal `.planning/` only.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| ExUnit → JUnit XML | Custom `ExUnit.Formatter` callback module | `{:junit_formatter, "~> 3.4", only: :test}` | D-06; solved, maintained, zero version constraints |
| Per-job CI durations | Manual `date` math summed across steps | `gh api .../runs/{run_id}/jobs` `.jobs[].started_at/completed_at` | Native, authoritative, matches GitHub UI; captures setup/queue overhead |
| Coverage artifact | Parse `mix test` output | `mix coveralls.json` (ExCoveralls already wired) | Already the repo's tool; `preferred_envs` mapped |
| Branch-protection read | Scrape the GitHub UI | `gh api .../branches/main/protection/required_status_checks` | Returns structured `contexts[]` + `checks[]` |
| Rerun/flake detection | Bespoke run-correlation DB | Group runs by `head_sha`, count attempts via `run_attempt` / `previous_attempt_url` | The API exposes attempt lineage directly |

**Key insight:** Everything OBS-01..03 needs is already produced by `mix`, ExCoveralls, or the GitHub Actions API — the phase is *surfacing and capturing*, not building measurement infrastructure.

## Runtime State Inventory

> This phase is additive-instrumentation, not a rename/refactor/migration. The only "state" relevant is **live GitHub branch-protection config**, which OBS-03 explicitly *reads and records* (does not mutate).

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — phase adds no migrations, touches no datastore. | None |
| Live service config | **Live branch protection on `main` has drift from the committed expected list:** live `required_status_checks.contexts[]` is missing `brandbook-tokens` (present in `setup_branch_protection.sh:30`). OBS-03 must record this verbatim — it is the live snapshot, not a bug to fix in this phase. | **Read + record only** (D-09/D-14). Do NOT re-apply protection — that's gate behavior. Note drift in `103-BASELINE.md`. |
| OS-registered state | None. | None |
| Secrets/env vars | Baseline collector uses the maintainer's local `gh` auth (or `GH_TOKEN`); the aggregator job uses `github.token` + job-level `actions: read`. No new secrets. `BRANCH_PROTECTION_PAT` already exists for the re-assert workflow but is NOT needed to *read* protection (read works in a maintainer admin `gh` session). | None new |
| Build artifacts | `cover/excoveralls.json`, `_build/test/lib/rindle/*.xml` (JUnit) — generated per-run, uploaded as artifacts, gitignored. The test-only `junit_formatter` adds to `mix.lock` (committed) but never to the shipped Hex package. | Verify `cover/` + `*.xml` are gitignored (Wave 0) |

## Common Pitfalls

### Pitfall 1: `cache-hit` empty on restore-keys partial hit
**What goes wrong:** `steps.<id>.outputs.cache-hit` is the empty string (not `'false'`) when only a `restore-keys` prefix matched, so a naive `== 'false'` check misreports.
**Why:** `actions/cache` sets `cache-hit: 'true'` only on an exact primary-key hit; partial restores leave it unset.
**How to avoid:** Always coalesce `${{ steps.id.outputs.cache-hit || 'false' }}` in the summary. [CITED: github.com/actions/cache#outputs]
**Warning signs:** Summary shows blank cells under "Hit".

### Pitfall 2: Rerun/flake rate is NOT a direct field — derive from `run_attempt`
**What goes wrong:** Expecting a `rerun_count` on the run or jobs object. There is none.
**Why:** GitHub models reruns as separate attempts. Each run object has `run_attempt` (integer, starts at 1) and `previous_attempt_url` (`null` on attempt 1, populated when an attempt was a rerun of an earlier one). [VERIFIED: live ci.yml runs show `run_attempt`, `previous_attempt_url`]
**How to derive the rate:** Over the last N `ci.yml` runs (e.g. last 50–100 on `main`+PR):
- A run with `run_attempt > 1` OR a non-null `previous_attempt_url` indicates a rerun.
- **Flake-ish rate** ≈ (count of runs that were re-attempted and later succeeded) / (total runs). A clean proxy without deep correlation: `count(run_attempt > 1) / count(distinct head_sha runs)`.
- For per-job flake, list jobs across attempts of the same `head_sha` and count jobs whose conclusion changed `failure → success` across attempts.
**Window recommendation:** last 50 runs on `branch=main` for stability + last 50 PR runs for realism; collector should parameterize `N` (default 50) and the branch filter.
**Warning signs:** A "rerun rate" that's always 0 because you only fetched attempt-1 runs (the default listing returns the *latest* attempt; pass `?per_page=...` and inspect `run_attempt`).

### Pitfall 3: Branch-protection API has two field shapes — pick `.contexts[]`
**What goes wrong:** Reading `.checks[].context` vs `.contexts[]` inconsistently across API versions.
**Why:** The modern API returns **both**: legacy flat `required_status_checks.contexts[]` (just names) and newer `required_status_checks.checks[]` (objects `{context, app_id}`). [VERIFIED: live `gh api` on szTheory/rindle returned both].
**How to avoid:** Diff against `.contexts[]` (verbatim names, simplest). If you ever need app-scoping, use `.checks[].context`. The sub-resource endpoint `.../required_status_checks` returns the same; you can also hit `.../required_status_checks/contexts` for a bare string array.
**Warning signs:** Empty diff because you read `.checks` where the response only had `.contexts` (or vice versa) on a different API version.

### Pitfall 4: Aggregator job `needs:` on skip-prone jobs
**What goes wrong:** Adding `mux-soak`/`gcs-soak`/`package-consumer-gcs-live` to `needs:` makes the aggregator skip or fail on forks/unlabeled PRs.
**Why:** Those jobs are `if:`-gated on `github.repository == 'szTheory/rindle'` or the `streaming` label; on a fork PR they don't run.
**How to avoid:** Omit them from `needs:`; rely on `if: always()`. (This same skip-on-fork dynamic is the "pending forever" trap Phase 105 closes for required checks — out of scope here, but the aggregator must not reintroduce it.)

### Pitfall 5: ExUnit seed is per-`mix test` invocation, not global
**What goes wrong:** Reporting "the seed" when several `mix test` calls ran (e.g. `integration` runs two separate `mix test` invocations, `ci.yml:279-280`; `package-consumer` runs many `install_smoke.sh` calls).
**Why:** ExUnit randomizes per invocation; each prints its own `Randomized with seed N`.
**How to avoid:** Capture the seed from the *representative* unit run (`quality`'s `mix coveralls`). Echo it explicitly: `mix test --seed 0 ...` would pin it, but D-05 wants the *actual* seed surfaced, so grep stdout for `Randomized with seed` rather than pinning.

## Code Examples

### junit_formatter wiring (D-06) — `test/test_helper.exs`
ExUnit formatters are passed on `ExUnit.start/1`. junit_formatter is configured via `config :junit_formatter` in `config/` OR via `Application.put_env` in the test helper (this repo has no `config/test.exs` visible for the lib; the test helper is the established place — it already starts repos/Oban there).

```elixir
# test/test_helper.exs — ADD near the existing ExUnit.start (currently line 31)

# Only emit JUnit XML in CI to keep local runs quiet (CI sets the CI env var).
formatters =
  if System.get_env("CI") do
    [ExUnit.CLIFormatter, JUnitFormatter]
  else
    [ExUnit.CLIFormatter]
  end

# Deterministic, upload-friendly report location.
Application.put_env(:junit_formatter, :report_dir, "_build/test/junit")
Application.put_env(:junit_formatter, :report_file, "rindle-junit.xml")
Application.put_env(:junit_formatter, :print_report_file, true)
Application.put_env(:junit_formatter, :include_filename?, true)

ExUnit.start(exclude: exclude_tags, formatters: formatters)
```
- Produced XML path with the config above: `_build/test/junit/rindle-junit.xml` → use that in the `upload-artifact` `path:`.
- Default (no `report_dir`) would be `Mix.Project.compile_path()` i.e. `_build/test/lib/rindle/`; setting it explicitly is cleaner.
- `JUnitFormatter` is the module name exported by the `junit_formatter` package. [CITED: hexdocs.pm/junit_formatter]
- **Idempotency note:** the existing `exclude_tags` logic (`test_helper.exs:24-29`) and `ExUnit.start` must stay intact; only add `formatters:` and the `Application.put_env` lines. Do not move the repo/Oban startup.

### OBS-02 evidence step (slowest tests, compile profile, schedulers, seed) — `quality` job
```yaml
      - name: Surface compile profile + schedulers
        run: |
          {
            echo "## Build profile — ${{ github.job }} (${{ matrix.elixir }}/${{ matrix.otp }})"
            echo ""
            echo "- schedulers_online: $(mix run --no-start -e 'IO.puts(System.schedulers_online())')"
          } >> "$GITHUB_STEP_SUMMARY"
          # compile --profile time prints a per-module table to stdout (already compiled, so force a clean view)
          mix compile --profile time 2>&1 | tail -20 >> "$GITHUB_STEP_SUMMARY" || true

      # In the test step, --slowest 20 prints the slowest tests + the seed line to stdout,
      # which GitHub captures in the job log. To ALSO put them in the summary, tee:
      - name: Run tests with coverage (slowest + seed surfaced)
        run: |
          set -o pipefail
          mix coveralls --slowest 20 2>&1 | tee /tmp/test.out
          {
            echo "## Test timing — ${{ github.job }}"
            echo '```'
            grep -E 'Randomized with seed|slowest|^\s+\* test ' /tmp/test.out | tail -30 || true
            echo '```'
          } >> "$GITHUB_STEP_SUMMARY"
```
Confirm `mix compile --profile time` flag name and `--slowest` output format in Wave 0 against the pinned Elixir (1.15/1.17) — `--slowest N` is stable since Elixir 1.0-era; `compile --profile time` since ~1.11. [ASSUMED for exact 1.15/1.17 stdout format — verify in Wave 0]

### OBS-03 baseline collector — `scripts/ci/collect_ci_baseline.sh` (skeleton)
Matches the `scripts/ci/` house style (`set -euo pipefail`, `repo_root` resolution, leading comment block — cf. `cohort_demo_smoke.sh:22-25`).

```bash
#!/usr/bin/env bash
# collect_ci_baseline.sh — capture a reproducible CI timing baseline (OBS-03).
#
# Reads recent ci.yml runs/jobs via `gh api`, computes per-job avg + p95 +
# rerun rate (derived from run_attempt — GitHub exposes no direct rerun_count),
# and prints a Markdown table for .planning/.../103-BASELINE.md. Read-only; uses
# the maintainer's authed gh session (no admin scope needed for runs/jobs).
set -euo pipefail

REPO="${GITHUB_REPOSITORY:-szTheory/rindle}"
BRANCH="${BASELINE_BRANCH:-main}"
N="${BASELINE_RUNS:-50}"

# 1. Recent runs (latest attempt per run is returned; run_attempt reveals reruns).
runs_json="$(gh api --paginate \
  -H "Accept: application/vnd.github+json" \
  "repos/${REPO}/actions/workflows/ci.yml/runs?branch=${BRANCH}&per_page=100" \
  --jq "[.workflow_runs[] | {id, head_sha, run_attempt, conclusion, previous_attempt_url}] | .[:${N}]")"

# 2. Rerun rate over the window.
total="$(jq 'length' <<<"$runs_json")"
reran="$(jq '[.[] | select(.run_attempt > 1 or .previous_attempt_url != null)] | length' <<<"$runs_json")"
echo "Rerun rate (last ${N} ${BRANCH} runs): ${reran}/${total}"

# 3. Per-job durations across those runs → avg + p95.
#    For each run id, pull jobs and emit "job_name<TAB>duration_seconds".
: >/tmp/job_durations.tsv
for id in $(jq -r '.[].id' <<<"$runs_json"); do
  gh api --paginate -H "Accept: application/vnd.github+json" \
    "repos/${REPO}/actions/runs/${id}/jobs?per_page=100" \
    --jq '.jobs[]
          | select(.started_at != null and .completed_at != null)
          | [ .name,
              ((.completed_at|fromdateiso8601) - (.started_at|fromdateiso8601)) ]
          | @tsv' >>/tmp/job_durations.tsv || true
done

# 4. avg + p95 per job name (awk: collect, sort, index p95).
awk -F'\t' '
  { sum[$1]+=$2; n[$1]++; vals[$1]=vals[$1] $2 " " }
  END {
    print "| Job | runs | avg(s) | p95(s) |"
    print "| --- | ---: | ---: | ---: |"
    for (j in sum) {
      c=split(vals[j], a, " ")-1
      # simple sort
      for(i=1;i<=c;i++) for(k=i+1;k<=c;k++) if(a[k]<a[i]){t=a[i];a[i]=a[k];a[k]=t}
      p95idx=int((c*0.95)+0.999); if(p95idx<1)p95idx=1; if(p95idx>c)p95idx=c
      printf "| %s | %d | %.0f | %.0f |\n", j, n[j], sum[j]/n[j], a[p95idx]
    }
  }' /tmp/job_durations.tsv
```
[VERIFIED: every `gh api` shape above against live szTheory/rindle responses, 2026-06-20]

### OBS-03 live required-check diff — `scripts/ci/check_required_checks.sh` (skeleton)
```bash
#!/usr/bin/env bash
# check_required_checks.sh — record LIVE branch-protection required checks (OBS-03)
# and diff against the committed expected list in setup_branch_protection.sh.
# Read-only. Works in a maintainer admin gh session (protection read needs admin
# on the repo, which the maintainer has; no separate PAT required to READ).
set -euo pipefail
REPO="${GITHUB_REPOSITORY:-szTheory/rindle}"
BRANCH="${1:-main}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

live="$(gh api \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "repos/${REPO}/branches/${BRANCH}/protection/required_status_checks" \
  --jq '.contexts[]' | sort)"

expected="$(bash "${HERE}/scripts/setup_branch_protection.sh" --print-expected-json \
  | jq -r '.required_status_checks.contexts[]' | sort)"

echo "## Live required status checks (${REPO}@${BRANCH})"
echo "$live" | sed 's/^/  - /'
echo ""
echo "## Diff vs setup_branch_protection.sh expected (expected-only / live-only):"
diff <(echo "$expected") <(echo "$live") || true
```
- **Auth:** reading `.../branches/{branch}/protection/...` requires **admin on the repo**; a maintainer's local `gh auth login` session has it (verified — this researcher read it live just now). The scheduled re-assert workflow uses `BRANCH_PROTECTION_PAT` (Administration read/write) but a read-only capture only needs admin read. [VERIFIED: live read succeeded]
- **Live drift confirmed today:** expected list (`setup_branch_protection.sh:17-31`) includes `brandbook-tokens`; live `.contexts[]` does **not**. Record verbatim in `103-BASELINE.md`. [VERIFIED: live diff]

### `$GITHUB_STEP_SUMMARY` append idiom (D-01) — verbatim repo pattern
```bash
# Established at branch-protection-apply.yml:28-33 — brace-group redirect once:
{
  echo "## Heading"
  echo ""
  echo "| Col | Col |"
  echo "| --- | --- |"
  echo "| a | b |"
} >> "$GITHUB_STEP_SUMMARY"
```
[VERIFIED: branch-protection-apply.yml:28-33; release.yml:406-408 uses the single-line `echo ... >> "$GITHUB_STEP_SUMMARY"` variant]
**Markdown limits:** `$GITHUB_STEP_SUMMARY` renders GitHub-flavored Markdown; total size cap is 1 MiB per step (truncated beyond). Tables, code fences, and lists all render. Keep `--slowest`/profile dumps inside ```` ``` ```` fences and `tail`-bounded to avoid the cap. [CITED: docs.github.com/actions — job summaries]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `actions/upload-artifact@v3` | `@v4` (already in repo) | v3 deprecated; v4 GA | Use v4 (already standard here) |
| Branch protection `contexts[]` only | `checks[]` (with `app_id`) added alongside `contexts[]` | API ~2022-11-28 | Both returned; diff on `.contexts[]` for names |
| Hand-timed step durations | Native job/step `started_at`/`completed_at` via Actions API | Long stable | Authoritative per-job/step timing without editing steps |

**Deprecated/outdated:** `actions/upload-artifact@v3` (do not introduce); `FedericoCarboni/setup-ffmpeg@v3` is still present in `release.yml:457` but its alignment is **Phase 104 CACHE-05 scope**, explicitly NOT this phase.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `mix compile --profile time` and `mix test --slowest 20` stdout formats are stable on Elixir 1.15 & 1.17 | Code Examples / OBS-02 | LOW — flags exist since ≤1.11; only the exact grep pattern for the summary might need tweaking. Verify in Wave 0 by running locally. |
| A2 | `mix coveralls.json` writes `cover/excoveralls.json` | Pattern 3 | LOW — `preferred_envs` maps `coveralls.json` (mix.exs:52); confirm output filename via `ls cover/` in Wave 0. |
| A3 | junit_formatter default report dir is `Mix.Project.compile_path()`; explicit `report_dir` override works | Code Examples | LOW — documented; the explicit override makes it moot. Verify file appears at `_build/test/junit/` in Wave 0. |
| A4 | Reading branch protection needs only repo *admin read* (maintainer session), not the write PAT | Code Examples / Env Availability | LOW — verified the read succeeded live in this session; CI-side automation (if ever wanted) would need the PAT, but D-09 capture is a maintainer-local action. |
| A5 | `mix run --no-start -e 'IO.puts(System.schedulers_online())'` works without DB/app boot | Code Examples | LOW — `--no-start` avoids the app supervisor; schedulers_online is a VM call. Verify in Wave 0. |

## Open Questions

1. **Where to run the OBS-03 collector — local-only or also an advisory CI job?**
   - What we know: D-08 mandates a committed `scripts/ci/` script; D-11 says "captured before any restructuring." A maintainer running it locally and committing `103-BASELINE.md` satisfies both.
   - What's unclear: whether the planner also wants an *advisory* scheduled job that refreshes the baseline (not required for OBS-03).
   - Recommendation: ship the script + a one-time committed `103-BASELINE.md` this phase; defer any scheduled refresh job (avoids new CI surface; keeps the phase additive).

2. **Per-step timing granularity in the summary — all steps or long-poles only?**
   - What we know: OBS-01 says "per-step timing"; the aggregator's `steps[]` data covers every step for free.
   - Recommendation: have the aggregator emit per-step timing for the three D-04 jobs (`quality`, `integration`, `package-consumer`) and per-job timing for all — full per-step for 16 jobs is noisy.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `gh` CLI | OBS-03 collector + live-check diff (maintainer-local) | ✓ | 2.94.0 | — |
| `jq` | collector + diff JSON shaping | ✓ (already required by `setup_branch_protection.sh`) | system | — |
| Repo admin read (maintainer `gh` session) | reading branch protection | ✓ | — | `BRANCH_PROTECTION_PAT` (already exists) if scripting in CI |
| `$GITHUB_TOKEN` + job-level `actions: read` | aggregator job reading current-run jobs | ✓ (runtime) | — | — |
| Hex (`junit_formatter`) | OBS-02 JUnit XML | ✓ | 3.4.0 | hand-rolled formatter (rejected by D-06) |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** none blocking.

## Validation Architecture

> `workflow.nyquist_validation` is not present in `.planning/config.json` → treated as enabled.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.15/OTP26 + 1.17/OTP27 matrix) |
| Config file | `test/test_helper.exs` (no `config/test.exs` for the lib) |
| Quick run command | `mix test test/<targeted>_test.exs` |
| Full suite command | `mix coveralls` (the merge-blocking gate, `ci.yml:118`) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| OBS-01 | Summary shows per-job + per-step timing + cache hit/miss; gate unchanged | workflow self-check (manual/PR observation) + shellcheck | `bash -n scripts/ci/collect_ci_baseline.sh`; PR run shows summary | ❌ Wave 0 (no automated harness for `$GITHUB_STEP_SUMMARY` content; verified on the phase PR run) |
| OBS-02 | `--slowest 20`, compile profile, schedulers, seed surfaced; JUnit+coverage uploaded | integration (junit XML produced) | `CI=1 mix test` → assert `_build/test/junit/rindle-junit.xml` exists | ❌ Wave 0 — add a tiny assertion (script or doc-checked step) that the XML + `cover/excoveralls.json` are produced |
| OBS-03 | Baseline + live required-check names committed before restructuring; diff runs | smoke (script runs, emits table) | `bash scripts/ci/check_required_checks.sh main`; `bash scripts/ci/collect_ci_baseline.sh` | ❌ Wave 0 — new scripts; `bash -n` lint + one live dry-run by maintainer |
| OBS-01/02 gate-unchanged | Same required checks pass/fail as pre-phase | regression | `scripts/ci/check_required_checks.sh` diff is empty *relative to the pre-phase live snapshot* | ✅ live read works; compare pre/post |

### Sampling Rate
- **Per task commit:** `bash -n` on any new/edited script + (for `test_helper.exs` change) `CI=1 mix test test/<one>_test.exs` to confirm JUnit XML appears and the suite still passes.
- **Per wave merge:** `mix coveralls` (full gating suite) green; the phase PR's own CI run shows the new summary sections.
- **Phase gate:** Full `ci.yml` green on the phase PR with identical required-check pass/fail vs the pre-phase baseline (OBS-03 diff empty against the captured pre-phase snapshot), and `103-BASELINE.md` committed.

### Wave 0 Gaps
- [ ] `scripts/ci/collect_ci_baseline.sh` — new; OBS-03 (avg/p95/rerun). Add `bash -n` lint.
- [ ] `scripts/ci/check_required_checks.sh` — new; OBS-03 live-vs-expected diff. Add `bash -n` lint.
- [ ] Assertion that `CI=1 mix test` produces `_build/test/junit/rindle-junit.xml` and `mix coveralls.json` produces `cover/excoveralls.json` (OBS-02) — small smoke check or documented Wave 0 verification.
- [ ] Confirm `cover/` and `_build/test/junit/` are gitignored (no artifact leakage into commits or the Hex package).
- [ ] Framework install: `mix deps.get` after adding `junit_formatter` (no new framework — ExUnit already present).

## Security Domain

> `security_enforcement` not disabled in config → included. This is a CI-observability phase with no `lib/` change and no new runtime surface; the security surface is GitHub Actions permissions + token scope, not application code.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No app auth touched |
| V3 Session Management | no | — |
| V4 Access Control | **yes** | Least-privilege Actions permissions: `actions: read` scoped to the single `ci-observability` job; workflow default stays `contents: read` (D-03/D-14). Branch-protection read uses maintainer admin session, not a broadened CI token. |
| V5 Input Validation | minimal | `gh api --jq`/`jq` over GitHub-controlled JSON; no user input. Quote all shell vars (`set -euo pipefail`, the repo house style). |
| V6 Cryptography | no | No crypto. |
| V14 Config / CI-CD | **yes** | No SHA-pinning change here (Phase 107 HARD-02). Do NOT widen `permissions:`; do NOT add the aggregator to required checks; do NOT mutate branch protection. |

### Known Threat Patterns for GitHub Actions observability
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Permission creep via workflow-level `actions: read` | Elevation of Privilege | Scope to one job only (verified pattern: `release.yml:101-103`) |
| Aggregator job turning fork-PR skips into failures / leaking secret-gated job status | Denial of Service / Info Disclosure | Omit secret/label-gated jobs from `needs:`; `if: always()`; advisory-only (Pitfall 4) |
| Baseline doc leaking into shipped Hex package | Information Disclosure | Keep in `.planning/` only (D-10); not in `files:`/`extras` |
| Artifact (coverage/JUnit) leaking secrets | Information Disclosure | These contain test names + coverage %, no secrets; bounded retention (`retention-days`) |

## Sources

### Primary (HIGH confidence)
- Live `gh api repos/szTheory/rindle/branches/main/protection/required_status_checks` — JSON shape (`contexts[]` + `checks[].context`), live drift (`brandbook-tokens` absent). [VERIFIED 2026-06-20]
- Live `gh api repos/szTheory/rindle/actions/runs/{id}/jobs` — per-job + per-step `started_at`/`completed_at`, 16 jobs. [VERIFIED]
- Live `gh api .../workflows/ci.yml/runs` — `run_attempt`, `previous_attempt_url`, `conclusion`. [VERIFIED]
- hex.pm API `packages/junit_formatter` + `releases/3.4.0` — version 3.4.0, `requirements: {}`. [VERIFIED]
- In-repo: `ci.yml`, `release.yml`, `release-please-automerge.yml`, `branch-protection-apply.yml`, `setup_branch_protection.sh`, `test_helper.exs`, `mix.exs`, `scripts/ci/*`. [VERIFIED by direct read]

### Secondary (MEDIUM confidence)
- docs.github.com — Actions job summaries (`$GITHUB_STEP_SUMMARY`, 1 MiB cap), branch-protection REST endpoints. [CITED]
- github.com/actions/cache — `cache-hit` output semantics (exact-key only). [CITED]
- hexdocs.pm/junit_formatter — `JUnitFormatter` module + `:report_dir`/`:report_file` config. [CITED]

### Tertiary (LOW confidence)
- Exact stdout format of `mix compile --profile time` / `mix test --slowest 20` on 1.15/1.17 — assumed stable; Wave 0 verifies (A1).

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — junit_formatter + all API shapes verified live.
- Architecture (hybrid mechanism + aggregator): HIGH — grounded in actual ci.yml topology + verified API responses + the existing `release.yml` job-scoped-permissions precedent.
- Pitfalls: HIGH — each derived from a live API response (run_attempt, two-shape protection, cache-hit semantics, skip-on-fork jobs).

**Research date:** 2026-06-20
**Valid until:** 2026-07-20 (GitHub API + junit_formatter are stable; re-verify live required-check list right before the OBS-03 capture since branch protection can change).
