const { test, expect } = require("@playwright/test");

test.skip(
  process.env.RINDLE_GCS_LIVE !== "1",
  "secret-gated: set RINDLE_GCS_LIVE=1 with GOOGLE_APPLICATION_CREDENTIALS_JSON + RINDLE_GCS_BUCKET"
);

test("GCS resumable upload browser path (live provider)", async () => {
  test.fixme(true, "wire demo host to Rindle.Storage.GCS when live secrets are present");
  await expect(true).toBeTruthy();
});
