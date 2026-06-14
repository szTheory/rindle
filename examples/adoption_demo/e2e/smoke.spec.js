const { test, expect } = require("@playwright/test");
const { waitForLiveSocket } = require("./support/liveview");

// Cold-start smoke (native path): the e2e CI job boots the demo from scratch —
// ecto.drop -> create -> migrate -> rindle.migrate -> seeds — before any spec
// runs. This asserts that a from-scratch boot serves the launchpad homepage with
// live data, catching startup/seed regressions that only surface on a fresh start.
test("homepage loads the Cohort launchpad after a cold boot", async ({ page }) => {
  await page.goto("/");
  await waitForLiveSocket(page);

  // Brand mark + the launchpad's primary prompt prove the page rendered live.
  await expect(page.locator(".ck-nav__brand")).toBeVisible();
  await expect(page.getByText("What do you want to do?")).toBeVisible();

  // Seeded credentials are surfaced inline — proof the seed step completed.
  await expect(page.getByText("minioadmin").first()).toBeVisible();
});
