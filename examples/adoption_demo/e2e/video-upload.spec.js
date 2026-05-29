const { test, expect } = require("@playwright/test");
const { waitForLiveSocket } = require("./support/liveview");

test("video AV upload button reaches ready state", async ({ page }) => {
  await page.goto("/upload?tab=video");
  await waitForLiveSocket(page);

  await expect(page.locator("#video-upload-panel")).toBeVisible();

  await page.locator("#video-upload-button").click();
  await expect(page.locator("#video-upload-status")).toContainText("ready", {
    timeout: 180_000,
  });
});
