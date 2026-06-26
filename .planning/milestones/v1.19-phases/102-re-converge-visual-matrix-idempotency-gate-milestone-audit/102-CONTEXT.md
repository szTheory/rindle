# Phase 102: Re-Converge - Visual Matrix, Idempotency Gate & Milestone Audit - Context

**Gathered:** 2026-06-18 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 102 reconverges v1.19 Track A and Track B proof surfaces. The phase must make the
deterministic visual matrix merge-blocking across admin and Cohort, prove forward-only
idempotency/no-regression, keep optional visual-audit artifacts non-blocking, and close v1.19
requirements traceability plus the milestone audit.

This is proof, convergence, and audit work only. Do not reopen tus, Mux, owner-erasure,
console lifecycle/write-path semantics, force-delete, second-provider scope, Tailwind adoption,
SaaS visual-regression tooling, or product-facing feature scope.
</domain>

<decisions>
## Implementation Decisions

### Visual Gate Topology

- **D-102-01:** The existing `examples/adoption_demo/e2e/support/admin-polish.js` computed-style
  gate is the single merge-blocking visual gate for Phase 102. Keep the gate inside the existing
  `adoption-demo-e2e` Playwright lane; do not add a second merge-blocking screenshot or visual
  regression lane.
- **D-102-02:** Admin keeps its current hard-fail path. Cohort must move from warn/report mode to
  hard-fail mode over explicit roots and selector lists: `[data-rindle-admin-root]` for admin and
  `[data-ck-root]` for Cohort. Preserve D-94-07: root selection remains explicit; no root
  auto-detection.
- **D-102-03:** Pixel baselines, `toHaveScreenshot()`, and gallery screenshots are optional
  assistive/audit signals only. They may be added or retained only if CI-generated,
  motion-frozen, font-stable, and non-blocking. They must never become the VIS-01 merge blocker
  in this milestone.

### Cohort Hard-Fail Readiness

- **D-102-04:** Before flipping Cohort to hard-fail, make `admin-polish.js` genuinely
  surface-aware for focus assertions. Extend the helper with an explicit focus-token contract
  that defaults to the existing admin token names (`--rindle-focus-width`,
  `--rindle-focus-ring`, `--rindle-focus-offset`) and lets Cohort callers pass the Cohort
  contract (`2px`, `--ck-focus`, `2px`). Do not infer token names from the root.
- **D-102-05:** Scope outline scanning and offender collection so Cohort defects are real
  surface defects, not global host-cascade noise. A harness crash remains a hard failure; polish
  offenders become hard failures once the Cohort matrix is promoted.
- **D-102-06:** Cohort dark coverage must be driven through the actual rendered Cohort theme
  contract (`data-theme` / server route state such as `?theme=dark` where needed), not by
  Playwright `colorScheme` alone. A dark test must assert the Cohort root rendered `data-theme`
  dark or otherwise prove the explicit dark path is active.

### Matrix Coverage And No-Regression

- **D-102-07:** Preserve admin's current matrix coverage and backstops, including the 24-state
  screenshot/check matrix and Phase 98 computed-style backstops. Phase 102 may reorganize the
  matrix, but it must not reduce admin coverage.
- **D-102-08:** Expand Cohort from the current route-level warn-mode coverage to a full
  light/dark/mobile matrix across `/styleguide`, `/dashboard`, `/ops`, account erasure, member,
  lesson, post, media, and all six `/upload` tabs. The matrix can be implemented by extending
  `cohort-pages.spec.js` or by creating a unified visual matrix spec that imports the same route
  helpers, but it must not fork the polish logic.
- **D-102-09:** Existing behavior and contract gates remain the no-regression backstops:
  `cohort_migration_contract_test.exs`, Cohort contrast/literal scanning, upload behavior specs,
  and the full adoption demo Playwright suite. The visual matrix proves design-system quality;
  it does not replace behavior proofs.

### CI, Idempotency, And Audit Closeout

- **D-102-10:** Use existing repo gates for idempotency. Generated admin CSS drift stays under
  `brandbook-tokens` (`tokens-build`, `admin-css-build`, `admin-contrast`,
  `admin-gallery-check`, `sync-admin-css`, empty diff). Hand-authored Cohort CSS stays under
  `cohort-contrast` plus Playwright/ExUnit ratchets. Do not generate `cohort.css` from
  `tokens.json`.
- **D-102-11:** A successful Phase 102 must make the full `scripts/ci/adoption_demo_e2e.sh`
  wrapper green. The known pre-Phase-102 admin strict-locator red must be fixed or otherwise
  resolved inside the proof lane before claiming VIS-01/VIS-02 closure.
- **D-102-12:** Milestone closeout follows the existing audit pattern from v1.18/v1.15:
  update requirements traceability to 20/20, write the v1.19 milestone audit, record exact
  verification evidence, and keep docs/proof parity truthful. If optional pixel/gallery artifacts
  are present, document them as non-blocking audit signals.

### Agent Discretion

Planner may choose exact spec filenames, route case data structures, helper option names,
surface labels, screenshot artifact names, and whether to extend `cohort-pages.spec.js` or add a
thin unified visual matrix spec. Those choices are local as long as the decisions above hold and
the phase remains within VIS-01..04.

### Folded Todos

No matching pending todos (`todo.match-phase 102` -> 0 matches).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` - Phase 102 goal, dependencies, success criteria, and v1.19 phase order.
- `.planning/REQUIREMENTS.md` - VIS-01..04 and v1.19 20/20 traceability state.
- `.planning/STATE.md` - current milestone state, proof posture, blockers, and accumulated
  decisions from phases 94-101.
- `.planning/METHODOLOGY.md` - repo-truth, adopter-first, research-first, and proof-surface
  lenses applied to this phase.
- `.planning/phases/94-foundation-token-pipeline-ci-gate-new-token-categories/94-CONTEXT.md`
  - generalized `admin-polish.js` seam and token/idempotency foundation.
- `.planning/phases/96-cohort-component-layer-dark-reduced-motion-contract-track-b/96-CONTEXT.md`
  - Cohort `data-ck-root`, dark theme, reduced-motion, styleguide, and warn-mode gate decisions.
- `.planning/phases/97-admin-level-2-meta-components-track-a/97-CONTEXT.md`
  - admin Level-2 polish assertions and hard-fail cohesion checks.
- `.planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-CONTEXT.md`
  - admin hard-fail matrix, Phase 98 computed-style backstops, and no-Cohort-generalization
  boundary.
- `.planning/phases/100-cohort-upload-migration-all-tabs-track-b/100-CONTEXT.md`
  - `/upload` route/tab/theme proof decisions and behavior backstop split.
- `.planning/phases/101-daisyui-retirement-track-b/101-CONTEXT.md`
  - Cohort daisyUI retirement ratchet, deleted `default.css`, and Playwright warn-mode boundary.
- `examples/adoption_demo/e2e/support/admin-polish.js` - shared computed-style visual gate.
- `examples/adoption_demo/e2e/admin-screenshots.spec.js` - current hard-fail admin matrix.
- `examples/adoption_demo/e2e/cohort-pages.spec.js` - current Cohort route coverage and warn-mode
  helper.
- `examples/adoption_demo/e2e/cohort-styleguide.spec.js` - Cohort styleguide theme,
  reduced-motion, and rendered-contrast probes.
- `examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs` -
  Cohort source/render/frozen-DOM ratchet.
- `examples/adoption_demo/priv/static/assets/cohort.css` - hand-authored Cohort theme,
  focus, reduced-motion, and `.ck-*` surface contract.
- `brandbook/src/admin-gallery-check.mjs` - living admin gallery audit and browser proof.
- `brandbook/src/cohort-contrast.mjs` - Cohort token/literal/contrast gate.
- `.github/workflows/ci.yml` - merge-blocking lane wiring for `adoption-demo-e2e` and
  `brandbook-tokens`.
- `scripts/ci/adoption_demo_e2e.sh` - full adoption demo E2E wrapper that must be green.

No external specs are required beyond the repo artifacts above.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `assertAdminPolish(page, { viewport, surface, root, interactiveSelectors })` is already the
  shared browser gate and accepts explicit root/selector overrides. It returns one aggregated
  failure with offender details.
- `cohort-pages.spec.js` already exports `assertCohortPagePolish`, `interactiveSelectors`, and
  `reportPolish`; this is the narrowest place to remove warn-mode handling or to share route cases.
- `cohort-styleguide.spec.js` already proves the styleguide, reduced-motion probe order, theme
  toggles, and rendered contrast warnings over `[data-ck-root]`.
- `admin-screenshots.spec.js` already models matrix enumeration, deterministic screenshots,
  hard-fail polish checks, and expected artifact lists.
- `cohort_migration_contract_test.exs` already pins preserved DOM, shared layout retirement,
  deleted generator artifacts, and deleted `default.css`.
- `brandbook-tokens` already proves generated admin artifact idempotency. Do not duplicate this
  logic in Phase 102 except by referencing/running it as part of verification.

### Established Patterns

- Explicit roots are required. Mixed admin+Cohort pages must not rely on auto-detection.
- Visual proof is computed-style first; screenshots are artifacts for review, not the blocker.
- Admin CSS is generated and mirrored to `priv/`; Cohort CSS is hand-authored and guarded by
  Cohort-specific contrast/literal checks.
- Cohort dark mode is explicit `data-theme` state; Playwright media emulation alone is only useful
  for media-fallback probes, not for proving rendered dark Cohort pages.
- The repo prefers source/render ratchets plus behavior E2E over raw substring shell greps or
  pixel-only assertions.

### Integration Points

- Update `admin-polish.js` surface options before promoting Cohort callers to hard-fail.
- Update Cohort Playwright specs to cover light/dark/mobile route cases and stop catching polish
  offender aggregates once promoted.
- Keep the full `scripts/ci/adoption_demo_e2e.sh` lane as the final E2E truth source.
- Update `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`, and write
  `.planning/milestones/v1.19-MILESTONE-AUDIT.md` during closeout.
</code_context>

<specifics>
## Specific Ideas

- Prefer a small `focusTokens`/`focusContract` option on `assertAdminPolish` over special-casing
  Cohort inside the helper. Admin callers should not need to change.
- For Cohort, pass a contract equivalent to width `2px`, ring `--ck-focus`, offset `2px`; verify
  against computed styles rather than hard-coded root token names.
- A route-case table can carry `{ route, surface, themes, viewports }` so Cohort light/dark/mobile
  cases stay declarative and do not duplicate test bodies.
- The known admin strict-locator failure from Phase 101 must be treated as part of making the
  merge-blocking visual lane truthful, not as a separate product feature.
</specifics>

<deferred>
## Deferred Ideas

None - analysis stayed within VIS-01..04.

### Reviewed Todos (not folded)

None.
</deferred>
