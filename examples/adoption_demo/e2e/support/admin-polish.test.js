const assert = require("node:assert/strict");
const test = require("node:test");

const {
  assertFocusVisibleTokens,
  assertFocusVisibleVsPointer,
} = require("./admin-polish");

function withFakeDom(callback) {
  const previousDocument = global.document;
  const previousGetComputedStyle = global.getComputedStyle;

  const focused = {
    tagName: "BUTTON",
    className: "ck-btn",
    id: "",
    focusVisible: false,
    getAttribute() {
      return null;
    },
    matches(selector) {
      if (selector === ":focus-within") return true;
      if (selector === ":focus-visible") return this.focusVisible;
      return false;
    },
    focus() {
      this.focusVisible = true;
    },
    blur() {
      this.focusVisible = false;
    },
  };

  const root = { tagName: "DIV", className: "ck", id: "cohort-root" };
  const documentElement = { tagName: "HTML" };

  global.document = {
    activeElement: focused,
    documentElement,
    querySelector(selector) {
      return selector === "[data-ck-root]" ? root : null;
    },
  };

  global.getComputedStyle = (element) => {
    if (element === focused) {
      return {
        outlineWidth: "2px",
        outlineStyle: "solid",
        outlineColor: "rgb(4, 120, 87)",
        outlineOffset: "2px",
      };
    }

    if (element === root) {
      return {
        getPropertyValue(name) {
          return name === "--ck-focus" ? "#047857" : "";
        },
      };
    }

    return {
      getPropertyValue() {
        return "";
      },
    };
  };

  return Promise.resolve()
    .then(() => callback(focused))
    .finally(() => {
      global.document = previousDocument;
      global.getComputedStyle = previousGetComputedStyle;
    });
}

function fakePage(focused) {
  const item = {
    isVisible: async () => true,
    isDisabled: async () => false,
    evaluate: async (fn, arg) => fn(focused, arg),
    click: async () => {
      focused.focusVisible = false;
      global.document.activeElement = focused;
    },
  };

  return {
    evaluate: async () => [],
    locator() {
      return {
        count: async () => 1,
        nth: () => item,
        first: () => item,
      };
    },
  };
}

const cohortFocusContract = {
  width: "2px",
  color: "--ck-focus",
  offset: "2px",
  root: "[data-ck-root]",
};

test("focus token check resolves explicit Cohort focus contract from the selected root", async () => {
  await withFakeDom(async (focused) => {
    const offenders = await assertFocusVisibleTokens(
      fakePage(focused),
      [".ck-btn"],
      cohortFocusContract
    );

    assert.deepEqual(offenders, []);
  });
});

test("focus-visible-vs-pointer check honors explicit Cohort focus contract", async () => {
  await withFakeDom(async (focused) => {
    const offenders = await assertFocusVisibleVsPointer(
      fakePage(focused),
      [".ck-btn"],
      cohortFocusContract
    );

    assert.deepEqual(offenders, []);
  });
});
