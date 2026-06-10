// Screenshot renderer for Rindle brand assets.
//
// Reuses the Playwright install from examples/adoption_demo (already a repo
// devDependency with Chromium downloaded) - no new dependencies.
//
// Usage:
//   node render.mjs <page.html> <out.png> [width] [height]
//     full-page screenshot of an HTML file (width default 1480)
//   node render.mjs --element <page.html> <selector> <out.png>
//     screenshot a single element

import { createRequire } from 'node:module';
import { resolve } from 'node:path';

const require = createRequire(import.meta.url);
const { chromium } = require('/Users/jon/projects/rindle/examples/adoption_demo/node_modules/playwright');

const args = process.argv.slice(2);

const run = async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ deviceScaleFactor: 2 });

  if (args[0] === '--element') {
    const [, html, selector, out] = args;
    await page.goto('file://' + resolve(html));
    await page.waitForTimeout(150);
    await page.locator(selector).screenshot({ path: out });
  } else {
    const [html, out, w, h] = args;
    await page.setViewportSize({ width: w ? parseInt(w, 10) : 1480, height: h ? parseInt(h, 10) : 900 });
    await page.goto('file://' + resolve(html));
    await page.waitForTimeout(150);
    await page.screenshot({ path: out, fullPage: !h });
  }

  await browser.close();
};

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
