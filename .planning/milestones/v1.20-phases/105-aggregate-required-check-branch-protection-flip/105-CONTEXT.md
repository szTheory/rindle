# Phase 105: Aggregate Required Check + Branch-Protection Flip - Context

**Gathered:** 2026-06-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Land ONE stable `CI Summary` aggregate job inside `.github/workflows/ci.yml` and make it
the **sole** required status check on `main`, in a single isolated PR, **before** any
Phase 106 matrix/lane rename — so later renames never touch branch protection again.

The aggregate is a JOB added to the existing `CI` workflow (not a new workflow). In the
same change, `scripts/setup_branch_protection.sh` (the `REQUIRED_CHECKS` source of truth)
and the nightly re-assert (`.github/workflows/branch-protection-apply.yml`, which just runs
that script) are updated so branch protection requires **only** `CI Summary`. The fork-PR
"pending forever" trap is closed. `name: CI` and the `ci.yml` filename are preserved so the
release-train coupling stays intact.

**In scope:** GATE-01 (the `CI Summary` aggregate job — `needs:` all gating jobs,
`if: always()`, skipped→pass), GATE-02 (collapse `setup_branch_protection.sh` +
nightly re-assert to require only `CI Summary`; close the fork trap; preserve
`name: CI` / filename + release coupling).

**Out of scope (later phases):** trigger/lane split, concurrency groups, scoping the
`package-consumer` matrix, moving soak/live lanes to nightly (Phase 106 LANE-01..04);
async-safety / partitioning / action-pinning / `mix ci` / Dialyzer-lane (Phase 107).
This phase does **not** rename, split, or move any existing job — it only adds the
aggregate and flips the required-check set.
</domain>

<decisions>
## Implementation Decisions

Decisions are backed by three parallel research passes (GitHub Actions ecosystem
best-practice; szTheory sibling-repo prior art; Rindle-internal code grounding). All four
are mutually coherent: a **pure, zero-permission, network-free** gate (A) is exactly what
the skip-aware result evaluation (B) needs to "fail only on code health"; B's `if: always()`
+ skipped-as-pass is the same mechanism that defeats the fork/never-reported pending-forever
traps in (D); C's single-context collapse is safe because B's `needs:` set faithfully proxies
"everything that gates is green," and durable because one context is immune to the
matrix-name churn the current 13-entry list is fragile to.

### A. `CI Summary` is a NEW dedicated job, separate from `ci-observability`
- **D-01:** Add a brand-new top-level job `ci-summary` with **`name: CI Summary`** (the exact
  string that becomes the required context). Place it last, after `ci-observability`
  (`ci.yml:1315`). Purely additive.
- **D-02:** The gate is **pure and network-free** — it evaluates only the `needs` context.
  It makes **no `gh api` call** and declares **no `permissions:`** (inherits the workflow
  default `contents: read`; it touches no API). Do NOT extend `ci-observability` to gate:
  that job runs a `set -euo pipefail` paginated `gh api .../jobs` read (`ci.yml:1272-1275`,
  needs `actions: read`) and **can exit non-zero for infra reasons** — the exact 401-class
  flake recorded in `103-BASELINE.md:73-77`. A required check must not be able to false-red
  on a GitHub API hiccup. `ci-observability` stays a separate, non-required telemetry job.

### B. `needs:` set + result-evaluation semantics
- **D-03:** `CI Summary` **`needs:` the 11 deterministic gating jobs** — the same set
  `ci-observability` already depends on:
  `quality, optional-dependencies, integration, contract, proof, package-consumer,
  adoption-demo-unit, cohort-demo-smoke, adoption-demo-e2e, adopter, brandbook-tokens`.
- **D-04:** **Exclude the three real-API soak/live lanes** (`mux-soak`, `gcs-soak`,
  `package-consumer-gcs-live`) from `needs:`. Rationale (resolves the one point the research
  passes split on): (1) `package-consumer-gcs-live` is **`continue-on-error: true`**
  (`ci.yml:1072`) so its `result` is masked to `success` even on failure — gating on it is
  meaningless; (2) `mux-soak` (real Mux API, label-gated `streaming`) and `gcs-soak` (real
  GCS bucket) hit live third-party services with real credentials — gating *every* merge on
  them violates "a gate must not fail for reasons unrelated to code health," and a live
  provider outage would block all merges; (3) Phase 106 explicitly moves the soak/live lanes
  **to nightly / off the PR critical path**, so they are not PR-gating by design. This
  matches the existing `ci-observability` omission (`103-PATTERNS.md:113-117` "Pitfall 4").
- **D-05:** **Skip semantics:** treat `success` **and** `skipped` as pass; treat `failure`
  and `cancelled` as fail. Skipped-as-pass is **mandatory** — `cohort-demo-smoke`,
  `adoption-demo-e2e`, and `brandbook-tokens` are repo-gated (`if: github.repository ==
  'szTheory/rindle'`) and **skip on forks**; treating their skip as pass is what closes the
  fork trap. Blanket skip-pass is safe here because the only skips are these intentional
  fork-gates AND every dependency *root* (`quality`, `optional-dependencies`) is directly in
  `needs:`, so a real root failure is always caught directly (it can't "merge through" a
  skipped downstream dependent).
- **D-06:** **Evaluate `needs.*.result` EXPLICITLY** — do not rely on the job's implicit
  success. The canonical footgun ("green checkmark lie"): an `if: always()` job whose steps
  don't *check* results reports success even when a dependency failed. Use the house idiom
  (proven in lattice_stripe / rulestead / sigra): an inline `run:` bash gate that iterates
  the results and `exit 1`s on any non-pass, collecting **all** failing jobs before exiting
  (so the log lists every red lane). Iterate `toJSON(needs)` via `jq` (drift-proof — auto-
  covers whatever is in `needs:`, no per-lane env var to maintain) and append a `| Job |
  Result |` table to `$GITHUB_STEP_SUMMARY` using the repo's existing append idiom
  (`ci.yml:1278-1291`). Prefer this over `re-actors/alls-green` — no szTheory repo adopted
  the third-party action, and keeping a third-party action out of the merge-gate critical
  path avoids a supply-chain surface (planner may still choose alls-green pinned-by-SHA if it
  wants named `allowed-skips` documentation, but the bash loop is the house default).
- **D-07 (naming, locked by roadmap):** The job display name is **`CI Summary`** (GATE-01
  names it verbatim). Do NOT adopt the siblings' `ci-gate` / `release_gate` name — the
  roadmap string wins and becomes the required context.

### C. Branch-protection list reconciliation
- **D-08:** Collapse `setup_branch_protection.sh` `REQUIRED_CHECKS` from 13 entries to the
  single context **`"CI Summary"`**. Edit the **two** in-lockstep spots in that one file
  (no other file encodes the list): the `REQUIRED_CHECKS=(...)` array (`:17-31`) AND the
  cosmetic `print_expected_text()` heredoc bullets (`:36-48`). `expected_json()`,
  `--print-expected*`, and the `gh api -X PUT` body read the array generically and need no
  change. `branch-protection-apply.yml` needs no edit (it just runs the script).
- **D-09 (drift reconciliation, deliberate):** `brandbook-tokens` is currently in the
  script's expected list but **absent from the live required set** (recorded drift,
  `103-BASELINE.md:120-133`). After the flip it leaves the required list entirely but **keeps
  running** as a job, and becomes **transitively gated** for the first time via
  `CI Summary`'s `needs: [... brandbook-tokens]`. This is an intended behavioral tightening —
  **surface it explicitly in the PR description.** Before flipping, dump the live applied set
  (`scripts/ci/check_required_checks.sh main`) so the cutover starts from a known state.

### D. Rollout safety (highest blast radius) — two-step cutover, do not reorder
- **D-10:** **The PR makes NO live branch-protection mutation.** It only (a) adds the
  `ci-summary` job to `ci.yml` and (b) edits the script's array + heredoc. During the PR the
  12 individual contexts remain the live gate, so the PR is gated normally and `CI Summary`
  runs as a **new, non-required** check — fully reversible.
- **D-11:** **Apply the live flip only AFTER the job has run on `main` at least once.** A
  maintainer runs `GH_TOKEN=<admin-PAT> scripts/setup_branch_protection.sh main` (or
  dispatches `branch-protection-apply.yml`, or waits for the `17 7 * * *` nightly). This is a
  **human go/no-go checkpoint** consistent with this milestone's between-step gating.
- **D-12 (the gotcha this avoids):** GitHub does **not** verify a required context name was
  ever produced — requiring `CI Summary` *before* any run posts it (or with a mismatched
  name string) leaves every PR pending **forever** ("Expected — Waiting for status to be
  reported"). Merge-job-first / flip-protection-second is what avoids it. The `if: always()`
  gate also fixes the existing latent fork trap: `Cohort Demo Smoke` is a live required
  context **and** fork-gated today (`ci.yml:740`, `if: github.repository ==`), so fork PRs
  currently hang on it — the single always-running `CI Summary` (skip-as-pass) ends that.
- **D-13 (verify the cutover):** Reuse `scripts/ci/check_required_checks.sh main` (Phase 103,
  read-only) to confirm live `.contexts[]` is exactly `CI Summary` and the diff vs
  `--print-expected-json` is empty. No new tooling needed. Also confirm the verbatim reported
  check-run name via `gh api repos/szTheory/rindle/commits/<main-sha>/check-runs` shows
  `CI Summary` before the flip.

### Claude's Discretion
- Exact bash/jq phrasing of the result loop, the `$GITHUB_STEP_SUMMARY` table wording, and
  `runs-on` pin (`ubuntu-22.04`, matching the repo) are the planner's/executor's to finalize,
  as long as D-05/D-06 semantics hold.
- Whether to also adopt mailglass's read-only `verify-branch-protection.sh` is optional
  polish — `check_required_checks.sh` already covers verification (D-13).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase inputs (load-bearing)
- `.planning/phases/103-observability-baseline/103-BASELINE.md` — the frozen pre-change
  OBS-03 baseline: §2 the **12 live required contexts**, §3 the `brandbook-tokens` drift,
  §4 names Phase 105 as the consumer. This is the exact pre-change gate to preserve/replace.
- `.planning/ROADMAP.md` § "Phase 105" — success criteria 1–4 (GATE-01/GATE-02), and the
  Phase 106 entry (soak/live → nightly) that justifies D-04.
- `.planning/REQUIREMENTS.md` — GATE-01 (`:54-55`), GATE-02 (`:57-60`).

### Files this phase edits / depends on
- `.github/workflows/ci.yml` — add `ci-summary` job (after `:1315`); `name: CI` (`:1`) and
  filename are LOCKED. Existing `ci-observability` job (`:1243-1315`) is the structural
  analog (needs set, `if: always()`, summary-append idiom) — but is NOT extended (D-02).
- `scripts/setup_branch_protection.sh` — `REQUIRED_CHECKS` array (`:17-31`) + heredoc
  (`:36-48`) are the two edit spots (D-08); `expected_json()` (`:64-85`) unchanged.
- `.github/workflows/branch-protection-apply.yml` — nightly re-assert; runs the script
  verbatim (`:40-46`), no edit needed.
- `scripts/ci/check_required_checks.sh` — read-only verifier reused for D-13.
- `.github/workflows/release.yml` `gate-ci-green` (`:96-210`, keys off `workflow_id:
  'ci.yml'` + run `conclusion`) and `.github/workflows/release-please-automerge.yml`
  (`on: workflow_run: workflows: [CI]` + run `conclusion`) — release coupling that MUST stay
  intact; **neither references any job/check name**, so the flip is invisible to both.

### Convention sources
- `.planning/phases/103-observability-baseline/103-PATTERNS.md` — job-scoped `permissions:`
  precedent, `$GITHUB_STEP_SUMMARY` append idiom, "Pitfall 4" (omit skip-prone jobs from an
  `if: always()` aggregator's `needs:`), and the "don't touch `name: CI`/filename" rule.
- `.planning/phases/104-cache-tooling-hygiene/104-CONTEXT.md` — single-workflow-shape
  conventions; composite-action house style (overkill for a pure-bash gate — use inline
  `run:`).

### Prior art (sibling szTheory repos — reference, not edited)
- `/Users/jon/projects/lattice_stripe/.github/workflows/ci.yml` (`ci-gate`, `:262-291`) —
  cleanest aggregate-gate to model; its wait-logic was originally ported FROM rindle.
- `/Users/jon/projects/rulestead/.github/workflows/ci.yml` (`release_gate`, `:316-362`) +
  `scripts/ci/release_gate.sh` — conditional skip-normalization (the escalation path if
  Phase 106 adds path-filtered lanes — see deferred note).
- `/Users/jon/projects/sigra/.github/workflows/ci.yml` (`ci-gate`, `:1325-1376`) — bash loop
  treating `skipped` as pass.
- `/Users/jon/projects/mailglass/.planning/research/ci-branch-protection-recommendation.md` —
  the authoritative WHY for collapsing N matrix-suffixed required contexts to one aggregate
  (the matrix-name-drift footgun rindle is exposed to today).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ci-observability` job (`ci.yml:1243-1315`): exact structural template for the new gate —
  copy its `needs:` list (the 11 gating jobs), its `if: always()`, and its
  `{ echo …; } >> "$GITHUB_STEP_SUMMARY"` table idiom. But it is a SEPARATE job (D-02), not
  extended.
- `scripts/ci/check_required_checks.sh`: read-only required-check verifier (Phase 103) —
  reused as-is for the post-flip verification (D-13). No re-encoding of names (reads
  `--print-expected-json`).
- `setup_branch_protection.sh --print-expected-json`: the single source of truth for the
  required set; the collapse to one context flows through it automatically.

### Established Patterns
- Required-check list is encoded in **exactly one file** (`setup_branch_protection.sh`), in
  two spots (load-bearing array + cosmetic heredoc) — edit both together.
- House aggregate-gate idiom across sibling repos = inline bash loop over `needs.*.result`
  with `if: always()`, branch protection requires only that one context. rindle is the
  family's origin for the wait-logic but never promoted it into `ci.yml` — this phase
  canonicalizes the pattern its siblings already copied.
- Release coupling is **workflow-level** (run name `CI` + filename `ci.yml` + run
  conclusion), never job-level — a job-level aggregate is safe.

### Integration Points
- New `ci-summary` job → its `needs:` edges into the 11 gating jobs; its `name: CI Summary`
  → the single context written by `setup_branch_protection.sh` → asserted by
  `branch-protection-apply.yml` → verified by `check_required_checks.sh`.
- Untouched: `release.yml` `gate-ci-green` and `release-please-automerge.yml` (consume the
  workflow run `conclusion`, not the required-check set).

</code_context>

<specifics>
## Specific Ideas

- Job display name MUST be the literal string `CI Summary` (GATE-01 / becomes the required
  context). `runs-on: ubuntu-22.04` to match the rest of `ci.yml`.
- Gate carries no `permissions:` and makes no network call — it is a pure `needs.*.result`
  evaluation.
- PR description must explicitly flag that `brandbook-tokens` goes from non-gating to
  transitively gating (D-09) — a deliberate tightening.

</specifics>

<deferred>
## Deferred Ideas

- **Soak/live lanes (`mux-soak`, `gcs-soak`, `package-consumer-gcs-live`) → nightly /
  off PR critical path** — Phase 106 (LANE-03). Excluded from the `CI Summary` `needs:` here
  (D-04) precisely because they are bound for nightly.
- **Conditional skip-normalization for path-filtered lanes** (rulestead's `release_gate.sh`
  pattern: an *unexpectedly* skipped lane fails, only path-filter-intended skips pass) —
  revisit in Phase 106 IF the trigger/lane split introduces `paths:`-filtered jobs. Not
  needed now: rindle's only skips are deterministic fork-gates (`if: github.repository ==`),
  so blanket skip-as-pass is safe today.
- **mailglass `verify-branch-protection.sh` adoption** — optional read-only drift-detection
  polish; `check_required_checks.sh` already covers the need.

### Reviewed Todos (not folded)
- `2026-06-19-fix-docker-demo-startup-warnings.md` ("Fix Docker demo startup warnings") —
  reviewed (weak keyword-only match: `scripts`, `yml`). **Not folded** — unrelated to CI
  gating / branch protection; belongs to Docker demo DX, not this phase.

</deferred>

---

*Phase: 105-aggregate-required-check-branch-protection-flip*
*Context gathered: 2026-06-21*
