const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const specPath = path.join(__dirname, "cohort-pages.spec.js");

function readSpec() {
  return fs.readFileSync(specPath, "utf8");
}

test("assertCohortPagePolish hard-fails through the shared gate", () => {
  const source = readSpec();

  assert.match(source, /async function assertCohortPagePolish/);
  assert.doesNotMatch(source, /function\s+reportPolish/);
  assert.doesNotMatch(source, /\.catch\(\(error\)\s*=>\s*reportPolish/);
  assert.match(source, /await assertAdminPolish\(page,\s*\{/);
  assert.match(source, /root:\s*"\[data-ck-root\]"/);
  assert.match(source, /interactiveSelectors/);
  assert.match(source, /focusContract:\s*COHORT_FOCUS_CONTRACT/);
  assert.match(source, /adminBackstops:\s*false/);
  assert.match(source, /module\.exports\s*=\s*\{\s*assertCohortPagePolish,\s*interactiveSelectors\s*\}/);
});

test("Cohort visual matrix declares locked route, theme, and viewport coverage", () => {
  const source = readSpec();

  assert.match(source, /const COHORT_VIEWPORTS\s*=\s*\[/);
  assert.match(source, /name:\s*"desktop"/);
  assert.match(source, /name:\s*"mobile"/);
  assert.match(source, /const COHORT_VISUAL_MATRIX\s*=\s*\[/);
  assert.match(source, /const COHORT_THEMES\s*=\s*\["light",\s*"dark"\]/);
  assert.match(source, /for \(const routeCase of COHORT_VISUAL_MATRIX\)/);
  assert.match(source, /for \(const theme of COHORT_THEMES\)/);
  assert.match(source, /for \(const viewport of COHORT_VIEWPORTS\)/);
  assert.match(source, /assertCohortRenderedTheme\(page,\s*theme/);

  for (const surface of [
    "styleguide",
    "dashboard",
    "ops",
    "account-erasure",
    "member",
    "lesson",
    "post",
    "media",
    "upload-image",
    "upload-tus",
    "upload-video",
    "upload-multipart",
    "upload-liveview",
    "upload-mux",
  ]) {
    assert.match(source, new RegExp(`surface:\\s*"${surface}"`));
  }

  for (const tab of ["image", "tus", "video", "multipart", "liveview", "mux"]) {
    assert.match(source, new RegExp(`tab:\\s*"${tab}"`));
  }

  assert.doesNotMatch(source, /colorScheme/);
});
