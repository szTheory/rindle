# Phase 112: PR↔main gate shift-left - Research

**Researched:** 2026-06-28
**Domain:** GitHub Actions CI topology (Elixir/BEAM lib) — lean E2E smoke lane → aggregate required check
**Confidence:** HIGH (every claim repo-grounded against live `ci.yml`, the locked `v1.21-PR-MAIN-GATE-GAP.md` research, and `103-BASELINE.md` timing)

## Summary

Phase 112 is the LAST phase of v1.21 and the only phase that touches the *merge gate topology*. Its single coherent change: clone the existing push:main-only `adoption-demo-e2e` job into a **lean, PR-gating `adoption-demo-e2e-smoke`** job that runs the deterministic subset (`smoke.spec.js` + `admin-console.spec.js`), excludes `admin-screenshots.spec.js`, runs on *every* PR (no repo-gate, no event-gate), Chromium-only, MinIO-local, no secrets, pinned Playwright container — and add it to **`CI Summary.needs`** and **`ci-observability.needs`** ONLY. This closes the render-regression half of the PR↔main gap that let the 2026-06-26 cluster reach `main`, without giving back the v1.20 wall-clock win.

The work is almost fully de-risked by the locked research (`v1.21-PR-MAIN-GATE-GAP.md`, HIGH confidence, repo-grounded). Every topology decision is locked: which lane to add (Lane A only), which specs (`smoke` + `admin-console`), the wall-clock guard (≤ image-smoke long pole, p95 ≤ 7.5 min), and that `setup_branch_protection.sh` stays byte-unchanged (the new lane is gated *transitively* through `CI Summary.needs`, never as a second required context). The crux of GATE-03 — why adding a job to `CI Summary.needs` keeps the branch-protection script byte-unchanged — is verified below at the source level: `REQUIRED_CHECKS=("CI Summary")` is the sole context, and `eval_ci_summary.sh` auto-iterates whatever is in `needs:` (drift-proof), so no script edits are required.

**Primary recommendation:** Implement the locked `v1.21-PR-MAIN-GATE-GAP.md` §7 recommendation verbatim. The two genuinely open decisions for the planner: (1) the **mechanism** for scoping specs on the lean lane — the research proposes an `ADOPTION_DEMO_E2E_SPECS` env var threaded through `e2e_local.sh`, but the *active* lane uses `e2e_local.sh` which currently runs `npx playwright test` with NO spec arg, so this requires a back-compatible edit; (2) the **GATE-04 precondition** — `N` is symbolic in every source (never a locked number), and "N consecutive green push:main runs observed" is an **operator checkpoint**, not a scriptable gate. The planner must encode both as explicit human-verify checkpoints.

## User Constraints (from ROADMAP — treated as LOCKED spec; no CONTEXT.md exists yet)

> No `CONTEXT.md` exists for Phase 112 yet (this research precedes discuss-phase). The ROADMAP Success Criteria + Invariants are the locked spec per the task brief.

### Locked Decisions (ROADMAP Phase 112 + `v1.21-PR-MAIN-GATE-GAP.md` §7)

1. **Add exactly ONE lean lane** — `adoption-demo-e2e-smoke` — to the PR gate. No other lane moves.
2. **Lean lane runs the deterministic subset only**: `e2e/smoke.spec.js` + `e2e/admin-console.spec.js`, **excluding `e2e/admin-screenshots.spec.js`** and the rest of the 22-spec matrix.
3. **Lean lane runs on EVERY PR** — no `if: github.repository ==` repo-gate, no `event_name` gate. (A repo-gate would make it skip on forks → skip-as-pass "green lie".)
4. **Chromium-only, MinIO-local, NO secrets, pinned `mcr.microsoft.com/playwright:v1.57.0-noble`** (same pin as the full lane).
5. **Add the lane to `CI Summary.needs` AND `ci-observability.needs`** — and to nothing else. Never a second required context.
6. **`setup_branch_protection.sh` byte-unchanged** — `CI Summary` remains the SOLE required check (GATE-03).
7. **`eval_ci_summary.sh` byte-unchanged** — the lane always runs on PR → plain success/fail, no skip-normalization (GATE-01).
8. **The full `adoption-demo-e2e` matrix stays push:main-only** (unchanged).
9. **`cohort-demo-smoke`, `package-consumer-full`, `mux-soak` stay OFF the PR gate** with documented rationale (GATE-03).
10. **Wall-clock guard (GATE-02):** lean lane p95 ≤ the image-smoke long pole; PR p95 ≤ ~7.5 min; observed/guarded, not assumed. If exceeded, narrow to `smoke.spec.js` only.
11. **Ordering (GATE-04, LOAD-BEARING):** lane enters `CI Summary.needs` ONLY after COV/EPIPE/ISO (phases 108/109/110) land AND N consecutive green push:main `adoption-demo-e2e` runs are observed.

### Claude's Discretion (genuinely open — see "What the planner needs to decide")
- The exact spec-scoping mechanism (env var name, default behavior, which wrapper to edit).
- The value of `N` and how the operator checkpoint is worded.
- Whether GATE-A9 (push:main issue-on-failure alerting) is in-scope here or deferred (escalation flag).

### Hard Invariants (every v1.21 phase; highest blast radius)
- Never rename `ci.yml` filename or `name: CI` (release-train coupling via `release-please-automerge.yml` + `release.yml gate-ci-green`).
- `CI Summary` keeps `skipped`==pass and stays the SOLE required check.
- Never weaken the release full-verification gate (`package-consumer-full` push:main → `gate-ci-green`).
- **No `lib/` change** (this is a CI-YAML + shell-script phase).

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GATE-01 | Lean `adoption-demo-e2e-smoke` runs on every PR (Chromium-only, MinIO-local, no secrets, pinned container, deterministic specs only — excludes screenshot spec) and is in `CI Summary.needs` + `ci-observability.needs`. | §"Standard Stack"/§"Code Examples": exact job YAML from `v1.21-PR-MAIN-GATE-GAP.md` §7a, reconciled with the LIVE `adoption-demo-e2e` job (`ci.yml:891-996`). Specs verified present: `smoke.spec.js`, `admin-console.spec.js`, `admin-screenshots.spec.js` (`e2e/` dir). No spec uses `toHaveScreenshot` (pixel-diff-free → safe). |
| GATE-02 | PR p95 ≤ ~7.5 min; lean lane ≤ image-smoke long pole; observed/guarded. | §"Wall-Clock Budget": baseline durations from `103-BASELINE.md §1` (full E2E 318s p95 / 23 specs; package-consumer image-smoke 887s historical → now lean ~414s chain). Guard mechanism: `ci-observability` per-job timing + `collect_ci_baseline.sh` post-merge. |
| GATE-03 | `cohort-demo-smoke`, `package-consumer-full`, `mux-soak` stay off PR gate (documented); `setup_branch_protection.sh` byte-unchanged. | §"setup_branch_protection.sh invariant": `REQUIRED_CHECKS=("CI Summary")` (line 17-19) is the sole context; new lane gated transitively. Rationale tables for the 3 off-PR lanes in `v1.21-PR-MAIN-GATE-GAP.md` §2. |
| GATE-04 | Lane enters `CI Summary.needs` ONLY after COV/EPIPE/ISO land + N consecutive green push:main `adoption-demo-e2e` runs observed. | §"GATE-04 precondition": 108/109/110 are COMPLETE (verified in STATE.md). `N` is symbolic everywhere — operator checkpoint, not scriptable. Planner must encode a `checkpoint:human-verify`. |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| PR merge-gate aggregation | CI / GitHub Actions (`ci-summary` job) | Branch protection (`setup_branch_protection.sh`) | `CI Summary` is the sole required context; it aggregates `needs.*.result` with skip==pass. Adding a lane = add to its `needs:` only. |
| Browser render-regression detection | CI / Playwright-in-container (`adoption-demo-e2e-smoke`) | `adoption-demo-unit` (browser-free PR proxy) | The lean lane proves *browser* render of the admin console + cold-boot homepage; the unit lane already proves browser-free render. |
| Spec-set selection | Shell wrapper (`scripts/ci/e2e_local.sh`) | Playwright config (`playwright.config.js`) | The wrapper invokes `npx playwright test`; spec scoping is a wrapper-arg concern, not a config change (config stays Chromium-only single-project). |
| Release full-verification | CI push:main (`package-consumer-full`) → `release.yml gate-ci-green` | — | UNTOUCHED. Stays off-PR; the lean lane never enters this path. |
| Wall-clock observation | CI advisory (`ci-observability` job) | `collect_ci_baseline.sh` (operator) | Advisory per-job timing; the GATE-02 guard reads it post-merge. Never a required check. |

## Standard Stack

This is a CI/CD-topology phase. No new libraries. The "stack" is the existing, pinned CI toolchain.

### Core (all already present and pinned)
| Component | Version / Pin | Purpose | Why Standard |
|-----------|---------------|---------|--------------|
| `@playwright/test` | `1.57.0` (npm, `examples/adoption_demo/package.json`) | Browser E2E runner | Already the demo's E2E framework; pinned exactly. [VERIFIED: package.json] |
| Playwright container | `mcr.microsoft.com/playwright:v1.57.0-noble` (`ci.yml:926`, `e2e_local.sh:29`) | Pinned browser + font image — the tag IS the browser/font pin | Matches the 1.57.0 npm pin; eliminates "green in CI, red locally". [VERIFIED: ci.yml] |
| `setup-elixir` composite | `./.github/actions/setup-elixir` | BEAM setup + deps/_build cache | House composite (Phase 104). [VERIFIED: ci.yml] |
| `setup-minio` composite | `./.github/actions/setup-minio` | MinIO-local S3 (no secrets) | House composite; `cors-allow-origin: "*"` for the demo. [VERIFIED: ci.yml:971-974] |
| `actions/checkout` | `@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4.3.1` | SHA-pinned checkout | Phase 107 supply-chain pin. [VERIFIED: ci.yml] |
| `actions/setup-node` | `@49933ea5288caeca8642d1e84afbd3f7d6820020 # v4.4.0` | Node 20 for Playwright | SHA-pinned. [VERIFIED: ci.yml] |
| `actions/upload-artifact` | `@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4.6.2` | Playwright report on failure | SHA-pinned. [VERIFIED: ci.yml] |

### Supporting
| Component | Location | Purpose | When to Use |
|-----------|----------|---------|-------------|
| `scripts/ci/e2e_local.sh` | shell | Active wrapper the full lane runs (container-based) | The lean lane should reuse this (back-compatibly) — see "Don't Hand-Roll". |
| `scripts/ci/eval_ci_summary.sh` | shell | The `CI Summary` aggregate gate (auto-iterates `needs`) | Byte-unchanged — it is drift-proof. |
| `scripts/ci/collect_ci_baseline.sh` | shell | Reads per-job durations + conclusions over last N main runs | The GATE-02 wall-clock guard + GATE-04 green-run observation. |

**Installation:** None. No `npm install`, no `mix deps`. This phase edits `ci.yml` (+ one wrapper script) only.

## Package Legitimacy Audit

**Not applicable — this phase installs ZERO new packages.** Every tool is already pinned in the repo (Playwright 1.57.0, the container image, all SHA-pinned actions). No npm/hex/cargo additions. No registry verification needed.

## Architecture Patterns

### System Architecture Diagram (PR gate, after Phase 112)

```
  PR opened/synchronized
          │
          ▼
   ┌──────────────┐   ┌─────────────────────────┐
   │   quality    │   │ optional-dependencies   │   (matrix fan-out, ~184s p95)
   │  (1.15, 1.17)│   │     (1.15, 1.17)        │
   └──────┬───────┘   └───────────┬─────────────┘
          │  (every PR lane needs: [quality, optional-dependencies])
          ├───────────────┬───────────────┬──────────────┬─────────────┬───────────────┐
          ▼               ▼               ▼              ▼             ▼               ▼
   ┌────────────┐  ┌────────────┐  ┌──────────┐  ┌────────────┐ ┌──────────────┐ ┌──────────────────────┐
   │integration │  │  contract  │  │  proof   │  │ adoption-  │ │ package-     │ │ adoption-demo-e2e-   │
   │            │  │            │  │          │  │ demo-unit  │ │ consumer     │ │ smoke   ◄── NEW      │
   │ (MinIO)    │  │            │  │          │  │ (browser-  │ │ (image-smoke │ │ (Chromium smoke +    │
   │            │  │            │  │          │  │  free)     │ │  LONG POLE)  │ │  admin-console;      │
   └─────┬──────┘  └─────┬──────┘  └────┬─────┘  └─────┬──────┘ └──────┬───────┘ │  MinIO; NO secrets)  │
         │ (adopter needs integration+contract)        │              │         └──────────┬───────────┘
         ▼                                              │              │                    │
   ┌──────────┐   ┌────────────────┐                    │              │                    │
   │ adopter  │   │ brandbook-     │                    │              │                    │
   │          │   │ tokens         │                    │              │                    │
   └────┬─────┘   └───────┬────────┘   ┌──────────────┐ │              │                    │
        │                 │            │ ci-script-   │ │              │                    │
        │                 │            │ tests        │ │              │                    │
        │                 │            └──────┬───────┘ │              │                    │
        └─────────────────┴───────────────────┴─────────┴──────────────┴────────────────────┘
                                              │  (all the above are CI Summary.needs)
                                              ▼
                                    ┌────────────────────┐
                                    │     CI Summary     │  if: always()
                                    │  (skip==pass; pure │  ← SOLE required context
                                    │   needs.*.result)  │     (branch protection)
                                    └─────────┬──────────┘
                                              ▼
                                        merge allowed

  push:main (unchanged): adoption-demo-e2e (FULL 22-spec), cohort-demo-smoke,
  package-consumer-full → run conclusion → release.yml gate-ci-green → Hex publish
```

The ONLY structural deltas: a new `adoption-demo-e2e-smoke` node parallel to `adoption-demo-unit`/`package-consumer`, fed by `[quality, optional-dependencies]`, feeding `CI Summary` + `CI Observability`. Everything else is byte-unchanged.

### Recommended File Structure (files this phase touches)
```
.github/workflows/ci.yml         # + new job; + 1 needs line in ci-summary; + 1 needs line in ci-observability
scripts/ci/e2e_local.sh          # + back-compatible ADOPTION_DEMO_E2E_SPECS scoping (1 line)
RUNNING.md                       # + lean-lane row in CI lane severity; document the 3 off-PR rationales
# (optional) scripts/ci/<a unit assertion that unset env → full suite invocation, GATE-A3)
```

### Pattern 1: Lean-on-PR + full-on-merge (the house pattern, extended one notch)
**What:** A heavy lane keeps its full form on push:main; a *lean subset* of it gates PRs as a parallel chain that finishes under the existing long pole.
**When to use:** This phase exactly. `adoption-demo-unit` (PR, browser-free) ↔ `adoption-demo-e2e` (main, full browser) already half-implement it; the lean smoke completes it with a *browser* PR proxy.
**Example:** See "Code Examples" — the lean job is a near-clone of `adoption-demo-e2e` (`ci.yml:891-996`) with the repo/event gate REMOVED and the spec set NARROWED.

### Pattern 2: Aggregate required check (Phase 105 house pattern)
**What:** A single `ci-summary` job lists every gating job in `needs:`, runs `if: always()`, and passes iff every need is `success` OR `skipped`. It is the SOLE required branch-protection context.
**When to use:** Adding any lane to the gate = add it to `ci-summary.needs` (and `ci-observability.needs`). NEVER add a second required context.
**Example:** `eval_ci_summary.sh:44-53` iterates `to_entries[]` of `toJSON(needs)` — drift-proof, so adding a need requires NO script change.

### Anti-Patterns to Avoid
- **Adding a second required context** (e.g. making `Adoption Demo E2E Smoke` itself a required check): breaks the Phase-105 single-required-check invariant, forces a `setup_branch_protection.sh` edit, and re-introduces the pending-forever trap (D-12).
- **Repo-gating or event-gating the lean lane** (`if: github.repository == … && event_name != 'pull_request'`): would make it `skipped` on forks/PRs → `CI Summary` skip==pass emits a green "lie" about a lane that never proved anything.
- **Adding it to `CI Summary.needs` BEFORE the lane is de-flaked + N green runs observed** (GATE-04 violation): imports a live flake into the merge-blocking gate — the exact failure mode this milestone exists to prevent.
- **Editing `eval_ci_summary.sh` or `setup_branch_protection.sh`**: both must stay byte-unchanged. If you find yourself editing either, you've taken a wrong turn.
- **Renaming `ci.yml` or `name: CI`**: release-train coupling — catastrophic blast radius.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Boot Phoenix + browser-in-container for the lean lane | A new bespoke E2E script | Reuse `scripts/ci/e2e_local.sh` (back-compatible spec env var) | The wrapper already pins the container, bring-up, MinIO, `--network=host`. A second script = drift + maintenance. |
| Aggregating the new lane's result into the gate | A new required check or custom gate logic | Add to `ci-summary.needs`; `eval_ci_summary.sh` auto-iterates | The aggregate is drift-proof by design. |
| Observing wall-clock / green-run history | A new timing harness | `ci-observability` job (per-job native timing) + `collect_ci_baseline.sh` | Both already exist (Phase 103). |
| MinIO-local without secrets | Inline `docker run minio` | `./.github/actions/setup-minio` composite | House composite (Phase 104), byte-identical across lanes. |

**Key insight:** This phase is ~95% *reuse existing, pinned infrastructure with two surgical edits*. The risk is not "what to build" — it's "don't accidentally touch the byte-frozen gate scripts or the release coupling."

## Runtime State Inventory

> This is a CI-topology phase (no rename/migration), but the GATE-04 ordering constraint and live-vs-research drift make a runtime-state pass valuable. Answered explicitly:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no datastore stores any string this phase renames. | None. |
| Live service config | **GitHub branch-protection on `main`** stores the required-check contexts (`["CI Summary"]`) in GitHub's config, NOT in git. The phase asserts it stays `["CI Summary"]` — but the *actual* live value lives in GitHub's API, not the repo. `setup_branch_protection.sh --print-expected` is the source-of-truth assertion. | Operator: confirm live `gh api .../protection` still lists only `CI Summary` after merge (GATE-A5). No mutation expected. |
| OS-registered state | None. | None. |
| Secrets/env vars | The lean lane deliberately uses **NO secrets** (MinIO-local creds `minioadmin` are literal, not GitHub secrets). The full `mux-soak` lane's secrets are untouched. | None — verify the new job has no `secrets.*` reference. |
| Build artifacts | None new. The Playwright container image is pulled fresh per run (pinned tag). | None. |
| **GATE-04 observation state** | "N consecutive green push:main `adoption-demo-e2e` runs" lives in **GitHub Actions run history** (not git, not a file). Observed via `gh run list` / `collect_ci_baseline.sh`. | **Operator checkpoint** before wiring the lane into `needs:` — see "GATE-04 precondition". |

## Common Pitfalls

### Pitfall 1: Research-vs-live drift in `ci.yml` (research written 2026-06-26, phases 108-111 since edited the file)
**What goes wrong:** The locked research's §7a YAML sketch was written before phases 108/109/110/111 modified `ci.yml`. Lifting it verbatim could conflict with the current job shapes.
**Why it happens:** The research is HIGH confidence but pre-dates 4 phases of edits.
**How to avoid:** Clone from the LIVE `adoption-demo-e2e` job (`ci.yml:891-996`), not the research sketch. The live job is the ground truth: it has the exact env block, `setup-elixir` composite call (`install-deps: "false"`), `setup-minio` with `cors-allow-origin: "*"`, the `Cohort contrast + literal gate` step, and `run: bash scripts/ci/e2e_local.sh`.
**Warning signs:** A `needs:` array, env var, or step name in the new job that doesn't match the current `adoption-demo-e2e`.
**Reconciliation status (verified this session):** The current `adoption-demo-e2e` job (`ci.yml:891-996`) matches the research's §7a sketch closely — same env, same pin (`v1.57.0-noble`), same composite calls, same `e2e_local.sh` invocation. The deltas for the lean clone: (a) remove `if: github.repository == … && event_name != 'pull_request'`, (b) add spec-scoping, (c) rename, (d) the research sketch's standalone `mix deps.get` + `apt install` steps mirror the live job's `Install root dependencies` / `Install FFmpeg` / `Install libvips` steps — reuse the live forms.

### Pitfall 2: The spec-scoping env var does NOT exist yet
**What goes wrong:** Assuming `ADOPTION_DEMO_E2E_SPECS` already works. It does not — `e2e_local.sh:79` runs `npx playwright test --config=playwright.config.js` with NO spec argument (runs ALL specs).
**Why it happens:** The research *proposes* the env var (GATE-A3); it is unimplemented.
**How to avoid:** The plan must include the `e2e_local.sh` edit. The container invocation (`e2e_local.sh:72-79`) must append `${ADOPTION_DEMO_E2E_SPECS:-}` to the `npx playwright test` command (unset → empty → full suite, byte-identical to today; set → the listed specs). Note: `npm run e2e` (`package.json`) is `playwright test`, and `npx playwright test e2e/smoke.spec.js e2e/admin-console.spec.js` is the standard positional-spec form Playwright accepts.
**Warning signs:** The lean lane runs all 22 specs (no time savings) — the env var wasn't threaded through, OR it was set but the wrapper ignores it.

### Pitfall 3: Two wrappers exist — edit the RIGHT one
**What goes wrong:** Editing `scripts/ci/adoption_demo_e2e.sh` (which uses `npm run e2e` and builds from a hex tarball) instead of `scripts/ci/e2e_local.sh` (the container-based wrapper the LIVE `adoption-demo-e2e` lane actually runs).
**Why it happens:** Both wrappers exist and look similar. The active lane (`ci.yml:986`) runs `bash scripts/ci/e2e_local.sh`.
**How to avoid:** The lean lane reuses `e2e_local.sh`. Thread the spec env var through `e2e_local.sh`'s container `sh -c "... npx playwright test ..."` line (`:79`). `adoption_demo_e2e.sh` is a *different* (tarball-based) path not used by the current E2E lane — leave it alone unless the planner deliberately chooses it.

### Pitfall 4: skip==pass green-lie if the lean lane is gated
**What goes wrong:** Copying the full lane's `if: github.repository == 'szTheory/rindle' && github.event_name != 'pull_request'` into the lean lane. On a PR this evaluates false → the job is `skipped` → `CI Summary` counts `skipped` as pass → the gate claims green while the browser check never ran.
**Why it happens:** Reflexive copy of the full lane's guard.
**How to avoid:** The lean lane has NO `if:` gate at all (or only a guard that is ALWAYS true on PR). It must run on every PR. This is GATE-01 + the §6 Security pillar in the research.
**Warning signs:** The new job shows "skipped" on a PR run.

### Pitfall 5: Wiring into `needs:` before GATE-04 is satisfied
**What goes wrong:** Adding the lane to `CI Summary.needs` while the E2E lane still flakes → imports the flake into the merge gate.
**Why it happens:** Treating Phase 112 as a single atomic edit instead of a sequenced one.
**How to avoid:** The plan must SEQUENCE: (1) add the de-flaked lean job + thread the env var (job exists but is NOT yet in `needs:`), (2) operator checkpoint — confirm N consecutive green push:main `adoption-demo-e2e` runs, (3) THEN add it to `ci-summary.needs` + `ci-observability.needs`. Consider splitting into two plans/waves so the `needs:` wiring is its own commit behind a `checkpoint:human-verify`.

### Pitfall 6: RUNNING.md doc drift (pre-existing)
**What goes wrong:** RUNNING.md line 73-74 currently labels `adoption-demo-e2e` and `cohort-demo-smoke` as "merge-blocking" — but `ci.yml` has them push:main-only (NOT in `CI Summary.needs`). This is stale (a Phase-106 doc-update miss).
**How to avoid:** When the plan edits RUNNING.md's CI-lane-severity table (GATE-A7), correct this drift too: the lean `adoption-demo-e2e-smoke` is the merge-blocking PR lane; the full `adoption-demo-e2e` is push:main-only (release/main signal, not PR-required). Don't propagate the stale "merge-blocking" label to the new row incorrectly.

## Code Examples

### The LIVE `adoption-demo-e2e` job to clone from (`ci.yml:891-996`)
```yaml
# Source: .github/workflows/ci.yml:891 (LIVE, post phase-111)
  adoption-demo-e2e:
    name: Adoption Demo E2E
    runs-on: ubuntu-22.04
    needs: [quality, optional-dependencies]
    if: github.repository == 'szTheory/rindle' && github.event_name != 'pull_request'   # <-- REMOVE for lean
    env:
      MIX_ENV: test
      RINDLE_AV_USE_CGROUPS: "false"
      PGUSER: postgres
      PGPASSWORD: postgres
      PGHOST: localhost
      PGPORT: "5432"
      RINDLE_MINIO_URL: http://localhost:9000
      RINDLE_MINIO_ACCESS_KEY: minioadmin
      RINDLE_MINIO_SECRET_KEY: minioadmin
      RINDLE_MINIO_BUCKET: rindle-test
      RINDLE_MINIO_REGION: us-east-1
      ADOPTION_DEMO_BROWSER_PORT: "4102"
      PLAYWRIGHT_IMAGE: mcr.microsoft.com/playwright:v1.57.0-noble
    services:
      postgres:
        image: postgres:16-alpine
        ports: ["5432:5432"]
        env: { POSTGRES_USER: postgres, POSTGRES_PASSWORD: postgres, POSTGRES_DB: rindle_test }
        options: >- ...health...
    steps:
      - name: Checkout
        uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4.3.1
      - name: Set up Elixir
        uses: ./.github/actions/setup-elixir
        with: { elixir-version: "1.17", otp-version: "27", mix-env: test, install-deps: "false" }
      - name: Set up Node
        uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020 # v4.4.0
        with: { node-version: "20" }
      - name: Install FFmpeg
        run: sudo apt-get update && sudo apt-get install -y ffmpeg
      - name: Install libvips
        run: sudo apt-get update && sudo apt-get install -y libvips-dev
      - name: Install root dependencies
        run: mix deps.get
      - name: Set up MinIO for adoption demo
        uses: ./.github/actions/setup-minio
        with: { cors-allow-origin: "*" }
      - name: Cohort contrast + literal gate           # <-- consider keeping (cheap, deterministic) or dropping for lean
        run: node brandbook/src/cohort-contrast.mjs
      - name: Run adoption demo Playwright suite (pinned container)
        run: bash scripts/ci/e2e_local.sh              # <-- lean lane sets ADOPTION_DEMO_E2E_SPECS in env
      - name: Upload Playwright report on failure
        if: failure()
        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4.6.2
        with: { name: adoption-demo-playwright-report, path: examples/adoption_demo/playwright-report/ ..., if-no-files-found: ignore }
```

**Lean clone deltas (apply to the above):** rename to `adoption-demo-e2e-smoke` / `name: Adoption Demo E2E Smoke`; DELETE the `if:` line (run on every PR); ADD `ADOPTION_DEMO_E2E_SPECS: "e2e/smoke.spec.js e2e/admin-console.spec.js"` to `env:`; rename the artifact to `adoption-demo-e2e-smoke-report`.

### The `e2e_local.sh` spec-scoping edit (`e2e_local.sh:72-79`)
```bash
# Source: scripts/ci/e2e_local.sh:72 (LIVE) — current container invocation runs ALL specs:
docker run --rm --ipc=host --network=host \
  -v "${repo_root}:/work" -w /work/examples/adoption_demo \
  -e CI=1 -e ADOPTION_DEMO_PRESEEDED=1 -e ADOPTION_DEMO_REUSE_SERVER=1 \
  -e ADOPTION_DEMO_BROWSER_PORT="${demo_port}" \
  "${PLAYWRIGHT_IMAGE}" \
  sh -c "npm ci && ADOPTION_DEMO_BROWSER_PORT=${demo_port} npx playwright test --config=playwright.config.js"

# Proposed back-compatible edit (GATE-A3): thread ADOPTION_DEMO_E2E_SPECS through.
# Unset → "" → full suite (byte-identical to today); set → only the listed specs.
#   -e ADOPTION_DEMO_E2E_SPECS="${ADOPTION_DEMO_E2E_SPECS:-}" \
#   ... sh -c "npm ci && ADOPTION_DEMO_BROWSER_PORT=${demo_port} npx playwright test --config=playwright.config.js ${ADOPTION_DEMO_E2E_SPECS:-}"
# Playwright accepts positional spec files: `npx playwright test e2e/smoke.spec.js e2e/admin-console.spec.js`.
```

### The `CI Summary.needs` + `ci-observability.needs` deltas (`ci.yml:1232` and `:1326`)
```yaml
# Source: ci.yml:1326 (ci-summary.needs) — ADD one line:
  ci-summary:
    needs:
      - quality
      - optional-dependencies
      - integration
      - contract
      - proof
      - package-consumer
      - adoption-demo-unit
      - adoption-demo-e2e-smoke   # <-- ADD (GATE-04: only after N green main runs observed)
      - adopter
      - brandbook-tokens
      - ci-script-tests

# Source: ci.yml:1232 (ci-observability.needs) — ADD the same line for timing parity.
```

### `eval_ci_summary.sh` — WHY no edit is needed (the GATE-03 crux)
```bash
# Source: scripts/ci/eval_ci_summary.sh:44-53 — drift-proof iteration over WHATEVER is in needs:
while IFS=$'\t' read -r job result; do
  echo "| ${job} | ${result} |" >> "${summary_file}"
  case "${result}" in
    success|skipped) ;;          # skip==pass
    *) echo "Gating job '${job}': ${result}"; failed=1 ;;
  esac
done < <(jq -r 'to_entries[] | "\(.key)\t\(.value.result)"' <<<"${NEEDS_JSON}")
# Adding a need → it auto-appears in toJSON(needs) → auto-evaluated. NO script change.
```

### `setup_branch_protection.sh` — WHY it stays byte-unchanged (the GATE-03 crux)
```bash
# Source: scripts/setup_branch_protection.sh:17-19 — the SOLE required context:
REQUIRED_CHECKS=(
  "CI Summary"
)
# The new lane is gated TRANSITIVELY via CI Summary.needs, never as its own context.
# `--print-expected` output (lines 21-38) stays identical → GATE-A5 assertion passes unchanged.
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Heavy E2E lane on every PR | Lean-on-PR + full-on-merge split | v1.20 Phase 106 (moved E2E to push:main) → v1.21 Phase 112 (lean smoke back on PR) | Restores render-regression PR coverage without the wall-clock cost. |
| Many required branch-protection contexts | Single `CI Summary` aggregate (skip==pass) | v1.20 Phase 105 | Adding a lane = `needs:` edit only; no branch-protection migration. |
| `merge_group` / GitHub merge queue | Lean-PR-lane + aggregate (deferred merge queue) | v1.21 decision (Out of Scope, REQUIREMENTS.md) | Simpler for a solo-maintainer 0.x lib; revisit if contributor volume grows. |

**Deprecated/outdated for this phase:**
- The research's §7a YAML sketch — superseded by the LIVE `adoption-demo-e2e` job (clone from live, per Pitfall 1).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The lean subset (`smoke.spec.js` + `admin-console.spec.js`) finishes under the image-smoke long pole (~414s chain), keeping PR p95 ≤ ~7.5 min. | Wall-Clock Budget | If wrong, p95 breaches the budget → GATE-02 fails. Mitigation: GATE-A6 guard narrows to `smoke.spec.js` only. This is a *measured*-post-merge guard, not a pre-merge certainty. [ASSUMED — estimate from full-lane 318s/23-specs; the 2-spec subset is a fraction but unmeasured] |
| A2 | `npx playwright test e2e/smoke.spec.js e2e/admin-console.spec.js` (positional spec form) runs exactly those two specs Chromium-only. | Code Examples / Pitfall 2 | Low risk — standard Playwright CLI behavior; config is single-project Chromium. [ASSUMED — Playwright CLI convention, not run this session] |
| A3 | `admin-console.spec.js` and `smoke.spec.js` have no hidden dependency on the screenshot spec's setup (they share `support/admin.js`/`support/liveview.js` but not screenshot artifacts). | GATE-01 | Low — verified `admin-screenshots.spec.js` is the only spec importing screenshot helpers; smoke/admin-console import only `support/admin.js`+`support/liveview.js`. [VERIFIED: grep of e2e/ specs] |
| A4 | `N` (consecutive green main runs) is an operator-chosen value, not a repo-locked number. | GATE-04 precondition | If a locked `N` exists somewhere unread, the planner should use it. Verified: `N` is symbolic in ROADMAP, STATE, REQUIREMENTS, and the research — no numeric lock found. [VERIFIED: grep across .planning] |
| A5 | Keeping the `Cohort contrast + literal gate` step (`node brandbook/src/cohort-contrast.mjs`) in the lean lane is harmless (deterministic, ~fast) — but it may be redundant since `brandbook-tokens` already runs the contrast gate on PR. | Code Examples | Low — at worst a few seconds of redundancy. Planner may drop it from the lean lane for speed. [ASSUMED] |

## Open Questions (RESOLVED)

> All three resolved during planning and reflected in executable PLAN.md content:
> Q1 → 112-01 Task 1 (env-var threaded through `e2e_local.sh`); Q2 → maintainer-locked DEFER
> (GATE-A9 out of scope); Q3 → 112-01 Task 2 (Cohort-contrast step dropped from the lean lane).

1. **RESOLVED:** **Spec-scoping mechanism: env var vs. a dedicated lean wrapper?**
   - What we know: the research proposes `ADOPTION_DEMO_E2E_SPECS` threaded through `e2e_local.sh`; the var is unimplemented; `e2e_local.sh` is the active wrapper.
   - What's unclear: whether to (a) thread the env var (back-compatible, research-locked) or (b) pass specs as positional args some other way.
   - Recommendation: (a) — exactly as the research specifies (GATE-A3), with a unit assertion that unset → full-suite invocation.

2. **RESOLVED (maintainer-locked: DEFER):** **Is GATE-A9 (push:main issue-on-failure alerting) in-scope for Phase 112?**
   - What we know: the research flags this as an *optional* escalation (a real sub-gap: red main `ci.yml` runs are silent, unlike nightly which has `nightly-failure-issue`).
   - What's unclear: whether "close the gate gap" includes alerting, or whether it's a separate concern.
   - Recommendation: Escalate to the maintainer in discuss-phase. Default: DEFER (keep Phase 112 minimal — the 4 GATE reqs don't mention alerting; it's a GATE-A9 "optional, escalate" bullet).

3. **RESOLVED (drop):** **Keep or drop the `Cohort contrast + literal gate` step in the lean lane?**
   - What we know: `brandbook-tokens` already runs the admin contrast gate on PR; `cohort-contrast.mjs` is the Cohort gate. The full E2E lane runs it before Playwright.
   - Recommendation: Drop it from the lean lane (it's not a browser-render check and may duplicate coverage); the lean lane's job is the *browser* smoke + admin-console mount. Confirm in discuss-phase.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| GitHub Actions (ubuntu-22.04) | The whole phase | ✓ (CI) | — | — |
| Playwright container | lean E2E lane | ✓ (pinned, pulled per-run) | `v1.57.0-noble` | — |
| `@playwright/test` | demo E2E | ✓ | `1.57.0` | — |
| `setup-minio` / `setup-elixir` composites | lean lane | ✓ | repo-local | — |
| `gh` CLI | GATE-04 green-run observation + branch-protection assertion | ✓ (operator/CI) | `2.94.0` (baseline) | — |
| Local Docker (for local repro of `e2e_local.sh`) | optional local verification | ⚠️ best-effort on macOS (`--network=host` is Linux-only; CI is source of truth) | — | Verify on CI, not locally |

**Missing dependencies with no fallback:** None — every tool is present and pinned.
**Missing dependencies with fallback:** Local `e2e_local.sh` repro on macOS is best-effort (`--network=host`); CI Linux runners are the source of truth.

## Validation Architecture

> `workflow.nyquist_validation` is not disabled in config, so this section is included. This phase's "tests" are CI assertions + the lean lane itself, not new ExUnit modules.

### Test Framework
| Property | Value |
|----------|-------|
| Framework (this phase) | GitHub Actions job assertions + bash gate-script unit tests (`scripts/ci/test_ci_summary_gate.sh`) + Playwright (the lean lane's own specs) |
| Config file | `.github/workflows/ci.yml`; `examples/adoption_demo/playwright.config.js` |
| Quick run command | `bash scripts/ci/test_ci_summary_gate.sh` (gate logic); `scripts/setup_branch_protection.sh --print-expected` (context assertion) |
| Full suite command | Push to a PR branch → observe `CI Summary` aggregates the new lane; push:main → observe full lane still green |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command / Check | File Exists? |
|--------|----------|-----------|---------------------------|-------------|
| GATE-01 | Lean lane runs on every PR, deterministic specs, in `CI Summary.needs` + `ci-observability.needs` | CI structural + live | YAML lint of new job (no `if:` gate; specs env set); a PR run shows the job as `success` (not `skipped`) and present in CI Summary table | ❌ Wave 0: new job |
| GATE-01 | `e2e_local.sh` honors `ADOPTION_DEMO_E2E_SPECS` (unset → full suite) | unit/assertion | A shell assertion: unset env → grep that the playwright invocation has no positional spec; set → has the two specs | ❌ Wave 0: add assertion (GATE-A3) |
| GATE-02 | PR p95 ≤ ~7.5 min; lean lane ≤ image-smoke long pole | observational | `ci-observability` per-job timing post-merge; `bash scripts/ci/collect_ci_baseline.sh` over recent runs | ✓ (existing tooling) |
| GATE-03 | `setup_branch_protection.sh` byte-unchanged; only `CI Summary` required | structural | `git diff --exit-code scripts/setup_branch_protection.sh`; `scripts/setup_branch_protection.sh --print-expected` unchanged | ✓ (assert no diff) |
| GATE-03 | 3 lanes stay off PR; rationale documented | docs | RUNNING.md CI-lane-severity table includes the 3 off-PR rationales + the new lean row | ✓ (RUNNING.md exists; edit it) |
| GATE-04 | Lane enters `needs:` only after 108/109/110 + N green main runs | sequencing + operator | `checkpoint:human-verify` — operator confirms `gh run list` shows N consecutive green `Adoption Demo E2E` on main | ❌ Wave 0: operator checkpoint (not automatable pre-merge) |

### Sampling Rate
- **Per task commit:** YAML validity (`actionlint` if available, else GitHub's own parse on push); `bash scripts/ci/test_ci_summary_gate.sh`.
- **Per wave merge:** A PR run showing the lean lane `success` and in the `CI Summary` table; `git diff --exit-code` on the two byte-frozen scripts.
- **Phase gate:** A push:main run with the full `adoption-demo-e2e` still green AND the lean lane green on the PR before the `needs:` wiring lands.

### Wave 0 Gaps
- [ ] The `adoption-demo-e2e-smoke` job — new YAML (covers GATE-01).
- [ ] The `e2e_local.sh` spec-scoping edit + an assertion that unset → full suite (GATE-A3).
- [ ] An operator `checkpoint:human-verify` task encoding GATE-04 (N consecutive green main runs).
- [ ] RUNNING.md CI-lane-severity row for the lean lane + 3 off-PR rationales (and fix the pre-existing "merge-blocking" drift on the full E2E/cohort rows, Pitfall 6).
- [ ] A `git diff --exit-code` guard (or plan assertion) that `setup_branch_protection.sh` + `eval_ci_summary.sh` are byte-unchanged.

## Security Domain

> `security_enforcement` is not disabled. This phase is CI-topology; the security surface is fork-PR safety + supply-chain pins.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V4 Access Control | yes (CI permissions) | The lean lane needs NO elevated permissions; inherits workflow default `contents: read`. No `actions: write`/`issues: write`. |
| V5 Input Validation | yes (no PR-string interpolation) | The lean lane must not interpolate `github.event.pull_request.*` (title/body/branch) into a shell — it doesn't (uses only trusted contexts). |
| V6 Cryptography | no | — |
| V14 Config / Supply Chain | yes | All actions SHA-pinned (Phase 107); the Playwright image is tag-pinned. No new unpinned action. |

### Known Threat Patterns for {GitHub Actions CI}
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Fork-PR secret exfiltration | Information Disclosure | Lean lane uses NO secrets (MinIO-local literal creds); safe `pull_request` trigger. Fork PRs run it fully (no repo-gate) but there's nothing to leak. |
| skip-as-pass "green lie" | Spoofing (of gate status) | Lean lane has NO `if:` gate → always runs on PR → real success/fail, never `skipped`-as-pass. |
| Unpinned action / image substitution | Tampering | SHA-pin every action; tag-pin the Playwright image (already the house pattern). |
| Importing a flake into the required gate | Denial of Service (of merges) | GATE-04 ordering: wire into `needs:` only after N consecutive green main runs (operator checkpoint). |

## Sources

### Primary (HIGH confidence)
- `.planning/research/v1.21-PR-MAIN-GATE-GAP.md` — the LOCKED milestone research; §2 per-lane decisions, §7 locked recommendation, §7a-7h requirement-ready bullets. [CITED]
- `.github/workflows/ci.yml` (LIVE, post-phase-111) — every job, `needs:` array, env, pin verified line-by-line. [VERIFIED]
- `scripts/ci/eval_ci_summary.sh` — drift-proof needs-iteration (GATE-03 crux). [VERIFIED]
- `scripts/setup_branch_protection.sh` — `REQUIRED_CHECKS=("CI Summary")` sole context. [VERIFIED]
- `scripts/ci/e2e_local.sh` — the active wrapper; spec-scoping is unimplemented. [VERIFIED]
- `examples/adoption_demo/playwright.config.js` + `package.json` — single Chromium project, `@playwright/test 1.57.0`. [VERIFIED]
- `examples/adoption_demo/e2e/{smoke,admin-console,admin-screenshots}.spec.js` — spec contents + no `toHaveScreenshot` usage. [VERIFIED]
- `.planning/milestones/v1.20-phases/103-observability-baseline/103-BASELINE.md §1` — per-job avg/p95 timing (E2E 318s p95; package-consumer 887s historical). [VERIFIED]

### Secondary (MEDIUM confidence)
- `.planning/STATE.md` — phases 108/109/110/111 COMPLETE; decisions 106-04/106-03/105-01 on the lane split + aggregate gate. [VERIFIED]
- `RUNNING.md` — CI lane severity table (and a pre-existing drift, Pitfall 6). [VERIFIED]

### Tertiary (LOW confidence)
- None. (No WebSearch needed — fully repo-grounded.)

## What the planner needs to decide

Everything below is OPEN; everything in "User Constraints / Locked Decisions" above is CLOSED.

1. **Spec-scoping mechanism (GATE-A3).** Confirm the `ADOPTION_DEMO_E2E_SPECS` env-var approach threaded through `e2e_local.sh` (recommended, research-locked, back-compatible: unset → full suite). Decide the exact assertion that proves "unset → full-suite invocation." *(LOCKED direction in research; only the implementation detail is open.)*

2. **Value of `N` (GATE-04).** `N` is symbolic in every source — no repo-locked number exists. The planner/maintainer must pick `N` (research says "≥N consecutive green"). Suggest a concrete small integer (e.g. 3 or 5) and encode it in the operator checkpoint wording. *(Genuinely open — escalate to maintainer.)*

3. **GATE-04 = operator checkpoint, not a scriptable gate.** There is no automated check that wires the lane into `needs:` only after N green runs. The plan MUST include a `checkpoint:human-verify` task: "Operator confirms `gh run list --workflow=CI --branch=main` shows N consecutive green `Adoption Demo E2E` before the `needs:` wiring commit." Decide whether to split Phase 112 into two waves (job-exists wave → checkpoint → needs-wiring wave). *(Recommended: yes, split.)*

4. **GATE-A9 alerting in-scope? (escalation flag).** Whether to add a push:main issue-on-failure job (mirroring `nightly.yml`'s `nightly-failure-issue`) so a red main `ci.yml` run is surfaced. Research flags this as VERY-impactful / escalate. *(Default: DEFER unless maintainer wants it; the 4 GATE reqs don't require it.)*

5. **Keep or drop the `Cohort contrast + literal gate` step** in the lean lane (possible redundancy with `brandbook-tokens`). *(Recommend drop; confirm.)*

6. **Whether to keep the full lane's `Cohort contrast` / extra steps or trim the lean clone** to the minimal browser path. The leaner the lane, the safer the wall-clock guard (GATE-02). *(Recommend: minimal — checkout, setup-elixir, setup-node, ffmpeg, libvips, deps.get, setup-minio, run e2e_local.sh with the spec env, upload-on-failure.)*

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every tool already pinned and verified in-repo; zero new packages.
- Architecture / topology: HIGH — locked research is repo-grounded and reconciled against live `ci.yml` this session.
- Pitfalls: HIGH — research-vs-live drift, the two wrappers, and the unimplemented env var all verified against source.
- Wall-clock (GATE-02): MEDIUM — the 2-spec subset duration is estimated, not measured; the guard is post-merge observational (A1).
- GATE-04 `N`: MEDIUM — symbolic everywhere; an operator decision, not a repo fact.

**Research date:** 2026-06-28
**Valid until:** ~2026-07-28 (stable CI topology) — but RE-READ `ci.yml` before planning if any further phase edits it, since the lean clone must match the LIVE `adoption-demo-e2e` job, not this snapshot.
