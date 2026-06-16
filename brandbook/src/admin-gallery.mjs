// Generates the static Rindle Admin component gallery.
// Run: node brandbook/src/admin-gallery.mjs

import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  COMPONENTS,
  LEVEL_1_STATES,
  STATUS_STATES,
  SURFACES,
  THEMES,
} from './admin-design-system-data.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const brandbookDir = join(here, '..');
const galleryDir = join(brandbookDir, 'admin-gallery');
const galleryPath = join(galleryDir, 'index.html');
const adminCssPath = join(brandbookDir, 'tokens', 'rindle-admin.css');

const requiredThemes = ['light', 'dark', 'auto'];
const requiredSurfaces = [
  'Home/Status',
  'Assets',
  'Upload Sessions',
  'Variants/Jobs',
  'Runtime/Doctor',
  'Actions',
];
const requiredStates = ['ready', 'processing', 'warning', 'danger', 'quarantine', 'info'];
const requiredComponents = [
  'shell',
  'nav',
  'table',
  'status-chip',
  'button',
  'theme-picker',
  'form-controls',
  'confirm-dialog',
  'drawer',
  'toast',
  'empty-state',
  'error-state',
  'loading-state',
  'skeleton',
];
export const LEVEL_1_COMPONENT_STATE_MATRIX = {
  shell: ['default'],
  nav: ['default', 'hover', 'focus-visible', 'active'],
  table: ['default', 'hover', 'focus-visible', 'empty', 'loading', 'skeleton'],
  'status-chip': ['default', 'error'],
  button: ['default', 'hover', 'focus-visible', 'active', 'disabled', 'loading'],
  'theme-picker': ['default', 'hover', 'focus-visible', 'active'],
  'form-controls': ['default', 'hover', 'focus-visible', 'disabled', 'error'],
  'confirm-dialog': ['default', 'focus-visible', 'disabled', 'error'],
  drawer: ['default'],
  toast: ['default', 'error'],
  'empty-state': ['empty'],
  'error-state': ['error'],
  'loading-state': ['loading'],
  skeleton: ['skeleton'],
};

const exact = (actual, expected, label) => {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) throw new Error(`${label} mismatch: expected ${e}, got ${a}`);
};

exact(THEMES, requiredThemes, 'THEMES');
exact(SURFACES, requiredSurfaces, 'SURFACES');
exact(STATUS_STATES, requiredStates, 'STATUS_STATES');
exact(COMPONENTS, requiredComponents, 'COMPONENTS');
exact(LEVEL_1_STATES, ['default', 'hover', 'focus-visible', 'active', 'disabled', 'loading', 'empty', 'error', 'skeleton'], 'LEVEL_1_STATES');

if (!existsSync(adminCssPath)) {
  throw new Error(`missing generated admin CSS: ${adminCssPath}`);
}

const adminCss = readFileSync(adminCssPath, 'utf8');
const cssRequired = [
  '../tokens/rindle-admin.css',
  '.rindle-admin-shell',
  '.rindle-admin-nav',
  '.rindle-admin-table',
  '.rindle-admin-status-chip',
  '.rindle-admin-button',
  '.rindle-admin-theme-picker',
  '.rindle-admin-confirm-dialog',
  '.rindle-admin-drawer',
  '.rindle-admin-toast',
  '.rindle-admin-empty-state',
  '.rindle-admin-skeleton',
  '[data-theme="dark"]',
  '[data-theme="auto"]',
  'prefers-color-scheme: dark',
  'prefers-reduced-motion',
];
const missingCss = cssRequired
  .filter((needle) => needle !== '../tokens/rindle-admin.css')
  .filter((needle) => !adminCss.includes(needle));
if (missingCss.length) {
  throw new Error(`admin CSS contract missing: ${missingCss.join(', ')}`);
}

const escapeHtml = (value) => String(value)
  .replace(/&/g, '&amp;')
  .replace(/</g, '&lt;')
  .replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;');

const statusLabels = {
  ready: 'Ready',
  processing: 'Processing',
  warning: 'Warning',
  danger: 'Danger',
  quarantine: 'Quarantine',
  info: 'Info',
};

const statusChips = (states = STATUS_STATES) => states.map((state) => `
          <span class="rindle-admin-status-chip rindle-admin-status-chip--${state}" data-rindle-admin-component="status-chip" data-rindle-admin-state="${state === 'danger' ? 'error' : 'default'}" data-rindle-admin-status="${state}">
            ${escapeHtml(statusLabels[state])}
          </span>`).join('');

const surfaceSlug = (surface) => surface.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

const navItems = SURFACES.map((surface, index) => `
          <li>
            <a class="rindle-admin-nav__item" href="#${surfaceSlug(surface)}" data-rindle-admin-nav-item data-rindle-admin-component="nav" data-rindle-admin-state="${['active', 'hover', 'focus-visible', 'default', 'default', 'default'][index] || 'default'}"${index === 0 ? ' aria-current="page"' : ''}>
              <span aria-hidden="true">${String(index + 1).padStart(2, '0')}</span>
              <span>${escapeHtml(surface)}</span>
            </a>
          </li>`).join('');

const tableRows = [
  ['asset:img-2048', 'Ready original and thumbnails', 'ready', 'Assets', 'Inspect'],
  ['session:upl-719', 'Tus upload still receiving chunks', 'processing', 'Upload Sessions', 'Review'],
  ['variant:hero-webp', 'Recipe changed; output is stale', 'warning', 'Variants/Jobs', 'Preview'],
  ['asset:doc-088', 'Analyzer rejected unsafe content', 'quarantine', 'Assets', 'Inspect'],
  ['job:oban-442', 'Processor failed after retry budget', 'danger', 'Variants/Jobs', 'Repair'],
  ['doctor:runtime', 'Provider credentials visible to doctor', 'info', 'Runtime/Doctor', 'Review'],
];

const tableMarkup = tableRows.map(([id, summary, state, surface, action]) => `
              <tr class="rindle-admin-table__row" tabindex="0" data-rindle-admin-component="table" data-rindle-admin-state="${state === 'processing' ? 'loading' : state === 'warning' ? 'hover' : state === 'danger' ? 'focus-visible' : 'default'}" data-rindle-admin-status="${state}">
                <td class="rindle-admin-table__cell"><code>${escapeHtml(id)}</code></td>
                <td class="rindle-admin-table__cell">${escapeHtml(summary)}</td>
                <td class="rindle-admin-table__cell">
                  <span class="rindle-admin-status-chip rindle-admin-status-chip--${state}" data-rindle-admin-component="status-chip" data-rindle-admin-state="${state === 'danger' ? 'error' : 'default'}" data-rindle-admin-status="${state}">${escapeHtml(statusLabels[state])}</span>
                </td>
                <td class="rindle-admin-table__cell">${escapeHtml(surface)}</td>
                <td class="rindle-admin-table__cell"><button class="rindle-admin-button rindle-admin-button--quiet" type="button" data-rindle-admin-component="button" data-rindle-admin-state="default" data-rindle-admin-detail-link>${escapeHtml(action)}</button></td>
              </tr>`).join('');

const html = `<!doctype html>
<html lang="en" data-theme="auto">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Rindle Admin Component Gallery</title>
<link rel="stylesheet" href="../tokens/rindle-admin.css">
<style>
html,
body {
  min-height: 100%;
}

body {
  margin: 0;
  background: var(--rindle-surface);
  color: var(--rindle-text);
}

code {
  font-family: var(--rindle-font-mono);
  font-size: var(--rindle-text-code-size);
}

.rindle-admin-gallery__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: var(--rindle-space-5);
  margin-bottom: var(--rindle-space-6);
}

.rindle-admin-gallery__eyebrow {
  margin: 0 0 var(--rindle-space-2);
  color: var(--rindle-text-secondary);
  font-family: var(--rindle-font-mono);
  font-size: 12px;
}

.rindle-admin-gallery__title {
  margin: 0;
  font-family: var(--rindle-font-display);
  font-size: var(--rindle-text-h2-size);
  line-height: var(--rindle-text-h2-line);
}

.rindle-admin-gallery__lede {
  max-width: 72ch;
  margin: var(--rindle-space-2) 0 0;
  color: var(--rindle-text-secondary);
}

.rindle-admin-gallery__grid {
  display: grid;
  grid-template-columns: minmax(0, 1.15fr) minmax(320px, 0.85fr);
  gap: var(--rindle-space-5);
  align-items: start;
}

.rindle-admin-gallery__section {
  display: grid;
  gap: var(--rindle-space-4);
  margin-bottom: var(--rindle-space-5);
  scroll-margin-block-start: var(--rindle-space-5);
}

.rindle-admin-gallery__section:target > .rindle-admin-gallery__panel,
.rindle-admin-gallery__section:target > .rindle-admin-confirm-dialog,
.rindle-admin-gallery__section:target > .rindle-admin-drawer,
.rindle-admin-gallery__section:target > .rindle-admin-empty-state {
  outline: var(--rindle-focus-width) solid var(--rindle-focus-ring);
  outline-offset: var(--rindle-focus-offset);
}

.rindle-admin-gallery__panel {
  padding: var(--rindle-space-5);
  border: var(--rindle-border-rule-subtle);
  border-radius: var(--rindle-radius-card);
  background: var(--rindle-surface-raised);
}

.rindle-admin-gallery__panel h2,
.rindle-admin-gallery__panel h3 {
  margin: 0 0 var(--rindle-space-3);
  font-family: var(--rindle-font-display);
  line-height: var(--rindle-text-h3-line);
}

.rindle-admin-gallery__panel p {
  margin: 0 0 var(--rindle-space-3);
  color: var(--rindle-text-secondary);
}

.rindle-admin-gallery__row {
  display: flex;
  flex-wrap: wrap;
  gap: var(--rindle-space-3);
  align-items: center;
}

.rindle-admin-gallery__stack {
  display: grid;
  gap: var(--rindle-space-3);
}

.rindle-admin-gallery__field {
  display: grid;
  gap: var(--rindle-space-2);
}

.rindle-admin-gallery__field label {
  font-weight: 600;
}

.rindle-admin-gallery__input {
  min-height: var(--rindle-admin-target-min);
  padding: var(--rindle-space-2) var(--rindle-space-3);
  border: var(--rindle-border-rule-strong);
  border-radius: var(--rindle-radius-control);
  background: var(--rindle-surface-raised);
  color: var(--rindle-text);
  font: inherit;
}

.rindle-admin-gallery__input:focus-visible {
  outline: var(--rindle-focus-width) solid var(--rindle-focus-ring);
  outline-offset: var(--rindle-focus-offset);
}

.rindle-admin-gallery__receipt {
  display: grid;
  grid-template-columns: 1fr auto;
  gap: var(--rindle-space-2) var(--rindle-space-4);
  margin: 0;
  font-size: var(--rindle-text-small-size);
}

.rindle-admin-gallery__receipt dt {
  color: var(--rindle-text-secondary);
  font-family: var(--rindle-font-mono);
}

.rindle-admin-gallery__receipt dd {
  margin: 0;
  font-weight: 600;
}

.rindle-admin-gallery__toast-region {
  display: grid;
  gap: var(--rindle-space-3);
}

.rindle-admin-gallery__skeleton-list {
  display: grid;
  gap: var(--rindle-space-2);
}

.rindle-admin-gallery__skeleton-list .rindle-admin-skeleton:nth-child(2) {
  width: 82%;
}

.rindle-admin-gallery__skeleton-list .rindle-admin-skeleton:nth-child(3) {
  width: 64%;
}

@media (max-width: 980px) {
  .rindle-admin-gallery__header,
  .rindle-admin-gallery__grid {
    grid-template-columns: 1fr;
    display: grid;
  }
}
</style>
</head>
<body>
<div class="rindle-admin-shell" data-rindle-admin-root data-rindle-admin-component="shell" data-rindle-admin-state="default">
  <nav class="rindle-admin-nav" aria-label="Rindle Admin surfaces" data-rindle-admin-component="nav" data-rindle-admin-state="default">
    <p class="rindle-admin-nav__brand">Rindle Admin</p>
    <ul class="rindle-admin-nav__list">
${navItems}
    </ul>
  </nav>

  <main class="rindle-admin-shell__main">
    <header class="rindle-admin-gallery__header">
      <div>
        <p class="rindle-admin-gallery__eyebrow">Generated component gallery</p>
        <h1 class="rindle-admin-gallery__title">Rindle Admin</h1>
        <p class="rindle-admin-gallery__lede">Task-first component fixtures for lifecycle operations, rendered with only the generated rindle-admin CSS layer.</p>
      </div>
      <div class="rindle-admin-theme-picker" role="group" aria-label="Theme">
        ${THEMES.map((theme, index) => `<button class="rindle-admin-theme-picker__option" type="button" data-rindle-admin-component="theme-picker" data-rindle-admin-state="${['default', 'hover', 'active'][index]}" data-rindle-admin-theme="${theme}" aria-pressed="${theme === 'auto' ? 'true' : 'false'}">${theme[0].toUpperCase()}${theme.slice(1)}</button>`).join('')}
        <button class="rindle-admin-theme-picker__option" type="button" data-rindle-admin-component="theme-picker" data-rindle-admin-state="focus-visible" data-rindle-admin-theme="focus" aria-pressed="false">Focus</button>
      </div>
    </header>

    <div class="rindle-admin-gallery__grid">
      <div>
        <section class="rindle-admin-gallery__section" id="home-status" aria-labelledby="table-heading" data-rindle-admin-surface="Home/Status">
          <div class="rindle-admin-gallery__panel" data-rindle-admin-component="table" data-rindle-admin-state="default">
            <h2 id="table-heading">Lifecycle table</h2>
            <p>Rows carry state, surface, and action context without relying on color alone.</p>
            <table class="rindle-admin-table">
              <thead class="rindle-admin-table__head">
                <tr>
                  <th class="rindle-admin-table__cell" scope="col">Record</th>
                  <th class="rindle-admin-table__cell" scope="col">Signal</th>
                  <th class="rindle-admin-table__cell" scope="col">State</th>
                  <th class="rindle-admin-table__cell" scope="col">Surface</th>
                  <th class="rindle-admin-table__cell" scope="col">Action</th>
                </tr>
              </thead>
              <tbody>
${tableMarkup}
                <tr class="rindle-admin-table__row" tabindex="0" data-rindle-admin-component="table" data-rindle-admin-state="empty">
                  <td class="rindle-admin-table__cell" colspan="5">No rows match the current lifecycle filter.</td>
                </tr>
                <tr class="rindle-admin-table__row" tabindex="0" data-rindle-admin-component="table" data-rindle-admin-state="skeleton">
                  <td class="rindle-admin-table__cell" colspan="5"><div class="rindle-admin-skeleton" aria-hidden="true"></div></td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <section class="rindle-admin-gallery__section" id="assets" aria-labelledby="status-heading" data-rindle-admin-surface="Assets">
          <div class="rindle-admin-gallery__panel">
            <h2 id="status-heading">Status chips</h2>
            <p>Ready, processing, warning, danger, quarantine, and info examples include visible labels plus non-color marks.</p>
            <div class="rindle-admin-gallery__row">
${statusChips()}
            </div>
          </div>
        </section>

        <section class="rindle-admin-gallery__section" id="upload-sessions" aria-labelledby="buttons-heading" data-rindle-admin-surface="Upload Sessions">
          <div class="rindle-admin-gallery__panel">
            <h2 id="buttons-heading">Buttons</h2>
            <div class="rindle-admin-gallery__row">
              <button class="rindle-admin-button rindle-admin-button--primary" type="button" data-rindle-admin-component="button" data-rindle-admin-state="default">Review component gallery</button>
              <button class="rindle-admin-button rindle-admin-button--secondary" type="button" data-rindle-admin-component="button" data-rindle-admin-state="hover">Inspect asset</button>
              <button class="rindle-admin-button rindle-admin-button--quiet" type="button" data-rindle-admin-component="button" data-rindle-admin-state="focus-visible">Filter sessions</button>
              <button class="rindle-admin-button rindle-admin-button--destructive" type="button" data-rindle-admin-component="button" data-rindle-admin-state="active">Erase owner</button>
              <button class="rindle-admin-button rindle-admin-button--secondary" type="button" data-rindle-admin-component="button" data-rindle-admin-state="disabled" disabled>Disabled</button>
              <button class="rindle-admin-button rindle-admin-button--secondary" type="button" data-rindle-admin-component="button" data-rindle-admin-state="loading" aria-busy="true">Loading</button>
            </div>
          </div>
        </section>

        <section class="rindle-admin-gallery__section" id="actions" aria-labelledby="confirm-heading" data-rindle-admin-surface="Actions">
          <div class="rindle-admin-confirm-dialog" data-rindle-admin-component="confirm-dialog" data-rindle-admin-state="default" tabindex="-1">
            <h2 class="rindle-admin-confirm-dialog__title" id="confirm-heading">Owner erasure preview</h2>
            <p>Owner erasure: Type the owner identifier to confirm after reviewing affected assets.</p>
            <dl class="rindle-admin-gallery__receipt">
              <dt>Expected value</dt><dd><code>owner:cohort-demo-42</code></dd>
              <dt>Affected assets</dt><dd>12 detached, 3 retained shared assets</dd>
              <dt>Queued work</dt><dd>2 purge jobs after confirmation</dd>
            </dl>
            <div class="rindle-admin-gallery__field">
              <label for="owner-confirmation">Owner identifier</label>
              <input class="rindle-admin-gallery__input" id="owner-confirmation" name="owner-confirmation" autocomplete="off" data-rindle-admin-component="form-controls" data-rindle-admin-state="default" data-rindle-admin-confirm-input>
            </div>
            <div class="rindle-admin-gallery__row">
              <button class="rindle-admin-button rindle-admin-button--destructive" type="button" data-rindle-admin-component="confirm-dialog" data-rindle-admin-state="disabled" data-rindle-admin-confirm-action disabled>Confirm erasure</button>
              <button class="rindle-admin-button rindle-admin-button--secondary" type="button" data-rindle-admin-component="confirm-dialog" data-rindle-admin-state="focus-visible">Cancel</button>
            </div>
          </div>
        </section>

        <section class="rindle-admin-gallery__section" id="form-controls" aria-labelledby="form-controls-heading" data-rindle-admin-surface="Actions">
          <div class="rindle-admin-gallery__panel" data-rindle-admin-component="form-controls" data-rindle-admin-state="default">
            <h2 id="form-controls-heading">Form controls</h2>
            <div class="rindle-admin-gallery__stack">
              <input data-rindle-admin-component="form-controls" data-rindle-admin-state="hover" data-rindle-admin-input value="asset:img-2048" aria-label="Hovered asset id">
              <textarea data-rindle-admin-component="form-controls" data-rindle-admin-state="focus-visible" data-rindle-admin-input aria-label="Focused note">Review component gallery</textarea>
              <select data-rindle-admin-component="form-controls" data-rindle-admin-state="disabled" data-rindle-admin-input aria-label="Disabled lifecycle filter" disabled><option>Processing</option></select>
              <label class="rindle-admin-gallery__row"><input data-rindle-admin-component="form-controls" data-rindle-admin-state="error" data-rindle-admin-input type="checkbox" aria-invalid="true"> Runtime/Doctor source missing</label>
            </div>
          </div>
        </section>
      </div>

      <aside class="rindle-admin-gallery__stack" aria-label="Supporting component states">
        <section class="rindle-admin-gallery__section" id="variants-jobs" data-rindle-admin-surface="Variants/Jobs">
          <div class="rindle-admin-drawer" data-rindle-admin-component="drawer" data-rindle-admin-state="default" tabindex="-1">
            <h2>Asset detail drawer</h2>
            <p>Drawer context stays close to the invoking lifecycle row.</p>
            <dl class="rindle-admin-gallery__receipt">
              <dt>Asset</dt><dd><code>asset:doc-088</code></dd>
              <dt>State</dt><dd><span class="rindle-admin-status-chip rindle-admin-status-chip--quarantine" data-rindle-admin-state="quarantine">Quarantine</span></dd>
              <dt>Next step</dt><dd>Review collateral before Actions</dd>
            </dl>
          </div>
        </section>

        <section class="rindle-admin-gallery__panel">
          <h2>Toasts</h2>
          <div class="rindle-admin-gallery__toast-region">
            <div class="rindle-admin-toast rindle-admin-toast--success" data-rindle-admin-component="toast" data-rindle-admin-state="default" tabindex="0"><span aria-hidden="true">✓</span><span>Variant regeneration queued for <code>hero-webp</code>.</span><button class="rindle-admin-button rindle-admin-button--quiet" type="button">Dismiss</button></div>
            <div class="rindle-admin-toast rindle-admin-toast--warning" data-rindle-admin-component="toast" data-rindle-admin-state="default" tabindex="0"><span aria-hidden="true">!</span><span>Upload residue is expired; review cleanup guidance.</span><button class="rindle-admin-button rindle-admin-button--quiet" type="button">Dismiss</button></div>
            <div class="rindle-admin-toast rindle-admin-toast--danger" data-rindle-admin-component="toast" data-rindle-admin-state="error" tabindex="0"><span aria-hidden="true">!</span><span>Repair failed. Runtime/Doctor has the missing source artifact.</span><button class="rindle-admin-button rindle-admin-button--quiet" type="button">Dismiss</button></div>
          </div>
        </section>

        <section class="rindle-admin-gallery__section" id="runtime-doctor" data-rindle-admin-surface="Runtime/Doctor">
          <div class="rindle-admin-empty-state" data-rindle-admin-component="empty-state" data-rindle-admin-state="empty">
            <h2 class="rindle-admin-empty-state__title">No assets match this state</h2>
            <p>Adjust the lifecycle filter or check Runtime/Doctor for setup issues before running actions.</p>
            <button class="rindle-admin-button rindle-admin-button--secondary" type="button">Review Runtime/Doctor</button>
          </div>
        </section>

        <section class="rindle-admin-gallery__panel" data-rindle-admin-component="error-state" data-rindle-admin-state="error" data-rindle-admin-error-state>
          <h2>Error state</h2>
          <p>Rindle Admin could not load this surface. Retry load or check Runtime/Doctor for the missing source artifact.</p>
          <div class="rindle-admin-confirm-dialog" data-rindle-admin-component="confirm-dialog" data-rindle-admin-state="error" tabindex="-1">
            <p>Source artifact missing for preview.</p>
          </div>
        </section>

        <section class="rindle-admin-gallery__panel" data-rindle-admin-component="loading-state" data-rindle-admin-state="loading" data-rindle-admin-loading-state>
          <h2>Loading state</h2>
          <p>Loading lifecycle rows.</p>
        </section>

        <section class="rindle-admin-gallery__panel" data-rindle-admin-component="skeleton" data-rindle-admin-state="skeleton">
          <h2>Loading skeletons</h2>
          <p>Stable rows reserve space while real pending work resolves.</p>
          <div class="rindle-admin-gallery__skeleton-list">
            <div class="rindle-admin-skeleton" data-rindle-admin-component="skeleton" data-rindle-admin-state="skeleton" aria-hidden="true"></div>
            <div class="rindle-admin-skeleton" aria-hidden="true"></div>
            <div class="rindle-admin-skeleton" aria-hidden="true"></div>
          </div>
        </section>
      </aside>
    </div>
  </main>
</div>

<script>
(() => {
  const root = document.documentElement;
  const allowedThemes = new Set(['light', 'dark', 'auto']);
  const controls = Array.from(document.querySelectorAll('[data-rindle-admin-theme]'));
  const setTheme = (theme) => {
    if (!allowedThemes.has(theme)) return;
    root.setAttribute('data-theme', theme);
    controls.forEach((control) => {
      control.setAttribute('aria-pressed', String(control.dataset.rindleAdminTheme === theme));
    });
  };

  controls.forEach((control) => {
    control.addEventListener('click', () => setTheme(control.dataset.rindleAdminTheme));
  });

  const navLinks = Array.from(document.querySelectorAll('.rindle-admin-nav__item[href^="#"]'));
  const setCurrentSurface = () => {
    const hash = window.location.hash || '#home-status';
    navLinks.forEach((link) => {
      if (link.getAttribute('href') === hash) {
        link.setAttribute('aria-current', 'page');
      } else {
        link.removeAttribute('aria-current');
      }
    });
  };
  window.addEventListener('hashchange', setCurrentSurface);
  setCurrentSurface();

  const expectedOwner = 'owner:cohort-demo-42';
  const input = document.querySelector('[data-rindle-admin-confirm-input]');
  const action = document.querySelector('[data-rindle-admin-confirm-action]');
  input.addEventListener('input', () => {
    action.disabled = input.value !== expectedOwner;
  });
})();
</script>
</body>
</html>
`;

const requiredGalleryComponents = [
  'shell',
  'nav',
  'table',
  'status-chip',
  'button',
  'theme-picker',
  'form-controls',
  'confirm-dialog',
  'drawer',
  'toast',
  'empty-state',
  'error-state',
  'loading-state',
  'skeleton',
];
const requiredSnippets = [
  '<link rel="stylesheet" href="../tokens/rindle-admin.css">',
  'data-theme="auto"',
  'data-rindle-admin-root',
  'Rindle Admin',
  'owner:cohort-demo-42',
  "const allowedThemes = new Set(['light', 'dark', 'auto'])",
  "root.setAttribute('data-theme', theme)",
  "window.addEventListener('hashchange', setCurrentSurface)",
  ...THEMES.map((theme) => `data-rindle-admin-theme="${theme}"`),
  ...SURFACES,
  ...SURFACES.map((surface) => `id="${surfaceSlug(surface)}"`),
  ...requiredGalleryComponents.map((component) => `data-rindle-admin-component="${component}"`),
  ...LEVEL_1_STATES.map((state) => `data-rindle-admin-state="${state}"`),
  'data-rindle-admin-component="button" data-rindle-admin-state="disabled"',
  'data-rindle-admin-component="form-controls" data-rindle-admin-state="focus-visible"',
  'data-rindle-admin-error-state',
  'Rindle Admin could not load this surface. Retry load or check Runtime/Doctor for the missing source artifact.',
];
const missingSnippets = requiredSnippets.filter((needle) => !html.includes(needle));
if (missingSnippets.length) {
  throw new Error(`gallery contract missing: ${missingSnippets.join(', ')}`);
}

mkdirSync(galleryDir, { recursive: true });
writeFileSync(galleryPath, html);
console.log(`admin gallery written to ${galleryPath}`);
