const MEMBERS = {
  jordan: "jordan@cohort.test",
  alex: "alex@cohort.test",
  maya: "maya@cohort.test",
  ops: "ops@cohort.test",
};

async function memberRow(page, email) {
  return page.locator(`[data-testid="member-row-${email}"]`);
}

async function memberId(page, email) {
  const row = await memberRow(page, email);
  const id = await row.getAttribute("id");
  return id.replace("member-", "");
}

module.exports = { MEMBERS, memberRow, memberId };
