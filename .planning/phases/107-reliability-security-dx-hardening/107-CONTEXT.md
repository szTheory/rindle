# Phase 107: Reliability, Security & DX Hardening - Context

**Gathered:** 2026-06-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Settle the now-stable v1.20 pipeline — the final phase of the milestone. Four
independent hardening tracks:

- **HARD-01 — Test async correctness:** Land an ExUnit async-safety *static guard*
  before any conversion, then convert verified-safe modules to `async: true`.
  `--partitions` adoption is **evidence-gated** and **deferred this phase** (see D-01).
- **HARD-02 — Supply-chain posture:** Pin **all** third-party + first-party actions to
  immutable SHAs, land `dependabot.yml` (`github-actions` + `mix`), add
  `{:mix_audit, "~> 2.1"}` to the audit lane, and declare least-privilege
  `permissions:` on every job.
- **HARD-03 — DX docs + local parity:** A single `mix ci` alias mirroring the
  merge-blocking PR checks; `CONTRIBUTING.md` documents the lanes + required check +
  local command; the README badge points at the meaningful (`CI Summary`) gate.
- **HARD-04 — Faithful Linux-Chromium repro:** A pinned Playwright container + exact
  `@playwright/test`/font pins + `scripts/ci/e2e_local.sh`, used by **both** CI's E2E
  lane and local runs; reconcile the divergent token-pair vs runtime contrast
  thresholds to **one** shared constant.

**Out of scope (later/other phases):**
- `--partitions` / DB-per-partition / merged-coverage wiring (deferred — D-01; not
  justified by Phase 103 measurement).
- Any `lib/` public-API or runtime behavior change (whole-milestone invariant).
- Making Credo/Dialyzer merge-blocking on PR (CI-04 keeps them advisory; Dialyzer is
  owned+gating in `nightly.yml` per 106 D-17).
- New CI lanes / topology changes — the lane set is **settled** as of Phase 106.

**Hard invariants (highest blast radius — never violate):**
- Never rename `ci.yml`'s filename or `name: CI` (release-train coupling).
- `CI Summary` stays the **sole** required check; `skipped` == **pass** (fork-PR safety).
  Pinning/permissions/audit changes must not add or remove a required check.
- Never weaken the release full-verification gate (full 5-profile matrix +
  `release_preflight` + `hex.publish --dry-run` still runs, provably, before publish).
- `nightly.yml` never becomes a PR-required check.
- ZERO `lib/` public-API or behavior change.
</domain>

<decisions>
## Implementation Decisions

All four locked at the recommended option; each is evidence-backed (Phase 103 timing
baseline + the current-state codebase scout below). The user's standing preference is
locked recommendations over interview-style discussion.

### A. Test async correctness (HARD-01)
- **D-01 (partitioning — DEFER, async-only this phase):** Land the async-safety static
  guard, convert verified-safe modules to `async: true`; **do NOT wire `--partitions`
  into CI this phase.** Evidence: the unit-test/`quality` job runs **~140s avg / 184s
  p95** (103-BASELINE) — already far under the ≤7-min PR budget hit in Phase 106, so it
  is **not a long pole**; standard GitHub runners are 2–4 cores; `--partitions` adds
  DB-per-partition + merged-coverage machinery for marginal payoff. This is the honest
  reading of HARD-01's "adopted only where measurement and runner cores justify it"
  clause: not justified yet. **Note:** partition *infra already exists* —
  `config/test.exs:13,31` uses `database: "rindle_test#{System.get_env("MIX_TEST_PARTITION")}"`
  — so it is harmless and ready if a future slice ever needs it. Record the deferral
  explicitly (see Deferred Ideas).
- **D-02 (guard-before-conversion ordering — MANDATORY):** The static async-safety guard
  must land and pass **before** any module is flipped to `async: true`. The guard is a
  test/check that flags async-marked modules using shared-state primitives unsafe under
  concurrent ExUnit (e.g. `Application.put_env`, `System.put_env`, named/registered
  processes, global Mox mode, unsandboxed ETS, CWD/`File` mutation, global Ecto sandbox
  in non-`{:shared}` mode). Research must read `test/`, the sandbox setup
  (`test/test_helper.exs` — `Sandbox.mode(:manual)` for both `Rindle.Repo` and
  `Rindle.Adopter.CanonicalApp.Repo`), and Oban test config to classify *genuinely*
  unsafe vs *conservatively* `async: false`. Current state: 72 `ExUnit.Case` files,
  60 `async: true` vs **74** `async: false` occurrences — the conversion target is the
  conservatively-marked subset.

### B. Supply-chain posture (HARD-02)
- **D-03 (SHA-pin breadth — pin ALL, uniform):** Pin **every** `uses:` to a full-length
  immutable commit SHA, **including first-party `actions/*`**, each with a trailing
  `# vX.Y.Z` version comment. Rationale: a uniform, auditable rule beats a
  "third-party-only" carve-out (which is non-uniform and easy to drift). Covers the
  current mutable tags: `actions/checkout@v4`, `actions/setup-node@v4`,
  `actions/cache@v4`, `actions/cache/restore@v4`, `actions/cache/save@v4`,
  `actions/upload-artifact@v4`, `actions/github-script@v7`, `erlef/setup-beam@v1`,
  `google-github-actions/auth@v2`, `google-github-actions/setup-gcloud@v2`,
  `googleapis/release-please-action@v4` — across `ci.yml`, `nightly.yml`, `release.yml`,
  `release-please-automerge.yml`, `branch-protection-apply.yml`, and the composite
  `action.yml`s.
- **D-04 (dependabot — grouped, low-noise):** Land `.github/dependabot.yml` with the
  `github-actions` and `mix` ecosystems (per the requirement); **grouped** updates
  (minor + patch grouped together) on a **weekly** cadence to keep the SHAs current
  without PR spam. dependabot is what keeps the D-03 SHAs from rotting. *(Discretion:
  optionally add an `npm` ecosystem for `examples/adoption_demo` so the HARD-04 exact
  Playwright pin stays current — coherent but not required by HARD-02.)*
- **D-05 (`mix_audit` — add to deps + audit lane):** Add `{:mix_audit, "~> 2.1"}`
  (`only: [:dev, :test]` or as a `:ci` tool — planner's call) and wire `mix deps.audit`
  into the audit lane. Planner determines exact lane placement against the settled
  Phase-106 lane set; it is fast + deterministic so PR-side is fine, but note it fetches
  the hex advisory DB (network) — gating-vs-advisory follows the house rule (advisory
  unless the user wants security findings to block). `junit_formatter` (already present,
  Phase 103) is the pattern for a test-only tool dep.
- **D-06 (least-privilege `permissions:`):** Every job declares an explicit
  least-privilege `permissions:` block (default `contents: read`; widen only where a job
  genuinely needs it). `nightly.yml` is already done (106 D-16: the
  `nightly-failure-issue` job has `issues: write` and nothing else). Audit the remaining
  `ci.yml` / `release.yml` jobs and the existing workflow-level defaults; do not grant a
  token scope a job doesn't use.

### C. DX docs + local parity (HARD-03)
- **D-07 (`mix ci` mirrors the merge-blocking PR set):** Add a `ci` alias to `mix.exs`
  (no `ci` alias exists today; `precommit: ["test"]` is the closest) that runs the
  **same merge-blocking checks the PR gate runs** — compile (warnings-as-errors),
  `format --check-formatted`, the gating test suite (`mix coveralls`/`mix test`), the
  optional-dependency compile, the contract/docs-parity proofs, and the
  `brandbook-tokens` drift gate. Document any local prerequisite (e.g. MinIO for the
  integration legs) in `CONTRIBUTING.md`. Goal: a single command reproduces the PR
  verdict locally.
- **D-08 (`CONTRIBUTING.md` — fill the reserved section):** `CONTRIBUTING.md` already
  documents the trust/speed lane split and **explicitly reserves** the local-command
  section for "Phase 107, HARD-03." Fill it: the lanes, the **sole required check
  (`CI Summary`)**, and the local `mix ci` command + prerequisites. Keep coherent with
  `RUNNING.md` §"CI lane severity" and the Phase-106 `106-LANE-CLASSIFICATION.md`
  already linked from CONTRIBUTING.
- **D-09 (README badge — keep the workflow badge, clarify it reflects `CI Summary`):**
  GitHub has **no native per-check badge**; the existing
  `ci.yml/badge.svg?branch=main` workflow-run badge already reflects the run whose
  conclusion is gated by `CI Summary`. Keep it and make the docs state it represents the
  `CI Summary` gate. Do **not** build a custom per-check badge endpoint.

### D. Faithful Linux-Chromium repro (HARD-04)
- **D-10 (both CI + local on ONE pinned container):** Move the adoption-demo E2E lane
  (currently `npx playwright install --with-deps chromium` on bare ubuntu, `ci.yml:1144`)
  onto a **pinned `mcr.microsoft.com/playwright:vX.Y.Z-<distro>` container**, and have
  `scripts/ci/e2e_local.sh` run against the **same image**. Rationale: a repro is only
  "faithful" if both sides share the exact browser/font/OS bytes — this kills the
  "green in CI, red locally" class by construction, not convention. The E2E lane is
  nightly/push-only (106 D-04), so this touches no PR-critical-path timing.
- **D-11 (exact version + font pins):** Drop the caret — pin `@playwright/test` to an
  **exact** version (currently `^1.57.0` in `examples/adoption_demo/package.json`) and
  pin the font set the container provides so glyph metrics are deterministic across
  CI/local. The container tag and the `@playwright/test` version must match.
- **D-12 (contrast threshold — ONE shared 4.5:1 AA constant):** Reconcile the divergent
  thresholds to a **single shared constant = 4.5:1 (WCAG AA normal text)** exported from
  one module and consumed by **both** the token-pair gate (`brandbook/src/*.mjs` —
  `contrast.mjs` / `admin-contrast.mjs` / `cohort-contrast.mjs`) and the runtime
  polish gate (`brandbook/src/admin-gallery-check.mjs:283`, currently a literal
  `ratio < 4.5`). Locate the token-pair side's threshold, replace both literals with the
  shared import. Single source of truth, no drift.

### Claude's Discretion (planner/executor to finalize)
- Exact async-safety guard mechanism (a Credo check vs a bespoke ExUnit/`Code`-AST test
  vs a script) and the precise unsafe-primitive inventory.
- Which conservatively-`async: false` modules are *actually* convertible (requires the
  research read of `test/` + sandbox/Oban config — the phase research flag).
- The exact SHA values + version-comment format; whether to add the optional `npm`
  dependabot ecosystem for the demo.
- `mix_audit` dep environment (`:dev/:test` vs `:ci`) and gating-vs-advisory placement.
- Exact `mix ci` task list ordering and how MinIO-dependent legs are handled locally
  (skip-with-note vs documented prerequisite).
- The exact Playwright container tag/distro (jammy vs noble) and font package list.
- The shared-constant module's location/name and export shape.

### Folded Todos
None folded.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase inputs (load-bearing)
- `.planning/ROADMAP.md` § "Phase 107" — the goal + 4 success criteria + the research flag
  (async-safety classification + evidence-gated partitioning).
- `.planning/REQUIREMENTS.md` — HARD-01 (`:` async guard/convert/partitions),
  HARD-02 (SHA pins + dependabot + mix_audit + permissions), HARD-03 (`mix ci` +
  CONTRIBUTING + badge), HARD-04 (Playwright container + e2e_local.sh + pins + contrast
  constant); plus the **Out of Scope** table (no `pull_request_target`; no
  Credo/Dialyzer merge-blocking; no `lib/` change; no matrix explosion).
- `.planning/phases/103-observability-baseline/103-BASELINE.md` §1 — per-job timing
  (Quality ~140s avg / 184s p95) — THE evidence for the D-01 defer-partitions call.
- `.planning/phases/106-trigger-split-matrix-lane-refinement/106-CONTEXT.md` — the
  settled lane shape (D-01..D-20): which lanes are PR vs push:main vs nightly, the
  `CI Summary` gate semantics, the release-coupling invariants. The DX docs (HARD-03)
  describe **this** settled set.
- `prompts/gsd-rindle-elixir-oss-dna.md` — §"CI is a contract surface" (named lanes;
  merge-blocking vs advisory EXPLICIT), §"Release as Verified Chain" (dry-run before
  publish). Every HARD decision coheres with this.

### Files this phase edits / depends on
- **HARD-01:** `test/test_helper.exs` (`Sandbox.mode(:manual)` for `Rindle.Repo` +
  `Rindle.Adopter.CanonicalApp.Repo`); `config/test.exs:13,31` (already
  `MIX_TEST_PARTITION`-parameterized DB names — partition infra exists); the ~72
  `ExUnit.Case` test modules (74 `async: false` occurrences — the conversion target);
  `test/support/data_case.ex` (sandbox checkout pattern). Oban test config.
- **HARD-02:** `.github/workflows/ci.yml`, `nightly.yml`, `release.yml`,
  `release-please-automerge.yml`, `branch-protection-apply.yml`,
  `.github/actions/setup-elixir/action.yml`, `.github/actions/setup-minio/action.yml`
  (all `uses:` → SHA); **NEW** `.github/dependabot.yml`; `mix.exs` (`deps/0` →
  `{:mix_audit, "~> 2.1"}`; `:junit_formatter` at `:127` is the test-only-dep pattern).
- **HARD-03:** `mix.exs` `aliases/0` (`:284` — add `ci`; `precommit: ["test"]` is the
  current closest); `CONTRIBUTING.md` (reserved local-command section, ~`:9-12`);
  `README.md:10` (the `ci.yml` workflow badge); `RUNNING.md` §"CI lane severity" and
  `.planning/phases/106-trigger-split-matrix-lane-refinement/106-LANE-CLASSIFICATION.md`
  (already linked from CONTRIBUTING — keep coherent).
- **HARD-04:** `.github/workflows/ci.yml:~1131-1144` (the adoption-demo E2E setup /
  `npx playwright install`); `examples/adoption_demo/package.json:10` (`@playwright/test`
  `^1.57.0` → exact); `examples/adoption_demo/playwright.config.js`; **NEW**
  `scripts/ci/e2e_local.sh`; `brandbook/src/admin-gallery-check.mjs:283`
  (runtime `ratio < 4.5`); `brandbook/src/contrast.mjs`,
  `brandbook/src/admin-contrast.mjs`, `brandbook/src/cohort-contrast.mjs`
  (token-pair gates — the other side of the divergence);
  `test/brandbook/admin_design_system_validation_test.exs:148,169-173`
  (the test that asserts the contrast gates' output).

### Prior art (sibling szTheory repos — reference, not edited)
- `/Users/jon/projects/sigra/.github/workflows/ci.yml`,
  `/Users/jon/projects/rulestead/.github/workflows/ci.yml`,
  `/Users/jon/projects/lattice_stripe/.github/workflows/ci.yml` — for SHA-pin format,
  `dependabot.yml` shape, `mix_audit` lane placement, and least-privilege `permissions:`
  conventions already shipped in the family.

### Ecosystem references (web — research to confirm exact values)
- StepSecurity / GitHub "pin actions to a full-length commit SHA" guidance (D-03 format).
- `mcr.microsoft.com/playwright` image tags ↔ `@playwright/test` version mapping (D-10/D-11).
- `mix_audit` (rrrene/sobelow-adjacent; `mirego/mix_audit`) usage + advisory-DB behavior (D-05).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `config/test.exs` already parameterizes the test DB name with `MIX_TEST_PARTITION`
  (`:13`, `:31`) for **both** repos — partition infra is pre-built, so D-01's deferral
  costs nothing and a future enable is low-lift.
- `:junit_formatter` (`mix.exs:127`, `only: :test`, Phase 103) — the established pattern
  for adding `{:mix_audit, ...}` as a test/ci-only dep (D-05).
- `nightly.yml`'s `nightly-failure-issue` job (106 D-16) — the worked example of a
  job-scoped least-privilege `permissions:` block to mirror across other jobs (D-06).
- `ci-observability` / `ci-summary` bash-loop + `$GITHUB_STEP_SUMMARY` idiom — the house
  "no third-party action on the critical path" style that D-03 SHA-pinning and D-05
  audit-lane placement should respect.
- The adoption-demo Playwright E2E lane (`ci.yml:~1131-1144`, nightly/push-only) — the
  surface D-10 moves onto the pinned container; no PR-critical-path timing impact.

### Established Patterns
- Required-check set is `CI Summary` **only** (Phase 105) → adding `mix_audit`/permissions/
  SHA pins must not introduce a new required check; matrix-leg/job names stay free.
- Merge-blocking vs advisory is **explicit** (DNA rule) → D-05 must state which `mix_audit`
  is, and `mix ci` (D-07) mirrors only the **merge-blocking** set.
- Release coupling is workflow-level (`name: CI` + `ci.yml` filename + run conclusion) →
  SHA-pinning/permissions edits must not touch those identifiers.
- Contrast is gated in two places (token-pair `.mjs` gates + runtime `admin-gallery-check.mjs`)
  → D-12 unifies the threshold; the validation test asserts both outputs.

### Integration Points
- `mix ci` (D-07) ↔ the PR merge-blocking lane set (must stay in sync as the source of
  truth for "what a PR must pass").
- `dependabot.yml` (D-04) ↔ the D-03 SHA pins (keeps them current) ↔ `mix.exs` deps.
- The pinned Playwright container (D-10) ↔ both `ci.yml` E2E lane and
  `scripts/ci/e2e_local.sh` ↔ `examples/adoption_demo/package.json` exact pin (D-11).
- The shared 4.5:1 constant (D-12) ↔ all `brandbook/src/*contrast*.mjs` +
  `admin-gallery-check.mjs` + the brandbook validation test.

</code_context>

<specifics>
## Specific Ideas

- HARD-01 is **ordering-sensitive**: guard lands + passes *before* any `async: true`
  flip (D-02). The conversion is a free in-runner speedup; partitioning is explicitly
  off the table this phase (D-01).
- "Faithful" in HARD-04 means **same image both sides** (D-10) — not "a local script that
  approximates CI." That's the whole point of the requirement.
- The contrast reconciliation is a one-constant change, not a re-derivation: 4.5:1 WCAG
  AA normal text, single module, both gates import it (D-12).
- `CONTRIBUTING.md` literally reserved this work ("being added in a follow-up (Phase 107,
  HARD-03)") — D-08 fills that exact placeholder.

</specifics>

<deferred>
## Deferred Ideas

- **`--partitions` / DB-per-partition / merged coverage (HARD-01):** deferred per D-01 —
  not justified by the ~140s/184s test-job timing on 2–4-core runners. Infra
  (`MIX_TEST_PARTITION`) already exists; revisit only if a future slowest-test/cores
  measurement shows the test lane becoming a PR long pole. Aligns with DEFER-02
  (larger runners only if core-starvation is *measured*).
- **`npm` dependabot ecosystem for `examples/adoption_demo`** — optional belt-and-suspenders
  to keep the HARD-04 exact Playwright pin current; coherent with D-04 but beyond
  HARD-02's stated `github-actions` + `mix` scope. Planner's discretion.
- **Custom per-check (`CI Summary`) badge endpoint** — rejected (D-09): GitHub has no
  native per-check badge and the workflow-run badge already reflects the gated run.
  Revisit only if a literal check-specific badge becomes a hard requirement.
- Tracked-not-now milestone deferrals (REQUIREMENTS.md): **DEFER-01** flaky-quarantine
  lane (trigger: a test proves flaky), **DEFER-02** larger/self-hosted runners (trigger:
  measured core-starvation), **DEFER-03** property-based/nightly test expansion.

### Reviewed Todos (not folded)
None — no pending todos matched this phase's scope.

</deferred>

---

*Phase: 107-reliability-security-dx-hardening*
*Context gathered: 2026-06-22*
