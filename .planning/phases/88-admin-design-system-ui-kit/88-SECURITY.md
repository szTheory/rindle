---
phase: 88
slug: admin-design-system-ui-kit
status: verified
threats_open: 0
asvs_level: 1
created: 2026-06-11
register_authored_at_plan_time: true
---

# Phase 88 - Security

Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| token JSON -> generator | `brandbook/tokens/tokens.json` drives generated admin CSS and contrast checks. | Brand token names and values |
| generator -> generated CSS | Node scripts write the generated `brandbook/tokens/rindle-admin.css` asset. | CSS variables, selectors, theme scopes |
| generated CSS -> host app | Future host pages may include the CSS; selectors must stay namespaced and self-contained. | Static stylesheet loaded by downstream console UI |
| maintainer scripts -> local filesystem | Brandbook scripts write generated assets, gallery HTML, and review screenshots under `brandbook/`. | Local generated files and PNG artifacts |
| generated gallery -> browser | Static HTML and inline theme behavior execute locally for maintainer review. | Local DOM state and fixture data |
| theme picker -> DOM attribute | Theme controls write the trusted `data-theme` value used by CSS. | `light`, `dark`, or `auto` theme state |
| gallery examples -> future implementation | Gallery markup becomes the reference pattern consumed by later admin console phases. | Component examples and stable test selectors |
| guide -> downstream executors | Future phases use `guides/admin_design_system.md` as the operating contract. | Commands, package-boundary rules, dependency prohibitions |
| review screenshots -> maintainer decision | Human review relies on generated local artifacts, not production data. | Hardcoded gallery fixture screenshots |
| package boundary -> Hex artifact | Phase 88 assets stay under `brandbook/`; later `priv/static/rindle_admin` serving changes package behavior. | Package inclusion policy and static asset paths |
| maintainer checkpoint -> workflow state | Execution pauses until explicit approval or change requests are recorded. | Human approval recorded in phase artifacts |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-88-01 | Tampering | `brandbook/tokens/rindle-admin.css` | mitigate | Generated header plus `brandbook/src/admin-css-build.mjs` parity checks; current run rewrote CSS and reported `23 selectors, 4 theme scopes, parity OK`. | closed |
| T-88-02 | Tampering | CSS dependency boundary | mitigate | Static forbidden-dependency/style scan passed for Tailwind, daisyUI, shadcn, Radix, `@apply`, generic `btn`/`card`, `.dark`, `theme-dark`, and host asset-pipeline leakage. | closed |
| T-88-03 | Information Disclosure | Lifecycle/status components | mitigate | `CONSOLE_CONTRAST_PAIRS` covers all status states and `node brandbook/src/admin-contrast.mjs` passed `38/38 pairs`; gallery uses visible labels and non-color state marks. | closed |
| T-88-04 | Denial of Service | Future non-console adopters | mitigate | Phase 88 stayed in Node/static brandbook assets; no Elixir runtime code was touched and `mix test test/rindle/api_surface_boundary_test.exs` passed. | closed |
| T-88-05 | Spoofing | Theme/status semantics | mitigate | `THEMES` and `STATUS_STATES` are allowlisted in `brandbook/src/admin-design-system-data.mjs`; generator parity checks required state selectors and theme scopes. | closed |
| T-88-06 | Spoofing | Theme picker | mitigate | Gallery controls use only `data-theme="light|dark|auto"`; `brandbook/src/admin-gallery-check.mjs` clicked all three controls and asserted exact DOM values. | closed |
| T-88-07 | Tampering | Component gallery source | mitigate | Gallery is generated from allowlisted design-system data and generated CSS; `node brandbook/src/admin-gallery.mjs` and `node brandbook/src/admin-gallery-check.mjs` passed. | closed |
| T-88-08 | Information Disclosure | Static gallery examples | mitigate | Gallery fixtures are hardcoded review data; summaries report no threat flags and no production media, secrets, env vars, or real owner data. | closed |
| T-88-09 | Denial of Service | Screenshot harness | mitigate | Browser checks render the static `file://` gallery, close the browser, and recreate the bounded seven-file screenshot set. | closed |
| T-88-10 | Elevation of Privilege | Phase boundary | mitigate | Phase artifacts and guide state no router macro, auth contract, `Plug.Static`, CSP/socket option, `Rindle.Admin.Queries`, or production route was implemented. | closed |
| T-88-11 | Repudiation | Maintainer review workflow | mitigate | `88-03-SUMMARY.md`, `88-VERIFICATION.md`, and `88-HUMAN-UAT.md` record the post-fix maintainer gallery approval. | closed |
| T-88-12 | Information Disclosure | Review screenshots | mitigate | Screenshot artifacts are generated from hardcoded gallery fixtures under `brandbook/admin-gallery/screenshots/`; no production data is rendered. | closed |
| T-88-13 | Tampering | Downstream guide | mitigate | `guides/admin_design_system.md` documents exact commands, package boundary, forbidden dependencies, theme contract, and Phase 89-owned serving surfaces. | closed |
| T-88-14 | Elevation of Privilege | Admin integration boundary | mitigate | The guide explicitly excludes router/auth/static-serving/query/production-route implementation from Phase 88; boundary test remained green. | closed |
| T-88-15 | Denial of Service | Package boundary | mitigate | The guide states no `mix.exs` package-file change is needed while assets stay under `brandbook/`; moving to `priv/static/rindle_admin` requires a package-file assertion. | closed |
| T-88-SC | Tampering | npm installs | accept | No package-manager install task was planned or performed; existing Playwright/opentype dependencies were reused from the audited local setup. | closed |

Status: open or closed. Disposition: mitigate, accept, or transfer.

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-88-01 | T-88-SC | Phase 88 reused existing local Node/Playwright dependencies and did not perform package-manager installs; supply-chain risk is accepted for this completed phase. | maintainer via plan-time disposition | 2026-06-11 |

Accepted risks do not resurface in future audit runs.

---

## Verification Evidence

| Check | Result |
|-------|--------|
| `node brandbook/src/admin-css-build.mjs` | PASS - `rindle-admin.css written - 23 selectors, 4 theme scopes, parity OK` |
| `node brandbook/src/admin-contrast.mjs` | PASS - `admin contrast: 38/38 pairs pass` |
| `node brandbook/src/admin-gallery.mjs` | PASS - regenerated `brandbook/admin-gallery/index.html` |
| `node brandbook/src/admin-gallery-check.mjs` | PASS - `admin gallery check passed - 7 screenshots written` |
| `node brandbook/src/contrast.mjs` | PASS - `38/38 pairs pass` |
| `mix test test/rindle/api_surface_boundary_test.exs` | PASS - 17 tests, 0 failures |
| Forbidden dependency/style scan | PASS - no forbidden UI framework, registry, `@apply`, generic `btn`/`card`, `.dark`, `theme-dark`, or host asset-pipeline leakage |
| Summary threat flags | PASS - `88-01-SUMMARY.md`, `88-02-SUMMARY.md`, and `88-03-SUMMARY.md` report `Threat Flags: None` |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-06-11 | 16 | 16 | 0 | Codex `gsd-secure-phase` |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

Approval: verified 2026-06-11
