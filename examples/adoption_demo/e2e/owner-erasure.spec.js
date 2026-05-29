const { test, expect } = require("@playwright/test");
const { waitForLiveSocket } = require("./support/liveview");

test("owner erasure preview and execute surfaces structured output", async ({ page }) => {
  await page.goto("/");
  await waitForLiveSocket(page);

  const opsRow = page.locator("#demo-users li").filter({ hasText: "Ops Operator" });
  await expect(opsRow).toBeVisible();
  const userId = (await opsRow.getAttribute("id")).replace("user-", "");

  await page.goto(`/account/${userId}/delete`);

  await page.locator("#preview-erasure-button").click();
  await expect(page.locator("#erasure-preview")).toBeVisible();

  await page.locator("#execute-erasure-button").click();
  await expect(page.locator("#erasure-result")).toBeVisible();
});
