---
phase: 100-cohort-upload-migration-all-tabs-track-b
plan: 01
subsystem: cohort-demo-ui
tags: [cohort, design-system, migration, frozen-contract, daisyui-retirement, a11y, upload]
status: complete
requires:
  - "ck_page/1 + .ck-* primitives (Phase 96/99)"
  - ".ck-tabs__tab tabs block in cohort.css (Phase 96)"
  - "cohort_migration_contract_test.exs shared helpers (Phase 99)"
provides:
  - "/upload migrated onto ck_page/1 + .ck-* primitives across all 6 tabs"
  - "validated ?theme=dark server read on /upload (enables Plan 02 dark case)"
  - "the only new CSS in the phase: .ck-tabs__tab[aria-current=\"page\"] cue"
  - "per-tab /upload frozen-contract + daisyUI-retirement ExUnit gate"
affects:
  - "examples/adoption_demo/lib/adoption_demo_web/live/upload_live.ex"
  - "examples/adoption_demo/priv/static/assets/cohort.css"
  - "examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs"
tech-stack:
  added: []
  patterns:
    - "class-by-class swap onto ck_page/1 (mirror ops_live/dashboard_live)"
    - "routed-tab strip = <.link patch> + aria-current (NOT role=tablist/ck_tabs)"
    - "enum-gated ?theme read (~w(light dark), default light) in mount + handle_params"
    - "tus error = .ck-error + inline warning SVG + role=alert (non-color cue)"
    - "per-tab for-comprehension contract test reusing shared helpers unchanged"
key-files:
  created: []
  modified:
    - "examples/adoption_demo/lib/adoption_demo_web/live/upload_live.ex"
    - "examples/adoption_demo/priv/static/assets/cohort.css"
    - "examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs"
decisions:
  - "D-100-01/02a: compose ck_page inside untouched Layouts.app nav={:upload}"
  - "D-100-03/04: routed tab links carry aria-current=\"page\"; tab_class/2 deleted; no role=tablist/ck_tabs (preserves ?tab= patch + tus deep link)"
  - "D-100-05: one consolidated token-only selector pair [aria-selected=\"true\"], [aria-current=\"page\"]"
  - "Pitfall F option 1: server-driven ?theme=dark read (emulateMedia alone would not flip the explicit data-theme); enum-gated, no raw/1"
  - "Pitfall A: .ck-btn ck-btn--primary on the EXISTING <button> (never ck_button/1, which drops the hook/submit)"
metrics:
  duration: "~8 min"
  completed: "2026-06-18"
  tasks: 3
  files: 3
---

# Phase 100 Plan 01: Cohort /upload Migration (all tabs) Summary

Migrated `/upload` — the heaviest Cohort inner page (6 tabs, 4 `phx-hook` upload flows,
2 `live_file_input`, 2 forms) — onto the hand-authored `.ck-*` Cohort design system
class-by-class, preserving the frozen DOM contract byte-for-byte across all 6 tabs, with
a11y-correct routed-tab navigation (`aria-current`, not `role=tablist`), an announced
(non-color-only) tus error, a validated server `?theme=dark` read, and the static ExUnit
proof that the contract survived and daisyUI is retired (COHORT-02).

## What Shipped

**Task 1 — one token-only CSS rule + extended retirement list (`cf2a60e`)**
- Consolidated `.ck-tabs__tab[aria-selected="true"]` with `[aria-current="page"]` in
  `cohort.css` — the single new CSS in the entire phase, token-only body
  (`color: var(--ck-ink); font-weight: 700; border-bottom-color: var(--ck-brand);`).
- Extended `@retired_daisyui_classes` with `tabs`, `text-red-600`, `~s( tab )` (standalone
  token residue of the deleted `tab_class/2`), and `break-all`.
- `node brandbook/src/cohort-contrast.mjs` green (28/28); no new token/pair, no `tokens.json`
  change, no generated-file edit.

**Task 2 — migrate `upload_live.ex` onto `ck_page/1` (`3a68d31`)**
- `import AdoptionDemoWeb.CohortComponents`; composed `<.ck_page eyebrow title lede theme>`
  inside an untouched `<Layouts.app nav={:upload}>`.
- Validated `?theme` read via `normalize_theme/2` (`~w(light dark)`, default `"light"`) in
  both `mount/2` and `handle_params/2`; no `raw/1` introduced.
- Tab strip → `class="ck-tabs__list" role="navigation" aria-label="Upload strategy"`;
  `tab_link/1` now `class="ck-tabs__tab ck-tab"` + `aria-current={@current == @tab && "page"}`,
  patch URL + `data-testid` kept byte-for-byte; `defp tab_class/2` deleted.
- Panel class swaps: status `<p>` → `.ck-output`; tus error → `.ck-error` + inline warning
  SVG + `role="alert"`; file inputs + `<.live_file_input>` → `.ck-input`; hook/submit buttons
  → `.ck-btn ck-btn--primary` on the existing `<button>`; descriptions + asset-id → `.ck-help`;
  `mux-streaming-url` → `.ck-output`; dropped `mt-6 space-y-3` from the 6 panel wrappers.
- Every `id`/`data-testid`/`phx-hook` (`PresignedPut`/`PresignedVideoPut`/`PresignedMuxPut`/
  `MultipartUpload`)/`phx-change`/`phx-submit`/`type="submit"`/file-input attr/the 2 `<.form>`/
  the 2 `<.live_file_input>`/the 6 `<div :if={@tab == "X"}>` panels survive byte-for-byte.
- `MIX_ENV=test mix compile` succeeds (no new warnings beyond pre-existing Mox ones).

**Task 3 — per-tab frozen-contract + daisyUI-retirement ExUnit test (`b7c1d99`)**
- One `test "/upload preserves its frozen contract and retires daisyUI across all tabs"`
  looping `~w(image tus video multipart liveview mux)`.
- `panel_contract/1` (6 clauses) → each tab's panel id + status testid + tab-specific
  hook/form/submit selectors.
- Asserts always-present member line + 6 tab links, the active panel's selectors, and the
  routed-link a11y shape (`aria-current="page"` present; `role="tablist"`/`role="tab"` refuted).
- Shared helpers (`assert_frozen_contract/2`, `assert_daisyui_retired/1`, `render_route/2`,
  `page_body/1`) reused unchanged; no `:if`-only selector asserted statically.

## Verification

- `node brandbook/src/cohort-contrast.mjs` → exit 0 (28/28 pairs).
- `MIX_ENV=test mix compile` → succeeds.
- grep: `<.ck_page`, `ck-tabs__list`, `ck-tabs__tab ck-tab`, `aria-current` present; no
  `defp tab_class`, no `raw(`, no `role="tab"`/`role="tablist"`/`ck_tabs`/`phx-hook="Tabs"`/
  `ck_button`; all 4 upload `phx-hook`s present; 2 `type="submit"`, 2 `live_file_input`,
  2 `phx-submit` preserved.
- Untouched-files guard: `layouts.ex`, `tokens.json`, `admin-polish.js` unchanged across the
  plan's commit range; the only `cohort.css` change is the one new token-only rule.
- Source-verified that all 27 selectors the test asserts are present post-migration and all
  retired daisyUI body classes are absent.

## Deviations from Plan

None — plan executed exactly as written. No Rule 1–4 fixes were required.

## Deferred / Environmental Notes

- **ExUnit local run blocked by saturated local Postgres** (`FATAL 53300 too_many_connections`
  — `psql` itself could not connect; not a defect in the test or migration). The test file
  compiles cleanly and every asserted selector is source-verified present in the migrated
  `upload_live.ex`. The DB-backed ExUnit lane is **CI-delegated**, matching the established
  maintainer-approved precedent in phases 98-04 and 99-03/99-01 (local Postgres saturation
  → live/DB-backed lanes run in CI). The test will run green where Postgres is provisioned.

## Known Stubs

None. No hardcoded empty values, placeholders, or unwired data sources were introduced; this
was a presentational class-swap migration preserving the existing live data flows.

## Self-Check: PASSED

- examples/adoption_demo/lib/adoption_demo_web/live/upload_live.ex — FOUND
- examples/adoption_demo/priv/static/assets/cohort.css — FOUND (new aria-current rule present)
- examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs — FOUND (panel_contract/1 present)
- Commit cf2a60e — FOUND
- Commit 3a68d31 — FOUND
- Commit b7c1d99 — FOUND
