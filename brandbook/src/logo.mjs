// Final Rindle logo system - built from the locked direction:
// Confluence e1 (D-b1.0-04/05): green entering tributary, Deep Current merged
// stroke, under-run ending below the i.
//
// Writes to ../assets/logo/:
//   rindle-logo.svg            primary lockup (light surfaces)
//   rindle-logo-dark.svg       dark-surface lockup
//   rindle-logo-mono.svg       one-color (currentColor) lockup
//   rindle-logo-subtitle.svg   the ONLY variant carrying the tagline
//   rindle-mark.svg            icon-only mark (light)
//   rindle-mark-dark.svg       icon-only mark (dark)
//   rindle-mark-mono.svg       one-color mark
//   favicon.svg                simplified two-tributary cut, dark-mode aware
//   social-avatar.svg          512-square avatar source (Deep Current surface)
//
// Run: node logo.mjs

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import opentype from 'opentype.js';
import { PALETTE, FONT_SIZE, PAD, svgDoc, r2 } from './geometry.mjs';
import { confluence } from './candidates.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const outDir = join(here, '..', 'assets', 'logo');
mkdirSync(outDir, { recursive: true });

function loadFont(file) {
  const buf = readFileSync(join(here, 'fonts', file));
  return opentype.parse(buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength));
}
const grotesk = loadFont('SpaceGrotesk-Medium.ttf');
const atkinson = loadFont('AtkinsonHyperlegible-Regular.ttf');

function contours(commands) {
  const out = [];
  let cur = [];
  for (const c of commands) {
    if (c.type === 'M' && cur.length) { out.push(cur); cur = []; }
    cur.push(c);
  }
  if (cur.length) out.push(cur);
  return out;
}
function commandsToD(cmds) {
  let d = '';
  for (const c of cmds) {
    if (c.type === 'M') d += `M${r2(c.x)} ${r2(c.y)}`;
    else if (c.type === 'L') d += `L${r2(c.x)} ${r2(c.y)}`;
    else if (c.type === 'C') d += `C${r2(c.x1)} ${r2(c.y1)} ${r2(c.x2)} ${r2(c.y2)} ${r2(c.x)} ${r2(c.y)}`;
    else if (c.type === 'Q') d += `Q${r2(c.x1)} ${r2(c.y1)} ${r2(c.x)} ${r2(c.y)}`;
    else if (c.type === 'Z') d += 'Z';
  }
  return d;
}
function textPath(font, text, size = FONT_SIZE) {
  const p = font.getPath(text, 0, 0, size, { kerning: true });
  return { d: contours(p.commands).map(commandsToD).join(' '), width: font.getAdvanceWidth(text, size) };
}

const word = textPath(grotesk, 'rindle');
const e1 = confluence(word, {}); // the locked execution

const SCHEMES = {
  light: { base: PALETTE.deep, accent: PALETTE.green },
  dark: { base: PALETTE.porcelain, accent: PALETTE.green },
  mono: { base: 'currentColor', accent: 'currentColor' },
};

function renderParts(parts, { base, accent }) {
  return parts
    .map((q) => {
      const color = q.role === 'accent' ? accent : base;
      const tx = q.dx ? r2(q.dx) : 0;
      const ty = q.dy ? r2(q.dy) : 0;
      const tr = tx || ty ? ` transform="translate(${tx} ${ty})"` : '';
      if (q.stroke) {
        return `  <path d="${q.d}" fill="none" stroke="${color}" stroke-width="${q.sw}" stroke-linecap="round" stroke-linejoin="round"${tr}/>`;
      }
      return `  <path d="${q.d}" fill="${color}"${tr}/>`;
    })
    .join('\n');
}
function wrap(parts, scheme, { box, title, desc }) {
  const x1 = box.x1 - PAD, y1 = box.y1 - PAD, x2 = box.x2 + PAD, y2 = box.y2 + PAD;
  const body = `<g transform="translate(${r2(-x1)} ${r2(-y1)})">\n${renderParts(parts, scheme)}\n</g>`;
  return svgDoc({ width: x2 - x1, height: y2 - y1, body, title, desc });
}

const DESC = 'Rindle - Phoenix-native media lifecycle library. Confluence mark: tributaries merge into one durable current.';
const lockupBox = { x1: 0, y1: e1.top, x2: e1.width, y2: e1.bottom };

writeFileSync(join(outDir, 'rindle-logo.svg'), wrap(e1.parts, SCHEMES.light, { box: lockupBox, title: 'Rindle', desc: DESC }));
writeFileSync(join(outDir, 'rindle-logo-dark.svg'), wrap(e1.parts, SCHEMES.dark, { box: lockupBox, title: 'Rindle (dark)', desc: DESC }));
writeFileSync(join(outDir, 'rindle-logo-mono.svg'), wrap(e1.parts, SCHEMES.mono, { box: lockupBox, title: 'Rindle (monochrome)', desc: DESC }));

// mark only
writeFileSync(join(outDir, 'rindle-mark.svg'), wrap(e1.markParts, SCHEMES.light, { box: e1.markBox, title: 'Rindle mark', desc: DESC }));
writeFileSync(join(outDir, 'rindle-mark-dark.svg'), wrap(e1.markParts, SCHEMES.dark, { box: e1.markBox, title: 'Rindle mark (dark)', desc: DESC }));
writeFileSync(join(outDir, 'rindle-mark-mono.svg'), wrap(e1.markParts, SCHEMES.mono, { box: e1.markBox, title: 'Rindle mark (monochrome)', desc: DESC }));

// subtitle variant - the only lockup carrying the tagline
const TAGLINE = 'Media, made durable.';
const tag = textPath(atkinson, TAGLINE, 24);
const wordX = e1.parts.find((q) => q.dx)?.dx ?? 0;
const tagY = e1.bottom + 34;
const subtitleParts = [...e1.parts, { d: tag.d, dx: wordX, dy: tagY, fill: true, role: 'subtitle' }];
const subtitleScheme = { base: PALETTE.deep, accent: PALETTE.green };
const subtitleBody = subtitleParts
  .map((q) => {
    const color = q.role === 'subtitle' ? '#52605A' : q.role === 'accent' ? subtitleScheme.accent : subtitleScheme.base;
    const tx = q.dx ? r2(q.dx) : 0, ty = q.dy ? r2(q.dy) : 0;
    const tr = tx || ty ? ` transform="translate(${tx} ${ty})"` : '';
    return q.stroke
      ? `  <path d="${q.d}" fill="none" stroke="${color}" stroke-width="${q.sw}" stroke-linecap="round" stroke-linejoin="round"${tr}/>`
      : `  <path d="${q.d}" fill="${color}"${tr}/>`;
  })
  .join('\n');
const sBox = { x1: -PAD, y1: e1.top - PAD, x2: Math.max(e1.width, wordX + tag.width) + PAD, y2: tagY + 8 + PAD };
writeFileSync(
  join(outDir, 'rindle-logo-subtitle.svg'),
  svgDoc({
    width: sBox.x2 - sBox.x1,
    height: sBox.y2 - sBox.y1,
    body: `<g transform="translate(${r2(-sBox.x1)} ${r2(-sBox.y1)})">\n${subtitleBody}\n</g>`,
    title: 'Rindle - Media, made durable.',
    desc: DESC,
  })
);

// favicon: simplified cut - two tributaries, heavier strokes, square box,
// dark-mode aware via prefers-color-scheme
const favTop = 'M 4 -58 C 16 -58 28 -53 38 -46';
const favBot = 'M 4 -28 C 16 -28 28 -33 38 -40';
const favExit = 'M 40 -43 C 53 -42.5 60 -35 63.5 -25 C 67 -14 71 -7 79 -3';
const favicon = `<?xml version="1.0" encoding="UTF-8"?>
<!-- generated by brandbook/src/logo.mjs - edit that script, not this file -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 92 92" role="img" aria-labelledby="t">
  <title id="t">Rindle</title>
  <desc>${DESC}</desc>
  <style>
    .base { stroke: ${PALETTE.deep}; }
    .accent { stroke: ${PALETTE.green}; }
    @media (prefers-color-scheme: dark) { .base { stroke: ${PALETTE.porcelain}; } }
  </style>
  <g transform="translate(4 76)" fill="none" stroke-linecap="round" stroke-linejoin="round">
    <path class="accent" d="${favTop}" stroke-width="10"/>
    <path class="base" d="${favBot}" stroke-width="10"/>
    <path class="base" d="${favExit}" stroke-width="14"/>
  </g>
</svg>
`;
writeFileSync(join(outDir, 'favicon.svg'), favicon);

// ExDoc sidebar logo: the sidebar is dark in BOTH ExDoc themes (0.40 layout),
// so mix.exs points logo: at rindle-mark-dark.svg - no separate asset needed.

// social avatar source: mark (dark scheme) centered on a Deep Current surface.
// The filled square is the avatar SURFACE, not a container on the mark.
const avatarMark = renderParts(e1.markParts, SCHEMES.dark);
const avatar = `<?xml version="1.0" encoding="UTF-8"?>
<!-- generated by brandbook/src/logo.mjs - edit that script, not this file -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" role="img" aria-labelledby="t">
  <title id="t">Rindle avatar</title>
  <desc>${DESC}</desc>
  <path d="M0 0 H512 V512 H0 Z" fill="${PALETTE.deep}"/>
  <g transform="translate(67.4 394) scale(4.6)">
${avatarMark}
  </g>
</svg>
`;
writeFileSync(join(outDir, 'social-avatar.svg'), avatar);

console.log('wrote final logo system to', outDir);
