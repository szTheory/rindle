const assert = require("node:assert/strict");
const test = require("node:test");
const { adminRoot } = require("./admin");

test("adminRoot targets the unique shell root marker", () => {
  const calls = [];
  const page = {
    locator(selector) {
      calls.push(selector);
      return { selector };
    },
  };

  const root = adminRoot(page);

  assert.equal(root.selector, ".rindle-admin-shell[data-rindle-admin-root]");
  assert.deepEqual(calls, [".rindle-admin-shell[data-rindle-admin-root]"]);
});
