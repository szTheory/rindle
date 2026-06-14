const { randomUUID } = require("node:crypto");
const { test, expect } = require("@playwright/test");
const {
  visitAdmin,
  expectAdminShell,
  selectAdminTheme,
  expectNoAdminRawSecrets,
  expectNoHorizontalScroll,
} = require("./support/admin");

// Discharges the phase-90 human-verification item ("visual styling clearly indicates a
// destructive action; the layout of the receipt and warnings is clear") with deterministic
// assertions. The fast ExUnit suite guards the *markup* contract (which classes are present);
// this browser suite proves the classes actually *paint* destructively with the stylesheet
// loaded, in both light and dark themes — the dimension a human was previously asked to eyeball.

function rgbChannels(color) {
  const match = String(color).match(/rgba?\(([^)]+)\)/);
  if (!match) {
    throw new Error(`unparseable color: ${color}`);
  }
  return match[1]
    .split(",")
    .slice(0, 3)
    .map((channel) => parseFloat(channel.trim()));
}

// Theme-agnostic destructive check: the danger token is #C83232 (light) / #F09090 (dark) —
// both red-dominant. Asserting dominance rather than an exact value survives token retuning
// and theme switches without becoming a flaky pixel comparison.
function isRedDominant(color) {
  const [r, g, b] = rgbChannels(color);
  return r > g && r > b;
}

async function selectAction(page, action) {
  await page.locator(`[data-rindle-admin-action="${action}"]`).click();
  await expect(page.locator(`[data-rindle-admin-action-panel="${action}"]`)).toBeVisible();
}

async function previewOwnerErasure(page, ownerId) {
  await page.locator('[data-rindle-admin-input="owner_type"]').fill("Elixir.String");
  await page.locator('[data-rindle-admin-input="owner_id"]').fill(ownerId);
  await page
    .locator('[data-rindle-admin-form="owner_erasure_preview"]')
    .evaluate((form) => form.requestSubmit());
  await expect(page.locator('[data-rindle-admin-preview="owner_erasure"]')).toBeVisible();
}

for (const theme of ["light", "dark"]) {
  test(`owner erasure reads as deliberately destructive (${theme})`, async ({ page }) => {
    await visitAdmin(page, "actions");
    await selectAdminTheme(page, theme);
    await expectAdminShell(page, "actions");
    await selectAction(page, "owner_erasure");

    // Standing destructive warning is visible before any interaction.
    const warning = page.locator("[data-rindle-admin-destructive-warning]");
    await expect(warning).toBeVisible();
    await expect(warning).toContainText("cannot be undone");
    const warningBorder = await warning.evaluate((el) => getComputedStyle(el).borderLeftColor);
    expect(
      isRedDominant(warningBorder),
      `standing warning border should be red-dominant, got ${warningBorder}`
    ).toBe(true);

    // Benign preview button (secondary styling) — captured for visual-distinction contrast.
    const previewBg = await page
      .locator('[data-rindle-admin-submit="preview_owner_erasure"]')
      .evaluate((el) => getComputedStyle(el).backgroundColor);

    // Advance to the confirm step to reveal the destructive execute button.
    const ownerId = randomUUID();
    await previewOwnerErasure(page, ownerId);

    const executeBtn = page.locator('[data-rindle-admin-submit="execute_owner_erasure"]');
    await expect(executeBtn).toBeVisible();
    const executeBg = await executeBtn.evaluate((el) => getComputedStyle(el).backgroundColor);

    // Contract: the destructive button paints a red-dominant fill...
    expect(
      isRedDominant(executeBg),
      `execute button should be red-dominant, got ${executeBg}`
    ).toBe(true);
    // ...and is visually distinct from the benign preview button.
    expect(executeBg).not.toBe(previewBg);

    // Confirmation gate is present and legible.
    await expect(page.locator("[data-rindle-admin-confirm-input]")).toBeVisible();
    await expect(page.getByText(`ERASE Elixir.String:${ownerId}`)).toBeVisible();

    await expectNoAdminRawSecrets(page);
    await expectNoHorizontalScroll(page);
  });
}

test("owner erasure stays legible from preview through receipt", async ({ page }) => {
  await visitAdmin(page, "actions");
  await expectAdminShell(page, "actions");
  await selectAction(page, "owner_erasure");

  const ownerId = randomUUID();
  await previewOwnerErasure(page, ownerId);

  // Wrong confirmation is blocked and keeps us on the confirm step.
  await page.locator('[data-rindle-admin-input="confirmation"]').fill("nope");
  await page.locator('[data-rindle-admin-submit="execute_owner_erasure"]').click();
  await expect(page.getByText("Confirmation does not match.")).toBeVisible();
  await expect(page.locator('[data-rindle-admin-state="preview"]')).toBeVisible();

  // Correct confirmation executes and renders a legible receipt.
  await page
    .locator('[data-rindle-admin-input="confirmation"]')
    .fill(`ERASE Elixir.String:${ownerId}`);
  await page.locator('[data-rindle-admin-submit="execute_owner_erasure"]').click();

  const receipt = page.locator('[data-rindle-admin-receipt="owner_erasure"]');
  await expect(receipt).toBeVisible();
  await expect(receipt).toContainText("Owner Erasure Complete");

  await expectNoAdminRawSecrets(page);
  await expectNoHorizontalScroll(page);
});
