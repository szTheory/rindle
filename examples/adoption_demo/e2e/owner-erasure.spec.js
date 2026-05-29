const { test, expect } = require("@playwright/test");
const { waitForLiveSocket } = require("./support/liveview");
const { MEMBERS, memberId } = require("./support/cohort");

test("owner erasure preview shows retained shared assets for Alex", async ({ page }) => {
  await page.goto("/");
  await waitForLiveSocket(page);

  const alexId = await memberId(page, MEMBERS.alex);
  await page.goto(`/account/${alexId}/delete`);
  await waitForLiveSocket(page);

  await page.getByTestId("preview-erasure-button").click();
  const preview = page.getByTestId("erasure-preview");
  await expect(preview).toBeVisible();
  await expect(preview).toContainText("retained_shared_assets");
});

test("owner erasure execute on ops operator", async ({ page }) => {
  await page.goto("/");
  await waitForLiveSocket(page);

  const opsId = await memberId(page, MEMBERS.ops);
  await page.goto(`/account/${opsId}/delete`);
  await waitForLiveSocket(page);

  await page.getByTestId("preview-erasure-button").click();
  await expect(page.getByTestId("erasure-preview")).toBeVisible();

  await page.getByTestId("execute-erasure-button").click();
  await expect(page.getByTestId("erasure-result")).toBeVisible();
});
