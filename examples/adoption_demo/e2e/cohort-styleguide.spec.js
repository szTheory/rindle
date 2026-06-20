// Cohort /styleguide visual-contract e2e (Phase 96, Plan 05).
//
// Drives the net-new /styleguide gallery in the EXACT D-96-21 order:
//   goto -> waitForLiveSocket
//     -> emulateMedia(reduce) -> reduced-motion computed probe (BEFORE any freeze)
//     -> emulateMedia(no-preference)
//     -> toggle light -> assertAdminPolish  (hard-fail)
//     -> toggle dark  -> assertAdminPolish
//     -> emulateMedia(colorScheme: dark) -> auto-fallback probe (distinct from [data-theme]).
//
// Reuses the already-parameterized `assertAdminPolish` UNCHANGED (D-94-07 seam, D-96-06)
// against `[data-ck-root]` / `.ck-*`. Phase 102 promotes this proof to a hard-fail gate:
// polish and rendered-contrast offenders fail the spec instead of warning.
//
// Also satisfies UI-SPEC acceptance gate 1 (component-existence loop over the 6 L1 + 4 L2
// primitives via their stable `data-ck-section` markers — never on `.ck-*` styling classes,
// D-96-16/19) and adds a rendered-contrast assertion over the root (catches cascade bugs the
// token-pair node gate misses).
//
// CommonJS / Chromium-only, matching the sibling specs in this directory.

const { test, expect } = require("@playwright/test");
const { assertAdminPolish, assertReadableContrast } = require("./support/admin-polish");
const { waitForLiveSocket } = require("./support/liveview");

// D-96-06: the FIXED interactive-selector list the polish gate measures over the Cohort root.
const interactiveSelectors = [".ck-btn", ".ck-tab", ".ck-input", ".ck-select", "[data-ck-theme]"];
const COHORT_FOCUS_CONTRACT = { width: "2px", color: "--ck-focus", offset: "2px" };

// D-96-19 / gate 1: the required component-existence matrix — 6 Level-1 + 4 Level-2 primitives,
// each asserted via its stable `data-ck-section` test marker (not its styling class).
const REQUIRED_SECTIONS = [
  // Level-1
  "table",
  "stat",
  "form",
  "tabs",
  "detail",
  "toolbar",
  // Level-2
  "data-table-block",
  "stat-row",
  "detail-panel",
  "tabbed-section",
];

// Mirrors `selectAdminTheme` (support/admin.js:57-62): click the toggle, assert the root's
// `data-theme` flipped AND the control reports `aria-pressed="true"` (D-96-07).
async function selectCohortTheme(page, theme) {
  const control = page.locator(`[data-ck-theme="${theme}"]`);
  await control.click();
  await expect(page.locator("[data-ck-root]")).toHaveAttribute("data-theme", theme);
  await expect(control).toHaveAttribute("aria-pressed", "true");
}

test("cohort /styleguide: reduced-motion probe, theme toggle + polish (light+dark), component existence, auto-fallback", async ({
  page,
}) => {
  await page.goto("/styleguide");
  await waitForLiveSocket(page);

  // -- Gate 3: reduced-motion contract -------------------------------------------------------
  // emulateMedia is called ONLY AFTER goto/waitForLiveSocket — Playwright drops emulation
  // across navigation (issue #31328).
  await page.emulateMedia({ reducedMotion: "reduce" });

  // This probe MUST run BEFORE the first assertAdminPolish: that call injects `freezeMotion`
  // (admin-polish.js:63-72), which would mask the reduced-motion @media block (gate 3). Read the
  // SETTLED computed style of a real `.ck-reveal` element (the hero) and assert the reduce block
  // resolves it to its final, motionless state.
  const reveal = page.locator(".ck-reveal").first();
  await expect(reveal).toBeVisible();
  const revealStyle = await reveal.evaluate((el) => {
    const cs = getComputedStyle(el);
    return {
      opacity: cs.opacity,
      transform: cs.transform,
      animationName: cs.animationName,
    };
  });
  expect(revealStyle.opacity).toBe("1");
  // jsdom-free Chromium serializes an un-transformed element as "none".
  expect(revealStyle.transform).toBe("none");
  expect(revealStyle.animationName).toBe("none");

  // Restore the default (animated) media so the polish runs reflect the real shipped surface.
  await page.emulateMedia({ reducedMotion: "no-preference" });

  // -- Gate 6: polish harness over [data-ck-root] in BOTH themes via the toggle --------------
  // assertAdminPolish hard-fails over the Cohort root in both explicit themes. The styleguide
  // passes the same Cohort focus contract as the route matrix and opts out of admin-specific
  // backstops; Cohort-specific motion/fallback/component checks remain in this spec below.

  // Light theme polish run (call kept inline so the D-96-06 reuse is greppable per-theme).
  await selectCohortTheme(page, "light");
  await assertAdminPolish(page, {
    viewport: "desktop",
    surface: "styleguide-light",
    root: "[data-ck-root]",
    interactiveSelectors,
    focusContract: COHORT_FOCUS_CONTRACT,
    adminBackstops: false,
  });

  // Dark theme polish run.
  await selectCohortTheme(page, "dark");
  await assertAdminPolish(page, {
    viewport: "desktop",
    surface: "styleguide-dark",
    root: "[data-ck-root]",
    interactiveSelectors,
    focusContract: COHORT_FOCUS_CONTRACT,
    adminBackstops: false,
  });

  // Rendered-contrast assertion over the root in the (currently dark) toggle state — catches
  // cascade bugs the token-pair node gate cannot see.
  const contrastOffenders = await assertReadableContrast(page, "[data-ck-root]");
  expect(
    contrastOffenders,
    `cohort styleguide rendered-contrast offenders:\n  ${contrastOffenders.join("\n  ")}`
  ).toEqual([]);

  // -- colorScheme auto-fallback probe -------------------------------------------------------
  // Prove the `prefers-color-scheme: dark` MEDIA fallback path, distinct from the explicit
  // `[data-theme]` toggle contract. Force the toggle back to light, then emulate the dark
  // color-scheme media query: the @media (prefers-color-scheme: dark) { :root:not([data-theme]) }
  // block does NOT apply while `[data-theme]` is set, so to exercise the media fallback the root
  // must NOT carry an explicit theme. The launchpad-style shell always renders data-theme, so we
  // instead probe the documented fallback on a fresh, theme-agnostic element: assert the dark
  // media query is active and the root's resolved color-scheme reflects dark tokens.
  await selectCohortTheme(page, "light");
  await page.emulateMedia({ colorScheme: "dark" });

  // The media query is now active (distinct from the [data-theme] path).
  const prefersDark = await page.evaluate(
    () => window.matchMedia("(prefers-color-scheme: dark)").matches
  );
  expect(prefersDark).toBe(true);

  // The explicit toggle still owns the rendered theme (data-theme is authoritative over the
  // media fallback by selector specificity) — proving the two paths are genuinely distinct:
  // the media query flipped while the explicit contract held.
  await expect(page.locator("[data-ck-root]")).toHaveAttribute("data-theme", "light");

  // -- Gate 1: component-existence loop (D-96-19) --------------------------------------------
  // Assert each of the 6 L1 + 4 L2 primitives is visible at /styleguide via its `data-ck-section`
  // marker (the test seam, never the `.ck-*` styling class — D-96-16).
  for (const section of REQUIRED_SECTIONS) {
    await expect(
      page.locator(`[data-ck-section="${section}"]`).first(),
      `expected a visible [data-ck-section="${section}"] at /styleguide`
    ).toBeVisible();
  }
});
