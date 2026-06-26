// Browser-checks the static Rindle Admin gallery and captures review screenshots.
// Run: node brandbook/src/admin-gallery-check.mjs

import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, rmSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

import { WCAG_AA_NORMAL } from './contrast-constants.mjs';
import { META_COMPONENTS } from './admin-design-system-data.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, '..', '..');
const galleryPath = join(repoRoot, 'brandbook', 'admin-gallery', 'index.html');
// Gallery screenshots are non-blocking audit/reference artifacts; the hard gate is the
// DOM/computed-style assertions in this script, not pixel diffs against these PNGs.
const screenshotsDir = join(repoRoot, 'brandbook', 'admin-gallery', 'screenshots');
const adoptionRequire = createRequire(join(repoRoot, 'examples', 'adoption_demo', 'package.json'));
const { chromium } = adoptionRequire('playwright');
// The two Level-2 cohesion checks live in the adoption_demo CommonJS polish module;
// load them through the SAME createRequire used for playwright (the gallery meta units
// are the surface where [data-rindle-admin-meta] actually exists, so this is the real
// proof that intra-unit rhythm is on-grid and no unit root overflows horizontally).
const { assertConsistentRhythm, assertNoHorizontalScroll } = adoptionRequire(
  join(repoRoot, 'examples', 'adoption_demo', 'e2e', 'support', 'admin-polish.js'),
);

const runNode = (script) => {
  execFileSync(process.execPath, [join(repoRoot, script)], {
    cwd: repoRoot,
    stdio: 'inherit',
  });
};

runNode('brandbook/src/admin-css-build.mjs');
runNode('brandbook/src/admin-gallery.mjs');

const requiredComponentStateMatrix = {
  shell: ['default'],
  nav: ['default', 'hover', 'focus-visible', 'active'],
  table: ['default', 'hover', 'focus-visible', 'empty', 'loading', 'skeleton'],
  'status-chip': ['default', 'error'],
  button: ['default', 'hover', 'focus-visible', 'active', 'disabled', 'loading'],
  'theme-picker': ['default', 'hover', 'focus-visible', 'active'],
  'form-controls': ['default', 'hover', 'focus-visible', 'disabled', 'error'],
  'confirm-dialog': ['default', 'focus-visible', 'disabled', 'error'],
  drawer: ['default'],
  toast: ['default', 'error'],
  'empty-state': ['empty'],
  'error-state': ['error'],
  'loading-state': ['loading'],
  skeleton: ['skeleton'],
};
const requiredGlobalStates = ['default', 'hover', 'focus-visible', 'active', 'disabled', 'loading', 'empty', 'error', 'skeleton'];
const requiredSectionIds = [
  'home-status',
  'assets',
  'upload-sessions',
  'variants-jobs',
  'runtime-doctor',
  'actions',
];
const forbiddenClassParts = [
  'btn',
  'card',
  'dark',
  `theme-${'dark'}`,
  `tail${'wind'}`,
  `dai${'sy'}`,
  `shad${'cn'}`,
  `ra${'dix'}`,
];
const expectedScreenshots = [
  'gallery-light-desktop.png',
  'gallery-dark-desktop.png',
  'gallery-auto-desktop.png',
  'gallery-light-mobile.png',
  'status-chips-dark.png',
  'theme-picker-light.png',
  'confirm-dialog-light.png',
  'form-controls-light.png',
  'error-state-dark.png',
  'loading-state-auto.png',
  // Level-2 meta-component element screenshots (one per META_COMPONENTS unit, 10 -> 18).
  'meta-toolbar-light.png',
  'meta-data-table-light.png',
  'meta-filter-bar-light.png',
  'meta-action-panel-light.png',
  'meta-detail-drilldown-light.png',
  'meta-confirm-panel-light.png',
  'meta-drawer-light.png',
  'meta-toast-stack-light.png',
];

const assert = (condition, message) => {
  if (!condition) throw new Error(message);
};

const assertVisible = async (page, selector) => {
  const locator = page.locator(selector);
  assert(await locator.count() > 0, `missing selector: ${selector}`);
  assert(await locator.first().isVisible(), `selector not visible: ${selector}`);
};

const assertComponentStateMatrix = async (page) => {
  for (const [component, states] of Object.entries(requiredComponentStateMatrix)) {
    for (const state of states) {
      await assertVisible(page, `[data-rindle-admin-component="${component}"][data-rindle-admin-state="${state}"]`);
    }
  }
  for (const state of requiredGlobalStates) {
    await assertVisible(page, `[data-rindle-admin-state="${state}"]`);
  }
};

const assertMetaUnits = async (page) => {
  for (const slug of META_COMPONENTS) {
    await assertVisible(page, `[data-rindle-admin-meta="${slug}"]`);
  }
};

const assertMetaCohesion = async (page) => {
  // Guard against a vacuous pass: confirm the polish checks have real meta units to
  // walk under the gallery root before trusting a zero-offender result.
  const unitCount = await page.locator('[data-rindle-admin-root] [data-rindle-admin-meta]').count();
  assert(unitCount === META_COMPONENTS.length, `expected ${META_COMPONENTS.length} meta units under the gallery root, found ${unitCount}`);

  const rhythmOffenders = await assertConsistentRhythm(page);
  assert(rhythmOffenders.length === 0, `off-grid intra-unit spacing: ${rhythmOffenders.join('; ')}`);

  const scrollOffenders = await assertNoHorizontalScroll(page);
  assert(scrollOffenders.length === 0, `meta unit horizontal overflow: ${scrollOffenders.join('; ')}`);
};

const assertMetaNoLeakage = async (page) => {
  const unknown = await page.evaluate(() => {
    return Array.from(document.querySelectorAll('[data-rindle-admin-meta] [class]'))
      .flatMap((element) => Array.from(element.classList))
      .filter((className) => !className.startsWith('rindle-admin-'));
  });
  assert(unknown.length === 0, `meta units leak non-rindle classes: ${unknown.join(', ')}`);
};

const assertNoBareOutlineNone = () => {
  const css = readFileSync(join(repoRoot, 'brandbook', 'tokens', 'rindle-admin.css'), 'utf8');
  const html = readFileSync(galleryPath, 'utf8');
  const stripCssComments = (text) => text.replace(/\/\*[\s\S]*?\*\//g, '');
  assert(!/outline\s*:\s*none\b/.test(stripCssComments(css)), 'generated admin CSS contains bare outline:none');
  assert(!/outline\s*:\s*none\b/.test(stripCssComments(html)), 'generated gallery HTML contains bare outline:none');
};

const sameColor = (a, b) => {
  const aa = parseColor(a);
  const bb = parseColor(b);
  return aa.every((value, index) => Math.abs(value - bb[index]) <= 1);
};

const assertFocusVisibleTokens = async (page) => {
  const selectors = [
    '.rindle-admin-button',
    '[data-rindle-admin-nav-item]',
    '[data-rindle-admin-theme]',
    '[data-rindle-admin-input]',
    '[data-rindle-admin-confirm-input]',
    '.rindle-admin-table__row',
  ];
  // Enter keyboard modality before measuring. `:focus-visible` does not reliably match
  // programmatic `.focus()` in headless Chromium unless the page has seen a keyboard
  // interaction — and `focusVisible: true` honouring varies across Chromium builds. A real
  // Tab press flips Chromium into keyboard-focus mode so the subsequent programmatic focuses
  // deterministically match `:focus-visible` (fixes an intermittent "outline 0px" CI flake).
  await page.keyboard.press('Tab');

  const failures = [];
  for (const selector of selectors) {
    const locator = page.locator(selector).first();
    await locator.evaluate((element) => element.focus({ focusVisible: true }));
    const state = await locator.evaluate((element) => {
      const styles = getComputedStyle(element);
      const rootStyles = getComputedStyle(document.documentElement);
      return {
        selector: element.matches('[data-rindle-admin-theme]') ? '[data-rindle-admin-theme]' : element.tagName.toLowerCase(),
        outlineWidth: styles.outlineWidth,
        outlineColor: styles.outlineColor,
        outlineOffset: styles.outlineOffset,
        expectedWidth: rootStyles.getPropertyValue('--rindle-focus-width').trim(),
        expectedColor: rootStyles.getPropertyValue('--rindle-focus-ring').trim(),
        expectedOffset: rootStyles.getPropertyValue('--rindle-focus-offset').trim(),
      };
    });
    if (state.outlineWidth !== state.expectedWidth) failures.push(`${selector} outlineWidth ${state.outlineWidth} != ${state.expectedWidth}`);
    if (state.outlineOffset !== state.expectedOffset) failures.push(`${selector} outlineOffset ${state.outlineOffset} != ${state.expectedOffset}`);
    if (!sameColor(state.outlineColor, state.expectedColor)) failures.push(`${selector} outlineColor ${state.outlineColor} != ${state.expectedColor}`);
  }
  assert(failures.length === 0, `focus-visible token failures: ${failures.join('; ')}`);
};

const assertActiveDistinctFromFocus = async (page) => {
  const navState = await page.evaluate(() => {
    const current = document.querySelector('.rindle-admin-nav__item[aria-current="page"]');
    const other = document.querySelector('.rindle-admin-nav__item:not([aria-current="page"])');
    const theme = document.querySelector('[data-rindle-admin-theme][aria-pressed="true"]');
    const root = getComputedStyle(document.documentElement);
    return {
      currentBg: getComputedStyle(current).backgroundColor,
      otherBg: getComputedStyle(other).backgroundColor,
      currentOutline: getComputedStyle(current).outlineStyle,
      themeBg: getComputedStyle(theme).backgroundColor,
      themeOutline: getComputedStyle(theme).outlineStyle,
      brand: root.getPropertyValue('--rindle-brand').trim(),
    };
  });
  assert(navState.currentBg !== navState.otherBg, 'current nav item background must differ from non-current nav item');
  assert(navState.currentOutline === 'none', `current nav active state must not rely on outline, got ${navState.currentOutline}`);
  assert(sameColor(navState.themeBg, navState.brand), `pressed theme option background ${navState.themeBg} must match brand ${navState.brand}`);
  assert(navState.themeOutline === 'none', `pressed theme active state must not rely on outline, got ${navState.themeOutline}`);
};

const assertDisabledAndLoadingAffordances = async (page) => {
  const disabled = await page.locator('[data-rindle-admin-component="button"][data-rindle-admin-state="disabled"]').evaluate((button) => ({
    disabled: button.disabled,
    ariaDisabled: button.getAttribute('aria-disabled'),
    cursor: getComputedStyle(button).cursor,
  }));
  assert(disabled.disabled || disabled.ariaDisabled === 'true', 'disabled button fixture must be disabled or aria-disabled');
  assert(disabled.cursor === 'not-allowed', `disabled button cursor must be not-allowed, got ${disabled.cursor}`);
  await assertVisible(page, '[data-rindle-admin-component="button"][data-rindle-admin-state="loading"]');
  await assertVisible(page, '[data-rindle-admin-component="loading-state"][data-rindle-admin-state="loading"]');
};

const assertHashTarget = async (page, id) => {
  await page.waitForFunction((targetId) => window.location.hash === `#${targetId}`, id);
  await assertVisible(page, `#${id}`);
  const targetState = await page.locator(`#${id}`).evaluate((element) => {
    const rect = element.getBoundingClientRect();
    return {
      top: rect.top,
      bottom: rect.bottom,
      viewportHeight: window.innerHeight,
      scrollY: window.scrollY,
      currentHref: document.querySelector('.rindle-admin-nav__item[aria-current="page"]')?.getAttribute('href'),
    };
  });
  assert(targetState.scrollY > 0, `expected #${id} navigation to move the scroll position`);
  assert(targetState.top < targetState.viewportHeight - 80, `expected #${id} target to enter the viewport, got ${targetState.top}`);
  assert(targetState.bottom > 0, `expected #${id} target to be visible`);
  assert(targetState.currentHref === `#${id}`, `expected current nav href #${id}, got ${targetState.currentHref}`);
};

const luminance = ([r, g, b]) => {
  const [rr, gg, bb] = [r, g, b].map((value) => {
    const channel = value / 255;
    return channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4);
  });
  return 0.2126 * rr + 0.7152 * gg + 0.0722 * bb;
};

const contrastRatio = (a, b) => {
  const [l1, l2] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (l1 + 0.05) / (l2 + 0.05);
};

const parseColor = (value) => {
  const color = value.trim();
  const hex = color.match(/^#([0-9a-f]{6})$/i);
  if (hex) {
    return [0, 2, 4].map((offset) => parseInt(hex[1].slice(offset, offset + 2), 16));
  }
  const rgb = color.match(/^rgba?\((\d+),\s*(\d+),\s*(\d+)/);
  if (rgb) return rgb.slice(1, 4).map(Number);
  throw new Error(`could not parse computed color: ${value}`);
};

const assertDarkStatusChipContrast = async (page) => {
  const chips = await page.locator('.rindle-admin-status-chip').evaluateAll((elements) => {
    return elements.map((chip) => {
      const styles = getComputedStyle(chip);
      return {
        state: chip.getAttribute('data-rindle-admin-state') || chip.textContent.trim(),
        color: styles.color,
        backgroundColor: styles.backgroundColor,
      };
    });
  });
  const failures = chips
    .map((chip) => ({
      state: chip.state,
      ratio: contrastRatio(parseColor(chip.color), parseColor(chip.backgroundColor)),
    }))
    .filter(({ ratio }) => ratio < WCAG_AA_NORMAL);
  assert(
    failures.length === 0,
    `dark status chip contrast failures: ${failures.map(({ state, ratio }) => `${state} ${ratio.toFixed(2)}:1`).join(', ')}`,
  );
};

const assertAutoDarkDrawerMatchesExplicitDark = async (page) => {
  const drawerSelector = '[data-rindle-admin-component="drawer"].rindle-admin-drawer';
  await page.emulateMedia({ colorScheme: 'dark' });
  await selectTheme(page, 'dark');
  const dark = await page.locator(drawerSelector).first().evaluate((element) => getComputedStyle(element).backgroundColor);
  await selectTheme(page, 'auto');
  assert(
    (await page.locator(drawerSelector).count()) === 1,
    `expected exactly one Level-1 drawer fixture for auto-dark parity check: ${drawerSelector}`,
  );
  const auto = await page.locator(drawerSelector).first().evaluate((element) => getComputedStyle(element).backgroundColor);
  assert(
    dark === auto,
    `auto dark drawer background mismatch: ${drawerSelector} dark=${dark} auto=${auto}`,
  );
};

const assertSecondaryButtonBorderColor = async (page) => {
  const borderState = await page.locator('.rindle-admin-button--secondary').first().evaluate((button) => {
    const rootStyles = getComputedStyle(document.documentElement);
    const buttonStyles = getComputedStyle(button);
    return {
      expected: rootStyles.getPropertyValue('--rindle-border-strong').trim(),
      actual: buttonStyles.borderTopColor,
    };
  });
  const expected = parseColor(borderState.expected);
  const actual = parseColor(borderState.actual);
  assert(
    expected.every((value, index) => value === actual[index]),
    `expected secondary button border ${borderState.expected}, got ${borderState.actual}`,
  );
};

const assertGalleryHelperBorders = async (page) => {
  const failures = [];
  for (const selector of ['.rindle-admin-gallery__panel', '.rindle-admin-gallery__input']) {
    const border = await page.locator(selector).first().evaluate((element) => {
      const styles = getComputedStyle(element);
      return {
        width: styles.borderTopWidth,
        style: styles.borderTopStyle,
      };
    });
    if (border.width === '0px' || border.style === 'none') {
      failures.push(`${selector} ${border.width} ${border.style}`);
    }
  }
  assert(failures.length === 0, `gallery helper borders are not rendered: ${failures.join(', ')}`);
};

const assertMobileTableBehavior = async (page) => {
  const stickySelector = '.rindle-admin-table--sticky .rindle-admin-table';
  assert(
    (await page.locator(stickySelector).count()) > 0,
    `missing sticky table for mobile assertion: ${stickySelector}`,
  );

  const stickyDisplay = await page.locator(stickySelector).first().evaluate((table) => {
    const tbody = table.querySelector('tbody');
    const row = table.querySelector('tbody tr');
    const cell = table.querySelector('tbody td');
    return {
      table: getComputedStyle(table).display,
      tbody: tbody ? getComputedStyle(tbody).display : null,
      tr: row ? getComputedStyle(row).display : null,
      td: cell ? getComputedStyle(cell).display : null,
    };
  });
  const expected = {
    table: 'table',
    tbody: 'table-row-group',
    tr: 'table-row',
    td: 'table-cell',
  };
  const displayFailures = Object.entries(expected)
    .filter(([key, value]) => stickyDisplay[key] !== value)
    .map(([key, value]) => `${key} ${stickyDisplay[key]} != ${value}`);
  assert(
    displayFailures.length === 0,
    `mobile sticky table display failures: ${displayFailures.join('; ')}`,
  );

  const labelFailures = await page.evaluate(() => {
    const cells = Array.from(document.querySelectorAll('td.rindle-admin-table__cell'))
      .filter((cell) => !cell.closest('.rindle-admin-table--sticky'));
    return {
      count: cells.length,
      failures: cells
        .filter((cell) => !(cell.getAttribute('data-label') || '').trim())
        .map((cell, index) => {
          const row = cell.closest('tr');
          const rowText = row ? row.textContent.trim().replace(/\s+/g, ' ') : '';
          const cellText = cell.textContent.trim().replace(/\s+/g, ' ');
          return `cell ${index + 1}: text="${cellText}" row="${rowText}"`;
        }),
    };
  });
  assert(labelFailures.count > 0, 'expected at least one non-sticky table cell for stacked-label assertion');
  assert(
    labelFailures.failures.length === 0,
    `non-sticky stacked table cells missing data-label: ${labelFailures.failures.join('; ')}`,
  );
};

const selectTheme = async (page, theme) => {
  await page.locator(`[data-rindle-admin-theme="${theme}"]`).click();
  const current = await page.evaluate(() => document.documentElement.getAttribute('data-theme'));
  assert(current === theme, `expected data-theme ${theme}, got ${current}`);
};

const screenshot = async (page, name, options = {}) => {
  await page.screenshot({
    path: join(screenshotsDir, name),
    animations: 'disabled',
    fullPage: options.fullPage ?? true,
  });
};

const elementScreenshot = async (page, selector, name) => {
  await page.locator(selector).first().screenshot({
    path: join(screenshotsDir, name),
    animations: 'disabled',
  });
};

rmSync(screenshotsDir, { recursive: true, force: true });
mkdirSync(screenshotsDir, { recursive: true });

const browser = await chromium.launch();

try {
  const page = await browser.newPage({
    deviceScaleFactor: 2,
    viewport: { width: 1480, height: 900 },
  });
  await page.goto(pathToFileURL(galleryPath).href);

  assertNoBareOutlineNone();
  await assertComponentStateMatrix(page);
  await assertMetaUnits(page);
  await assertMetaNoLeakage(page);
  for (const id of requiredSectionIds) {
    await assertVisible(page, `#${id}`);
    assert(await page.locator(`.rindle-admin-nav__item[href="#${id}"]`).count() === 1, `missing nav link for #${id}`);
  }

  const leakedClasses = await page.evaluate((forbidden) => {
    return Array.from(document.querySelectorAll('[class]'))
      .flatMap((element) => Array.from(element.classList))
      .filter((className) => forbidden.some((part) => className.includes(part)));
  }, forbiddenClassParts);
  assert(leakedClasses.length === 0, `forbidden class names found: ${leakedClasses.join(', ')}`);

  const confirmAction = page.locator('[data-rindle-admin-confirm-action]');
  const confirmInput = page.locator('[data-rindle-admin-confirm-input]');
  assert(await confirmAction.isDisabled(), 'confirm action must start disabled');
  await confirmInput.fill('owner:cohort-demo-42');
  assert(await confirmAction.isEnabled(), 'confirm action must enable after owner confirmation matches');

  await selectTheme(page, 'light');
  await assertMetaUnits(page);
  await assertMetaCohesion(page);
  await assertSecondaryButtonBorderColor(page);
  await assertGalleryHelperBorders(page);
  await assertFocusVisibleTokens(page);
  await assertActiveDistinctFromFocus(page);
  await assertDisabledAndLoadingAffordances(page);
  await screenshot(page, 'gallery-light-desktop.png');
  await elementScreenshot(page, '[data-rindle-admin-component="theme-picker"]', 'theme-picker-light.png');
  await elementScreenshot(page, '[data-rindle-admin-component="confirm-dialog"]', 'confirm-dialog-light.png');
  await elementScreenshot(page, '[data-rindle-admin-component="form-controls"]', 'form-controls-light.png');
  // One element screenshot per Level-2 meta-component unit (10 -> 18).
  for (const slug of META_COMPONENTS) {
    await elementScreenshot(page, `[data-rindle-admin-meta="${slug}"]`, `meta-${slug}-light.png`);
  }

  await selectTheme(page, 'dark');
  await assertMetaUnits(page);
  await assertDarkStatusChipContrast(page);
  await screenshot(page, 'gallery-dark-desktop.png');
  await elementScreenshot(page, '[data-rindle-admin-component="status-chip"]', 'status-chips-dark.png');
  await elementScreenshot(page, '[data-rindle-admin-component="error-state"]', 'error-state-dark.png');

  await page.emulateMedia({ colorScheme: 'dark' });
  await selectTheme(page, 'auto');
  await assertMetaUnits(page);
  await assertAutoDarkDrawerMatchesExplicitDark(page);
  await screenshot(page, 'gallery-auto-desktop.png');
  await elementScreenshot(page, '[data-rindle-admin-component="loading-state"]', 'loading-state-auto.png');

  await page.setViewportSize({ width: 390, height: 900 });
  await page.emulateMedia({ colorScheme: 'light' });
  await selectTheme(page, 'light');
  await assertMobileTableBehavior(page);
  await screenshot(page, 'gallery-light-mobile.png');

  await page.close();

  const deepLinkPage = await browser.newPage({
    deviceScaleFactor: 2,
    viewport: { width: 1480, height: 900 },
  });
  await deepLinkPage.goto(`${pathToFileURL(galleryPath).href}#assets`);
  await assertHashTarget(deepLinkPage, 'assets');
  await deepLinkPage.close();

  const navClickPage = await browser.newPage({
    deviceScaleFactor: 2,
    viewport: { width: 1480, height: 900 },
  });
  await navClickPage.goto(pathToFileURL(galleryPath).href);
  await navClickPage.locator('.rindle-admin-nav__item[href="#actions"]').click();
  await assertHashTarget(navClickPage, 'actions');
  await navClickPage.close();
} finally {
  await browser.close();
}

const missing = expectedScreenshots.filter((name) => !existsSync(join(screenshotsDir, name)));
assert(missing.length === 0, `missing screenshots: ${missing.join(', ')}`);
console.log(`admin gallery check passed - ${expectedScreenshots.length} screenshots written`);
