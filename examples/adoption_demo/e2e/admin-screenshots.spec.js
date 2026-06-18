const fs = require("node:fs");
const path = require("node:path");
const { test, expect } = require("@playwright/test");
const {
  visitAdmin,
  adminRoot,
  expectAdminShell,
  selectAdminTheme,
  firstAdminDetailHref,
  expectNoAdminRawSecrets,
  expectNoHorizontalScroll,
} = require("./support/admin");
const {
  assertAdminPolish,
  assertTwoPaneBand,
  assertStackedCard,
  assertReducedMotion,
  assertDialogInert,
  assertFocusVisibleVsPointer,
} = require("./support/admin-polish");
const { waitForLiveSocket } = require("./support/liveview");
const { MEMBERS, memberId } = require("./support/cohort");

const screenshotsDir = path.join(__dirname, "..", "test-results", "admin-screenshots");
const desktopCases = [
  { suffix: "", surface: "home-status", name: "home-status" },
  { suffix: "assets", surface: "assets", name: "assets" },
  { suffix: "assets", surface: "assets", name: "asset-detail", detail: "asset" },
  { suffix: "upload-sessions", surface: "upload-sessions", name: "upload-sessions" },
  {
    suffix: "upload-sessions",
    surface: "upload-sessions",
    name: "upload-session-detail",
    detail: "upload-session",
  },
  { suffix: "variants-jobs", surface: "variants-jobs", name: "variants-jobs" },
  { suffix: "runtime-doctor", surface: "runtime-doctor", name: "runtime-doctor" },
  { suffix: "actions", surface: "actions", name: "actions" },
  { suffix: "actions", surface: "actions", name: "actions-owner-preview", ownerPreview: true },
];
const mobileCases = [
  { suffix: "", surface: "home-status", name: "home-status" },
  { suffix: "actions", surface: "actions", name: "actions" },
];
const themes = ["light", "dark"];
const expectedScreenshots = [
  "light/home-status.png",
  "light/assets.png",
  "light/asset-detail.png",
  "light/upload-sessions.png",
  "light/upload-session-detail.png",
  "light/variants-jobs.png",
  "light/runtime-doctor.png",
  "light/actions.png",
  "light/actions-owner-preview.png",
  "dark/home-status.png",
  "dark/assets.png",
  "dark/asset-detail.png",
  "dark/upload-sessions.png",
  "dark/upload-session-detail.png",
  "dark/variants-jobs.png",
  "dark/runtime-doctor.png",
  "dark/actions.png",
  "dark/actions-owner-preview.png",
  "mobile/light/home-status.png",
  "mobile/light/actions.png",
  "mobile/dark/home-status.png",
  "mobile/dark/actions.png",
  // Phase 98 net-new band/stacked states (D-98-06, Pitfall 9): the §A<->§C 760-1023 two
  // -pane band and the <760 stacked-card flip are net-new VIEWPORT states that need their
  // own capture (the other backstops — reduced-motion / dialog-inert / focus-visible-vs
  // -pointer — are computed-style reads that RIDE existing captures, so they add no entry).
  "band/light/assets-760-1023.png",
  "stacked/light/assets-sub-760.png",
];

test.beforeAll(() => {
  fs.rmSync(screenshotsDir, { recursive: true, force: true });
  fs.mkdirSync(screenshotsDir, { recursive: true });
});

async function capture(page, theme, relativePath) {
  await selectAdminTheme(page, theme);
  await expectNoAdminRawSecrets(page);
  await expectNoHorizontalScroll(page);

  // Deterministic visual-polish gate: replaces the former human screenshot review by
  // asserting clipped text, contrast, target sizes, overlap, and stable dimensions on
  // the exact rendered state of every capture (all 22 surface/theme/viewport states).
  const surface = await adminRoot(page).getAttribute("data-rindle-admin-surface");
  const viewport = relativePath.startsWith("mobile/") ? "mobile" : "desktop";
  await assertAdminPolish(page, { viewport, surface });

  const outputPath = path.join(screenshotsDir, relativePath);
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  await page.screenshot({ path: outputPath, animations: "disabled", fullPage: true });
}

async function visitDetail(page, detailKind) {
  const href = await firstAdminDetailHref(page, detailKind);
  await page.goto(href);
  await waitForLiveSocket(page);
}

async function selectOwnerErasure(page) {
  await page.locator('[data-rindle-admin-action="owner_erasure"]').click();
  await expect(page.locator('[data-rindle-admin-action-panel="owner_erasure"]')).toBeVisible();
}

async function prepareOwnerPreview(page, ownerId) {
  await selectOwnerErasure(page);
  await page.locator('[data-rindle-admin-input="owner_type"]').fill("AdoptionDemo.Accounts.Member");
  await page.locator('[data-rindle-admin-input="owner_id"]').fill(ownerId);
  await page
    .locator('[data-rindle-admin-form="owner_erasure_preview"]')
    .evaluate((form) => form.requestSubmit());
  await expect(page.locator('[data-rindle-admin-preview="owner_erasure"]')).toBeVisible();
}

async function visitScreenshotCase(page, screenshotCase, ownerId) {
  await visitAdmin(page, screenshotCase.suffix);

  if (screenshotCase.detail) {
    await visitDetail(page, screenshotCase.detail);
  }

  if (screenshotCase.ownerPreview) {
    await prepareOwnerPreview(page, ownerId);
  }

  await expectAdminShell(page, screenshotCase.surface);
}

test("captures admin-screenshots light and dark matrix", async ({ page }) => {
  await page.goto("/dashboard");
  await waitForLiveSocket(page);
  const alexId = await memberId(page, MEMBERS.alex);

  await page.setViewportSize({ width: 1480, height: 900 });
  for (const theme of themes) {
    for (const screenshotCase of desktopCases) {
      await visitScreenshotCase(page, screenshotCase, alexId);
      await capture(page, theme, `${theme}/${screenshotCase.name}.png`);
    }
  }

  await page.setViewportSize({ width: 390, height: 900 });
  for (const theme of themes) {
    for (const screenshotCase of mobileCases) {
      await visitScreenshotCase(page, screenshotCase, alexId);
      await capture(page, theme, `mobile/${theme}/${screenshotCase.name}.png`);
    }
  }

  const missing = expectedScreenshots.filter(
    (relativePath) => !fs.existsSync(path.join(screenshotsDir, relativePath))
  );
  expect(missing, `missing screenshots: ${missing.join(", ")}`).toEqual([]);
  // Bumped 22 -> 24 in LOCKSTEP with the two net-new band/stacked viewport states above
  // (D-98-06, Pitfall 9 — deliberately, exactly as 97-04 bumped 10 -> 18). The length and
  // the expectedScreenshots array are changed together in the same commit.
  expect(expectedScreenshots).toHaveLength(24);
});

// Phase 98 — the five computed-style backstops at real viewports / focus-states / media
// (D-98-05/06, RESEARCH backstops 1-5). DialogInert + the per-state runner checks ride the
// matrix test above; this dedicated test drives the viewport/media/keyboard-vs-pointer
// states that the per-capture runner cannot (it mutates viewport + emulateMedia + focus).
// All checks are admin-root-only; no warn->fail flip, no Cohort generalization (Phase 102).
test("phase-98 computed-style backstops (band, stacked, reduced-motion, dialog, focus-visible)", async ({
  page,
}) => {
  await page.goto("/dashboard");
  await waitForLiveSocket(page);
  const alexId = await memberId(page, MEMBERS.alex);

  const fail = (label, offenders) =>
    expect(offenders, `${label} backstop offenders:\n  ${offenders.join("\n  ")}`).toEqual([]);

  // --- Backstop 1: two-pane track count + 760-1023 band (assets surface) ---
  await visitAdmin(page, "assets");
  await expectAdminShell(page, "assets");

  await page.setViewportSize({ width: 900, height: 900 }); // safe-inside the 760-1023 band
  fail("two-pane-band@900", await assertTwoPaneBand(page));
  await page.screenshot({
    path: path.join(screenshotsDir, "band/light/assets-760-1023.png"),
    animations: "disabled",
    fullPage: true,
  });

  await page.setViewportSize({ width: 1480, height: 900 }); // >=1024 two tracks (if :aside)
  fail("two-pane-band@1480", await assertTwoPaneBand(page));

  // --- Backstop 2: stacked card ::before attr() resolution + display flip ---
  await page.setViewportSize({ width: 759, height: 900 }); // <760 -> stacked label:value cards
  fail("stacked@759", await assertStackedCard(page));
  await page.screenshot({
    path: path.join(screenshotsDir, "stacked/light/assets-sub-760.png"),
    animations: "disabled",
    fullPage: true,
  });

  await page.setViewportSize({ width: 761, height: 900 }); // >=760 -> real <table>
  fail("stacked@761", await assertStackedCard(page));
  await page.setViewportSize({ width: 1025, height: 900 });
  fail("stacked@1025", await assertStackedCard(page));

  // --- Backstop 3: reduced-motion read UN-FROZEN (Pitfall 6) ---
  // A fresh navigation discards any injected freeze style; assertReducedMotion also
  // hard-fails if a freeze style is present, so the read can never pass vacuously.
  await page.setViewportSize({ width: 1480, height: 900 });
  await page.emulateMedia({ reducedMotion: "reduce" });
  await visitAdmin(page, "assets");
  await expectAdminShell(page, "assets");
  fail("reduced-motion@reduce", await assertReducedMotion(page, "reduce"));

  await page.emulateMedia({ reducedMotion: "no-preference" });
  await visitAdmin(page, "assets");
  await expectAdminShell(page, "assets");
  fail("reduced-motion@no-preference", await assertReducedMotion(page, "no-preference"));

  // --- Backstop 4: dialog inert open + reset-on-close + survives reconnect ---
  await visitAdmin(page, "actions");
  await expectAdminShell(page, "actions");
  // Closed baseline: main must NOT be inert.
  fail("dialog-closed-baseline", await assertDialogInert(page, { expectOpen: false }));

  // Open the owner-erasure preview dialog (server-assign-driven inert).
  await prepareOwnerPreview(page, alexId);
  fail("dialog-open", await assertDialogInert(page, { expectOpen: true }));

  // Reconnect with the dialog CLOSED: reload re-renders server state; main must NOT be left
  // inert (the D-98-11 landmine). A fresh visit re-renders dialog_open=false from the server.
  await visitAdmin(page, "actions");
  await expectAdminShell(page, "actions");
  fail("dialog-reset-on-reconnect", await assertDialogInert(page, { expectOpen: false }));

  // --- Backstop 5: focus-visible (keyboard) vs pointer differentiation ---
  fail("focus-visible-vs-pointer", await assertFocusVisibleVsPointer(page));
});
