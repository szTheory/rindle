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
