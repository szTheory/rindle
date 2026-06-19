# Phase 102: Re-Converge - Visual Matrix, Idempotency Gate & Milestone Audit - Research

**Researched:** 2026-06-19  
**Domain:** Repo-local deterministic visual gating, Playwright matrix coverage, Phoenix LiveView Cohort contracts, generated-asset idempotency, milestone audit closeout  
**Confidence:** HIGH - phase scope, current failures, test harnesses, CI jobs, and closeout docs were verified from repository files and local commands. [VERIFIED: .planning/ROADMAP.md:455] [VERIFIED: .planning/STATE.md:7] [VERIFIED: command `node --check examples/adoption_demo/e2e/support/admin-polish.js examples/adoption_demo/e2e/admin-screenshots.spec.js examples/adoption_demo/e2e/cohort-pages.spec.js examples/adoption_demo/e2e/cohort-styleguide.spec.js`]

<user_constraints>
## User Constraints (from CONTEXT.md)

Source: copied verbatim from Phase 102 context. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:1]

### Locked Decisions
## Implementation Decisions

### Visual Gate Topology

- **D-102-01**: The existing `examples/adoption_demo/e2e/support/admin-polish.js` must remain the single merge-blocking deterministic computed-style visual gate inside the existing `adoption-demo-e2e` job. Phase 102 should not add a second merge-blocking screenshot, Percy, Playwright `toHaveScreenshot`, or separate visual-regression lane. [locked]
- **D-102-02**: Admin coverage stays hard-fail. Cohort coverage moves from warn/report mode to hard-fail mode over explicit roots only: admin `[data-rindle-admin-root]`, Cohort `[data-ck-root]`. Preserve D-94-07: no root auto-detection. [locked]
- **D-102-03**: Pixel baselines, Playwright screenshots, and living gallery screenshots may be added only as non-blocking audit artifacts. They may be CI-generated, motion-frozen, and font-stable, but they must never become the VIS-01 merge blocker. [locked]

### Cohort Hard-Fail Readiness

- **D-102-04**: Before Cohort is promoted to hard-fail, `admin-polish.js` focus assertions must become surface-aware with an explicit focus-token contract. Defaults remain admin `--rindle-focus-width`, `--rindle-focus-ring`, `--rindle-focus-offset`; Cohort must pass an explicit contract matching its CSS (`2px`, `--ck-focus`, `2px`). Do not infer contracts from host globals. [locked]
- **D-102-05**: Outline scanning and offender collection must be scoped so Cohort failures represent real Cohort surface defects, not global host-cascade noise. Harness crashes remain hard failures; visual offenders become hard once Cohort is promoted. [locked]
- **D-102-06**: Cohort dark-mode coverage must be proven through rendered contract state (`data-theme` or server route state such as `?theme=dark`), not through Playwright `colorScheme` alone. The test must assert the Cohort root is actually dark, or include equivalent explicit proof. [locked]

### Matrix Coverage And No-Regression

- **D-102-07**: Preserve the current admin matrix and Phase 98 backstops. Phase 102 may reorganize specs/helpers, but must not reduce admin coverage, including the 24-state screenshot/check matrix and computed-style backstops added in Phase 98. [locked]
- **D-102-08**: Cohort coverage must expand from route warn coverage to a full light/dark/mobile matrix across styleguide, dashboard, ops, account erasure, member, lesson, post, media, and all six upload tabs. It may extend `cohort-pages.spec.js` or create a thin unified visual matrix spec, but must not fork the polish logic. [locked]
- **D-102-09**: Keep behavior and contract gates alongside visual gates: `cohort_migration_contract_test.exs`, Cohort contrast/literal checks, upload behavior coverage, and the full Playwright suite remain part of the no-regression proof. [locked]

### CI, Idempotency, And Audit Closeout

- **D-102-10**: Reuse existing repo gates for idempotency. Admin generated CSS drift remains under the brandbook-tokens sequence (`tokens-build`, `admin-css-build`, `admin-contrast`, `admin-gallery-check`, `sync-admin-css`, empty diff). Hand-authored Cohort CSS remains under `cohort-contrast` plus Playwright/ExUnit ratchets. Do not create a Cohort CSS generator or move `cohort.css` into brandbook token generation in this phase. [locked]
- **D-102-11**: Phase 102 must make the full `scripts/ci/adoption_demo_e2e.sh` lane green, not only targeted specs. The known pre-102 admin strict-locator red must be fixed or otherwise resolved before claiming VIS-01/VIS-02. [locked]
- **D-102-12**: Audit closeout should follow the v1.18/v1.15 audit pattern: update requirement traceability to 20/20, write the v1.19 milestone audit, include exact verification evidence, and make docs/proof parity truthful. Optional pixel/gallery artifacts should be documented as non-blocking if added. [locked]

### the agent's Discretion
- Exact spec filenames and whether to extend `cohort-pages.spec.js` or add a thin unified matrix spec.
- Exact route case data structures, helper names, and surface labels.
- Whether optional screenshot artifacts are generated from the unified matrix or left to existing gallery/styleguide flows, as long as they remain non-blocking.

### Deferred Ideas (OUT OF SCOPE)
- None. The phase is intentionally scoped to converging existing visual-system work and closing VIS-01..VIS-04.

### Reviewed Todos (not folded)
- None.
</user_constraints>

## Summary

Phase 102 is a convergence phase, not a new visual tooling phase: the implementation should keep `admin-polish.js` as the one merge-blocking deterministic gate, fix current harness defects, promote Cohort from warn/report to fail-fast coverage, and close VIS-01..VIS-04 with idempotency and audit proof. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:9] [VERIFIED: .planning/ROADMAP.md:455]

The first implementation dependency is the current admin strict-locator red: `adminRoot(page)` resolves `[data-rindle-admin-root]`, while admin shell and page markup both emit that attribute, producing strict-mode failures before Cohort can be promoted. [VERIFIED: examples/adoption_demo/e2e/support/admin.js:29] [VERIFIED: examples/adoption_demo/lib/rindle/admin/components.ex:50] [VERIFIED: examples/adoption_demo/lib/rindle/admin/components.ex:446] Phase 102 should narrow admin helper roots to a unique shell locator and keep visual assertions explicitly rooted, preserving D-94-07's no-auto-detect rule. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:10]

The second dependency is making `admin-polish.js` surface-aware before hard-failing Cohort: focus tokens are currently hardcoded to `documentElement` admin variables, and `assertDialogInert` is invoked for every surface even though it checks admin landmarks. [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:356] [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:751] [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:893] Cohort CSS already declares its own focus contract and light/dark tokens, but most Cohort LiveViews currently render light only, so full dark coverage needs server-rendered theme state such as `?theme=dark` across all migrated pages. [VERIFIED: examples/adoption_demo/priv/static/assets/cohort.css:43] [VERIFIED: examples/adoption_demo/priv/static/assets/cohort.css:116] [VERIFIED: examples/adoption_demo/priv/static/assets/cohort.css:221] [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/live/cohort/dashboard_live.ex:9]

**Primary recommendation:** Fix admin root strictness first, refactor `assertAdminPolish` to accept explicit surface contracts, add server-backed Cohort dark theme routing, then promote a shared admin+Cohort light/dark/mobile Playwright matrix to hard-fail inside `scripts/ci/adoption_demo_e2e.sh`; prove closure with the full wrapper, ExUnit Cohort contract, contrast/literal scanner, double-run generated-asset diff, and v1.19 audit updates. [VERIFIED: scripts/ci/adoption_demo_e2e.sh:1] [VERIFIED: .github/workflows/ci.yml:649] [VERIFIED: .github/workflows/ci.yml:1147]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Deterministic visual gate execution | E2E Test Harness | CI | Playwright specs call `assertAdminPolish`, and the merge-blocking wrapper is `scripts/ci/adoption_demo_e2e.sh` inside the `adoption-demo-e2e` job. [VERIFIED: examples/adoption_demo/e2e/admin-screenshots.spec.js:82] [VERIFIED: scripts/ci/adoption_demo_e2e.sh:40] [VERIFIED: .github/workflows/ci.yml:749] |
| Admin root disambiguation | E2E Test Harness | Admin LiveView markup | The failing helper uses a broad root locator, while the LiveView emits root markers on both shell and page. [VERIFIED: examples/adoption_demo/e2e/support/admin.js:29] [VERIFIED: examples/adoption_demo/lib/rindle/admin/components.ex:50] [VERIFIED: examples/adoption_demo/lib/rindle/admin/components.ex:446] |
| Cohort dark-mode activation | Phoenix LiveView | E2E Test Harness | Cohort pages render `data-theme` through `ck_page`; upload already reads `theme` from params, while most migrated pages currently mount light only. [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/components/cohort_components.ex:71] [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/live/cohort/upload_live.ex:18] [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/live/cohort/dashboard_live.ex:13] |
| Focus-token contract | Shared E2E Helper | CSS Tokens | Admin polish currently reads admin variables from `documentElement`; Cohort focus styling uses `2px solid var(--ck-focus)` on `.ck` controls. [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:356] [VERIFIED: examples/adoption_demo/priv/static/assets/cohort.css:221] |
| Admin Phase 98 backstops | E2E Test Harness | Admin Components | Phase 98 added computed-style backstops and the admin spec still asserts a 24-entry screenshot/check matrix. [VERIFIED: .planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-SUMMARY.md:14] [VERIFIED: examples/adoption_demo/e2e/admin-screenshots.spec.js:24] [VERIFIED: examples/adoption_demo/e2e/admin-screenshots.spec.js:162] |
| Cohort contract and literal retirement | ExUnit / Static Script | Phoenix LiveView | The contract test checks migrated route contracts and `cohort-contrast.mjs` checks token contrast and retired literal patterns. [VERIFIED: examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs:32] [VERIFIED: brandbook/src/cohort-contrast.mjs:259] |
| Generated-asset idempotency | CI / Build Scripts | Git Working Tree | The brandbook-tokens job runs token/CSS/gate/sync scripts and enforces `git diff --exit-code`. [VERIFIED: .github/workflows/ci.yml:1147] [VERIFIED: .github/workflows/ci.yml:1199] |
| Milestone audit closeout | Planning Docs | Verification Evidence | Phase 102 requires requirements traceability 20/20, v1.19 audit, exact evidence, and truthful docs/proof parity. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:40] [VERIFIED: .planning/milestones/v1.18-MILESTONE-AUDIT.md:1] |

## Project Constraints (from AGENTS.md)

- Keep edits focused, run the checks named by `RUNNING.md` for the changed area, and update `.planning/PROJECT.md` only when product scope or shipped claims intentionally change. [VERIFIED: AGENTS.md:38] [VERIFIED: RUNNING.md:1]
- UI/admin-console work must follow `guides/ui_principles.md` before changing console, Cohort, E2E, or visual-polish surfaces. [VERIFIED: AGENTS.md:40] [VERIFIED: guides/ui_principles.md:1]
- The repository expects a green-main release-train posture for merge-blocking jobs, including Quality/coveralls, Integration, Proof, Package Consumer, and Adopter lanes. [VERIFIED: AGENTS.md:44]
- Serious milestone or feature-depth work should prefer PR-first execution, and release prep should run `./scripts/maintainer/repo_hygiene_check.sh`. [VERIFIED: AGENTS.md:46] [VERIFIED: AGENTS.md:54]
- Adoption-demo code lives under its own Phoenix 1.8 guidance: use existing stable IDs in LiveView tests, prefer `element/2` and `has_element?/2`, avoid `Process.sleep`, avoid raw HTML assertions where possible, and keep HEEx class attributes as list syntax. [VERIFIED: examples/adoption_demo/AGENTS.md:1] [VERIFIED: examples/adoption_demo/AGENTS.md:88] [VERIFIED: examples/adoption_demo/AGENTS.md:92] [VERIFIED: examples/adoption_demo/AGENTS.md:109]
- Adoption-demo completion guidance names `mix precommit`; for Phase 102 planning, the repo-specific full gate is still `scripts/ci/adoption_demo_e2e.sh` plus the contract and idempotency commands below because Phase 102 explicitly targets the adoption-demo E2E lane. [VERIFIED: examples/adoption_demo/AGENTS.md:12] [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:39]

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| VIS-01 | Deterministic computed-style assertions remain the single merge-blocking visual gate and extend to admin + Cohort light/dark. | Implement via `admin-polish.js` with explicit admin/Cohort roots, surface-aware focus contract, no screenshot blocker, and Cohort hard-fail matrix. [VERIFIED: .planning/REQUIREMENTS.md:272] [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:858] |
| VIS-02 | Full light/dark/mobile pass with idempotency and no functional regressions. | Use full `scripts/ci/adoption_demo_e2e.sh`, `cohort_migration_contract_test.exs`, `cohort-contrast.mjs`, and double-run generated-asset diff proof. [VERIFIED: .planning/REQUIREMENTS.md:273] [VERIFIED: scripts/ci/adoption_demo_e2e.sh:1] [VERIFIED: examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs:1] [VERIFIED: brandbook/src/cohort-contrast.mjs:1] |
| VIS-03 | Pixel baselines are optional/non-blocking and CI-generated if used. | Keep Playwright `toHaveScreenshot` and gallery screenshots as audit artifacts only; merge blocker remains computed-style assertions in adoption-demo-e2e. [VERIFIED: .planning/REQUIREMENTS.md:274] [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:13] |
| VIS-04 | Living gallery or equivalent artifact covers migrated admin + Cohort states. | Preserve `admin-gallery-check.mjs` for admin/token proof and use Cohort styleguide/matrix artifacts as non-blocking audit proof if added. [VERIFIED: .planning/REQUIREMENTS.md:275] [VERIFIED: brandbook/src/admin-gallery-check.mjs:1] [VERIFIED: examples/adoption_demo/e2e/cohort-styleguide.spec.js:1] |

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| `@playwright/test` | 1.60.0 installed locally | Runs admin and Cohort browser matrix specs. | Existing adoption-demo E2E stack and CI wrapper already use Playwright. [VERIFIED: command `cd examples/adoption_demo && npm ls @playwright/test --depth=0`] [VERIFIED: examples/adoption_demo/playwright.config.js:1] |
| Phoenix LiveView / ExUnit | Phoenix 1.8 guidance; Mix 1.19.5 local | Renders Cohort/admin pages and verifies migration contracts. | Adoption-demo project guidance and existing tests use LiveView helpers and ExUnit. [VERIFIED: examples/adoption_demo/AGENTS.md:1] [VERIFIED: command `mix --version`] [VERIFIED: examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs:1] |
| `admin-polish.js` | Internal helper | Deterministic computed-style visual gate. | Locked as the single merge-blocking visual gate for Phase 102. [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:858] [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:9] |
| `scripts/ci/adoption_demo_e2e.sh` | Internal CI wrapper | Full adoption-demo browser lane. | Phase 102 must make this entire lane green, not only targeted specs. [VERIFIED: scripts/ci/adoption_demo_e2e.sh:1] [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:39] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| `brandbook/src/cohort-contrast.mjs` | Internal script | Checks Cohort token contrast, parity, and retired literals. | Run before and after Cohort hard-fail promotion. [VERIFIED: brandbook/src/cohort-contrast.mjs:171] [VERIFIED: command `node brandbook/src/cohort-contrast.mjs`] |
| `brandbook/src/admin-gallery-check.mjs` | Internal script | Checks admin gallery states, focus tokens, and generated screenshot artifacts. | Keep in brandbook idempotency proof and VIS-04 audit proof. [VERIFIED: brandbook/src/admin-gallery-check.mjs:36] [VERIFIED: brandbook/src/admin-gallery-check.mjs:142] |
| `cohort_migration_contract_test.exs` | Internal ExUnit test | Verifies retired daisyUI/default CSS contract and migrated route markup. | Run as behavior/contract proof alongside E2E visual gates. [VERIFIED: examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs:1] [VERIFIED: command `cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs`] |
| `guides/ui_principles.md` | Repo guide | Defines selector, theme, focus, motion, and accessibility expectations. | Use to judge whether matrix coverage preserves project UI constraints. [VERIFIED: guides/ui_principles.md:7] [VERIFIED: guides/ui_principles.md:84] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `admin-polish.js` hard gate | Playwright `toHaveScreenshot` baselines | Rejected as merge blocker by D-102-01/D-102-03; screenshots may only be non-blocking audit artifacts. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:9] [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:13] |
| Existing adoption-demo-e2e job | New visual-regression CI lane | Rejected because Phase 102 locks the gate inside the existing adoption-demo-e2e lane. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:9] |
| Hand-authored Cohort CSS | Cohort CSS generator | Rejected by D-102-10; Cohort remains hand-authored under contrast/Playwright/ExUnit ratchets. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:38] |

**Installation:**

```bash
# No new package installation is recommended for Phase 102.
```

**Version verification:** Existing browser-test package availability was verified locally with `npm ls @playwright/test --depth=0`, returning `@playwright/test@1.60.0`; Phase 102 does not require `npm install` or new packages. [VERIFIED: command `cd examples/adoption_demo && npm ls @playwright/test --depth=0`]

## Package Legitimacy Audit

Phase 102 should not install new external packages, so the package legitimacy gate is not required for new recommendations. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:9] Existing package use is already locked in `examples/adoption_demo/package-lock.json` and local install state. [VERIFIED: examples/adoption_demo/package-lock.json:1] [VERIFIED: command `cd examples/adoption_demo && npm ls @playwright/test --depth=0`]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| None newly recommended | n/a | n/a | n/a | n/a | n/a | No install task should be planned. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:38] |

**Packages removed due to [SLOP] verdict:** none; no package candidates were introduced. [VERIFIED: this research scope]  
**Packages flagged as suspicious [SUS]:** none; no package candidates were introduced. [VERIFIED: this research scope]

## Architecture Patterns

### System Architecture Diagram

```text
GitHub CI / local runner
  |
  +--> scripts/ci/adoption_demo_e2e.sh
  |      |
  |      +--> reset DB + seed demo state + prepare assets
  |      |      [VERIFIED: scripts/ci/adoption_demo_e2e.sh:19]
  |      |
  |      +--> npm run e2e / Playwright specs
  |             |
  |             +--> admin-screenshots.spec.js
  |             |      +--> unique admin shell/page roots
  |             |      +--> assertAdminPolish(admin contract)
  |             |      +--> Phase 98 backstops + 24-state matrix
  |             |      [VERIFIED: examples/adoption_demo/e2e/admin-screenshots.spec.js:82]
  |             |
  |             +--> Cohort visual matrix spec or extended cohort-pages.spec.js
  |                    +--> explicit [data-ck-root]
  |                    +--> server-rendered light/dark state
  |                    +--> assertAdminPolish(Cohort contract)
  |                    +--> no warn/report catch once promoted
  |                    [VERIFIED: examples/adoption_demo/e2e/cohort-pages.spec.js:48]
  |
  +--> brandbook-tokens job
  |      +--> tokens-build -> admin-css-build -> admin-contrast
  |      +--> admin-gallery-check -> sync-admin-css -> git diff
  |      [VERIFIED: .github/workflows/ci.yml:1172]
  |
  +--> contract/static gates
         +--> mix test cohort_migration_contract_test.exs
         +--> node brandbook/src/cohort-contrast.mjs
         [VERIFIED: examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs:1]
         [VERIFIED: brandbook/src/cohort-contrast.mjs:1]
```

### Recommended Project Structure

```text
examples/adoption_demo/e2e/
├── support/
│   ├── admin.js                 # Narrow admin root helpers and theme assertions. [VERIFIED: examples/adoption_demo/e2e/support/admin.js:1]
│   └── admin-polish.js          # Shared deterministic visual gate with explicit surface contracts. [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:858]
├── admin-screenshots.spec.js    # Preserve 24-state admin matrix and Phase 98 backstops. [VERIFIED: examples/adoption_demo/e2e/admin-screenshots.spec.js:24]
├── cohort-pages.spec.js         # Existing Cohort route coverage; promote or feed unified matrix. [VERIFIED: examples/adoption_demo/e2e/cohort-pages.spec.js:69]
└── cohort-styleguide.spec.js    # Existing styleguide/theme proof; keep component checks and route into matrix as needed. [VERIFIED: examples/adoption_demo/e2e/cohort-styleguide.spec.js:56]

examples/adoption_demo/lib/adoption_demo_web/live/cohort/
└── *_live.ex                    # Add shared server-rendered theme param support for dark matrix. [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/live/cohort/upload_live.ex:18]

brandbook/src/
├── cohort-contrast.mjs          # Cohort contrast/literal/static gate. [VERIFIED: brandbook/src/cohort-contrast.mjs:1]
└── admin-gallery-check.mjs      # Admin gallery/idempotency/audit proof. [VERIFIED: brandbook/src/admin-gallery-check.mjs:1]
```

### Pattern 1: Unique Explicit Roots

**What:** Keep surface roots explicit, but make helper locators strict by targeting a unique admin shell root instead of the shared marker alone. [VERIFIED: examples/adoption_demo/e2e/support/admin.js:29]  
**When to use:** Before every admin theme assertion, screenshot capture, and visual-gate call. [VERIFIED: examples/adoption_demo/e2e/admin-screenshots.spec.js:82]

```javascript
// Source: existing strict failure source and current admin markup.
// [VERIFIED: examples/adoption_demo/e2e/support/admin.js:29]
// [VERIFIED: examples/adoption_demo/lib/rindle/admin/components.ex:50]
// [VERIFIED: examples/adoption_demo/lib/rindle/admin/components.ex:446]
const ADMIN_SHELL_ROOT = ".rindle-admin-shell[data-rindle-admin-root]";
const ADMIN_PAGE_ROOT = ".rindle-admin-page[data-rindle-admin-root]";

function adminRoot(page) {
  return page.locator(ADMIN_SHELL_ROOT);
}
```

### Pattern 2: Surface-Aware Focus Contract

**What:** Add an explicit focus contract to `assertAdminPolish`; default to admin variables and require Cohort callers to pass width/color/offset expectations. [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:356] [VERIFIED: examples/adoption_demo/priv/static/assets/cohort.css:221]  
**When to use:** Every Cohort hard-fail call, plus admin defaults to preserve existing behavior. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:21]

```javascript
// Source: Phase 102 D-102-04 and current Cohort focus CSS.
// [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:21]
// [VERIFIED: examples/adoption_demo/priv/static/assets/cohort.css:221]
const ADMIN_FOCUS_CONTRACT = {
  width: "var(--rindle-focus-width)",
  color: "var(--rindle-focus-ring)",
  offset: "var(--rindle-focus-offset)"
};

const COHORT_FOCUS_CONTRACT = {
  width: "2px",
  color: "var(--ck-focus)",
  offset: "2px"
};

await assertAdminPolish(page, {
  root: "[data-ck-root]",
  surface: "cohort-dashboard-dark",
  viewport: "desktop",
  focusContract: COHORT_FOCUS_CONTRACT,
  adminBackstops: false
});
```

### Pattern 3: Promote Cohort by Removing Warn-Mode Catching

**What:** Replace `reportPolish` catch/report calls with direct `await assertAdminPolish(...)`, so offenders fail the spec after the helper is surface-ready. [VERIFIED: examples/adoption_demo/e2e/cohort-pages.spec.js:30] [VERIFIED: examples/adoption_demo/e2e/cohort-pages.spec.js:48]  
**When to use:** After strict admin locator, focus contract, admin-only backstop scoping, and Cohort dark route support are in place. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:22]

```javascript
// Source: current cohort-pages helper is warn-mode and hardcodes desktop.
// [VERIFIED: examples/adoption_demo/e2e/cohort-pages.spec.js:48]
async function assertCohortPagePolish(page, { route, surface, theme, viewport }) {
  await page.goto(route);
  const root = page.locator("[data-ck-root]");
  await expect(root).toHaveAttribute("data-theme", theme);
  await assertAdminPolish(page, {
    root: "[data-ck-root]",
    surface,
    viewport,
    interactiveSelectors: [".ck-btn", ".ck-tabs__tab", ".ck-input", ".ck-select", "[data-ck-theme]"],
    focusContract: COHORT_FOCUS_CONTRACT,
    adminBackstops: false
  });
}
```

### Pattern 4: Server-Rendered Cohort Dark State

**What:** Reuse upload's route-param pattern across migrated Cohort pages so E2E can assert actual rendered `data-theme="dark"`. [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/live/cohort/upload_live.ex:18] [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/components/cohort_components.ex:71]  
**When to use:** For dashboard, ops, account erasure, member, lesson, post, media, styleguide, and all upload tab cases in the light/dark/mobile matrix. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:32]

```elixir
# Source: UploadLive already normalizes params["theme"] into @theme.
# [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/live/cohort/upload_live.ex:18]
theme = normalize_theme(params["theme"])
{:noreply, assign(socket, theme: theme)}
```

### Pattern 5: Idempotency Proof Uses Existing Gates

**What:** Reuse the current admin generator/gate sequence and assert the working tree remains clean after a repeated run. [VERIFIED: .github/workflows/ci.yml:1172] [VERIFIED: .github/workflows/ci.yml:1199]  
**When to use:** Before claiming VIS-02 and before writing the final milestone audit verdict. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:38]

```bash
node brandbook/src/tokens-build.mjs
node brandbook/src/admin-css-build.mjs
node brandbook/src/admin-contrast.mjs
node brandbook/src/admin-gallery-check.mjs
node brandbook/src/sync-admin-css.mjs
node brandbook/src/cohort-contrast.mjs
git diff --exit-code

node brandbook/src/tokens-build.mjs
node brandbook/src/admin-css-build.mjs
node brandbook/src/admin-contrast.mjs
node brandbook/src/admin-gallery-check.mjs
node brandbook/src/sync-admin-css.mjs
node brandbook/src/cohort-contrast.mjs
git diff --exit-code
```

### Anti-Patterns to Avoid

- **Root auto-detection:** Phase 102 explicitly preserves explicit root selection, so do not scan the DOM for a likely admin or Cohort root. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:10]
- **Screenshot-as-blocker:** Pixel baselines and gallery screenshots must stay non-blocking audit artifacts. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:13]
- **Admin-only checks over Cohort:** `assertDialogInert` currently reads admin shell landmarks, so running it unconditionally over `[data-ck-root]` would produce non-Cohort failures. [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:751] [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:893]
- **Playwright `colorScheme` as dark proof:** Cohort dark coverage must prove rendered contract state such as `data-theme="dark"`. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:25]
- **Reducing admin coverage while unifying specs:** The admin 24-state matrix and Phase 98 computed-style backstops are locked. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:31] [VERIFIED: examples/adoption_demo/e2e/admin-screenshots.spec.js:24]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Visual regression blocking | New pixel-diff engine or new screenshot CI lane | Existing `admin-polish.js` computed-style gate | Phase 102 locks computed-style assertions as the single merge-blocking visual gate. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:9] |
| Surface discovery | DOM root auto-detector | Explicit `root` option: `[data-rindle-admin-root]` for admin and `[data-ck-root]` for Cohort | D-102-02 preserves explicit roots and D-94-07 no auto-detection. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:10] |
| Cohort theme simulation | Browser-only `colorScheme` forcing | Server-rendered `data-theme` or `?theme=dark` route state | D-102-06 requires rendered dark proof. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:25] |
| Cohort CSS generation | New brandbook generator for `cohort.css` | Hand-authored `cohort.css` plus `cohort-contrast.mjs`, ExUnit, and Playwright | D-102-10 forbids moving Cohort CSS into generation in this phase. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:38] |
| Migration proof | Grep-only retirement checks | Existing `cohort_migration_contract_test.exs` plus `cohort-contrast.mjs` literal scanner | Current tests already encode route contracts and retired class/literal checks. [VERIFIED: examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs:32] [VERIFIED: brandbook/src/cohort-contrast.mjs:259] |
| CI idempotency | New drift framework | Existing brandbook token/generator/sync sequence plus `git diff --exit-code` | CI already enforces the generated admin asset drift check. [VERIFIED: .github/workflows/ci.yml:1172] [VERIFIED: .github/workflows/ci.yml:1199] |

**Key insight:** The phase should converge existing gates and contracts, not multiply them; adding another blocker would conflict with D-102-01 and obscure the known strict-locator and surface-contract failures that already block VIS-01/VIS-02. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:9] [VERIFIED: .planning/phases/101-daisyui-retirement-track-b/101-SUMMARY.md:1]

## Runtime State Inventory

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | Adoption-demo E2E resets and seeds the local DB through the wrapper; Phase 102 does not rename stored identifiers or require data migration. [VERIFIED: scripts/ci/adoption_demo_e2e.sh:19] | No data migration; preserve seeded route IDs used by account/member/lesson/post/media/upload specs. [VERIFIED: examples/adoption_demo/e2e/cohort-pages.spec.js:69] |
| Live service config | GitHub CI job names and branch protection are external to the repo, while the in-repo merge-blocking jobs are `adoption-demo-e2e` and `brandbook-tokens`. [VERIFIED: .github/workflows/ci.yml:649] [VERIFIED: .github/workflows/ci.yml:1147] | Do not add a new required visual job; keep Phase 102 changes inside existing jobs unless maintainers intentionally update branch protection. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:9] |
| OS-registered state | No OS service registration is required by the phase; local Postgres, Docker/MinIO, and Playwright browsers are runtime dependencies. [VERIFIED: scripts/ci/adoption_demo_e2e.sh:13] [VERIFIED: scripts/ci/adoption_demo_e2e.sh:34] | No re-registration task; planner should include environment checks or use CI for final proof. [VERIFIED: command `docker --version`] |
| Secrets/env vars | The wrapper uses local CI-style environment variables such as `MIX_ENV`, `DATABASE_URL`, MinIO credentials, and browser port settings; no secret key rename is in scope. [VERIFIED: scripts/ci/adoption_demo_e2e.sh:13] [VERIFIED: scripts/ci/adoption_demo_e2e.sh:25] | Preserve wrapper defaults; do not rename env vars for Phase 102. [VERIFIED: scripts/ci/adoption_demo_e2e.sh:1] |
| Build artifacts | Generated admin CSS/gallery artifacts are governed by brandbook scripts and `git diff`; Cohort CSS is hand-authored and should not be generated. [VERIFIED: .github/workflows/ci.yml:1172] [VERIFIED: .github/workflows/ci.yml:1199] [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:38] | Run the double idempotency sequence and keep optional screenshots non-blocking. [VERIFIED: .planning/ROADMAP.md:462] |

## Current Readiness Gaps

| Gap | Evidence | Planning Implication |
|-----|----------|----------------------|
| Admin strict locator failure | `adminRoot(page)` uses `[data-rindle-admin-root]`; shell and page both emit the attribute. [VERIFIED: examples/adoption_demo/e2e/support/admin.js:29] [VERIFIED: examples/adoption_demo/lib/rindle/admin/components.ex:50] [VERIFIED: examples/adoption_demo/lib/rindle/admin/components.ex:446] | First implementation task should narrow admin helper roots and re-run admin screenshot/check specs before changing Cohort behavior. |
| Cohort polish is warn-mode | `cohort-pages.spec.js` and `cohort-styleguide.spec.js` catch `Admin polish gate failed` and call `reportPolish`. [VERIFIED: examples/adoption_demo/e2e/cohort-pages.spec.js:30] [VERIFIED: examples/adoption_demo/e2e/cohort-styleguide.spec.js:96] | Remove catch/report only after surface-aware helper changes land, so real offenders hard-fail. |
| Focus contract is admin-global | `assertFocusVisibleTokens` reads `--rindle-focus-*` from `document.documentElement`; Cohort CSS uses `2px`, `--ck-focus`, `2px`. [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:356] [VERIFIED: examples/adoption_demo/priv/static/assets/cohort.css:221] | Add explicit `focusContract` and resolve token values against the intended scope/root, not host globals. |
| Admin-only backstop is unconditional | `assertAdminPolish` calls `assertDialogInert` for every surface; that helper checks `.rindle-admin-shell__main` and admin nav landmarks. [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:751] [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:893] | Add an `adminBackstops` or `surfaceKind` option so Cohort hard-fail does not fail on missing admin landmarks. |
| Cohort dark route support is incomplete | Upload reads `params["theme"]`, but dashboard/ops/account/member/lesson/post/media mount light-only state. [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/live/cohort/upload_live.ex:18] [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/live/cohort/dashboard_live.ex:13] [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/live/cohort/ops_live.ex:18] | Add shared theme-param support or equivalent rendered theme state before claiming dark matrix coverage. |
| Cohort helper hardcodes desktop | `assertCohortPagePolish` passes `viewport: "desktop"` regardless of route case. [VERIFIED: examples/adoption_demo/e2e/cohort-pages.spec.js:56] | Convert route cases to include desktop/mobile viewport labels and sizes. |
| Cohort interactive selectors are incomplete | `cohort-pages.spec.js` uses `.ck-tab`, while styleguide coverage includes `[data-ck-theme]`; Cohort CSS/test surfaces use `.ck-tabs__tab`. [VERIFIED: examples/adoption_demo/e2e/cohort-pages.spec.js:23] [VERIFIED: examples/adoption_demo/e2e/cohort-styleguide.spec.js:28] [VERIFIED: examples/adoption_demo/priv/static/assets/cohort.css:1000] | Use one Cohort selector set: `.ck-btn`, `.ck-tabs__tab`, `.ck-input`, `.ck-select`, `[data-ck-theme]`. |
| VIS traceability is not closed | Requirements list VIS-02..VIS-04 as pending, and ROADMAP names Phase 102 as current focus for closeout. [VERIFIED: .planning/REQUIREMENTS.md:273] [VERIFIED: .planning/ROADMAP.md:455] | Final implementation must update requirements traceability, v1.19 audit, and state/roadmap evidence after gates pass. |

## Common Pitfalls

### Pitfall 1: Fixing Cohort Before Admin Strictness
**What goes wrong:** The full E2E lane remains red before Cohort assertions execute because admin helpers fail strict locator resolution. [VERIFIED: examples/adoption_demo/e2e/support/admin.js:29]  
**Why it happens:** Two admin elements carry `[data-rindle-admin-root]`. [VERIFIED: examples/adoption_demo/lib/rindle/admin/components.ex:50] [VERIFIED: examples/adoption_demo/lib/rindle/admin/components.ex:446]  
**How to avoid:** Narrow helper roots to the unique shell or explicit page root and run admin specs before Cohort promotion. [VERIFIED: examples/adoption_demo/e2e/admin-screenshots.spec.js:82]  
**Warning signs:** Playwright strict-mode errors mentioning `[data-rindle-admin-root]` resolving to more than one element. [VERIFIED: .planning/phases/101-daisyui-retirement-track-b/101-SUMMARY.md:1]

### Pitfall 2: Treating Cohort Dark as Browser Color Scheme
**What goes wrong:** Tests claim dark coverage while the rendered Cohort root remains light. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:25]  
**Why it happens:** Most Cohort pages mount `theme: "light"` and do not currently read route theme state. [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/live/cohort/dashboard_live.ex:13]  
**How to avoid:** Add route or server state and assert `[data-ck-root]` has `data-theme="dark"`. [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/components/cohort_components.ex:78]  
**Warning signs:** Playwright project uses dark color scheme but `data-theme` remains `light`. [VERIFIED: examples/adoption_demo/e2e/cohort-pages.spec.js:197]

### Pitfall 3: Running Admin Landmark Checks on Cohort
**What goes wrong:** Cohort hard-fail reports missing admin landmarks instead of Cohort visual defects. [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:751]  
**Why it happens:** `assertAdminPolish` currently calls `assertDialogInert` unconditionally. [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:893]  
**How to avoid:** Gate Phase 98 admin-only backstops behind explicit surface options and keep general checks shared. [VERIFIED: .planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-SUMMARY.md:14]  
**Warning signs:** Cohort route errors mention `.rindle-admin-shell__main` or admin nav selectors. [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:763]

### Pitfall 4: Reducing Admin Coverage While Unifying
**What goes wrong:** Phase 102 appears green but loses Phase 98 checks or the 24-state admin matrix. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:31]  
**Why it happens:** A unified matrix can accidentally replace `admin-screenshots.spec.js` instead of feeding the same helper coverage. [VERIFIED: examples/adoption_demo/e2e/admin-screenshots.spec.js:24]  
**How to avoid:** Keep the `expectedScreenshots` length assertion at 24 and preserve the Phase 98 backstop tests. [VERIFIED: examples/adoption_demo/e2e/admin-screenshots.spec.js:162] [VERIFIED: examples/adoption_demo/e2e/admin-screenshots.spec.js:170]  
**Warning signs:** `expectedScreenshots` count changes without an explicit added/removed admin state. [VERIFIED: examples/adoption_demo/e2e/admin-screenshots.spec.js:24]

### Pitfall 5: Calling Optional Artifacts Verification
**What goes wrong:** Non-blocking screenshots become required CI blockers and violate D-102-03. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:13]  
**Why it happens:** Playwright screenshots are easy to add inside the same specs that hard-fail computed styles. [VERIFIED: examples/adoption_demo/e2e/admin-screenshots.spec.js:102]  
**How to avoid:** Keep optional screenshots out of the VIS-01 assertion path and label them audit-only in docs. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:40]  
**Warning signs:** CI fails only because a PNG diff changed while computed-style assertions pass. [VERIFIED: .planning/ROADMAP.md:464]

## Code Examples

### Admin Strict Locator Repair

```javascript
// Existing helper is too broad:
// [VERIFIED: examples/adoption_demo/e2e/support/admin.js:29]
export function adminRoot(page) {
  return page.locator("[data-rindle-admin-root]");
}

// Recommended Phase 102 direction:
// [VERIFIED: examples/adoption_demo/lib/rindle/admin/components.ex:50]
export function adminRoot(page) {
  return page.locator(".rindle-admin-shell[data-rindle-admin-root]");
}
```

### Surface-Aware Polish Options

```javascript
// Preserve admin defaults and pass Cohort contracts explicitly.
// [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:858]
await assertAdminPolish(page, {
  root: "[data-ck-root]",
  surface: "cohort-upload-image-dark-mobile",
  viewport: "mobile",
  interactiveSelectors: [".ck-btn", ".ck-tabs__tab", ".ck-input", ".ck-select", "[data-ck-theme]"],
  focusContract: {
    width: "2px",
    color: "var(--ck-focus)",
    offset: "2px"
  },
  adminBackstops: false
});
```

### Cohort Matrix Case Shape

```javascript
// Route set must cover styleguide, dashboard, ops, account erasure, member,
// lesson, post, media, and all six upload tabs.
// [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:32]
const cohortRoutes = [
  { surface: "styleguide", path: "/styleguide" },
  { surface: "dashboard", path: "/dashboard" },
  { surface: "upload-image", path: "/upload?tab=image" }
];

for (const route of cohortRoutes) {
  for (const theme of ["light", "dark"]) {
    for (const viewport of ["desktop", "mobile"]) {
      test(`${route.surface} ${theme} ${viewport}`, async ({ page }) => {
        await assertCohortPagePolish(page, {
          route: `${route.path}${route.path.includes("?") ? "&" : "?"}theme=${theme}`,
          surface: `cohort-${route.surface}-${theme}`,
          theme,
          viewport
        });
      });
    }
  }
}
```

### Rendered Dark Proof

```javascript
// Do not rely on Playwright colorScheme alone.
// [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:25]
await expect(page.locator("[data-ck-root]")).toHaveAttribute("data-theme", "dark");
```

### Audit Evidence Commands

```bash
# Contract and static proof.
# [VERIFIED: command `cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs`]
cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs
node brandbook/src/cohort-contrast.mjs

# Full merge-blocking E2E proof.
# [VERIFIED: scripts/ci/adoption_demo_e2e.sh:1]
bash scripts/ci/adoption_demo_e2e.sh
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Human screenshot review and advisory visual checks | Deterministic computed-style gate in `admin-polish.js` | Locked before Phase 102 and reaffirmed in Phase 102 context. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:9] | Planner should extend `admin-polish.js`, not add another blocker. |
| Admin-only visual gate | Admin hard-fail plus Cohort warn/report coverage | Phase 101 left Cohort in warn/report mode. [VERIFIED: .planning/phases/101-daisyui-retirement-track-b/101-SUMMARY.md:1] | Phase 102 promotes Cohort to hard-fail after helper readiness fixes. |
| Partial Cohort dark proof | Rendered `data-theme` proof required for dark matrix | D-102-06 locks rendered contract proof. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:25] | Planner must wire server theme state across pages, not only Playwright projects. |
| Generated admin CSS drift check | Existing brandbook sequence plus empty diff | CI already runs token build, admin CSS build, contrast, gallery, sync, and diff. [VERIFIED: .github/workflows/ci.yml:1172] [VERIFIED: .github/workflows/ci.yml:1199] | Phase 102 should reuse this flow and double-run for VIS-02 evidence. |
| DaisyUI/default CSS dependency | Retired Cohort class/literal contract | Phase 101 verification passed 19/19 and static contract exists. [VERIFIED: .planning/phases/101-daisyui-retirement-track-b/101-VERIFICATION.md:1] [VERIFIED: examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs:32] | Do not reintroduce retired classes or default CSS while promoting Cohort. |

**Deprecated/outdated:**
- Cohort warn/report mode is outdated for Phase 102 because D-102-02 requires hard-fail Cohort coverage. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:10]
- Playwright `colorScheme` as the only dark-mode proof is outdated for Phase 102 because rendered `data-theme` proof is locked. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:25]
- Adding a Cohort CSS generator is out of scope because D-102-10 keeps Cohort CSS hand-authored. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:38]

## Assumptions Log

All claims in this research are verified from repository files, local command output, or copied Phase 102 context. No `[ASSUMED]` claims are used. [VERIFIED: command `git status --short`] [VERIFIED: command `node brandbook/src/cohort-contrast.mjs`]

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| n/a | No assumed claims. | n/a | n/a |

## Open Questions

1. **Unified spec or extended Cohort spec?**  
   - What we know: Phase 102 allows either extending `cohort-pages.spec.js` or adding a thin unified visual matrix spec. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:32]  
   - What's unclear: The final file shape is discretionary. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:44]  
   - Recommendation: Use a thin shared matrix helper or spec only if it reduces duplication; do not fork polish logic. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:32]

2. **Route param versus in-page toggle for non-styleguide dark pages?**  
   - What we know: Upload already supports `?theme=dark`; most other pages mount light-only state. [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/live/cohort/upload_live.ex:18] [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/live/cohort/dashboard_live.ex:13]  
   - What's unclear: Whether maintainers prefer a shared route helper or per-page local helpers. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:44]  
   - Recommendation: Add shared route-param normalization for migrated Cohort pages so URLs are deterministic and matrix cases are simple. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:25]

3. **Optional screenshots?**  
   - What we know: Optional screenshots may be added only as non-blocking audit artifacts. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:13]  
   - What's unclear: Whether Phase 102 needs new artifacts beyond existing admin gallery and Cohort styleguide proof. [VERIFIED: brandbook/src/admin-gallery-check.mjs:1] [VERIFIED: examples/adoption_demo/e2e/cohort-styleguide.spec.js:1]  
   - Recommendation: Defer new screenshot artifacts unless the milestone audit needs visual evidence after hard gates are green. [VERIFIED: .planning/ROADMAP.md:464]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Node.js | Playwright and brandbook scripts | yes | v22.14.0 local | CI uses Node 20 for relevant jobs. [VERIFIED: command `node --version`] [VERIFIED: .github/workflows/ci.yml:665] |
| npm | Playwright install/scripts | yes | 11.1.0 local | CI runs `npm ci` in adoption demo and root jobs. [VERIFIED: command `npm --version`] [VERIFIED: .github/workflows/ci.yml:739] |
| Playwright package | E2E specs | yes | `@playwright/test@1.60.0` local | CI installs Chromium through npm script/wrapper. [VERIFIED: command `cd examples/adoption_demo && npm ls @playwright/test --depth=0`] [VERIFIED: scripts/ci/adoption_demo_e2e.sh:38] |
| Elixir / Mix | Cohort ExUnit contract | yes | Elixir 1.19.5, Mix 1.19.5 local | CI uses setup-beam for adoption demo jobs. [VERIFIED: command `elixir --version`] [VERIFIED: command `mix --version`] [VERIFIED: .github/workflows/ci.yml:668] |
| PostgreSQL | adoption-demo E2E DB | yes | `pg_isready` accepting local connections | CI provisions Postgres service. [VERIFIED: command `pg_isready`] [VERIFIED: .github/workflows/ci.yml:651] |
| Docker | MinIO helper / local services | yes | Docker 29.5.2 local | CI provisions MinIO service directly. [VERIFIED: command `docker --version`] [VERIFIED: .github/workflows/ci.yml:657] |
| FFmpeg | media/upload E2E support | yes | ffmpeg 8.0.1 local | CI installs FFmpeg. [VERIFIED: command `ffmpeg -version`] [VERIFIED: .github/workflows/ci.yml:704] |
| libvips / `vips` CLI | media/image processing | no local CLI | missing local `vips` command | CI installs `libvips-dev`; local full E2E may need system package or CI proof. [VERIFIED: command `command -v vips`] [VERIFIED: .github/workflows/ci.yml:704] |
| GSD tools shim | Research-plan seam | partially unavailable | local shim failed loading core modules | Not blocking because phase dir and required repo sources were supplied and no external package/docs research is needed. [VERIFIED: command `node /Users/jon/.codex/gsd-core/bin/gsd-tools.cjs query init.phase-op 102`] |

**Missing dependencies with no fallback:**
- None for planning; local `vips` absence can block a local full media E2E run, but CI installs `libvips-dev`. [VERIFIED: command `command -v vips`] [VERIFIED: .github/workflows/ci.yml:704]

**Missing dependencies with fallback:**
- GSD research-plan seam failed locally; this research uses direct repository evidence because the task is repo-specific and required sources were provided. [VERIFIED: command `node /Users/jon/.codex/gsd-core/bin/gsd-tools.cjs query init.phase-op 102`]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Playwright `@playwright/test@1.60.0` for browser matrix; ExUnit/Mix 1.19.5 local for Cohort contract. [VERIFIED: command `cd examples/adoption_demo && npm ls @playwright/test --depth=0`] [VERIFIED: command `mix --version`] |
| Config file | `examples/adoption_demo/playwright.config.js`; ExUnit config under adoption-demo Mix project. [VERIFIED: examples/adoption_demo/playwright.config.js:1] [VERIFIED: examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs:1] |
| Quick run command | `node --check examples/adoption_demo/e2e/support/admin-polish.js examples/adoption_demo/e2e/admin-screenshots.spec.js examples/adoption_demo/e2e/cohort-pages.spec.js examples/adoption_demo/e2e/cohort-styleguide.spec.js` [VERIFIED: command output exit 0] |
| Contract run command | `cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` [VERIFIED: command output `17 tests, 0 failures`] |
| Static visual-token command | `node brandbook/src/cohort-contrast.mjs` [VERIFIED: command output `Cohort contrast: 28/28 pairs pass.`] |
| Full suite command | `bash scripts/ci/adoption_demo_e2e.sh` [VERIFIED: scripts/ci/adoption_demo_e2e.sh:1] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| VIS-01 | Single hard-fail computed-style gate covers admin and Cohort light/dark. | Playwright E2E | `cd examples/adoption_demo && npx playwright test e2e/admin-screenshots.spec.js e2e/cohort-pages.spec.js e2e/cohort-styleguide.spec.js` plus full wrapper. [VERIFIED: examples/adoption_demo/e2e/admin-screenshots.spec.js:1] [VERIFIED: examples/adoption_demo/e2e/cohort-pages.spec.js:1] | yes |
| VIS-02 | Full light/dark/mobile pass with idempotency and no regressions. | E2E + ExUnit + static + diff | `bash scripts/ci/adoption_demo_e2e.sh`; `cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs`; brandbook double-run diff sequence. [VERIFIED: scripts/ci/adoption_demo_e2e.sh:1] [VERIFIED: .github/workflows/ci.yml:1172] | partial; matrix/double-run tasks need implementation |
| VIS-03 | Pixel baselines stay non-blocking and CI-generated if present. | Source assertion + audit | `rg -n "toHaveScreenshot|screenshot" examples/adoption_demo/e2e brandbook/src .github/workflows/ci.yml` and audit docs must state non-blocking status. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:13] | needs closeout doc update |
| VIS-04 | Living gallery/equivalent artifact covers migrated admin + Cohort states. | Brandbook + E2E audit | `node brandbook/src/admin-gallery-check.mjs`; Cohort styleguide/matrix evidence; docs updated in v1.19 audit. [VERIFIED: brandbook/src/admin-gallery-check.mjs:1] [VERIFIED: examples/adoption_demo/e2e/cohort-styleguide.spec.js:1] | yes, with optional Cohort artifact decision |

### Source Assertions

- Admin matrix source assertion: keep `expectedScreenshots` at 24 unless a deliberate admin-state addition changes the count with explicit evidence. [VERIFIED: examples/adoption_demo/e2e/admin-screenshots.spec.js:24] [VERIFIED: examples/adoption_demo/e2e/admin-screenshots.spec.js:162]
- Phase 98 backstop source assertion: keep tests for two-pane band, stacked card, reduced motion, dialog inert, and focus visible versus pointer. [VERIFIED: examples/adoption_demo/e2e/admin-screenshots.spec.js:170] [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:594] [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:650] [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:717] [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:751] [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:801]
- Cohort hard-fail source assertion: remove or bypass warn-mode `reportPolish` catch paths after helper readiness fixes. [VERIFIED: examples/adoption_demo/e2e/cohort-pages.spec.js:30] [VERIFIED: examples/adoption_demo/e2e/cohort-styleguide.spec.js:96]
- Dark proof source assertion: each dark matrix case must assert rendered `[data-ck-root][data-theme="dark"]` or equivalent root state. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:25] [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/components/cohort_components.ex:78]
- Optional pixel artifact assertion: no `toHaveScreenshot` or PNG diff may be required for VIS-01 pass/fail. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:13]

### Idempotency / Diff Proof

Run the following sequence before closing VIS-02, and record both `git diff --exit-code` passes in the milestone audit. [VERIFIED: .planning/ROADMAP.md:462] [VERIFIED: .github/workflows/ci.yml:1172]

```bash
node brandbook/src/tokens-build.mjs
node brandbook/src/admin-css-build.mjs
node brandbook/src/admin-contrast.mjs
node brandbook/src/admin-gallery-check.mjs
node brandbook/src/sync-admin-css.mjs
node brandbook/src/cohort-contrast.mjs
git diff --exit-code

node brandbook/src/tokens-build.mjs
node brandbook/src/admin-css-build.mjs
node brandbook/src/admin-contrast.mjs
node brandbook/src/admin-gallery-check.mjs
node brandbook/src/sync-admin-css.mjs
node brandbook/src/cohort-contrast.mjs
git diff --exit-code
```

### Audit / Documentation Proof Points

- Update `.planning/REQUIREMENTS.md` traceability so VIS-01..VIS-04 are all complete only after commands are green. [VERIFIED: .planning/REQUIREMENTS.md:272]
- Update `.planning/ROADMAP.md` Phase 102 entry or completion status with exact command evidence. [VERIFIED: .planning/ROADMAP.md:455]
- Update `.planning/STATE.md` current focus/proof posture after the full wrapper and idempotency sequence pass. [VERIFIED: .planning/STATE.md:7]
- Write `.planning/milestones/v1.19-MILESTONE-AUDIT.md` using the v1.18/v1.15 audit shape: scorecard, phase verification summary, requirements coverage, integration report, Nyquist coverage, tech debt, and verdict. [VERIFIED: .planning/milestones/v1.18-MILESTONE-AUDIT.md:1] [VERIFIED: .planning/milestones/v1.15-MILESTONE-AUDIT.md:1]
- Keep optional screenshot/gallery artifacts labelled non-blocking if added. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:13]

### Sampling Rate

- **Per task commit:** run JS syntax checks for edited Playwright helpers/specs and the narrow contract/static command for the touched surface. [VERIFIED: command `node --check examples/adoption_demo/e2e/support/admin-polish.js examples/adoption_demo/e2e/admin-screenshots.spec.js examples/adoption_demo/e2e/cohort-pages.spec.js examples/adoption_demo/e2e/cohort-styleguide.spec.js`]
- **Per wave merge:** run targeted Playwright matrix specs, `cohort_migration_contract_test.exs`, and `cohort-contrast.mjs`. [VERIFIED: examples/adoption_demo/e2e/admin-screenshots.spec.js:1] [VERIFIED: examples/adoption_demo/e2e/cohort-pages.spec.js:1] [VERIFIED: examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs:1]
- **Phase gate:** run full `scripts/ci/adoption_demo_e2e.sh`, brandbook double-run diff proof, requirements/doc audit checks, and any release-train checks maintainers require. [VERIFIED: scripts/ci/adoption_demo_e2e.sh:1] [VERIFIED: .github/workflows/ci.yml:1172] [VERIFIED: AGENTS.md:44]

### Wave 0 Gaps

- [ ] `examples/adoption_demo/e2e/support/admin.js` - narrow admin root locator to eliminate strict-mode failure. [VERIFIED: examples/adoption_demo/e2e/support/admin.js:29]
- [ ] `examples/adoption_demo/e2e/support/admin-polish.js` - add explicit focus contract and surface/admin-backstop scoping. [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:356] [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:893]
- [ ] Cohort LiveViews - add rendered dark theme route support across non-upload migrated pages. [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/live/cohort/dashboard_live.ex:13] [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/live/cohort/upload_live.ex:18]
- [ ] Cohort E2E matrix - convert warn-mode route checks to hard-fail light/dark/mobile matrix over all locked surfaces. [VERIFIED: examples/adoption_demo/e2e/cohort-pages.spec.js:48] [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:32]
- [ ] Closeout docs - update traceability, state, roadmap, and v1.19 audit after proof commands pass. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:40]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | Phase 102 does not change authentication flows; keep existing seeded test auth helpers. [VERIFIED: examples/adoption_demo/e2e/support/admin.js:10] |
| V3 Session Management | no | Phase 102 does not change session storage or cookie handling. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:1] |
| V4 Access Control | low | Route tests should continue using seeded entities and existing app routing; do not weaken admin/Cohort route authorization behavior. [VERIFIED: scripts/ci/adoption_demo_e2e.sh:19] |
| V5 Input Validation | yes | Theme params must be enum-normalized to `light`/`dark`, matching existing upload behavior. [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/live/cohort/upload_live.ex:18] |
| V6 Cryptography | no | Phase 102 does not introduce cryptography or secret handling. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:1] |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Query-param theme tampering | Tampering | Allowlist `light`/`dark` and default invalid values to `light`, matching existing upload normalization. [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/live/cohort/upload_live.ex:18] |
| Visual gate bypass through swallowed errors | Repudiation / Tampering | Remove `reportPolish` catch paths for hard-fail Cohort matrix after helper readiness fixes. [VERIFIED: examples/adoption_demo/e2e/cohort-pages.spec.js:30] |
| Secret disclosure in screenshots | Information Disclosure | Preserve existing admin raw-secret visual checks and avoid adding screenshots as blockers. [VERIFIED: examples/adoption_demo/e2e/admin-screenshots.spec.js:91] |
| CI flakiness from sleeps or animation | Denial of Service | Keep motion frozen and avoid `Process.sleep`; existing polish helper freezes motion and project test guidance forbids sleeps. [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:69] [VERIFIED: examples/adoption_demo/AGENTS.md:92] |
| Supply-chain expansion | Tampering | Do not add packages for this phase. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:9] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md` - locked decisions, discretion, and scope. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:1]
- `.planning/ROADMAP.md` - Phase 102 goal and success criteria. [VERIFIED: .planning/ROADMAP.md:455]
- `.planning/REQUIREMENTS.md` - VIS-01..VIS-04 requirement status and traceability. [VERIFIED: .planning/REQUIREMENTS.md:272]
- `.planning/STATE.md` - current milestone focus and proof posture. [VERIFIED: .planning/STATE.md:7]
- `guides/ui_principles.md` - UI, theme, focus, motion, and E2E principles. [VERIFIED: guides/ui_principles.md:1]
- `examples/adoption_demo/e2e/support/admin-polish.js` - current deterministic visual gate implementation. [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:858]
- `examples/adoption_demo/e2e/admin-screenshots.spec.js` - admin matrix and Phase 98 backstop coverage. [VERIFIED: examples/adoption_demo/e2e/admin-screenshots.spec.js:24]
- `examples/adoption_demo/e2e/cohort-pages.spec.js` and `cohort-styleguide.spec.js` - current Cohort warn-mode coverage. [VERIFIED: examples/adoption_demo/e2e/cohort-pages.spec.js:30] [VERIFIED: examples/adoption_demo/e2e/cohort-styleguide.spec.js:96]
- `examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs` - Cohort migration contract. [VERIFIED: examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs:1]
- `examples/adoption_demo/priv/static/assets/cohort.css` - Cohort light/dark/focus/reduced-motion contract. [VERIFIED: examples/adoption_demo/priv/static/assets/cohort.css:43] [VERIFIED: examples/adoption_demo/priv/static/assets/cohort.css:116] [VERIFIED: examples/adoption_demo/priv/static/assets/cohort.css:221]
- `brandbook/src/admin-gallery-check.mjs` and `brandbook/src/cohort-contrast.mjs` - existing audit/static gates. [VERIFIED: brandbook/src/admin-gallery-check.mjs:1] [VERIFIED: brandbook/src/cohort-contrast.mjs:1]
- `.github/workflows/ci.yml` and `scripts/ci/adoption_demo_e2e.sh` - CI job topology and wrapper behavior. [VERIFIED: .github/workflows/ci.yml:649] [VERIFIED: scripts/ci/adoption_demo_e2e.sh:1]

### Command Evidence (HIGH confidence)

- `node --check examples/adoption_demo/e2e/support/admin-polish.js examples/adoption_demo/e2e/admin-screenshots.spec.js examples/adoption_demo/e2e/cohort-pages.spec.js examples/adoption_demo/e2e/cohort-styleguide.spec.js` - exited 0. [VERIFIED: command output]
- `node brandbook/src/cohort-contrast.mjs` - reported `Cohort contrast: 28/28 pairs pass.` [VERIFIED: command output]
- `cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` - reported `17 tests, 0 failures` with existing Mox warnings. [VERIFIED: command output]
- Environment probes for Node, npm, Playwright, Elixir/Mix, Postgres, Docker, FFmpeg, and vips were run locally. [VERIFIED: command `node --version`] [VERIFIED: command `npm --version`] [VERIFIED: command `cd examples/adoption_demo && npm ls @playwright/test --depth=0`] [VERIFIED: command `elixir --version`] [VERIFIED: command `mix --version`] [VERIFIED: command `pg_isready`] [VERIFIED: command `docker --version`] [VERIFIED: command `ffmpeg -version`] [VERIFIED: command `command -v vips`]

### Secondary (MEDIUM confidence)

- None used; no external web or package documentation was required because Phase 102 is constrained to existing repo-local tooling and no new packages. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:9]

### Tertiary (LOW confidence)

- None used; no `[ASSUMED]` claims are included. [VERIFIED: this research artifact]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - existing tools and versions were verified from lock/install state, CI config, and command output. [VERIFIED: command `cd examples/adoption_demo && npm ls @playwright/test --depth=0`] [VERIFIED: .github/workflows/ci.yml:649]
- Architecture: HIGH - gate topology, root issues, Cohort theme gaps, and CI/idempotency flows were verified from source files and phase context. [VERIFIED: examples/adoption_demo/e2e/support/admin.js:29] [VERIFIED: examples/adoption_demo/e2e/support/admin-polish.js:858] [VERIFIED: .github/workflows/ci.yml:1172]
- Pitfalls: HIGH - each pitfall maps to current code or locked Phase 102 decisions. [VERIFIED: .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-CONTEXT.md:1] [VERIFIED: examples/adoption_demo/e2e/cohort-pages.spec.js:30]
- Validation: HIGH for source/contract/static checks already run; MEDIUM for full E2E local execution because local `vips` CLI is missing and full wrapper was not run during research. [VERIFIED: command `command -v vips`] [VERIFIED: scripts/ci/adoption_demo_e2e.sh:1]

**Research date:** 2026-06-19  
**Valid until:** 2026-07-19 for repo-local architecture, or until `admin-polish.js`, adoption-demo E2E specs, or CI job topology changes. [VERIFIED: .planning/STATE.md:1]
