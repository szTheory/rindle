const { test, expect } = require("@playwright/test");
const { waitForLiveSocket } = require("./support/liveview");

test("member picture_tag and lesson video_tag render on seeded Cohort data", async ({ page }) => {
  await page.goto("/dashboard");
  await waitForLiveSocket(page);

  await page.getByRole("link", { name: "Pattern matching basics" }).first().click();
  await expect(page.getByTestId("lesson-title")).toBeVisible();
  await expect(page.getByTestId("lesson-video-tag")).toBeVisible();
  await expect(page.getByTestId("lesson-asset-state")).toContainText("ready", {
    timeout: 30_000,
  });
  await expect(page.getByTestId("variant-poster")).toBeVisible();
  await expect(page.getByTestId("variant-web_720p")).toBeVisible();

  await page.goto("/dashboard");
  await waitForLiveSocket(page);

  await page.getByTestId("member-row-alex@cohort.test").getByTestId("member-avatar-link").click();
  await expect(page.getByTestId("member-picture-tag")).toBeVisible();
  await expect(page.getByTestId("member-picture-tag").locator("img")).toBeVisible();
});
