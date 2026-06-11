// Browser-checks the static Rindle Admin gallery and captures review screenshots.
// Run: node brandbook/src/admin-gallery-check.mjs

import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, rmSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, '..', '..');
const galleryPath = join(repoRoot, 'brandbook', 'admin-gallery', 'index.html');
const screenshotsDir = join(repoRoot, 'brandbook', 'admin-gallery', 'screenshots');
const adoptionRequire = createRequire(join(repoRoot, 'examples', 'adoption_demo', 'package.json'));
const { chromium } = adoptionRequire('playwright');

const runNode = (script) => {
  execFileSync(process.execPath, [join(repoRoot, script)], {
    cwd: repoRoot,
    stdio: 'inherit',
  });
};

runNode('brandbook/src/admin-css-build.mjs');
runNode('brandbook/src/admin-gallery.mjs');

const requiredComponents = [
  'shell',
  'nav',
  'table',
  'status-chips',
  'buttons',
  'theme-picker',
  'confirm-dialog',
  'drawer',
  'toasts',
  'empty-state',
  'skeletons',
];
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
];

const assert = (condition, message) => {
  if (!condition) throw new Error(message);
};

const assertVisible = async (page, selector) => {
  const locator = page.locator(selector);
  assert(await locator.count() > 0, `missing selector: ${selector}`);
  assert(await locator.first().isVisible(), `selector not visible: ${selector}`);
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
    .filter(({ ratio }) => ratio < 4.5);
  assert(
    failures.length === 0,
    `dark status chip contrast failures: ${failures.map(({ state, ratio }) => `${state} ${ratio.toFixed(2)}:1`).join(', ')}`,
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
  await page.locator(selector).screenshot({
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

  for (const component of requiredComponents) {
    await assertVisible(page, `[data-rindle-admin-component="${component}"]`);
  }
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
  await assertSecondaryButtonBorderColor(page);
  await assertGalleryHelperBorders(page);
  await screenshot(page, 'gallery-light-desktop.png');
  await elementScreenshot(page, '[data-rindle-admin-component="theme-picker"]', 'theme-picker-light.png');
  await elementScreenshot(page, '[data-rindle-admin-component="confirm-dialog"]', 'confirm-dialog-light.png');

  await selectTheme(page, 'dark');
  await assertDarkStatusChipContrast(page);
  await screenshot(page, 'gallery-dark-desktop.png');
  await elementScreenshot(page, '[data-rindle-admin-component="status-chips"]', 'status-chips-dark.png');

  await page.emulateMedia({ colorScheme: 'dark' });
  await selectTheme(page, 'auto');
  await screenshot(page, 'gallery-auto-desktop.png');

  await page.setViewportSize({ width: 390, height: 900 });
  await page.emulateMedia({ colorScheme: 'light' });
  await selectTheme(page, 'light');
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
