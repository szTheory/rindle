// Rasterizes the derived brand assets (favicon PNGs, avatar) from their SVG
// sources at exact pixel sizes, then favicon.ico is assembled with ImageMagick:
//   magick ../assets/logo/favicon-32.png ../assets/logo/favicon-16.png ../assets/logo/favicon.ico
//
// Reuses the Playwright install from examples/adoption_demo.
// Run: node render-derived.mjs

import { createRequire } from 'node:module';
import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const { chromium } = require('/Users/jon/projects/rindle/examples/adoption_demo/node_modules/playwright');

const here = dirname(fileURLToPath(import.meta.url));
const LOGO = join(here, '..', 'assets', 'logo');
const browser = await chromium.launch();

async function raster(svg, size, out, transparent = true) {
  const html = `/tmp/rindle-raster-${size}.html`;
  writeFileSync(html, `<body style="margin:0"><img src="file://${svg}" width="${size}" height="${size}" style="display:block"></body>`);
  const page = await browser.newPage({ deviceScaleFactor: 1 });
  await page.setViewportSize({ width: size, height: size });
  await page.goto('file://' + html);
  await page.waitForTimeout(150);
  await page.screenshot({ path: out, omitBackground: transparent });
  await page.close();
}

await raster(join(LOGO, 'favicon.svg'), 16, join(LOGO, 'favicon-16.png'));
await raster(join(LOGO, 'favicon.svg'), 32, join(LOGO, 'favicon-32.png'));
await raster(join(LOGO, 'social-avatar.svg'), 512, join(LOGO, 'avatar-512.png'), false);
await browser.close();
console.log('derived rasters written to', LOGO);
