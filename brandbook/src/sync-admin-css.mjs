// Mirrors the generated rindle-admin.css to the shipped package copy.
//
// This is the SINGLE committed mechanism (D-94-03) that copies the brandbook
// generator output (brandbook/tokens/rindle-admin.css) into the Hex-shipped
// asset (priv/static/rindle_admin/rindle-admin.css). It replaces the previous
// undocumented hand-mirror so the package artifact can never drift silently:
// both CI and local developers run this one script, and the Plan 04 diff gate
// plus the ExUnit equality test (admin_design_system_validation_test.exs:213)
// fail hard on any divergence.
//
// This is a straight byte-for-byte read -> write copy, NOT a re-render: the
// generator (admin-css-build.mjs) already wrote the canonical output. Run it
// AFTER admin-css-build.mjs in the pipeline order.
//
// Run: node brandbook/src/sync-admin-css.mjs

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, '..', '..');
const sourcePath = join(here, '..', 'tokens', 'rindle-admin.css');
const shippedPath = join(
  repoRoot,
  'priv',
  'static',
  'rindle_admin',
  'rindle-admin.css',
);

const css = readFileSync(sourcePath, 'utf8');
writeFileSync(shippedPath, css);

console.log(
  `synced rindle-admin.css -> priv/static/rindle_admin/rindle-admin.css (${css.length} bytes)`,
);
