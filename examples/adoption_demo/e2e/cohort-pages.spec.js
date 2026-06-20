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
const COHORT_THEMES = ["light", "dark"];
const COHORT_VIEWPORTS = [
  { name: "desktop", size: { width: 1480, height: 900 } },
  { name: "mobile", size: { width: 390, height: 900 } },
];
const COHORT_UPLOAD_TABS = [
  { surface: "upload-image", tab: "image" },
  { surface: "upload-tus", tab: "tus" },
  { surface: "upload-video", tab: "video" },
  { surface: "upload-multipart", tab: "multipart" },
  { surface: "upload-liveview", tab: "liveview" },
  { surface: "upload-mux", tab: "mux" },
];

function pathFromCurrentPage(page) {
  const url = new URL(page.url());
  return url.pathname;
}

function withTheme(route, theme) {
  const url = new URL(route, "http://cohort.local");
  url.searchParams.set("theme", theme);
  return `${url.pathname}${url.search}`;
}

async function resolveMemberIdRoute(page, buildRoute) {
  await page.goto("/dashboard");
  await waitForLiveSocket(page);
  const id = await memberId(page, MEMBERS.alex);
  return buildRoute(id);
}

async function resolveLinkedRoute(page, linkAction) {
  await page.goto("/dashboard");
  await waitForLiveSocket(page);
  await linkAction(page);
  await waitForLiveSocket(page);
  return pathFromCurrentPage(page);
}

async function selectStyleguideTheme(page, theme) {
  const control = page.locator(`[data-ck-theme="${theme}"]`);
  await control.click();
  await expect(page.locator("[data-ck-root]")).toHaveAttribute("data-theme", theme);
  await expect(control).toHaveAttribute("aria-pressed", "true");
}

async function assertCohortRenderedTheme(page, theme, { styleguide = false } = {}) {
  await expect(page.locator("[data-ck-root]")).toHaveAttribute("data-theme", theme);
  if (styleguide) {
    await expect(page.locator(`[data-ck-theme="${theme}"]`)).toHaveAttribute("aria-pressed", "true");
  }
}

const COHORT_VISUAL_MATRIX = [
  {
    surface: "styleguide",
    styleguide: true,
    resolveRoute: async () => "/styleguide",
  },
  {
    surface: "dashboard",
    resolveRoute: async () => "/dashboard",
  },
  {
    surface: "ops",
    resolveRoute: async () => "/ops",
  },
  {
    surface: "account-erasure",
    resolveRoute: async (page) => resolveMemberIdRoute(page, (id) => `/account/${id}/delete`),
  },
  {
    surface: "member",
    resolveRoute: async (page) => resolveMemberIdRoute(page, (id) => `/members/${id}`),
  },
  {
    surface: "lesson",
    resolveRoute: async (page) =>
      resolveLinkedRoute(page, (linkPage) =>
        linkPage.getByRole("link", { name: "Pattern matching basics" }).first().click()
      ),
  },
  {
    surface: "post",
    resolveRoute: async (page) =>
      resolveLinkedRoute(page, (linkPage) =>
        linkPage.getByRole("link", { name: "Study group this week" }).first().click()
      ),
  },
  {
    surface: "media",
    resolveRoute: async (page) =>
      resolveLinkedRoute(page, (linkPage) =>
        linkPage.getByTestId("demo-assets").getByRole("link").first().click()
      ),
  },
  ...COHORT_UPLOAD_TABS.map(({ surface, tab }) => ({
    surface,
    tab,
    resolveRoute: async () => `/upload?tab=${tab}`,
  })),
];

// Shared per-route polish runner. Per-page plans call this inside a `test(...)`.
//   1. navigate + wait for the LiveSocket
//   2. assert the page renders the .ck shell FIRST (Pitfall 5 guard — without it
//      the gate vacuously passes on a page that never mounted [data-ck-root])
//   3. run assertAdminPolish reused UNCHANGED over [data-ck-root]/.ck-*
async function assertCohortPagePolish(
  page,
  { route, surface, theme = "light", viewport = "desktop", styleguide = false }
) {
  await page.goto(route);
  await waitForLiveSocket(page);

  // Pitfall 5 guard: the migrated page MUST render the .ck shell or the polish
  // gate has nothing to measure and passes vacuously.
  await expect(page.locator("[data-ck-root]")).toBeVisible();

  if (styleguide) {
    await selectStyleguideTheme(page, theme);
  }
  await assertCohortRenderedTheme(page, theme, { styleguide });

  await assertAdminPolish(page, {
    viewport,
    surface,
    root: "[data-ck-root]",
    interactiveSelectors,
    focusContract: COHORT_FOCUS_CONTRACT,
    adminBackstops: false,
  });
}

module.exports = { assertCohortPagePolish, interactiveSelectors };

for (const routeCase of COHORT_VISUAL_MATRIX) {
  for (const theme of COHORT_THEMES) {
    for (const viewport of COHORT_VIEWPORTS) {
      test(`${routeCase.surface} renders ${theme} ${viewport.name} in the Cohort visual matrix`, async ({
        page,
      }) => {
        await page.setViewportSize(viewport.size);
        const baseRoute = await routeCase.resolveRoute(page);
        const route = routeCase.styleguide ? baseRoute : withTheme(baseRoute, theme);

        await assertCohortPagePolish(page, {
          route,
          surface: `${routeCase.surface}-${theme}-${viewport.name}`,
          theme,
          viewport: viewport.name,
          styleguide: !!routeCase.styleguide,
        });
      });
    }
  }
}

// Chrome brand-typography continuity (post-0.3.0 gap closure — COHORT-02 re-audit).
//
// The shared nav (`cohort_nav`) and footer (`cohort_footer`) are rendered by
// `Layouts.app` OUTSIDE the `.ck` / `[data-ck-root]` shell, so `assertAdminPolish`
// — which measures strictly over `[data-ck-root]` (D-96-06) — structurally cannot
// see them. That blind spot let the chrome ship in a system font on every inner
// page while the polish gate passed. This chrome-scoped assertion closes it:
// the nav brand mark and the footer must resolve the Cohort brand font
// (`--ck-font-sans` → "Atkinson Hyperlegible") on an inner route, matching home.
test("chrome (nav brand + footer) uses the Cohort brand font on inner pages", async ({ page }) => {
  await page.goto("/upload?tab=image");
  await waitForLiveSocket(page);

  const brand = page.locator(".ck-nav__brand");
  const footer = page.locator(".ck-footer");
  await expect(brand).toBeVisible();
  await expect(footer).toBeVisible();

  for (const locator of [brand, footer]) {
    const fontFamily = await locator.evaluate((el) => getComputedStyle(el).fontFamily);
    expect(fontFamily).toContain("Atkinson Hyperlegible");
  }
});
