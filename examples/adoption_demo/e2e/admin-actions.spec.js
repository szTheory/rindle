const { randomUUID } = require("node:crypto");
const { test, expect } = require("@playwright/test");
const {
  visitAdmin,
  expectAdminShell,
  firstAdminDetailHref,
  expectNoAdminRawSecrets,
  expectNoHorizontalScroll,
} = require("./support/admin");
const { MEMBERS, memberId } = require("./support/cohort");

const ACTION_SELECTORS = {
  owner_erasure: '[data-rindle-admin-action="owner_erasure"]',
  batch_erasure: '[data-rindle-admin-action="batch_erasure"]',
  lifecycle_repair: '[data-rindle-admin-action="lifecycle_repair"]',
  variant_regeneration: '[data-rindle-admin-action="variant_regeneration"]',
  quarantine_review: '[data-rindle-admin-action="quarantine_review"]',
};

const PREVIEW_SELECTORS = {
  owner_erasure: '[data-rindle-admin-preview="owner_erasure"]',
  batch_erasure: '[data-rindle-admin-preview="batch_erasure"]',
};

const RECEIPT_SELECTORS = {
  owner_erasure: '[data-rindle-admin-receipt="owner_erasure"]',
  batch_erasure: '[data-rindle-admin-receipt="batch_erasure"]',
  lifecycle_repair: '[data-rindle-admin-receipt="lifecycle_repair"]',
  variant_regeneration: '[data-rindle-admin-receipt="variant_regeneration"]',
};

const QUARANTINE_PANEL_SELECTOR = '[data-rindle-admin-panel="quarantine_review"]';

function actionTab(page, action) {
  return page.locator(ACTION_SELECTORS[action]);
}

function actionPanel(page, action) {
  return page.locator(`[data-rindle-admin-action-panel="${action}"]`);
}

async function selectAction(page, action) {
  await actionTab(page, action).click();
  await expect(actionPanel(page, action)).toBeVisible();
}

function actionForm(page, form) {
  return page.locator(`[data-rindle-admin-form="${form}"]`);
}

function actionInput(page, input) {
  return page.locator(`[data-rindle-admin-input="${input}"]`);
}

function actionSubmit(page, submit) {
  return page.locator(`[data-rindle-admin-submit="${submit}"]`);
}

async function firstSeededAssetId(page) {
  await visitAdmin(page, "assets");
  const assetHref = await firstAdminDetailHref(page, "asset");
  return assetHref.split("/").filter(Boolean).at(-1);
}

async function expectActionsShell(page) {
  await expectAdminShell(page, "actions");
  await expectNoAdminRawSecrets(page);
  await expectNoHorizontalScroll(page);
}

test("owner erasure blocks wrong confirmation and receipts generated execution", async ({ page }) => {
  await page.goto("/dashboard");
  const alexId = await memberId(page, MEMBERS.alex);

  await visitAdmin(page, "actions");
  await expectActionsShell(page);

  await selectAction(page, "owner_erasure");
  await actionInput(page, "owner_type").fill("AdoptionDemo.Accounts.Member");
  await actionInput(page, "owner_id").fill(alexId);
  await actionForm(page, "owner_erasure_preview").evaluate((form) => form.requestSubmit());

  const alexPreview = page.locator(PREVIEW_SELECTORS.owner_erasure);
  await expect(alexPreview).toBeVisible();
  await expect(alexPreview).toContainText("Attachments to detach");
  await expect(page.locator('[data-rindle-admin-state="preview"]')).toBeVisible();

  await actionInput(page, "confirmation").fill("wrong");
  await actionSubmit(page, "execute_owner_erasure").click();
  await expect(page.getByText("Confirmation does not match.")).toBeVisible();
  await expect(page.locator('[data-rindle-admin-state="preview"]')).toBeVisible();

  await visitAdmin(page, "actions");
  await expectActionsShell(page);
  await selectAction(page, "owner_erasure");
  const ownerId = randomUUID();
  await actionInput(page, "owner_type").fill("Elixir.String");
  await actionInput(page, "owner_id").fill(ownerId);
  await actionForm(page, "owner_erasure_preview").evaluate((form) => form.requestSubmit());
  await expect(page.locator(PREVIEW_SELECTORS.owner_erasure)).toBeVisible();
  await actionInput(page, "confirmation").fill(`ERASE Elixir.String:${ownerId}`);
  await actionSubmit(page, "execute_owner_erasure").click();
  await expect(page.locator(RECEIPT_SELECTORS.owner_erasure)).toBeVisible();

  await expectActionsShell(page);
});

test("batch erasure blocks wrong confirmation and receipts generated owners", async ({ page }) => {
  await visitAdmin(page, "actions");
  await expectActionsShell(page);

  await selectAction(page, "batch_erasure");
  const owners = [`Elixir.String:${randomUUID()}`, `Elixir.String:${randomUUID()}`].join("\n");
  await actionInput(page, "batch_owners").fill(owners);
  await actionForm(page, "batch_erasure_preview").evaluate((form) => form.requestSubmit());

  const batchPreview = page.locator(PREVIEW_SELECTORS.batch_erasure);
  await expect(batchPreview).toBeVisible();
  await expect(batchPreview).toContainText("Owners to process: 2");
  await expect(batchPreview).toContainText("Attachments to detach");
  await expect(page.locator('[data-rindle-admin-state="preview"]')).toBeVisible();

  await actionInput(page, "confirmation").fill("wrong");
  await actionSubmit(page, "execute_batch_erasure").click();
  await expect(page.getByText("Confirmation does not match.")).toBeVisible();
  await expect(page.locator('[data-rindle-admin-state="preview"]')).toBeVisible();

  await actionInput(page, "confirmation").fill("ERASE 2 OWNERS");
  await actionSubmit(page, "execute_batch_erasure").click();
  await expect(page.locator(RECEIPT_SELECTORS.batch_erasure)).toBeVisible();

  await expectActionsShell(page);
});

test("lifecycle repair reprobes the first seeded asset", async ({ page }) => {
  const assetId = await firstSeededAssetId(page);

  await visitAdmin(page, "actions");
  await expectActionsShell(page);

  await selectAction(page, "lifecycle_repair");
  await actionInput(page, "asset_id").fill(assetId);
  await actionInput(page, "repair_action").selectOption("reprobe");
  await actionSubmit(page, "execute_lifecycle_repair").click();

  const receipt = page.locator(RECEIPT_SELECTORS.lifecycle_repair);
  await expect(receipt).toBeVisible();
  await expect(receipt).toContainText("Action taken: reprobe");
  await expectNoAdminRawSecrets(page);
  await expectNoHorizontalScroll(page);
});

test("variant regeneration requires confirmation before receipt", async ({ page }) => {
  await visitAdmin(page, "actions");
  await expectActionsShell(page);

  await selectAction(page, "variant_regeneration");
  await actionSubmit(page, "execute_variant_regeneration").click();
  await expect(page.getByText("You must confirm this action")).toBeVisible();

  await actionInput(page, "confirm").check();
  await actionSubmit(page, "execute_variant_regeneration").click();
  await expect(page.locator(RECEIPT_SELECTORS.variant_regeneration)).toBeVisible();
  await expectNoAdminRawSecrets(page);
  await expectNoHorizontalScroll(page);
});

test("quarantine review remains read-only triage", async ({ page }) => {
  await visitAdmin(page, "actions");
  await expectActionsShell(page);

  await selectAction(page, "quarantine_review");
  const panel = page.locator(QUARANTINE_PANEL_SELECTOR);
  await expect(panel).toBeVisible();
  await expect(panel.locator('button[type="submit"], input[type="submit"]')).toHaveCount(0);
  await expectNoAdminRawSecrets(page);
  await expectNoHorizontalScroll(page);
});
