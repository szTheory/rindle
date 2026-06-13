const { test, expect } = require("@playwright/test");
const { waitForLiveSocket } = require("./support/liveview");
const { MEMBERS, memberRow } = require("./support/cohort");

test("multipart upload completes via client hook", async ({ page }) => {
  await page.goto("/dashboard");
  await waitForLiveSocket(page);

  const jordanRow = await memberRow(page, MEMBERS.jordan);
  await jordanRow.getByTestId("member-upload-link").click();
  await page.getByTestId("upload-tab-multipart").click();

  await page.getByTestId("multipart-upload-button").click();
  await expect(page.getByTestId("multipart-upload-status")).toContainText("ready", {
    timeout: 60_000,
  });
});
