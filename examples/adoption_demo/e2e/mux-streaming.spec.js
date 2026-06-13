const { test, expect } = require("@playwright/test");
const path = require("node:path");
const { waitForLiveSocket } = require("./support/liveview");
const { MEMBERS, memberRow } = require("./support/cohort");

test("mux cassette upload surfaces streaming URL", async ({ page }) => {
  await page.goto("/dashboard");
  await waitForLiveSocket(page);

  const jordanRow = await memberRow(page, MEMBERS.jordan);
  await jordanRow.getByTestId("member-upload-link").click();
  await page.getByTestId("upload-tab-mux").click();

  const fixture = path.join(__dirname, "..", "priv", "fixtures", "demo-video.webm");
  await page.getByTestId("mux-file-input").setInputFiles(fixture);

  await expect(page.getByTestId("mux-upload-status")).toContainText("ready", {
    timeout: 180_000,
  });
  await expect(page.getByTestId("mux-streaming-url")).toBeVisible();
});
