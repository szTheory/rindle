// @ts-check
const path = require("node:path");
const { defineConfig, devices } = require("@playwright/test");

const port = process.env.ADOPTION_DEMO_BROWSER_PORT || "4102";
const baseURL = `http://localhost:${port}`;

module.exports = defineConfig({
  testDir: "./e2e",
  globalSetup: path.join(__dirname, "e2e/global-setup.js"),
  timeout: 120_000,
  expect: { timeout: 15_000 },
  fullyParallel: false,
  workers: 1,
  reporter: process.env.CI
    ? [["github"], ["html", { open: "never", outputFolder: "playwright-report" }]]
    : [["list"]],
  use: {
    baseURL,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },
  webServer: {
    command: `PORT=${port} PHX_SERVER=true MIX_ENV=test mix phx.server`,
    url: `${baseURL}/`,
    reuseExistingServer: process.env.ADOPTION_DEMO_REUSE_SERVER === "1",
    timeout: 180_000,
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
  outputDir: "test-results",
});
