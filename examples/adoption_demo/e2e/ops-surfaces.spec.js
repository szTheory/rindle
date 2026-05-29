const { test, expect } = require("@playwright/test");
const { waitForLiveSocket } = require("./support/liveview");

test("ops surfaces render doctor and runtime status output", async ({ page }) => {
  await page.goto("/ops");
  await waitForLiveSocket(page);

  await page.locator("#run-doctor-button").click();
  await expect(page.locator("#doctor-output")).toContainText("doctor_success=", {
    timeout: 30_000,
  });

  await page.locator("#run-runtime-status-button").click();
  await expect(page.locator("#runtime-status-output")).toBeVisible();
  await expect(page.locator("#runtime-status-output")).not.toBeEmpty();
});
