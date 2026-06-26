const { test, expect } = require("@playwright/test");
const { waitForLiveSocket } = require("./support/liveview");

// Regression guard for the split-horizon presign endpoint (RINDLE_MINIO_PUBLIC_URL /
// Rindle.Storage.S3 :public_endpoint). A community-post image is served by a browser-facing S3
// presigned URL. The Docker demo previously signed it for `host.docker.internal:<port>`, which
// the host browser cannot resolve, so the <img> silently failed to load even though the asset
// was healthy and `ready`.
//
// `.toBeVisible()` does NOT catch this — a broken <img> element is still "visible" in the DOM —
// so this spec asserts the image actually DECODED (naturalWidth > 0) and that no <img src> on
// the page points at the container-only alias. Walks every seeded post and exercises the ones
// that carry an image, proving at least one image-bearing post actually rendered.
test("post images load over a browser-reachable presigned URL (no host.docker.internal)", async ({
  page,
}) => {
  await page.goto("/dashboard");
  await waitForLiveSocket(page);

  const hrefs = await page
    .locator('[data-testid^="post-link-"]')
    .evaluateAll((links) => links.map((a) => a.getAttribute("href")));

  expect(hrefs.length).toBeGreaterThan(0);

  let postsWithImage = 0;

  for (const href of hrefs) {
    await page.goto(href);
    await waitForLiveSocket(page);

    const pic = page.getByTestId("post-picture-tag");
    if ((await pic.count()) === 0) {
      // Post with no attached image renders the empty state — nothing to assert here.
      continue;
    }

    postsWithImage += 1;

    const img = pic.locator("img");
    await expect(img).toBeVisible();

    // The image must actually DECODE, not merely exist in the DOM.
    await expect
      .poll(async () => img.evaluate((el) => el.complete && el.naturalWidth > 0), {
        timeout: 30_000,
      })
      .toBe(true);

    // No <img> on the page may point at the container-only alias the host can't resolve.
    const srcs = await page
      .locator("img")
      .evaluateAll((imgs) => imgs.map((i) => i.currentSrc || i.src));
    for (const src of srcs) {
      expect(src).not.toContain("host.docker.internal");
    }
  }

  // Prove the guard actually exercised an image-bearing post (the seeded community post),
  // so a seed change that drops post images can't quietly turn this into a no-op.
  expect(postsWithImage).toBeGreaterThan(0);
});
