const { test, expect } = require("@playwright/test");
const path = require("node:path");
const { waitForLiveSocket } = require("./support/liveview");
const { MEMBERS, memberRow } = require("./support/cohort");

test("LiveView server upload attaches image to a new post", async ({ page }) => {
  await page.goto("/dashboard");
  await waitForLiveSocket(page);

  const jordanRow = await memberRow(page, MEMBERS.jordan);
  await jordanRow.getByTestId("member-upload-link").click();
  await page.getByTestId("upload-tab-liveview").click();

  const fixture = path.join(__dirname, "..", "priv", "fixtures", "avatar.png");
  await page.getByTestId("liveview-file-input").setInputFiles(fixture);
  await page.getByTestId("liveview-submit").click();

  await expect(page.getByTestId("liveview-upload-status")).toContainText("ready", {
    timeout: 60_000,
  });
});
