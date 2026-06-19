// Cohort per-page visual-contract harness (Phase 99, Plan 01).
//
// The shared Wave-0 home for the 7 small-page migrations. Models on
// `cohort-styleguide.spec.js` (Phase 96, Plan 05) and reuses the already
// parameterized `assertAdminPolish` (D-94-07 seam, D-96-06) against
// `[data-ck-root]` / `.ck-*`. Phase 102 promotes Cohort to hard-fail:
// polish offender aggregates and helper crashes both fail the Playwright test.
//
// `assertCohortPagePolish` + `interactiveSelectors` stay exported for any
// existing imports, while this file owns the Phase 102 visual matrix.
//
// CommonJS / Chromium-only, matching the sibling specs in this directory.

const { test, expect } = require("@playwright/test");
const { assertAdminPolish } = require("./support/admin-polish");
const { waitForLiveSocket } = require("./support/liveview");
const { MEMBERS, memberId } = require("./support/cohort");

// D-96-06: the FIXED interactive-selector list the polish gate measures over the
// Cohort root for the migrated pages.
const interactiveSelectors = [".ck-btn", ".ck-tab", ".ck-input", ".ck-select"];

const COHORT_FOCUS_CONTRACT = { width: "2px", color: "--ck-focus", offset: "2px" };

// Shared per-route polish runner. Per-page plans call this inside a `test(...)`.
//   1. navigate + wait for the LiveSocket
//   2. assert the page renders the .ck shell FIRST (Pitfall 5 guard — without it
//      the gate vacuously passes on a page that never mounted [data-ck-root])
//   3. run assertAdminPolish reused UNCHANGED over [data-ck-root]/.ck-*
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
    focusContract: COHORT_FOCUS_CONTRACT,
    adminBackstops: false,
  });
}

module.exports = { assertCohortPagePolish, interactiveSelectors };

// Wave-0 smoke: prove the harness wiring loads and runs against /styleguide
// (which already renders the .ck shell). The 7 real route cases are added by
// P2–P5 (each a `test(...)` calling assertCohortPagePolish for its route).
test("cohort-pages harness loads and runs (Wave-0 smoke over /styleguide)", async ({ page }) => {
  expect(typeof assertCohortPagePolish).toBe("function");
  await assertCohortPagePolish(page, { route: "/styleguide", surface: "styleguide-smoke" });
});

// Wave-2 (Plan 02): /dashboard migrated onto ck_page/1. Reuses the shared
// warn-mode helper — root-visibility guarded, no harness logic duplicated.
test("/dashboard renders on the Cohort DS (polish, warn mode)", async ({ page }) => {
  await assertCohortPagePolish(page, { route: "/dashboard", surface: "dashboard-cohort" });
});

// Wave-3 (Plan 03): /ops migrated onto ck_page/1 (.ck-btn buttons + .ck-output
// panels). Reuses the shared warn-mode helper — no harness logic duplicated.
test("/ops renders on the Cohort DS (polish, warn mode)", async ({ page }) => {
  await assertCohortPagePolish(page, { route: "/ops", surface: "ops-cohort" });
});

// Wave-3 (Plan 03): /account/:id/delete erasure migrated onto ck_page/1. The
// route needs a seeded member id, derived the same way the owner-erasure spec
// does — visit /dashboard, read the member row id via support/cohort's memberId
// helper — then run the shared polish helper against the resolved route.
test("/account erasure renders on the Cohort DS (polish, warn mode)", async ({ page }) => {
  await page.goto("/dashboard");
  await waitForLiveSocket(page);
  const id = await memberId(page, MEMBERS.alex);

  await assertCohortPagePolish(page, {
    route: `/account/${id}/delete`,
    surface: "account-cohort",
  });
});

// Wave-4 (Plan 04): /members/:id migrated onto ck_page/1 (avatar + replace/detach,
// picture_tag wrapper). Derive a seeded member id the same way the owner-erasure /
// account spec does — visit /dashboard, read alex's row id via support/cohort's
// memberId — then run the shared warn-mode polish helper against the resolved route.
test("/members renders on the Cohort DS (polish, warn mode)", async ({ page }) => {
  await page.goto("/dashboard");
  await waitForLiveSocket(page);
  const id = await memberId(page, MEMBERS.alex);

  await assertCohortPagePolish(page, {
    route: `/members/${id}`,
    surface: "member-cohort",
  });
});

// Wave-4 (Plan 04): /lessons/:id migrated onto ck_page/1 (video + variant list).
// Navigate via the seeded lesson link the way rendering.spec.js does (the lesson
// id is not exposed on /dashboard as an attribute we can read directly), then run
// the shared warn-mode polish helper against the resolved URL.
test("/lessons renders on the Cohort DS (polish, warn mode)", async ({ page }) => {
  await page.goto("/dashboard");
  await waitForLiveSocket(page);

  await page.getByRole("link", { name: "Pattern matching basics" }).first().click();
  await waitForLiveSocket(page);

  await assertCohortPagePolish(page, {
    route: page.url(),
    surface: "lesson-cohort",
  });
});

// Wave-5 (Plan 05): /posts/:id migrated onto ck_page/1 (title + body + picture_tag
// image section). Navigate via the seeded "Study group this week" post link the
// way rendering.spec.js navigates the lesson link (the post id is not exposed on
// /dashboard as a directly-readable attribute), then run the shared warn-mode
// polish helper against the resolved URL.
test("/posts renders on the Cohort DS (polish, warn mode)", async ({ page }) => {
  await page.goto("/dashboard");
  await waitForLiveSocket(page);

  await page.getByRole("link", { name: "Study group this week" }).first().click();
  await waitForLiveSocket(page);

  await assertCohortPagePolish(page, {
    route: page.url(),
    surface: "post-cohort",
  });
});

// Wave-5 (Plan 05): /media/:id migrated onto ck_page/1 (the <dl> restyled IN
// PLACE — media-id/media-state/media-delivery-url <dd>s — plus the variant list
// + alex link). The asset link text on /dashboard is the asset id (a UUID), so
// click the first link inside the seeded "Recent assets" (demo-assets) section,
// then run the shared warn-mode polish helper against the resolved URL.
test("/media renders on the Cohort DS (polish, warn mode)", async ({ page }) => {
  await page.goto("/dashboard");
  await waitForLiveSocket(page);

  await page.getByTestId("demo-assets").getByRole("link").first().click();
  await waitForLiveSocket(page);

  await assertCohortPagePolish(page, {
    route: page.url(),
    surface: "media-cohort",
  });
});

// Wave-2 / Phase 100 Plan 02 (COHORT-02 SC1/SC3): /upload migrated onto ck_page/1
// across all 6 tabs (Plan 01). Prove every tab via the deterministic ?tab= URL —
// load_member!(nil) falls back to the first seeded member, so no id is needed.
// Reuses the shared warn-mode helper UNCHANGED (root-visibility guarded, Pitfall D);
// admin-polish.js is NOT edited (D-96-06).
for (const tab of ["image", "tus", "video", "multipart", "liveview", "mux"]) {
  test(`/upload?tab=${tab} renders on the Cohort DS (polish, warn mode)`, async ({ page }) => {
    await assertCohortPagePolish(page, {
      route: `/upload?tab=${tab}`,
      surface: `upload-${tab}-cohort`,
    });
  });
}

// +1 dark case on the image tab (COHORT-02 SC3 — a light AND dark polish case
// covers the upload surface). Pitfall F (the one CONTEXT-mechanism correction):
// Playwright's colorScheme media emulation ALONE will NOT flip the theme — ck_page
// emits an explicit data-theme that is authoritative over the @media fallback. Drive
// the dark case via the SERVER ?theme=dark assign (the enum-gated read Plan 01 added
// to upload_live.ex). After the polish assertion, additionally assert the surface
// actually rendered dark so the dark path is real, not vacuous.
test("/upload?tab=image renders on the Cohort DS in dark (polish, warn mode)", async ({ page }) => {
  await assertCohortPagePolish(page, {
    route: "/upload?tab=image&theme=dark",
    surface: "upload-image-dark-cohort",
  });

  await expect(page.locator("[data-ck-root]")).toHaveAttribute("data-theme", "dark");
});
