// Cohort per-page visual-contract harness (Phase 99, Plan 01).
//
// The shared Wave-0 home for the 7 small-page migrations. Models on
// `cohort-styleguide.spec.js` (Phase 96, Plan 05) and reuses the already
// parameterized `assertAdminPolish` UNCHANGED (D-94-07 seam, D-96-06) against
// `[data-ck-root]` / `.ck-*` — admin-polish.js is NOT modified. The polish gate
// runs in WARN mode this phase (warn->fail is Phase 102): a polish *offender
// aggregate* is downgraded to console.warn, while a genuine harness crash
// (ReferenceError / TypeError) is re-thrown so it cannot hide.
//
// `assertCohortPagePolish` + `interactiveSelectors` are exported so the per-page
// plans (P2–P5) can `require` them, or add a `test(...)` to this file that calls
// the helper for their route. This plan adds only ONE smoke test proving the
// harness wiring loads against /styleguide.
//
// CommonJS / Chromium-only, matching the sibling specs in this directory.

const { test, expect } = require("@playwright/test");
const { assertAdminPolish } = require("./support/admin-polish");
const { waitForLiveSocket } = require("./support/liveview");

// D-96-06: the FIXED interactive-selector list the polish gate measures over the
// Cohort root for the migrated pages.
const interactiveSelectors = [".ck-btn", ".ck-tab", ".ck-input", ".ck-select"];

// Warn-mode reporter (D-96-06): downgrade a polish offender aggregate to a
// console warning this phase; re-throw a genuine harness crash. Mirrors the
// `reportPolish` predicate in cohort-styleguide.spec.js.
function reportPolish(surface, error) {
  if (!error) return;
  const isOffenderAggregate =
    error instanceof Error &&
    !(error instanceof ReferenceError) &&
    !(error instanceof TypeError) &&
    /Admin polish gate failed/.test(error.message);
  if (!isOffenderAggregate) throw error;
  // eslint-disable-next-line no-console
  console.warn(`[cohort-pages] polish gate (${surface}) reported offenders:\n  ${error.message}`);
}

// Shared per-route polish runner. Per-page plans call this inside a `test(...)`.
//   1. navigate + wait for the LiveSocket
//   2. assert the page renders the .ck shell FIRST (Pitfall 5 guard — without it
//      the gate vacuously passes on a page that never mounted [data-ck-root])
//   3. run assertAdminPolish reused UNCHANGED over [data-ck-root]/.ck-*
//   4. downgrade an offender aggregate to a warning (warn mode this phase)
async function assertCohortPagePolish(page, { route, surface }) {
  await page.goto(route);
  await waitForLiveSocket(page);

  // Pitfall 5 guard: the migrated page MUST render the .ck shell or the polish
  // gate has nothing to measure and passes vacuously.
  await expect(page.locator("[data-ck-root]")).toBeVisible();

  await assertAdminPolish(page, {
    viewport: "desktop",
    surface,
    root: "[data-ck-root]",
    interactiveSelectors,
  }).catch((error) => reportPolish(surface, error));
}

module.exports = { assertCohortPagePolish, interactiveSelectors, reportPolish };

// Wave-0 smoke: prove the harness wiring loads and runs against /styleguide
// (which already renders the .ck shell). The 7 real route cases are added by
// P2–P5 (each a `test(...)` calling assertCohortPagePolish for its route).
test("cohort-pages harness loads and runs (Wave-0 smoke over /styleguide)", async ({ page }) => {
  expect(typeof assertCohortPagePolish).toBe("function");
  await assertCohortPagePolish(page, { route: "/styleguide", surface: "styleguide-smoke" });
});
