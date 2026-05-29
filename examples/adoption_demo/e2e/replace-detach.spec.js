const { test, expect } = require("@playwright/test");
const path = require("node:path");
const { waitForLiveSocket } = require("./support/liveview");

test("replace and detach avatar controls update status", async ({ page }) => {
  await page.goto("/");
  await waitForLiveSocket(page);

  const aliceRow = page.locator("#demo-users li").filter({ hasText: "Alice Acme" });
  await aliceRow.getByRole("link", { name: "upload" }).click();
  await expect(page.locator("#upload-user-name")).toContainText("Alice");

  const fixture = path.join(__dirname, "..", "priv", "fixtures", "avatar.png");
  await page.locator("#image-file-input").setInputFiles(fixture);
  await expect(page.locator("#image-upload-status")).toContainText("ready", {
    timeout: 60_000,
  });

  await page.goto("/");
  await aliceRow.getByRole("link", { name: "attached" }).click();

  await page.locator("#replace-avatar-button").click();
  await expect(page.locator("#replace-status")).toContainText("replaced:", {
    timeout: 60_000,
  });

  await page.locator("#detach-avatar-button").click();
  await expect(page.locator("#replace-status")).toContainText("detached");
});
