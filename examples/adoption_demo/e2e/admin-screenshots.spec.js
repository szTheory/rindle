const fs = require("node:fs");
const path = require("node:path");
const { test, expect } = require("@playwright/test");
const {
  visitAdmin,
  adminRoot,
  expectAdminShell,
  selectAdminTheme,
  firstAdminDetailHref,
  expectNoAdminRawSecrets,
  expectNoHorizontalScroll,
} = require("./support/admin");
const { assertAdminPolish } = require("./support/admin-polish");
const { waitForLiveSocket } = require("./support/liveview");
const { MEMBERS, memberId } = require("./support/cohort");

const screenshotsDir = path.join(__dirname, "..", "test-results", "admin-screenshots");
const desktopCases = [
  { suffix: "", surface: "home-status", name: "home-status" },
  { suffix: "assets", surface: "assets", name: "assets" },
  { suffix: "assets", surface: "assets", name: "asset-detail", detail: "asset" },
  { suffix: "upload-sessions", surface: "upload-sessions", name: "upload-sessions" },
  {
    suffix: "upload-sessions",
    surface: "upload-sessions",
    name: "upload-session-detail",
    detail: "upload-session",
  },
  { suffix: "variants-jobs", surface: "variants-jobs", name: "variants-jobs" },
  { suffix: "runtime-doctor", surface: "runtime-doctor", name: "runtime-doctor" },
  { suffix: "actions", surface: "actions", name: "actions" },
  { suffix: "actions", surface: "actions", name: "actions-owner-preview", ownerPreview: true },
];
const mobileCases = [
  { suffix: "", surface: "home-status", name: "home-status" },
  { suffix: "actions", surface: "actions", name: "actions" },
];
const themes = ["light", "dark"];
const expectedScreenshots = [
  "light/home-status.png",
  "light/assets.png",
  "light/asset-detail.png",
  "light/upload-sessions.png",
  "light/upload-session-detail.png",
  "light/variants-jobs.png",
  "light/runtime-doctor.png",
  "light/actions.png",
  "light/actions-owner-preview.png",
  "dark/home-status.png",
  "dark/assets.png",
  "dark/asset-detail.png",
  "dark/upload-sessions.png",
  "dark/upload-session-detail.png",
  "dark/variants-jobs.png",
  "dark/runtime-doctor.png",
  "dark/actions.png",
  "dark/actions-owner-preview.png",
  "mobile/light/home-status.png",
  "mobile/light/actions.png",
  "mobile/dark/home-status.png",
  "mobile/dark/actions.png",
];

test.beforeAll(() => {
  fs.rmSync(screenshotsDir, { recursive: true, force: true });
  fs.mkdirSync(screenshotsDir, { recursive: true });
});

async function capture(page, theme, relativePath) {
  await selectAdminTheme(page, theme);
  await expectNoAdminRawSecrets(page);
  await expectNoHorizontalScroll(page);

  // Deterministic visual-polish gate: replaces the former human screenshot review by
  // asserting clipped text, contrast, target sizes, overlap, and stable dimensions on
  // the exact rendered state of every capture (all 22 surface/theme/viewport states).
  const surface = await adminRoot(page).getAttribute("data-rindle-admin-surface");
  const viewport = relativePath.startsWith("mobile/") ? "mobile" : "desktop";
  await assertAdminPolish(page, { viewport, surface });

  const outputPath = path.join(screenshotsDir, relativePath);
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  await page.screenshot({ path: outputPath, animations: "disabled", fullPage: true });
}

async function visitDetail(page, detailKind) {
  const href = await firstAdminDetailHref(page, detailKind);
  await page.goto(href);
  await waitForLiveSocket(page);
}

async function selectOwnerErasure(page) {
  await page.locator('[data-rindle-admin-action="owner_erasure"]').click();
  await expect(page.locator('[data-rindle-admin-action-panel="owner_erasure"]')).toBeVisible();
}

async function prepareOwnerPreview(page, ownerId) {
  await selectOwnerErasure(page);
  await page.locator('[data-rindle-admin-input="owner_type"]').fill("AdoptionDemo.Accounts.Member");
  await page.locator('[data-rindle-admin-input="owner_id"]').fill(ownerId);
  await page
    .locator('[data-rindle-admin-form="owner_erasure_preview"]')
    .evaluate((form) => form.requestSubmit());
  await expect(page.locator('[data-rindle-admin-preview="owner_erasure"]')).toBeVisible();
}

async function visitScreenshotCase(page, screenshotCase, ownerId) {
  await visitAdmin(page, screenshotCase.suffix);

  if (screenshotCase.detail) {
    await visitDetail(page, screenshotCase.detail);
  }

  if (screenshotCase.ownerPreview) {
    await prepareOwnerPreview(page, ownerId);
  }

  await expectAdminShell(page, screenshotCase.surface);
}

test("captures admin-screenshots light and dark matrix", async ({ page }) => {
  await page.goto("/dashboard");
  await waitForLiveSocket(page);
  const alexId = await memberId(page, MEMBERS.alex);

  await page.setViewportSize({ width: 1480, height: 900 });
  for (const theme of themes) {
    for (const screenshotCase of desktopCases) {
      await visitScreenshotCase(page, screenshotCase, alexId);
      await capture(page, theme, `${theme}/${screenshotCase.name}.png`);
    }
  }

  await page.setViewportSize({ width: 390, height: 900 });
  for (const theme of themes) {
    for (const screenshotCase of mobileCases) {
      await visitScreenshotCase(page, screenshotCase, alexId);
      await capture(page, theme, `mobile/${theme}/${screenshotCase.name}.png`);
    }
  }

  const missing = expectedScreenshots.filter(
    (relativePath) => !fs.existsSync(path.join(screenshotsDir, relativePath))
  );
  expect(missing, `missing screenshots: ${missing.join(", ")}`).toEqual([]);
  expect(expectedScreenshots).toHaveLength(22);
});
