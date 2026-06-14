const { test, expect } = require("@playwright/test");
const {
  visitAdmin,
  expectAdminShell,
  firstAdminDetailHref,
  expectNoAdminRawSecrets,
  expectNoHorizontalScroll,
} = require("./support/admin");

const ADMIN_SURFACES = [
  ["", "home-status"],
  ["assets", "assets"],
  ["upload-sessions", "upload-sessions"],
  ["variants-jobs", "variants-jobs"],
  ["runtime-doctor", "runtime-doctor"],
  ["actions", "actions"],
];

test("admin console top-level surfaces render the shell and seeded rows", async ({ page }) => {
  for (const [suffix, surface] of ADMIN_SURFACES) {
    await visitAdmin(page, suffix);
    await expectAdminShell(page, surface);
    await expectNoHorizontalScroll(page);
  }

  await visitAdmin(page, "assets");
  await expect(page.locator('[data-rindle-admin-row="asset"]').first()).toBeVisible();

  await visitAdmin(page, "upload-sessions");
  await expect(page.locator('[data-rindle-admin-row="upload-session"]').first()).toBeVisible();
  await expect(page.locator("[data-rindle-admin-redacted-value]").first()).toBeVisible();

  await visitAdmin(page, "variants-jobs");
  await expect(page.locator('[data-rindle-admin-row="variant-finding"]').first()).toBeVisible();
  await expect(page.getByText("Variant/job buckets")).toBeVisible();

  await visitAdmin(page, "runtime-doctor");
  await expect(page.locator('[data-rindle-admin-row="doctor-check"]').first()).toBeVisible();
  await expect(page.getByText("Doctor checks")).toBeVisible();
});

test("seeded lifecycle edge states render gracefully across surfaces", async ({ page }) => {
  // Phase 91 deliverable: quarantined/degraded assets and failed/expired upload
  // sessions must display without 500s. Full-stack complement to the ExUnit
  // admin_lifecycle_display_test — proves the seeded edge states reach the browser.
  await visitAdmin(page, "assets");
  await expectAdminShell(page, "assets");
  await expect(page.getByText("quarantined").first()).toBeVisible();
  await expect(page.getByText("degraded").first()).toBeVisible();
  await expect(page.locator("[data-rindle-admin-error-state]")).toHaveCount(0);

  await visitAdmin(page, "upload-sessions");
  await expectAdminShell(page, "upload-sessions");
  await expect(page.getByText("failed").first()).toBeVisible();
  await expect(page.getByText("expired").first()).toBeVisible();
  await expect(page.locator("[data-rindle-admin-error-state]")).toHaveCount(0);
});

test("asset and upload-session detail pages render redacted detail sections", async ({ page }) => {
  await visitAdmin(page, "assets");
  const assetHref = await firstAdminDetailHref(page, "asset");

  await page.goto(assetHref);
  await expectAdminShell(page, "assets");
  await expect(page.getByText("Attachment context")).toBeVisible();
  await expect(page.getByRole("heading", { name: "Upload sessions" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Provider assets" })).toBeVisible();
  await expectNoAdminRawSecrets(page);
  await expectNoHorizontalScroll(page);

  await visitAdmin(page, "upload-sessions");
  const uploadSessionHref = await firstAdminDetailHref(page, "upload-session");

  await page.goto(uploadSessionHref);
  await expectAdminShell(page, "upload-sessions");
  await expect(page.getByText("Strategy/protocol")).toBeVisible();
  await expect(page.getByText("Cleanup guidance")).toBeVisible();
  await expect(page.locator("[data-rindle-admin-redacted-value]").first()).toBeVisible();
  await expectNoAdminRawSecrets(page);
  await expectNoHorizontalScroll(page);
});

test("empty filters render empty states instead of errors", async ({ page }) => {
  for (const [suffix, surface] of [
    ["assets?state=missing", "assets"],
    ["upload-sessions?state=missing", "upload-sessions"],
  ]) {
    await visitAdmin(page, suffix);
    await expectAdminShell(page, surface);
    await expect(page.locator("[data-rindle-admin-empty-state]")).toBeVisible();
    await expect(page.locator("[data-rindle-admin-error-state]")).toHaveCount(0);
    await expect(page.getByText("No records match this view")).toBeVisible();
  }
});

test("missing detail routes render stable error states", async ({ page }) => {
  for (const [suffix, surface] of [
    ["assets/not-a-real-asset", "assets"],
    ["upload-sessions/not-a-real-session", "upload-sessions"],
  ]) {
    await visitAdmin(page, suffix);
    await expectAdminShell(page, surface);
    await expect(page.locator("[data-rindle-admin-error-state]")).toBeVisible();
    await expect(page.locator("[data-rindle-admin-empty-state]")).toHaveCount(0);
    await expect(page.getByText("Rindle Admin could not load this surface").first()).toBeVisible();
    await expectNoAdminRawSecrets(page);
  }
});
