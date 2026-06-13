const { test, expect } = require("@playwright/test");
const path = require("node:path");
const { waitForLiveSocket } = require("./support/liveview");
const { MEMBERS, memberRow } = require("./support/cohort");

test("browser video file upload reaches ready state", async ({ page }) => {
  await page.goto("/dashboard");
  await waitForLiveSocket(page);

  const jordanRow = await memberRow(page, MEMBERS.jordan);
  await jordanRow.getByTestId("member-upload-link").click();
  await page.getByTestId("upload-tab-video").click();

  await expect(page.getByTestId("video-upload-panel")).toBeVisible();

  const fixture = path.join(__dirname, "..", "priv", "fixtures", "demo-video.webm");
  await page.getByTestId("video-file-input").setInputFiles(fixture);

  await expect(page.getByTestId("video-upload-status")).toContainText("ready", {
    timeout: 180_000,
  });
});
