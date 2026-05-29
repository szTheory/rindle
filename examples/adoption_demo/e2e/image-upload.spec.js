const { test, expect } = require("@playwright/test");
const path = require("node:path");
const { waitForLiveSocket } = require("./support/liveview");

test("presigned PUT avatar upload attaches and shows ready", async ({ page }) => {
  await page.goto("/");
  await waitForLiveSocket(page);

  const bobRow = page.locator("#demo-users li").filter({ hasText: "Bob Globex" });
  await expect(bobRow).toBeVisible();

  await bobRow.getByRole("link", { name: "upload" }).click();
  await expect(page.locator("#upload-user-name")).toContainText("Bob");

  const fixture = path.join(__dirname, "..", "priv", "fixtures", "avatar.png");
  await page.locator("#image-file-input").setInputFiles(fixture);

  await expect(page.locator("#image-upload-status")).toContainText("ready", {
    timeout: 60_000,
  });
  await expect(page.locator("#image-upload-asset-id")).toBeVisible();
});
