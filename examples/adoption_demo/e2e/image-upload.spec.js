const { test, expect } = require("@playwright/test");
const path = require("node:path");
const { waitForLiveSocket } = require("./support/liveview");
const { MEMBERS, memberRow } = require("./support/cohort");

test("presigned PUT avatar upload attaches and shows ready", async ({ page }) => {
  await page.goto("/dashboard");
  await waitForLiveSocket(page);

  const jordanRow = await memberRow(page, MEMBERS.jordan);
  await expect(jordanRow).toBeVisible();

  await jordanRow.getByTestId("member-upload-link").click();
  await expect(page.getByTestId("upload-member-name")).toContainText("Jordan");

  const fixture = path.join(__dirname, "..", "priv", "fixtures", "avatar.png");
  await page.getByTestId("image-file-input").setInputFiles(fixture);

  await expect(page.getByTestId("image-upload-status")).toContainText("ready", {
    timeout: 60_000,
  });
  await expect(page.getByTestId("image-upload-asset-id")).toBeVisible();
});
