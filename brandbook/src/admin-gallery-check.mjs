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
  await screenshot(page, 'gallery-light-desktop.png');
  await elementScreenshot(page, '[data-rindle-admin-component="theme-picker"]', 'theme-picker-light.png');
  await elementScreenshot(page, '[data-rindle-admin-component="confirm-dialog"]', 'confirm-dialog-light.png');

  await selectTheme(page, 'dark');
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
} finally {
  await browser.close();
}

const missing = expectedScreenshots.filter((name) => !existsSync(join(screenshotsDir, name)));
assert(missing.length === 0, `missing screenshots: ${missing.join(', ')}`);
console.log(`admin gallery check passed - ${expectedScreenshots.length} screenshots written`);
