const { test, expect } = require("@playwright/test");
const {
  visitAdmin,
  adminRoot,
  expectAdminShell,
  selectAdminTheme,
  expectNoHorizontalScroll,
} = require("./support/admin");

const THEMES = ["light", "dark", "auto"];

async function expectThemeState(page, selectedTheme) {
  await expect(adminRoot(page)).toHaveAttribute("data-theme", selectedTheme);

  for (const theme of THEMES) {
    await expect(page.locator(`[data-rindle-admin-theme="${theme}"]`)).toHaveAttribute(
      "aria-pressed",
      theme === selectedTheme ? "true" : "false"
    );
  }
}

async function expectThemeReadySurface(page, selectedTheme) {
  await expectThemeState(page, selectedTheme);
  await expect(page.locator("[data-rindle-admin-nav-item]").first()).toBeVisible();
  await expect(page.locator("[data-rindle-admin-page-header]")).toBeVisible();
  await expect(page.locator("[data-rindle-admin-live-indicator]")).toBeVisible();
  await expect(page.locator('[data-rindle-admin-component="theme-picker"]')).toBeVisible();
  await expectNoHorizontalScroll(page);
}

async function exerciseThemePicker(page) {
  await selectAdminTheme(page, "light");
  await expectThemeReadySurface(page, "light");
  await selectAdminTheme(page, "dark");
  await expectThemeReadySurface(page, "dark");
  await selectAdminTheme(page, "auto");
  await expectThemeReadySurface(page, "auto");
}

test("admin theme picker applies light, dark, and auto on core surfaces", async ({ page }) => {
  await visitAdmin(page, "");
  await expectAdminShell(page, "home-status");
  await exerciseThemePicker(page);

  await visitAdmin(page, "assets");
  await expectAdminShell(page, "assets");
  await exerciseThemePicker(page);

  await visitAdmin(page, "actions");
  await expectAdminShell(page, "actions");
  await exerciseThemePicker(page);
});
