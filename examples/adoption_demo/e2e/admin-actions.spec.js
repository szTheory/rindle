const { randomUUID } = require("node:crypto");
const { test, expect } = require("@playwright/test");
const {
  visitAdmin,
  expectAdminShell,
  expectNoAdminRawSecrets,
  expectNoHorizontalScroll,
} = require("./support/admin");
const { MEMBERS, memberId } = require("./support/cohort");

const ACTION_SELECTORS = {
  owner_erasure: '[data-rindle-admin-action="owner_erasure"]',
  batch_erasure: '[data-rindle-admin-action="batch_erasure"]',
};

const PREVIEW_SELECTORS = {
  owner_erasure: '[data-rindle-admin-preview="owner_erasure"]',
  batch_erasure: '[data-rindle-admin-preview="batch_erasure"]',
};

const RECEIPT_SELECTORS = {
  owner_erasure: '[data-rindle-admin-receipt="owner_erasure"]',
  batch_erasure: '[data-rindle-admin-receipt="batch_erasure"]',
};

function actionTab(page, action) {
  return page.locator(ACTION_SELECTORS[action]);
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

async function expectActionsShell(page) {
  await expectAdminShell(page, "actions");
  await expectNoAdminRawSecrets(page);
  await expectNoHorizontalScroll(page);
}

test("owner erasure blocks wrong confirmation and receipts generated execution", async ({ page }) => {
  await page.goto("/");
  const alexId = await memberId(page, MEMBERS.alex);

  await visitAdmin(page, "actions");
  await expectActionsShell(page);

  await actionTab(page, "owner_erasure").click();
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
  await actionTab(page, "owner_erasure").click();
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

  await actionTab(page, "batch_erasure").click();
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
