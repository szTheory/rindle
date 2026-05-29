const { test, expect } = require("@playwright/test");
const path = require("node:path");
const { waitForLiveSocket } = require("./support/liveview");
const { MEMBERS, memberRow } = require("./support/cohort");

test("replace and detach avatar controls update status", async ({ page }) => {
  await page.goto("/");
  await waitForLiveSocket(page);

  const alexRow = await memberRow(page, MEMBERS.alex);
  await alexRow.getByTestId("member-avatar-link").click();
  await expect(page.getByTestId("member-profile-title")).toContainText("Alex");

  await page.getByTestId("replace-avatar-button").click();
  await expect(page.getByTestId("replace-status")).toContainText("replaced:", {
    timeout: 60_000,
  });

  await page.getByTestId("detach-avatar-button").click();
  await expect(page.getByTestId("replace-status")).toContainText("detached");
});
