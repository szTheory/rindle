# Phase 71: CI Proof Honesty - Context

**Gathered:** 2026-05-27 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 71 closes the v1.15 **CI proof honesty** wedge: maintainers and adopters can read an honest severity story for CI lanes, and the highest-signal consumer/adopter lanes actually fail the workflow when they fail.

**In scope:**
- CI-01: `RUNNING.md` gains a maintainer-facing **CI lane severity matrix** (merge-blocking vs advisory vs secret-gated soak) covering `quality`, `integration`, `contract`, `package-consumer`, `adopter`, and optional soak lanes.
- CI-02: Remove job-level `continue-on-error: true` from `package-consumer`; remove step-level `continue-on-error` on `adopter` doctor + lifecycle test steps (no job-level COE on `adopter` — none exists today).
- Workflow comments at soak/advisory jobs explaining why they remain non-blocking, with pointer to `RUNNING.md`.

**Out of scope (explicit):**
- Making dialyzer, credo, doctor, or coveralls merge-blocking (REQUIREMENTS out-of-scope).
- Removing `release.yml` `gate-ci-green` BYPASS on non-success/timeout (document only).
- Making `contract` ExUnit step or entire `contract` job merge-blocking (beyond CI-02).
- Branch protection / required-check configuration in GitHub settings (post-merge checklist only).

</domain>

<decisions>
## Implementation Decisions

All decisions confirmed via assumptions mode (2026-05-27). Source: `.github/workflows/ci.yml`, `RUNNING.md`, `.planning/REQUIREMENTS.md` CI-01/CI-02, post-v1.14 assessment thread.

### RUNNING.md matrix (CI-01)

- **D-01:** Add `## CI lane severity` **immediately after** the intro block (after the "shared install/runtime matrix" paragraph, **before** `## Verify The Runtime`). Do not relocate or rewrite the existing FFmpeg install matrix.
- **D-02:** Matrix is a table with columns: **Job** (workflow job name), **Severity** (`merge-blocking` | `advisory` | `secret-gated soak`), **When it runs** (trigger / `needs` summary), **Notes** (one line). One row per top-level `ci.yml` job plus notable step-level splits inside `quality` and `contract` (see D-07).
- **D-03:** Link from matrix intro to `.github/workflows/ci.yml` as source of truth; matrix must stay in sync when YAML changes.

### CI-02 workflow changes

- **D-04:** Delete job-level `continue-on-error: true` on the `package-consumer` job (`.github/workflows/ci.yml` ~298).
- **D-05:** On `adopter`, remove step-level `continue-on-error: true` from:
  - `Verify AV runtime with public doctor task` (~515)
  - `Run adopter tests` (~522)
  Do **not** add job-level `continue-on-error` on `adopter` (already absent; ROADMAP criterion satisfied).
- **D-06:** Keep the duplicate doctor step on `adopter` (blocking after D-05) — both doctor and lifecycle tests are part of the release-readiness signal; do not drop doctor to reduce redundancy with `quality`'s advisory doctor.

### Advisory and soak lanes (unchanged YAML)

- **D-07:** **Merge-blocking ladder** documented in the matrix:
  | Job / step | Severity | Notes |
  |------------|----------|-------|
  | `quality` — Compile, Check formatting | merge-blocking | Both matrix cells (Elixir 1.15/26, 1.17/27) must pass |
  | `quality` — Credo, Doctor (full), AV doctor, Coveralls, Dialyzer | advisory | Step-level `continue-on-error: true` |
  | `integration` | merge-blocking | Lifecycle + MinIO adapter tests; `needs: quality` |
  | `contract` — Run AV hygiene gate | merge-blocking | `scripts/assert_av_hygiene.sh` |
  | `contract` — Run contract tests | advisory | Step-level COE; job still required in graph |
  | `package-consumer` | merge-blocking | After D-04; install-smoke matrix + release preflight |
  | `adopter` | merge-blocking | After D-05; canonical lifecycle + doc parity steps |
  | `mux-soak` | secret-gated soak | Label `streaming` on PR; **blocking when job runs** (no COE) |
  | `gcs-soak` | secret-gated soak | Repo + secrets; test step advisory (COE); skips when secrets empty |
  | `package-consumer-gcs-live` | secret-gated soak | Job-level COE; live GCS install-smoke when secrets present |
- **D-08:** Do **not** remove step-level COE from `quality`, `contract` tests, `gcs-soak` test step, or job-level COE on `package-consumer-gcs-live`.
- **D-09:** Document `release.yml` `gate-ci-green` behavior: non-`success` conclusion or wait timeout logs `(BYPASSED)` and publish continues (~204–214). **No workflow change** this phase.

### Workflow comments (ROADMAP criterion 4)

- **D-10:** Add `# Phase 71 (CI proof honesty):` comment blocks adjacent to each **non-blocking** soak/advisory job or step listed in D-08, mirroring existing `mux-soak` / `gcs-soak` header style (~580–590, ~680–686). Each block states **why** the lane stays non-blocking (fork secrets, optional provider proof, dialyzer/credo policy, missing GCS secrets) and points to `RUNNING.md` for the full matrix.
- **D-11:** Update `package-consumer` and `adopter` job headers after D-04/D-05 to state they are **merge-blocking** release-readiness lanes.

### Post-merge maintainer checklist (Claude's discretion)

- **D-12:** After merge, verify GitHub branch protection required checks include `package-consumer` and `adopter` if green-main honesty is to hold in practice (settings are out of repo).

### Claude's Discretion

- Exact matrix table wording and row ordering in `RUNNING.md`.
- Whether to add a one-line link from `README.md` to the new CI section (only if it fits existing doc parity patterns without scope creep).
- Doc parity test updates if `docs_parity_test.exs` should assert the CI section exists.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and requirements
- `.planning/ROADMAP.md` — Phase 71 goal and success criteria
- `.planning/REQUIREMENTS.md` — CI-01, CI-02; out-of-scope table (dialyzer/credo, release bypass)
- `.planning/PROJECT.md` — v1.15 maintenance charter
- `.planning/threads/2026-05-27-post-v114-milestone-assessment.md` — CI proof honesty open concern

### CI implementation (source of truth)
- `.github/workflows/ci.yml` — All lane definitions and `continue-on-error` placements
- `.github/workflows/release.yml` — `gate-ci-green` BYPASS behavior (~204–214)
- `RUNNING.md` — Target doc for CI-01 matrix (FFmpeg content unchanged below new section)

### Prior CI lane decisions (pattern reference)
- `.planning/milestones/v1.6-phases/36-public-dx-onboarding-ci-proof/36-CONTEXT.md` — package-consumer / mux-soak lane design
- `.planning/milestones/v1.7-phases/41-onboarding-docs-doctor-package-consumer-proof/41-CONTEXT.md` — GCS generated-app lane
- `.planning/milestones/v1.7-phases/37-gcs-adapter-foundation/37-CONTEXT.md` — secret-gated soak discipline

### Methodology
- `.planning/METHODOLOGY.md` — Adopter-First Done, Repo-Truth Evidence Ladder lenses

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `RUNNING.md`: Existing maintainer/adopter runtime matrix; FFmpeg sections and `docs_parity_test.exs` assertions must remain valid.
- `.github/workflows/ci.yml`: Extensive inline comments at `mux-soak`, `gcs-soak`, `package-consumer`, `adopter` — extend same pattern for Phase 71.
- `scripts/install_smoke.sh`, `scripts/release_preflight.sh`: Invoked by `package-consumer`; failures must fail job after D-04.

### Established Patterns
- Secret-gated soak: fork PRs get empty secrets; lanes skip or fail closed without leaking credentials (Phase 36/37 CONTEXT).
- `adopter` `needs: [quality, integration, contract]` — explicit dependency graph for release-readiness documentation.
- Advisory static analysis in `quality` (credo, dialyzer) — intentional; not changing in v1.15.

### Integration Points
- `RUNNING.md` linked from `README.md` and `guides/getting_started.md` (lines 10–12) — new CI section is maintainer-facing but lives in same doc per CI-01.
- Release train: `gate-ci-green` documented but unchanged; publish path independent of CI-02.

</code_context>

<specifics>
## Specific Ideas

- User confirmed all assumptions without correction (assumptions mode, 2026-05-27).
- Post-v1.14 assessment: green `main` may overstate package-consumer/adopter readiness until CI-02 lands.

</specifics>

<deferred>
## Deferred Ideas

- Making `contract` ExUnit tests merge-blocking — noted in assessment; out of CI-02 scope.
- Tightening `release.yml` to hard-fail publish on red CI — separate high-impact change.
- Making dialyzer/credo merge-blocking — explicit REQUIREMENTS out-of-scope.

</deferred>

---

*Phase: 71-ci-proof-honesty*
*Context gathered: 2026-05-27*
