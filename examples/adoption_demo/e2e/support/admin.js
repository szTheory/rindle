const { expect } = require("@playwright/test");
const { waitForLiveSocket } = require("./liveview");

const ADMIN_BASE = "/admin/rindle";
const TOP_LEVEL_SURFACES = new Set([
  "home-status",
  "assets",
  "upload-sessions",
  "variants-jobs",
  "runtime-doctor",
  "actions",
]);

function adminPath(suffix = "") {
  const normalizedSuffix = String(suffix || "").replace(/^\/+/, "");

  if (normalizedSuffix === "") {
    return ADMIN_BASE;
  }

  return `${ADMIN_BASE}/${normalizedSuffix}`;
}

async function visitAdmin(page, suffix = "") {
  await page.goto(adminPath(suffix));
  await waitForLiveSocket(page);
}

function adminRoot(page) {
  return page.locator("[data-rindle-admin-root]");
}

async function expectAdminShell(page, surface) {
  const root = adminRoot(page);
  await expect(root).toBeVisible();
  await expect(root).toHaveAttribute("data-rindle-admin-surface", surface);
  await expect(page.locator(`[data-rindle-admin-surface="${surface}"]`)).toBeVisible();
  await expect(page.locator("[data-rindle-admin-component=\"nav\"]")).toBeVisible();
  await expect(page.locator("[data-rindle-admin-page-header]")).toBeVisible();
  await expect(page.locator("[data-rindle-admin-live-indicator]")).toBeVisible();
  await expect(page.locator("[data-rindle-admin-theme=\"light\"]")).toBeVisible();
  await expect(page.locator("[data-rindle-admin-theme=\"dark\"]")).toBeVisible();
  await expect(page.locator("[data-rindle-admin-theme=\"auto\"]")).toBeVisible();

  for (const slug of TOP_LEVEL_SURFACES) {
    await expect(page.locator(`[data-rindle-admin-nav-item="${slug}"]`)).toBeVisible();
  }

  if (TOP_LEVEL_SURFACES.has(surface)) {
    await expect(page.locator(`[data-rindle-admin-nav-item="${surface}"]`)).toHaveAttribute(
      "aria-current",
      "page"
    );
  }
}

async function selectAdminTheme(page, theme) {
  const control = page.locator(`[data-rindle-admin-theme="${theme}"]`);
  await control.click();
  await expect(adminRoot(page)).toHaveAttribute("data-theme", theme);
  await expect(control).toHaveAttribute("aria-pressed", "true");
}

async function firstAdminDetailHref(page, detailKind) {
  const href = await page
    .locator(`[data-rindle-admin-detail-link="${detailKind}"]`)
    .first()
    .getAttribute("href");

  if (!href) {
    throw new Error(`Missing admin detail href for ${detailKind}`);
  }

  return href;
}

async function expectNoAdminRawSecrets(page) {
  const body = page.locator("body");

  await expect(body).not.toContainText("provider-secret");
  await expect(body).not.toContainText("raw-session-secret-token");
  await expect(body).not.toContainText("raw-secret-token");
  await expect(body).not.toContainText("https://storage.example");
}

async function expectNoHorizontalScroll(page) {
  const documentHasNoHorizontalScroll = await page.evaluate(
    () => document.documentElement.scrollWidth <= document.documentElement.clientWidth
  );
  expect(documentHasNoHorizontalScroll).toBe(true);

  const rootHasNoHorizontalScroll = await adminRoot(page).evaluate(
    (root) => root.scrollWidth <= root.clientWidth
  );
  expect(rootHasNoHorizontalScroll).toBe(true);
}

module.exports = {
  ADMIN_BASE,
  adminPath,
  visitAdmin,
  adminRoot,
  expectAdminShell,
  selectAdminTheme,
  firstAdminDetailHref,
  expectNoAdminRawSecrets,
  expectNoHorizontalScroll,
};
