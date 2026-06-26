# Phase 106: Trigger Split + Matrix/Lane Refinement - Context

**Gathered:** 2026-06-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Now that `CI Summary` is the **sole** required check (Phase 105), split CI work by
**trigger** so the per-PR critical path carries only *representative* signal at ≤7 min
wall-clock, while release-readiness *breadth* moves to `push:main` / nightly / release.
This delivers the milestone's headline 15→≤7 min PR cut (LANE-01..04).

**In scope:**
- **LANE-01** — a fast PR lane with a `concurrency` group that cancels stale in-progress PR
  runs; main + release lanes serialize and **never** cancel.
- **LANE-02** — scope the `package-consumer` long pole by trigger: one representative `image`
  install-smoke on PR; full 5-profile matrix + `release_preflight` + `hex.publish --dry-run`
  on `push:main`/nightly/release, with the release full-verification gate provably intact.
- **LANE-03** — a **separate `nightly.yml`** lane carrying the broad OTP×Elixir compat matrix,
  `gcs-soak`, `package-consumer-gcs-live`, and an owned (gating) Dialyzer lane — off the PR
  critical path.
- **LANE-04** — a documented keep/optimize/move-to-nightly/quarantine/delete (buckets A–E)
  classification backing every lane placement; coverage moved off the PR critical path; the
  trust/speed tradeoff labeled explicitly in CONTRIBUTING and the PR.

**Out of scope (later/other phases):**
- Async-safety audit / ExUnit partitioning, action SHA-pinning + supply-chain, `mix ci` +
  CONTRIBUTING authoring depth, faithful Linux-Chromium repro → **Phase 107** (HARD-01..04).
- Making Dialyzer merge-blocking *on PR* (explicitly rejected — see D-19).
- A GitHub merge-queue (`merge_group`) — deferred (see Deferred Ideas).
- ZERO `lib/` public-API change (whole-milestone invariant).

**Hard invariants (highest blast radius — never violate):**
- Never rename `ci.yml`'s filename or `name: CI` (release-train coupling via
  `release-please-automerge.yml` + `release.yml gate-ci-green`).
- `CI Summary` must treat `skipped` as **pass** (fork-PR safety).
- Never weaken the release full-verification gate: the full 5-profile matrix +
  `release_preflight` + `hex.publish --dry-run` MUST still run, provably, before publish.
- The nightly lane must **never** become a required check on PRs.
</domain>

<decisions>
## Implementation Decisions

Decisions are backed by four parallel research passes (GitHub Actions ecosystem best-practice;
szTheory sibling-repo prior art — sigra/rulestead/lattice_stripe; Rindle-internal code +
Phase 103 timing baseline; the project CI DNA in `prompts/gsd-rindle-elixir-oss-dna.md`). All
four sets are mutually coherent and were cross-checked against each other. Evidence: the
Phase-103 per-job timing baseline (`Package Consumer Proof Matrix + Release Preflight` =
**550s avg / 887s p95** — the long pole; `Adoption Demo E2E` = 160s/318s; `Cohort Demo Smoke`
= 105s/176s; `Quality` ≈ 140s; `Integration` 60s; `Adopter` 58s; `adoption-demo-unit` 92s).

### A. PR-lane signal cut (LANE-01, LANE-04) — the trust/speed tradeoff
- **D-01 (model):** Adopt the **Tokio model** — a representative gate on PR, breadth
  post-merge/nightly — NOT the Ecto/Oban/Phoenix model (full matrix on every PR). Justified:
  rindle's lane-cost profile (install-smoke matrix, Playwright E2E, Docker cold-start) is
  unlike a pure lib's (compile + ExUnit); the deviation is well-precedented at the top of OSS.
  Coheres with the DNA "split lanes by responsibility… keep heavy checks scoped" rule.
- **D-02 (stays on PR):** `quality` (both cells), `optional-dependencies`, `integration`,
  `contract`, `proof`, `adopter`, `adoption-demo-unit`, `brandbook-tokens`, the scoped
  `package-consumer` (image-only, D-10), and `CI Summary`. Wall-clock ≈ **7.2 min p95 / 5 min
  avg** (jobs fan out after `quality`+`optional-dependencies`; PR wall-clock ≈ longest single
  chain, not the sum — long pole = image-smoke chain ~414s p95 or adopter chain ~385s p95).
- **D-03 (`integration`/`adopter`/`contract`/`proof` are NON-NEGOTIABLE on PR):** deterministic,
  MinIO-local (no third-party), highest "expensive-to-discover-late" value per second. Do NOT
  move these to chase budget — scope the package-consumer matrix instead (D-10). A regression
  here that only surfaces on main would block the whole team's merge train.
- **D-04 (move to `push:main`): `adoption-demo-e2e`** (318s p95, ~2× its avg — a variance
  signature; Chromium/browser flake class; fork-skipped today). Its PR-side proxy is
  `adoption-demo-unit` (browser-free admin-console mount + brand + lifecycle render), which
  stays on PR (D-02). MTTD of a real render regression = 1 merge (blocks the *next* merge, not
  the innocent author).
- **D-05 (move to `push:main`): `cohort-demo-smoke`** (Docker-compose cold-start; already
  `if: github.repository == 'szTheory/rindle'` so it gives **zero** signal on fork PRs today;
  its historical breaks were compile/pin failures `quality`+`optional-dependencies` catch on
  PR independently). MTTD = 1 merge.
- **D-06 (concurrency, LANE-01):** PR lane uses a `concurrency` group with
  `cancel-in-progress: true` (abandon stale PR pushes). `push:main` and `release` lanes
  serialize and set `cancel-in-progress: false`. **Footgun this avoids:** cancelling a main
  run would destroy the very full-matrix run that release coupling (`gate-ci-green` keys off
  run `conclusion`) depends on. Mirror Oban's cancel-on-PR / serialize-on-push pattern.
- **D-07 (coverage off the critical path, LANE-04):** coverage *measurement* is advisory
  telemetry — gating tests stay (`mix coveralls` is still the test invocation), but no
  per-PR coverage-% gate sits on the critical path.

### B. Package-consumer split mechanism (LANE-02)
- **D-08 (mechanism — Hybrid B+C, sigra-proven):** Split the current single `package-consumer`
  job into TWO top-level jobs:
  - **`package-consumer` (lean, PR + all triggers):** the single representative `image`
    install-smoke + cheap structural checks (version-alignment). Stays in `CI Summary.needs`.
  - **`package-consumer-full` (`if: github.event_name != 'pull_request'`):** `release_preflight.sh`,
    `repo_hygiene_check.sh --ci`, `hex.publish --dry-run`, and a
    `strategy.matrix.profile: [video, image, tus, mux, gcs]` with **`fail-fast: false`** so the
    five proofs run **in parallel** (off-PR wall-clock ≈ slowest profile, not 5× serial).
    `skipped` on PR. **No `continue-on-error`** anywhere on this lane (would mask leg failures
    from the run conclusion — the `package-consumer-gcs-live` masking trap from 105 D-04).
  This matches sigra's `install_smoke` (PR) + event-gated `install_matrix` shape exactly.
  Rejected (A) one-job-event-gated-steps (buries full-vs-lean in step `if:`s, no parallelism,
  heavy setup still on PR) and pure (C) matrixify (orthogonal to the trigger split).
- **D-09 (`CI Summary` interaction — Design 1, the highest-stakes call):** **OMIT
  `package-consumer-full` from `CI Summary.needs` entirely** (sigra's exact choice). The lean
  `package-consumer` (always-running) is the PR-gating representative. **Zero change to the
  Phase-105 `eval_ci_summary.sh` gate** (blanket skip-as-pass stays drift-proof). This is the
  resolution of the 105-deferred conditional-skip-normalization tension: the answer is
  **omit-from-needs, NOT normalize-inside-gate**. Rationale: the skip-as-pass "green checkmark
  lie" footgun only bites when the gate `needs:` a conditionally-skipped job; if the full lane
  is not in `needs:`, the gate makes no claim about it. The rulestead `release_gate.sh`
  event-aware skip-normalization stays the **escalation path** reserved for a future
  *path-filtered* lane — not adopted now.
- **D-10 (PR scoping):** On PR, only the `image` profile runs (representative of the common
  consumer path). The 5-profile→1-profile cut is THE load-bearing wall-clock win (the
  887s p95 long pole). `gcs` (structural-only) + `mux` (cassette mode — no live API) go in the
  off-PR full matrix; the **real-API** `gcs-soak`/`mux-soak`/`package-consumer-gcs-live` go to
  nightly (D-14).
- **D-11 (release-gate proof, LANE-02 criterion):** Release readiness is proven by the
  **`push:main` `ci.yml` run conclusion**, NOT by `CI Summary` or any check name.
  `release.yml gate-ci-green` polls `listWorkflowRuns({workflow_id:'ci.yml', head_sha})` and
  requires `conclusion === 'success'`. Because `package-consumer-full` is a first-class job in
  the push:main run (`if: != pull_request`) with no `continue-on-error`, any leg failure makes
  the run conclusion non-success → publish blocked. Airtight *because* the release path keys
  off run conclusion. The matrix-suffixed contexts (`package-consumer-full (video)` …) are
  **not** required checks (only `CI Summary` is, post-105), so leg names are free to
  add/rename/remove — never re-add any to `setup_branch_protection.sh`.

### C. Nightly lane home (LANE-03)
- **D-12 (separate file, NOT `schedule:` in `ci.yml` — decisive):** Create
  **`.github/workflows/nightly.yml`** with **`name: Nightly`**. A `schedule:` trigger on
  `ci.yml` is **disqualifying**: scheduled runs are named `CI` on `head_branch: main` and
  would fire `release-please-automerge.yml`'s `on: workflow_run: workflows: [CI]` +
  `head_branch == 'main'` listener (no SHA/event filter) on a **cron tick** → it would
  `gh pr list` for an eligible Release Please PR and **auto-squash-merge it + dispatch
  `release.yml`**. A clock-triggered release violates the "never weaken the release gate"
  invariant. A separate file (distinct `workflow_id`, run name `Nightly`) is invisible to all
  three release consumers and structurally cannot become a PR required check (no
  `pull_request:` trigger). Precedent: `branch-protection-apply.yml` is already a standalone
  scheduled workflow. Reuse the existing composite actions (`setup-elixir`, `setup-minio`) so
  duplication is near-zero — do NOT introduce a `workflow_call` reusable workflow (the only
  shared surface is setup, already factored into composites).
- **D-13 (broad matrix — curated diagonal, NOT cartesian):** Nightly `compat-matrix` job runs
  the full test suite across a **curated ~6-cell diagonal**, NOT a cartesian product
  (cartesian/dynamic-matrix is an explicit milestone anti-feature). Recommended cells (planner
  pins exact patches): `1.15/26` (floor), `1.15/25` (OTP<27 polyfill path on the floor),
  `1.16/26` (interior), `1.17/27` (PR ceiling/home), `1.18/27`, `1.18/28` (newest/newest
  drift early-warning). Deliberately exercises **both sides of the OTP-27 polyfill branch**
  (`mix.exs:142-144`). `fail-fast: false`. Mirrors Ecto/Oban/LiveView (curated diagonal +
  lint-on-newest); the PR lane keeps its representative 2-cell matrix.
- **D-14 (nightly contents):** `compat-matrix`, owned `Dialyzer` (D-17), `gcs-soak` (moved
  from ci.yml, keep `if: github.repository ==`), `package-consumer-gcs-live` (moved; **drop
  `continue-on-error`** so it becomes a real signal), and a `Nightly Summary` + issue-on-failure
  job. **`mux-soak` STAYS in `ci.yml` as a label-gated PR lane** (`if: contains(...labels...
  'streaming')`) — it has no natural nightly cadence (no PR label exists on a schedule); it is
  already excluded from `CI Summary.needs` (105 D-04). Classify it as "label-gated PR lane,"
  NOT "nightly," in the LANE-04 buckets — do not silently move it.
- **D-15 (cron):** `27 7 * * *` (07:27 UTC). Off-the-hour avoids the documented top-of-hour
  scheduled-run clustering/queue-drop; offset from `branch-protection-apply.yml`'s `:17` for
  clean log separation in the same low-traffic UTC window.
- **D-16 (failure surfacing — advisory + push alert):** Nightly is advisory (never a required
  check). Add a `nightly-failure-issue` job (`if: failure() && github.event_name == 'schedule'`,
  job-scoped `permissions: issues: write`) that opens/updates a tracking issue on failure —
  prefer inline `gh issue create` with find-existing-open-nightly-issue→comment-else-create
  (zero new dependency, house bash idiom per 105 D-06) over a third-party action. Default
  GitHub scheduled-failure emails only reach the last committer — insufficient for the
  maintainer-as-consumer JTBD. A `Nightly Summary` job mirrors `CI Summary`'s
  bash-loop-over-`needs.*.result` + `$GITHUB_STEP_SUMMARY` table idiom for at-a-glance status.

### D. Dialyzer ownership (LANE-03)
- **D-17 (Option C — owned + gating + nightly):** Extract Dialyzer from the `quality` job's
  advisory steps (`ci.yml:195-228`, CI-04 `continue-on-error`) into a dedicated **`Dialyzer`**
  job that lives in `nightly.yml`, is **GATING** there (`mix dialyzer` WITHOUT
  `continue-on-error` → a real type-contract regression or ignore-file drift fails the nightly
  lane), and is **removed from PR runs entirely**. This is the only placement that reconciles
  LANE-03 ("owned + off the PR critical path") with the DNA rule ("merge-blocking vs advisory
  is explicit; lanes must be meaningful") — advisory-anywhere lets the 11-entry
  `.dialyzer_ignore.exs` + warning set rot (the failure mode the milestone retires).
- **D-18 (`CI Summary` does NOT `needs:` Dialyzer):** explicit — mirrors the 105 D-04 exclusion
  of nightly-bound lanes. Adding it would re-gate every PR and defeat LANE-03.
- **D-19 (NOT PR-gating — rejected):** rulestead + Oban gate Dialyzer on PR, but both accept it
  on the critical path; rindle's milestone forbids that (headline ≤7-min cut). Phoenix/sigra/
  lattice_stripe don't run Dialyzer in CI at all. Nightly-gating is the contract-respecting
  middle path; MTTD ≈ 24h is acceptable for a *contract*-confidence signal (the merge-blocking
  ExUnit suite still catches behavior on every PR). Optionally also run it on `push:main` for
  faster MTTD (planner's discretion) — but never on PR.
- **D-20 (PLT cache + drift-prevention):** Reuse the Phase-104 PLT restore/save split verbatim;
  key on **OTP + Elixir + `hashFiles('mix.exs', '.dialyzer_ignore.exs')`** (the existing CACHE
  key, NOT `mix.lock`). Because the nightly lane spans the broad D-13 matrix, the PLT key's
  OTP/Elixir prefix now covers more cells (each a distinct PLT lineage — a cold build on the
  first nightly after any OTP/Elixir bump; fine nightly, free wall-clock). Anti-rot: gating is
  the primary device; visible nightly red (D-16); optionally flag stale/unused ignore lines.

### Claude's Discretion (planner/executor to finalize)
- Exact bash/jq phrasing of the concurrency `group:` keys, the nightly summary/issue body
  wording, matrix patch pins, and whether `nightly.yml` *also* re-runs `package-consumer-full`
  for redundancy (LANE-02 lists nightly as a valid trigger; its primary home is ci.yml push:main
  per D-11 — adding it to nightly is optional belt-and-suspenders, cheap via composites).
- Whether to add a `paths:`-filter that adds the relevant install-smoke profile when an
  adapter's files change (representative-image-drift mitigation) — optional, lean toward Phase 107.
- Skipping MinIO setup on the structural-only `gcs` matrix leg to save runner-minutes.

### Folded Todos
None folded.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase inputs (load-bearing)
- `.planning/phases/103-observability-baseline/103-BASELINE.md` — §1 per-job timing baseline
  (avg + p95). THE evidence for every wall-clock claim and lane-placement decision.
- `.planning/phases/105-aggregate-required-check-branch-protection-flip/105-CONTEXT.md` —
  the `CI Summary` gate semantics (D-05 skip-as-pass, D-06 explicit result-eval, the bash loop),
  D-04 soak/live exclusion, and the **deferred conditional-skip-normalization note** this phase
  resolves (→ D-09: omit-from-needs).
- `.planning/ROADMAP.md` § "Phase 106" — the 5 success criteria + LANE-01..04.
- `.planning/REQUIREMENTS.md` — LANE-01 (`:64-66`), LANE-02 (`:68-70`), LANE-03 (`:72-73`),
  LANE-04 (`:75-77`); cartesian-matrix-explosion + "fake green" out-of-scope clauses (`~:119,123`).
- `prompts/gsd-rindle-elixir-oss-dna.md` — §2 "CI is a contract surface, not a test runner"
  (`:29`, named-purpose lanes; merge-blocking vs advisory EXPLICIT) and §"CI as Layered Proof"
  (`:175`, split lanes by responsibility, keep heavy checks scoped, stable names where branch
  protection depends on them) + §"Release as Verified Chain" (`:198`, dry-run before publish).
  The locked CI philosophy every decision coheres with.

### Files this phase edits / depends on
- `.github/workflows/ci.yml` — `name: CI` (`:1`) + filename LOCKED. `package-consumer`
  (`:528-683`, split per D-08). `quality` job + advisory Dialyzer steps (`:195-228`, extracted
  per D-17). `pull_request: types:[…labeled]` (`:12` — note `labeled` still yields
  `event_name == 'pull_request'`, so the D-08 `if:` correctly skips the full lane on label).
  `gcs-soak` (`~:1007`), `package-consumer-gcs-live` (`~:1078`), `mux-soak` (`~:934`).
  `ci-summary` job (`:1338-1367`).
- `.github/workflows/nightly.yml` — **NEW** (D-12).
- `.github/workflows/release-please-automerge.yml` — `on: workflow_run: workflows:[CI]` +
  `head_branch=='main'` (`:4-6,22`), no SHA filter → the disqualifying hazard behind D-12.
- `.github/workflows/release.yml` — `gate-ci-green` (`:96-213`; keys off `workflow_id:'ci.yml'`
  + `head_sha` + run `conclusion`) → the release-proof mechanism for D-11.
- `.github/workflows/branch-protection-apply.yml` — existing standalone scheduled workflow
  (`cron: "17 7 * * *"`) → the precedent + cron-offset basis for D-12/D-15.
- `.github/actions/setup-elixir`, `.github/actions/setup-minio` — reusable composites
  (D-12: neutralize the "separate file = duplication" cost).
- `scripts/install_smoke.sh` — the 5 profiles (video/image/tus/mux/gcs); `gcs` is structural-only,
  `mux` is cassette-mode. `scripts/release_preflight.sh` — the release-readiness checks.
- `scripts/ci/eval_ci_summary.sh` — the Phase-105 gate; **unchanged** under D-09.
- `setup_branch_protection.sh` — required-check source of truth; **unchanged** (only `CI Summary`
  required; matrix-leg names are free per D-11).
- `.dialyzer_ignore.exs` — 11-entry baseline; PLT key input + anti-rot target (D-20).
- `mix.exs` — `elixir: "~> 1.15"` support window; OTP-27 polyfill branch (`:142-144`) → D-13.
- `RUNNING.md` § "CI lane severity" — existing merge-blocking/advisory language the LANE-04
  classification + CONTRIBUTING label must cohere with.

### Prior art (sibling szTheory repos — reference, not edited)
- `/Users/jon/projects/sigra/.github/workflows/ci.yml` — `install_matrix`
  (`if: github.event_name != 'pull_request'` + `strategy.matrix`, **absent from `ci-gate.needs`**)
  = the D-08/D-09 shape, shipped. Also a `schedule:` cron precedent (but in-ci.yml — rindle
  rejects per D-12 due to its different release coupling).
- `/Users/jon/projects/rulestead/.github/workflows/ci.yml` + `scripts/ci/release_gate.sh` —
  conditional skip-normalization (the D-09 escalation path, NOT adopted now); gates Dialyzer in
  its `lint` lane (the D-19 PR-gating model rindle rejects).
- `/Users/jon/projects/lattice_stripe/.github/workflows/ci.yml` — cleanest aggregate gate
  (originally ported from rindle); no Dialyzer.

### Ecosystem references (web)
- Tokio CI (`basics` gate + heavy/flaky lanes off PR) — the D-01 model.
- Ecto / Oban / Phoenix LiveView CI — curated-diagonal matrices + lint-on-newest (D-13).
- GitHub Docs: scheduled-workflow 60-day auto-disable; scheduled-failure notifies last
  committer only; `schedule` top-of-hour delay (D-15/D-16 footguns).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ci-observability` / `ci-summary` jobs (`ci.yml:1252-1367`) — `if: always()` + bash loop over
  `needs.*.result` + `$GITHUB_STEP_SUMMARY` table idiom; template for the `Nightly Summary` job.
- Composite actions `.github/actions/setup-elixir` (deps/_build cache) + `.github/actions/setup-minio`
  — reused by every new/moved job so `nightly.yml` and the split `package-consumer-full` add
  near-zero setup duplication.
- Phase-104 PLT restore/save split (`ci.yml:195-220`) — lifted verbatim into the owned Dialyzer
  job (D-20).
- `scripts/install_smoke.sh` profile dispatch + `scripts/release_preflight.sh` — moved, not
  rewritten, into `package-consumer-full`.

### Established Patterns
- Required-check set is `CI Summary` ONLY (Phase 105) → internal job/matrix-leg names are free to
  add/rename/split without touching branch protection (D-11). This is what makes matrixify free.
- Release coupling is **workflow-level** (run name `CI` + filename `ci.yml` + run `conclusion`),
  never job/check-name-level → a separate `nightly.yml` is invisible to it; a `schedule:` on
  `ci.yml` is not (D-12).
- House aggregate-gate idiom = inline bash loop over `needs.*.result`, `if: always()`, skip==pass
  (no third-party action on the merge-gate critical path).
- Curated-diagonal matrix + lint-on-newest is the family + ecosystem norm (D-13); cartesian is a
  milestone anti-feature.

### Integration Points
- New `package-consumer-full` (`if: != pull_request`) → runs on push:main → its result feeds the
  push:main run `conclusion` → consumed by `release.yml gate-ci-green` (the release proof, D-11).
- New `nightly.yml` → distinct `workflow_id`/run-name `Nightly` → NOT matched by
  `release-please-automerge.yml`'s `workflows:[CI]` listener, NOT in branch protection (D-12).
- Moved `gcs-soak`/`package-consumer-gcs-live` → `nightly.yml`; `mux-soak` stays in `ci.yml`
  (label-gated). `CI Summary.needs` loses nothing it gated (those were already excluded, 105 D-04).
- Dialyzer extracted from `quality` → `Dialyzer` job in `nightly.yml`; PR `quality` shrinks
  (one of the long-pole removals enabling ≤7 min).
</code_context>

<specifics>
## Specific Ideas

- PR wall-clock target is ≤7 min on a representative change; D-02 hits ~7.2 min p95 / ~5 min avg.
  The scoped `package-consumer` (image-only, D-10) is the load-bearing cut, not the demo-lane
  moves — but the demo-lane moves (D-04/D-05) are what keep p95 under budget (the demo-e2e chain
  alone is ~502s = 8.4 min if left on PR).
- **LANE-04 trust/speed label** (must appear in CONTRIBUTING + the PR, per the requirement). Draft:
  > On every PR we run the representative gate — compile (warnings-as-errors) + full test suite on
  > both supported Elixir/OTP cells, optional-dependency compile, integration (storage + MinIO),
  > contract + docs-parity proofs, the canonical adopter lifecycle, the storage-free
  > adoption-demo unit suite, the token→CSS drift gate, and one representative `image`
  > package-consumer install-smoke — targeting ≤7 minutes. We verify the following **after merge**
  > (`push:main`) or **nightly**, not on your PR: the full five-profile package-consumer matrix +
  > release preflight + `hex.publish --dry-run`, the Playwright browser E2E, the Docker-compose
  > cold-start smoke, the broad OTP×Elixir compatibility matrix, the owned Dialyzer lane, and the
  > real-API GCS/Mux soak lanes. Why: these are expensive (the 5-profile matrix is the ~9-min long
  > pole), browser/Docker-flaky (false reds erode trust more than they catch bugs), or depend on
  > live third-party services (a provider outage must never block your merge). A regression in a
  > moved lane is caught on `main` within one merge — it blocks the *next* merge, not your PR — and
  > the full release-verification gate always runs, provably, before any Hex publish.
- LANE-04 A–E bucket seed: **keep** = integration/contract/proof/adopter/adoption-demo-unit/
  brandbook-tokens/`image` smoke; **optimize** = matrixify the 5 profiles, extract Dialyzer;
  **move-to-nightly** = broad compat matrix, gcs-soak, gcs-live, owned Dialyzer; **label-gated PR
  lane** = mux-soak (NOT nightly); **off-critical-path** = full package matrix/preflight/dry-run +
  demo-e2e + cohort-smoke + coverage. No quarantine/delete entries identified.
</specifics>

<deferred>
## Deferred Ideas

- **GitHub merge-queue (`merge_group`)** to run heavy lanes only at merge time — same MTTD as the
  push:main approach but adds branch-protection complexity right after the Phase-105 single-required-
  check flip. Revisit in a later milestone, not this phase.
- **`paths:`-filtered install-smoke profiles** (add the tus/mux/gcs profile to PR when those adapter
  files change — representative-image-drift mitigation) — optional polish, lean toward Phase 107.
- **rulestead `release_gate.sh` conditional skip-normalization** — the D-09 escalation path; adopt
  ONLY if a future *path-filtered* (not event-filtered) lane must be gate-enforced through
  `CI Summary`. Not needed now (omit-from-needs handles the event-filtered case).
- **`workflow_call` reusable workflow** to share whole job bodies between PR-CI and nightly —
  rejected now (composites already share the only shared surface: setup). Revisit only if the two
  ever need byte-identical full job bodies.
- **Phase 107 (HARD-01..04):** async-safety/partitioning, action SHA-pinning + supply-chain,
  `mix ci` + CONTRIBUTING depth, faithful Linux-Chromium repro. The issue-on-failure action (if a
  third-party one is chosen) gets SHA-pinned there.

### Reviewed Todos (not folded)
- `2026-06-19-fix-docker-demo-startup-warnings.md` ("Fix Docker demo startup warnings") — weak
  keyword-only match (0.2, `yml`); already reviewed-and-rejected in Phase 105. Not folded —
  Docker-demo DX, unrelated to trigger/lane refinement.
</deferred>

---

*Phase: 106-trigger-split-matrix-lane-refinement*
*Context gathered: 2026-06-22*
