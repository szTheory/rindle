const { test, expect } = require("@playwright/test");
const path = require("node:path");
const { waitForLiveSocket } = require("./support/liveview");

test("tus upload completes via LiveView helper", async ({ page }) => {
  await page.goto("/upload?tab=tus");
  await waitForLiveSocket(page);

  await expect(page.locator("#tus-upload-panel")).toBeVisible();

  const fixture = path.join(__dirname, "..", "priv", "fixtures", "demo-video.webm");
  await page.locator("#tus-form input[type='file']").setInputFiles(fixture);
  await expect(page.locator("#tus-upload-status")).toContainText("uploading", {
    timeout: 60_000,
  });
  await page.locator("#tus-submit").click();

  await expect(page.locator("#tus-upload-status")).toContainText("ready", {
    timeout: 120_000,
  });
});
