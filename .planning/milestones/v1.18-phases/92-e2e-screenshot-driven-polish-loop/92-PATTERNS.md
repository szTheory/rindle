# Phase 92: E2E & Screenshot-Driven Polish Loop - Pattern Map

**Mapped:** 2026-06-13
**Files analyzed:** 12
**Analogs found:** 12 / 12

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `examples/adoption_demo/e2e/support/admin.js` | utility | request-response | `examples/adoption_demo/e2e/support/liveview.js` + `examples/adoption_demo/e2e/support/cohort.js` | role-match |
| `examples/adoption_demo/e2e/admin-console.spec.js` | test | request-response | `examples/adoption_demo/e2e/ops-surfaces.spec.js` + `test/rindle/admin/live/home_assets_upload_test.exs` | role-match |
| `examples/adoption_demo/e2e/admin-actions.spec.js` | test | request-response | `examples/adoption_demo/e2e/owner-erasure.spec.js` + `test/rindle/admin/live/actions_live_test.exs` | role-match |
| `examples/adoption_demo/e2e/admin-theme.spec.js` | test | request-response | `brandbook/src/admin-gallery-check.mjs` + `lib/rindle/admin/components.ex` | role-match |
| `examples/adoption_demo/e2e/admin-screenshots.spec.js` | test | file-I/O | `brandbook/src/admin-gallery-check.mjs` | role-match |
| `lib/rindle/admin/components.ex` | component | request-response | `lib/rindle/admin/components.ex` | exact |
| `lib/rindle/admin/live/actions_live.ex` | component | event-driven | `lib/rindle/admin/live/actions_live.ex` | exact |
| `lib/rindle/admin/live/assets_live.ex` | component | CRUD | `lib/rindle/admin/live/assets_live.ex` | exact |
| `lib/rindle/admin/live/upload_sessions_live.ex` | component | CRUD | `lib/rindle/admin/live/upload_sessions_live.ex` | exact |
| `lib/rindle/admin/live/variants_jobs_live.ex` | component | request-response | `lib/rindle/admin/live/variants_jobs_live.ex` | exact |
| `lib/rindle/admin/live/runtime_doctor_live.ex` | component | request-response | `lib/rindle/admin/live/runtime_doctor_live.ex` | exact |
| `examples/adoption_demo/docs/adoption-proof-matrix.md` + `scripts/maintainer/check_adoption_proof_matrix.sh` + `examples/adoption_demo/README.md` | config | request-response | existing same files | exact |

## Pattern Assignments

### `examples/adoption_demo/e2e/support/admin.js` (utility, request-response)

**Analog:** `examples/adoption_demo/e2e/support/liveview.js`, `examples/adoption_demo/e2e/support/cohort.js`

**CommonJS helper pattern** (`examples/adoption_demo/e2e/support/liveview.js` lines 1-7):
```javascript
async function waitForLiveSocket(page) {
  await page.waitForFunction(
    () => window.liveSocket && window.liveSocket.isConnected && window.liveSocket.isConnected()
  );
}

module.exports = { waitForLiveSocket };
```

**Stable selector helper pattern** (`examples/adoption_demo/e2e/support/cohort.js` lines 1-16):
```javascript
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
```

**Apply:** export `ADMIN_BASE`, `adminPath`, `visitAdmin`, `expectAdminShell`, `selectAdminTheme`, and detail-link helpers from a CommonJS module. Use `data-rindle-admin-*` selectors, not `data-testid`, for new admin helpers.

### `examples/adoption_demo/e2e/admin-console.spec.js` (test, request-response)

**Analog:** `examples/adoption_demo/e2e/ops-surfaces.spec.js`, `test/rindle/admin/live/home_assets_upload_test.exs`

**Playwright import and LiveView wait pattern** (`examples/adoption_demo/e2e/ops-surfaces.spec.js` lines 1-15):
```javascript
const { test, expect } = require("@playwright/test");
const { waitForLiveSocket } = require("./support/liveview");

test("ops surfaces render doctor and runtime status output", async ({ page }) => {
  await page.goto("/ops");
  await waitForLiveSocket(page);

  await page.getByTestId("run-doctor-button").click();
  await expect(page.getByTestId("doctor-output")).toContainText("doctor_success=", {
    timeout: 30_000,
  });
});
```

**Admin shell contract to assert in browser tests** (`test/rindle/admin/live/home_assets_upload_test.exs` lines 297-309):
```elixir
defp assert_shell(html, surface) do
  assert html =~ ~s(data-rindle-admin-root)
  assert html =~ ~s(data-rindle-admin-surface="#{surface}")
  assert html =~ ~s(data-rindle-admin-nav-item)
  assert html =~ ~s(data-rindle-admin-status-chip)
  assert html =~ ~s(data-rindle-admin-live-indicator)
  assert html =~ ~s(data-theme="auto")
  assert html =~ ~s(data-rindle-admin-theme="light")
  assert html =~ ~s(data-rindle-admin-theme="dark")
  assert html =~ ~s(data-rindle-admin-theme="auto")
  assert html =~ ~s(aria-label="Theme")
  assert html =~ "rindle-admin-target-min"
end
```

**Surface coverage pattern** (`test/rindle/admin/live/home_assets_upload_test.exs` lines 150-186):
```elixir
assert_shell(html, "assets")
assert html =~ ~s(data-rindle-admin-filter="state")
assert html =~ ~s(data-rindle-admin-filter="profile")
assert html =~ ~s(data-rindle-admin-filter="kind")
assert html =~ ~s(data-rindle-admin-row="asset")
assert html =~ "Inspect asset"

{:ok, _detail, detail_html} =
  Phoenix.LiveViewTest.live(conn, "/admin/rindle/assets/#{asset.id}")

assert_shell(detail_html, "assets")
assert detail_html =~ "Attachment context"
assert detail_html =~ "Variants"
assert detail_html =~ "Upload sessions"
assert detail_html =~ "Processing runs"
refute detail_html =~ "provider-secret-asset-id"
```

**Apply:** write browser assertions for every admin route using `expectAdminShell(page, surface)`, row selectors such as `[data-rindle-admin-row="asset"]`, and explicit secret-redaction checks.

### `examples/adoption_demo/e2e/admin-actions.spec.js` (test, request-response)

**Analog:** `examples/adoption_demo/e2e/owner-erasure.spec.js`, `test/rindle/admin/live/actions_live_test.exs`

**Browser destructive-flow pattern** (`examples/adoption_demo/e2e/owner-erasure.spec.js` lines 19-32):
```javascript
test("owner erasure execute on ops operator", async ({ page }) => {
  await page.goto("/");
  await waitForLiveSocket(page);

  const opsId = await memberId(page, MEMBERS.ops);
  await page.goto(`/account/${opsId}/delete`);
  await waitForLiveSocket(page);

  await page.getByTestId("preview-erasure-button").click();
  await expect(page.getByTestId("erasure-preview")).toBeVisible();

  await page.getByTestId("execute-erasure-button").click();
  await expect(page.getByTestId("erasure-result")).toBeVisible();
});
```

**LiveView action-state pattern to mirror with admin selectors** (`test/rindle/admin/live/actions_live_test.exs` lines 80-141):
```elixir
view
|> form("form[phx-submit=\"preview_owner_erasure\"]", %{
  "owner_type" => "Elixir.String",
  "owner_id" => owner_id
})
|> render_submit()

assert has_element?(view, "[data-rindle-admin-state=\"preview\"]")

view
|> form("form[phx-submit=\"execute_owner_erasure\"]", %{
  "owner_type" => "Elixir.String",
  "owner_id" => owner_id,
  "confirmation" => "wrong"
})
|> render_submit()

assert has_element?(view, "[data-rindle-admin-state=\"preview\"]")

view
|> form("form[phx-submit=\"execute_owner_erasure\"]", %{
  "owner_type" => "Elixir.String",
  "owner_id" => owner_id,
  "confirmation" => "ERASE Elixir.String:#{owner_id}"
})
|> render_submit()

assert has_element?(view, "[data-rindle-admin-receipt=\"owner_erasure\"]")
```

**Batch and other action coverage pattern** (`test/rindle/admin/live/actions_live_test.exs` lines 144-188, 190-253, 256-266):
```elixir
assert has_element?(view, "[data-rindle-admin-receipt=\"batch_erasure\"]")
assert has_element?(view, "[data-rindle-admin-receipt=\"lifecycle_repair\"]")
assert has_element?(view, "[data-rindle-admin-receipt=\"variant_regeneration\"]")
assert has_element?(view, "[data-rindle-admin-panel=\"quarantine_review\"]")
```

**Apply:** tests should assert preview, wrong confirmation stays in preview, successful receipt, partial/receipt state, and read-only quarantine panel. If existing buttons/forms lack stable admin selectors, add `data-rindle-admin-action`, `data-rindle-admin-form`, or `data-rindle-admin-submit` attributes in `actions_live.ex` before using text locators.

### `examples/adoption_demo/e2e/admin-theme.spec.js` (test, request-response)

**Analog:** `brandbook/src/admin-gallery-check.mjs`, `lib/rindle/admin/components.ex`

**Theme picker DOM contract** (`lib/rindle/admin/components.ex` lines 55-63):
```elixir
def theme_picker(assigns) do
  ~H"""
  <div class="rindle-admin-theme-picker" data-rindle-admin-component="theme-picker" role="group" aria-label="Theme">
    <button class="rindle-admin-theme-picker__option rindle-admin-target-min" type="button" data-rindle-admin-theme="light" aria-pressed="false">Light</button>
    <button class="rindle-admin-theme-picker__option rindle-admin-target-min" type="button" data-rindle-admin-theme="dark" aria-pressed="false">Dark</button>
    <button class="rindle-admin-theme-picker__option rindle-admin-target-min" type="button" data-rindle-admin-theme="auto" aria-pressed="true">Auto</button>
  </div>
  """
end
```

**Theme toggle assertion pattern** (`brandbook/src/admin-gallery-check.mjs` lines 178-182):
```javascript
const selectTheme = async (page, theme) => {
  await page.locator(`[data-rindle-admin-theme="${theme}"]`).click();
  const current = await page.evaluate(() => document.documentElement.getAttribute('data-theme'));
  assert(current === theme, `expected data-theme ${theme}, got ${current}`);
};
```

**Apply:** in Playwright, use `await page.locator('[data-rindle-admin-theme="dark"]').click()` then `await expect(page.locator('[data-rindle-admin-theme="dark"]')).toHaveAttribute("aria-pressed", "true")` and assert the root or document `data-theme`. Do not rely only on `page.emulateMedia`.

### `examples/adoption_demo/e2e/admin-screenshots.spec.js` (test, file-I/O)

**Analog:** `brandbook/src/admin-gallery-check.mjs`

**File-system and expected screenshot pattern** (`brandbook/src/admin-gallery-check.mjs` lines 4-15, 58-66):
```javascript
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, rmSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';

const expectedScreenshots = [
  'gallery-light-desktop.png',
  'gallery-dark-desktop.png',
  'gallery-auto-desktop.png',
  'gallery-light-mobile.png',
  'status-chips-dark.png',
  'theme-picker-light.png',
  'confirm-dialog-light.png',
];
```

**Capture pattern** (`brandbook/src/admin-gallery-check.mjs` lines 184-200):
```javascript
const screenshot = async (page, name, options = {}) => {
  await page.screenshot({
    path: join(screenshotsDir, name),
    animations: 'disabled',
    fullPage: options.fullPage ?? true,
  });
};

rmSync(screenshotsDir, { recursive: true, force: true });
mkdirSync(screenshotsDir, { recursive: true });
```

**Viewport and theme matrix pattern** (`brandbook/src/admin-gallery-check.mjs` lines 205-251):
```javascript
const page = await browser.newPage({
  deviceScaleFactor: 2,
  viewport: { width: 1480, height: 900 },
});

await selectTheme(page, 'light');
await screenshot(page, 'gallery-light-desktop.png');

await selectTheme(page, 'dark');
await screenshot(page, 'gallery-dark-desktop.png');

await page.setViewportSize({ width: 390, height: 900 });
await selectTheme(page, 'light');
await screenshot(page, 'gallery-light-mobile.png');
```

**Missing-file assertion pattern** (`brandbook/src/admin-gallery-check.mjs` lines 275-277):
```javascript
const missing = expectedScreenshots.filter((name) => !existsSync(join(screenshotsDir, name)));
assert(missing.length === 0, `missing screenshots: ${missing.join(', ')}`);
console.log(`admin gallery check passed - ${expectedScreenshots.length} screenshots written`);
```

**Apply:** adapt to CommonJS Playwright tests under `examples/adoption_demo/e2e/`, put output under `examples/adoption_demo/test-results/admin-screenshots/{theme}/`, use `baseURL` routes, call `waitForLiveSocket(page)`, and assert every expected file exists.

### `lib/rindle/admin/components.ex` (component, request-response)

**Analog:** same file

**Shell/root/nav selector pattern** (lines 22-51):
```elixir
def shell(assigns) do
  assigns = assign(assigns, :surfaces, surface_links(assigns.base_path))

  ~H"""
  <div class="rindle-admin-shell" data-rindle-admin-root data-rindle-admin-surface={@active} data-theme="auto">
    <nav class="rindle-admin-nav" aria-label="Rindle Admin surfaces" data-rindle-admin-component="nav">
      <p class="rindle-admin-nav__brand">Rindle Admin</p>
      <ul class="rindle-admin-nav__list">
        <li :for={surface <- @surfaces}>
          <a
            class="rindle-admin-nav__item"
            href={surface.path}
            aria-current={if surface.slug == @active, do: "page", else: nil}
            data-rindle-admin-nav-item={surface.slug}
          >
            {surface.name}
          </a>
        </li>
      </ul>
      <.theme_picker />
    </nav>
    <main class="rindle-admin-shell__main" data-rindle-admin-surface={@active}>
      <header data-rindle-admin-page-header>
```

**Reusable states/selectors pattern** (lines 79-93, 119-138, 143-159):
```elixir
<span
  class={"rindle-admin-status-chip rindle-admin-status-chip--#{@class_state}"}
  data-rindle-admin-status-chip
  data-rindle-admin-state={@class_state}
>
  {@label}
</span>

<section class="rindle-admin-empty-state" data-rindle-admin-empty-state data-rindle-admin-state="empty">

<section class="rindle-admin-empty-state" data-rindle-admin-error-state data-rindle-admin-state="error">

<dl data-rindle-admin-metadata-list>

<code data-rindle-admin-redacted-value>{format_value(@value || "Redacted by Rindle Admin")}</code>
```

**Apply:** new selectors should use the same `data-rindle-admin-*` namespace. Keep selector attributes semantic and narrow; do not introduce `data-testid` into published admin components.

### `lib/rindle/admin/live/actions_live.ex` (component, event-driven)

**Analog:** same file

**Event-state pattern** (lines 29-40, 51-79):
```elixir
def handle_event("select_action", %{"id" => id_str}, socket) do
  id = String.to_existing_atom(id_str)

  {:noreply,
   socket
   |> assign(
     active_action_id: id,
     action_state: :input,
     action_data: %{}
   )}
end

def handle_event("execute_owner_erasure", %{"confirmation" => confirmation}, socket) do
  %{type: type, id: id, report: _report} = socket.assigns.action_data
  expected = "ERASE #{type}:#{id}"

  if confirmation == expected do
    owner = %{__struct__: String.to_atom(type), id: id}
    case Rindle.erase_owner(owner) do
      {:ok, report} ->
        {:noreply, assign(socket, action_state: :receipt, action_data: %{report: report, type: type, id: id})}
      {:error, _} ->
        {:noreply, socket |> put_flash(:error, "Execution failed")}
    end
  else
    {:noreply, socket |> put_flash(:error, "Confirmation does not match.")}
  end
end
```

**Existing selector surfaces to extend** (lines 319-365, 373-422, 435-492):
```elixir
<div data-rindle-admin-state="input">
<div data-rindle-admin-state="preview">
<input type="text" name="confirmation" data-rindle-admin-confirm-input required />
<div data-rindle-admin-state="receipt" data-rindle-admin-receipt="owner_erasure">

<div data-rindle-admin-state="receipt" data-rindle-admin-receipt="batch_erasure">
<div data-rindle-admin-state="receipt" data-rindle-admin-receipt="batch_erasure" data-rindle-admin-error="batch_failed">

<div data-rindle-admin-state="receipt" data-rindle-admin-receipt="lifecycle_repair">
<div data-rindle-admin-state="receipt" data-rindle-admin-receipt="variant_regeneration">
```

**Apply:** add stable selectors to action tabs, forms, owner inputs, batch textarea, submit buttons, preview report containers, and non-destructive action controls. Preserve the event names and confirmation copy because ExUnit tests assert them.

### `lib/rindle/admin/live/assets_live.ex` and `upload_sessions_live.ex` (component, CRUD)

**Analog:** same files

**List/detail routing pattern** (`lib/rindle/admin/live/assets_live.ex` lines 28-40):
```elixir
def handle_params(%{"id" => id}, _uri, socket) do
  {:noreply, load_detail(socket, id)}
end

def handle_params(params, _uri, socket) do
  filters = take_filters(params, ~w(state profile kind))

  {:noreply,
   socket
   |> assign(filters: filters, detail: nil)
   |> load_list()}
end
```

**Rows/detail-link pattern** (`lib/rindle/admin/live/assets_live.ex` lines 100-132):
```elixir
<.filters filters={[{"state", @filters["state"]}, {"profile", @filters["profile"]}, {"kind", @filters["kind"]}]} />

<%= if Enum.empty?(@model.rows) do %>
  <.empty_state />
<% else %>
  <table class="rindle-admin-table">
    <tbody>
      <tr :for={asset <- @model.rows} class="rindle-admin-table__row" data-rindle-admin-row="asset">
        <td class="rindle-admin-table__cell"><code>{asset.filename || asset.id}</code></td>
        <td class="rindle-admin-table__cell"><.status_chip state={asset.state} label={asset.state} /></td>
        <td class="rindle-admin-table__cell">
          <a class="rindle-admin-button rindle-admin-button--secondary rindle-admin-target-min" href={admin_path(@admin_base_path, "assets/#{asset.id}")}>
            Inspect asset
          </a>
        </td>
      </tr>
    </tbody>
  </table>
<% end %>
```

**Upload-session redaction pattern** (`lib/rindle/admin/live/upload_sessions_live.ex` lines 123-131):
```elixir
<tr :for={session <- @model.rows} class="rindle-admin-table__row" data-rindle-admin-row="upload-session">
  <td class="rindle-admin-table__cell"><code>{session.id}</code></td>
  <td class="rindle-admin-table__cell"><.status_chip state={session.state} label={session.state} /></td>
  <td class="rindle-admin-table__cell"><.redacted_value value={session.session_uri} /></td>
  <td class="rindle-admin-table__cell">
    <a class="rindle-admin-button rindle-admin-button--secondary rindle-admin-target-min" href={admin_path(@admin_base_path, "upload-sessions/#{session.id}")}>
      Review session
    </a>
  </td>
</tr>
```

**Apply:** if Playwright needs first detail links, add `data-rindle-admin-detail-link="asset"` and `data-rindle-admin-detail-link="upload-session"` to existing anchors rather than matching button text.

### `lib/rindle/admin/live/variants_jobs_live.ex` and `runtime_doctor_live.ex` (component, request-response)

**Analog:** same files

**Variants/jobs diagnostic row pattern** (`lib/rindle/admin/live/variants_jobs_live.ex` lines 68-130):
```elixir
<%= if @error? do %>
  <.error_state surface="Variants/Jobs" />
<% else %>
  <%= if Enum.empty?(@model.findings) do %>
    <.empty_state />
  <% else %>
    <section>
      <h2>Variant/job buckets</h2>
      <table class="rindle-admin-table">
        <tbody>
          <tr :for={finding <- @model.findings} class="rindle-admin-table__row" data-rindle-admin-row="variant-finding">
            <td class="rindle-admin-table__cell">
              <.status_chip state={bucket_state(finding)} label={bucket_label(finding)} />
            </td>
            <span :if={sample_value(sample, :provider_asset_id)}>Provider identifier redacted</span>
          </tr>
        </tbody>
      </table>
    </section>
  <% end %>
<% end %>
```

**Runtime/doctor row pattern** (`lib/rindle/admin/live/runtime_doctor_live.ex` lines 52-75):
```elixir
<%= if @error? do %>
  <.error_state surface="Runtime/Doctor" />
<% else %>
  <section>
    <h2>Doctor checks</h2>
    <table class="rindle-admin-table">
      <tbody>
        <tr :for={check <- @model.doctor.checks} class="rindle-admin-table__row" data-rindle-admin-row="doctor-check">
          <td class="rindle-admin-table__cell"><code>{check.id}</code></td>
          <td class="rindle-admin-table__cell"><.status_chip state={to_string(check.status)} label={to_string(check.status)} /></td>
          <td class="rindle-admin-table__cell">{check.summary}</td>
          <td class="rindle-admin-table__cell">{check.fix}</td>
        </tr>
      </tbody>
    </table>
  </section>
<% end %>
```

**Apply:** browser specs should assert diagnostic rows with `data-rindle-admin-row="variant-finding"` and `data-rindle-admin-row="doctor-check"`, plus redaction and recommendation text. Avoid triggering repairs from these read-only surfaces.

### Proof Matrix and Local Docs (config, request-response)

**Analog:** `examples/adoption_demo/docs/adoption-proof-matrix.md`, `scripts/maintainer/check_adoption_proof_matrix.sh`, `examples/adoption_demo/README.md`

**Proof matrix row pattern** (`examples/adoption_demo/docs/adoption-proof-matrix.md` lines 24-40):
```markdown
| Concern | Realism | Proof | Where | CI severity |
|---------|---------|-------|-------|-------------|
| Operator doctor + runtime status | Host env | Mix task output on `/ops` | `e2e/ops-surfaces.spec.js`, `mix rindle.doctor` in install-smoke | Demo: blocking |
| Batch owner erasure preview | MinIO | Ops UI batch preview | `e2e/batch-erasure.spec.js`, `mix rindle.batch_owner_erasure` | Demo + proof: blocking |
| Owner erasure preview + execute | MinIO | preview `retained_shared_assets` + ops execute | `e2e/owner-erasure.spec.js`, `canonical_app/lifecycle_test.exs` | Demo + adopter: blocking |
```

**Drift gate pattern** (`scripts/maintainer/check_adoption_proof_matrix.sh` lines 13-18, 31-43):
```bash
require_substring() {
  local needle="$1"
  local label="$2"
  if ! grep -Fq "${needle}" "${matrix}"; then
    echo "check_adoption_proof_matrix: matrix missing ${label} (expected: ${needle})" >&2
    exit 1
  fi
}

require_substring "e2e/image-upload.spec.js" "image Playwright spec"
require_substring "e2e/owner-erasure.spec.js" "owner erasure Playwright spec"
require_substring "check_adoption_proof_matrix.sh" "drift gate script self-reference"
```

**README E2E command pattern** (`examples/adoption_demo/README.md` lines 102-115):
```text
Browser E2E (Playwright)

With MinIO + Postgres running:

  cd examples/adoption_demo
  npm ci
  npx playwright install chromium
  npm run e2e

Playwright starts the Phoenix server in MIX_ENV=test on port 4102 (override with
ADOPTION_DEMO_BROWSER_PORT). CI uses scripts/ci/adoption_demo_e2e.sh with
ADOPTION_DEMO_PRESEEDED=1.
```

**Apply:** every new E2E spec filename must be named in the matrix and drift gate. README updates are optional unless a separate screenshot command is exposed.

## Shared Patterns

### Playwright Harness

**Source:** `examples/adoption_demo/playwright.config.js`
**Apply to:** all new `examples/adoption_demo/e2e/*.spec.js`
```javascript
module.exports = defineConfig({
  testDir: "./e2e",
  globalSetup: path.join(__dirname, "e2e/global-setup.js"),
  timeout: 120_000,
  expect: { timeout: 15_000 },
  fullyParallel: false,
  workers: 1,
  use: {
    baseURL,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },
  outputDir: "test-results",
});
```

### CI Browser Lane

**Source:** `scripts/ci/adoption_demo_e2e.sh`
**Apply to:** adoption demo E2E proof and screenshot spec execution
```bash
export MIX_ENV=test
export PHX_SERVER=1
export RINDLE_MINIO_RESET_BUCKET="${RINDLE_MINIO_RESET_BUCKET:-1}"
bash "${repo_root}/scripts/ensure_minio.sh"

cd "${demo_dir}"
mix deps.get --only test
mix assets.vendor
mix ecto.drop --quiet || true
mix ecto.create
mix ecto.migrate
mix rindle.migrate
PHX_SERVER= mix run priv/repo/seeds.exs

npm ci
npm run vendor:js
npx playwright install --with-deps chromium
export ADOPTION_DEMO_PRESEEDED=1
npm run e2e
```

### Admin Mount Path

**Source:** `examples/adoption_demo/lib/adoption_demo_web/router.ex`
**Apply to:** admin helper base route
```elixir
scope "/admin" do
  pipe_through :browser

  rindle_admin "/", allow_unauthenticated?: true
end
```

Effective browser base path is `/admin/rindle`.

### LiveView Admin Test Selectors

**Source:** `lib/rindle/admin/components.ex`
**Apply to:** all admin browser specs and any selector additions
```elixir
data-rindle-admin-root
data-rindle-admin-surface={@active}
data-rindle-admin-nav-item={surface.slug}
data-rindle-admin-theme="light"
data-rindle-admin-theme="dark"
data-rindle-admin-theme="auto"
data-rindle-admin-row="asset"
data-rindle-admin-row="upload-session"
data-rindle-admin-empty-state
data-rindle-admin-error-state
data-rindle-admin-redacted-value
```

### Project Guidelines

**Source:** `AGENTS.md`, `examples/adoption_demo/AGENTS.md`
**Apply to:** all plans

- Follow `guides/ui_principles.md` before changing console, Cohort, E2E, or visual-polish surfaces.
- Keep the existing merge-blocking `adoption-demo-e2e` lane green.
- For Phoenix/LiveView edits, avoid sleeps in tests, use stable DOM IDs/selectors, and prefer existing HEEx/list/class syntax conventions.
- Run checks named in `RUNNING.md` for implementation changes; phase research specifically calls out targeted admin ExUnit tests, `bash scripts/ci/adoption_demo_e2e.sh`, and `bash scripts/maintainer/check_adoption_proof_matrix.sh`.

## No Analog Found

All expected files have a close local analog. The only partial mismatch is `examples/adoption_demo/e2e/admin-screenshots.spec.js`: screenshot mechanics exist in `brandbook/src/admin-gallery-check.mjs`, but the new file should be a Playwright test fixture rather than a standalone `.mjs` browser script.

## Metadata

**Analog search scope:** `examples/adoption_demo/e2e`, `examples/adoption_demo/docs`, `examples/adoption_demo/README.md`, `brandbook/src`, `lib/rindle/admin`, `test/rindle/admin`, `scripts/ci`, `scripts/maintainer`
**Files scanned:** 40+
**Pattern extraction date:** 2026-06-13
