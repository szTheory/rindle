const { test, expect } = require("@playwright/test");
const { waitForLiveSocket } = require("./support/liveview");

test("batch erasure preview on ops surface", async ({ page }) => {
  await page.goto("/ops");
  await waitForLiveSocket(page);

  await page.getByTestId("preview-batch-button").click();
  await expect(page.getByTestId("batch-preview")).toBeVisible();
  await expect(page.getByTestId("batch-preview")).toContainText("owners");
});
