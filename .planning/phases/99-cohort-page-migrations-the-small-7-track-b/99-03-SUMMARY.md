---
phase: 99-cohort-page-migrations-the-small-7-track-b
plan: 03
subsystem: cohort-design-system
status: complete
tags: [cohort, migration, ops, account, erasure, ck-btn, ck-output, phx-click, frozen-contract, class-by-class]
requirements: [COHORT-03, COHORT-04]
dependency_graph:
  requires:
    - "ck_page/1 scaffold (Phase 99 P01)"
    - ".ck-output token-only <pre> surface (Phase 99 P01)"
    - "cohort-pages.spec.js shared assertCohortPagePolish harness (Phase 99 P01)"
    - "cohort_migration_contract_test.exs shared assert_frozen_contract/2 + assert_daisyui_retired/1 (Phase 99 P01)"
    - ".ck-btn / .ck-btn--primary / .ck-toolbar / .ck-section CSS (Phase 96)"
    - "support/cohort.js MEMBERS + memberId (existing e2e harness)"
  provides:
    - "/ops migrated onto ck_page/1 — bare .ck-btn phx-click buttons + .ck-output panels (COHORT-03)"
    - "/account/:id/delete erasure migrated onto ck_page/1 — same two shapes (COHORT-04)"
    - "/ops + /account polish cases (warn mode) in cohort-pages.spec.js"
    - "/ops + /account frozen-contract + daisyUI-retirement tests in cohort_migration_contract_test.exs"
    - "the sole runtime consumers of the P01 .ck-output rule"
  affects:
    - "ops-surfaces.spec.js / batch-erasure.spec.js / owner-erasure.spec.js (frozen contract preserved; CI-delegated this run)"
    - "Phase 99 P4-P5 (remaining small-7 migrations follow this exact pattern)"
tech_stack:
  added: []
  patterns:
    - "interactive <button phx-click> keeps its element; only class swaps to bare .ck-btn / .ck-btn--primary (Pitfall 4 — NOT ck_button/1 which is link-only)"
    - "<pre :if=...> debug panels swap daisyUI bg-gray-100 for the P01 token-only .ck-output; id/testid/:if byte-for-byte"
    - "button rows -> .ck-toolbar; batch section -> .ck-section/.ck-section__head/__title"
    - "server-owned theme default light in mount assigns (D-96-07)"
    - "<pre :if> output panels are the behavior-spec backstop (handlers touch the erasure/storage subsystem) — ExUnit asserts the always-present static body contract + every phx-click handler, not a force-click"
    - "Playwright behavior lane CI-delegated when local Postgres saturates (Phase-98 / P02 precedent)"
key_files:
  created: []
  modified:
    - examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex
    - examples/adoption_demo/lib/adoption_demo_web/live/account_live.ex
    - examples/adoption_demo/e2e/cohort-pages.spec.js
    - examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs
decisions:
  - "Batch-section <p> (\"Preview + execute for seeded students\") left UNCLASSED rather than given a .ck-muted class: .ck-muted exists only as a token (--ck-muted), NOT a class, and the plan HARD-forbids adding CSS here (P01 owns CSS). The unclassed <p> inherits the .ck cascade defaults — identical to P02's decision to leave the dashboard lists unclassed."
  - "ExUnit /ops + /account tests assert the ALWAYS-PRESENT static body contract (the four/two phx-click buttons, batch section, member-name, every phx-click handler, data-ck-root) + daisyUI-retirement, and do NOT force-click the handlers. The <pre :if=...> output panels render only after run_doctor/preview_batch/preview/execute fire, and those handlers call Rindle.preview_owner_erasure/erase_* which touch the erasure/storage subsystem (MinIO) — not bootable in the static ExUnit lane. The <pre> id/testid survival is grep-verified in source (per-page acceptance) and exercised at runtime by ops-surfaces/batch-erasure/owner-erasure. This is the plan's offered 'assert always-present selectors statically' approach, documented."
  - "/account polish-case member id derived at runtime via support/cohort's memberId(page, MEMBERS.alex) after visiting /dashboard — byte-identical to how owner-erasure.spec.js navigates to /account/:id/delete; no new harness logic."
  - "run-doctor/execute-batch/execute-erasure buttons get .ck-btn--primary; the secondary actions (runtime-status, preview-batch, preview-erasure) get bare .ck-btn — a presentation-only choice within the .ck-btn family."
metrics:
  duration_min: 5
  tasks: 3
  files: 4
  completed: "2026-06-18"
---

# Phase 99 Plan 03: /ops + /account Migration onto ck_page/1 Summary

Migrated `/ops` (`ops_live.ex`, COHORT-03) and `/account/:member_id/delete` (`account_live.ex`, COHORT-04 erasure) onto the P01 `ck_page/1` scaffold class-by-class — the two pages that share the same two migration shapes and are the sole runtime consumers of the P01 `.ck-output` rule. Every interactive `<button phx-click>` kept its element and only swapped `class="btn"` for the BARE `.ck-btn`/`.ck-btn--primary` (Pitfall 4 — `ck_button/1` is link-only and would drop `phx-click`); every `<pre :if=...>` debug panel swapped daisyUI `bg-gray-100` for the token-only `.ck-output`. Added `/ops` + `/account` polish cases (warn mode) to `cohort-pages.spec.js` and `/ops` + `/account` frozen-contract + daisyUI-retirement tests to the ExUnit contract module; all four ExUnit tests green.

## What Was Built

### Task 1 — /ops render/1 onto ck_page/1 (commit c00f541)
- Wrapped the `render/1` body in `<.ck_page title="Operator surfaces" lede="Doctor, runtime status, and batch owner erasure." theme={@theme}>` inside the kept `<Layouts.app>` chrome; added `theme: "light"` to `mount/3` assigns (D-96-07) and `import AdoptionDemoWeb.CohortComponents`. The `<h1>`/`<p>` header moved into the scaffold `:title`/`:lede`.
- All four `<button phx-click>` (`run_doctor`, `run_runtime_status`, `preview_batch`, `execute_batch`) kept their element + `id` + `data-testid` byte-for-byte; only `class="btn"` swapped to bare `.ck-btn` (secondaries) / `.ck-btn--primary` (run-doctor, execute-batch) — Pitfall 4, no `ck_button/1`.
- All four `<pre :if=...>` panels (`doctor-output`, `runtime-status-output`, `batch-preview`, `batch-result`) swapped `bg-gray-100 …` for the P01 token-only `.ck-output`; `id`/`data-testid`/`:if` kept.
- `batch-erasure` `<section>` -> `.ck-section` + `.ck-section__head`/`.ck-section__title` (id/testid kept); button rows -> `.ck-toolbar`; every `<span data-testid={"batch-member-#{email}"}>` kept byte-for-byte.
- All daisyUI/Tailwind body utilities removed (`btn`/`bg-gray-100`/`text-2xl`/`text-lg`/`text-sm`/`text-xs`/`opacity-80`/`font-semibold`/`space-y-3`/`flex gap-3`/`mt-*`/`p-3`/`overflow-x-auto`); no `raw/1`; no new CSS.

### Task 2 — /account erasure render/1 onto ck_page/1 (commit d7f9bb1)
- Wrapped the body in `<.ck_page title="Owner erasure demo" theme={@theme}>` inside the kept `<Layouts.app>`; added `theme: "light"` to `mount/3` and the CohortComponents import.
- `erasure-member-name` `<p>` kept (testid + "Member: …" text), unclassed (inherits `.ck`).
- Both `<button phx-click>` (`preview`, `execute`) kept element + id + testid; `class="btn"` -> bare `.ck-btn` (preview) / `.ck-btn--primary` (execute) — Pitfall 4. Row -> `.ck-toolbar`.
- Both `<pre :if=...>` (`erasure-preview`, `erasure-result`) swapped `bg-gray-100 …` for `.ck-output`; id/testid/:if kept.
- daisyUI retired from body; no `raw/1`; no new CSS.

### Task 3 — polish cases + ExUnit frozen-contract tests (commit df9a413)
- `cohort-pages.spec.js`: a `test("/ops …")` and a `test("/account erasure …")` calling the shared `assertCohortPagePolish(page, {route, surface})` (warn mode). The `/account` route id is derived at runtime via `memberId(page, MEMBERS.alex)` after visiting `/dashboard` — the owner-erasure navigation idiom. No harness logic duplicated; `admin-polish.js` untouched.
- `cohort_migration_contract_test.exs`: a `/ops` test (seeds two students for the batch-member spans) asserting the four `phx-click` handlers, the four/two buttons, `batch-erasure-section`, `id="batch-erasure"`, `data-ck-root`, then `assert_daisyui_retired/1`; and an `/account` test (seeds a member) asserting `erasure-member-name`, both buttons, `phx-click="preview"`/`"execute"`, `data-ck-root`, then `assert_daisyui_retired/1`.

## Verification

- `MIX_ENV=test mix compile` -> no errors for `ops_live.ex` / `account_live.ex` (pre-existing test-only Mox warnings filtered).
- `mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` -> **4 tests, 0 failures** (styleguide smoke + /dashboard + /ops + /account). The `Oban.Notifiers.Postgres … too_many_connections` line is a noisy background log, not a test failure.
- `node --check e2e/cohort-pages.spec.js` -> exit 0 (valid JS).
- Acceptance greps on `ops_live.ex`: `<.ck_page`=1, four `phx-click` handlers=4, `ck-output`=4, `bg-gray-`=0, `<.ck_button`=0, `class="btn"`/`text-2xl`=0, `raw(`=0, residual daisyUI utils=0; all frozen ids/testids present (`run-doctor-button`, `run-runtime-status-button`, `doctor-output`, `runtime-status-output`, `batch-erasure-section`, `preview-batch-button`, `execute-batch-button`, `batch-preview`, `batch-result`, `batch-member-`).
- Acceptance greps on `account_live.ex`: `<.ck_page`=1, `phx-click="preview"`/`"execute"`=2, `ck-output`=2, `bg-gray-`=0, `<.ck_button`=0, `class="btn"`/`text-2xl`=0, `raw(`=0; frozen testids present (`erasure-member-name`, `preview-erasure-button`, `execute-erasure-button`, `erasure-preview`, `erasure-result`).
- `git status --porcelain` empty for `admin-polish.js` and `cohort.css` (all CSS is P01).

## Deviations from Plan

None affecting scope — the plan's DECIDE-and-document instructions were exercised:

**1. [Plan-directed decision] `<pre :if>` output panels asserted via behavior specs, not force-clicked in ExUnit.**
- The plan offered: "assert the always-present selectors (buttons/section/member-name) statically and the `<pre>` ids after a `render_click`; pick the approach the sibling specs use and document it." The `<pre :if=...>` panels render only after `run_doctor`/`preview_batch`/`preview`/`execute` fire, and those handlers call `Rindle.preview_owner_erasure`/`erase_*` which touch the erasure/storage subsystem (MinIO) — not bootable in the static ExUnit lane. So the ExUnit tests assert the ALWAYS-PRESENT static body contract (every `phx-click` handler, buttons, batch section, member-name, `data-ck-root`) + daisyUI-retirement; the `<pre>` id/testid survival is grep-verified in source and exercised at runtime by ops-surfaces/batch-erasure/owner-erasure.

**2. [Plan-directed decision] Batch-section `<p>` left unclassed.**
- `.ck-muted` is a token (`--ck-muted`), not a CSS class, and the plan HARD-forbids adding CSS here (P01 owns CSS). The unclassed `<p>` inherits the `.ck` cascade — identical to P02's unclassed-dashboard-lists decision.

**3. [Plan-anticipated] Playwright behavior specs CI-delegated.**
- The local Playwright lane is saturated: `e2e/global-setup.js`'s `mix ecto.create` fails with Postgres `FATAL 53300 too_many_connections`, blocking DB boot (the P02 / Phase-98 precedent). Per the plan's explicit allowance ("CI-delegate if the local lane is saturated — record in SUMMARY"), the runtime backstop is the seeded ExUnit `/ops` + `/account` contract tests (green) plus the `cohort-pages.spec.js` polish cases that run in CI. `ops-surfaces.spec.js`, `batch-erasure.spec.js`, `owner-erasure.spec.js` are CI-delegated.

## Known Stubs

None. Both pages render real seeded data through `ck_page/1`; no empty/placeholder data flows to the UI. The `<pre :if>` panels are gated on real handler output (existing behavior), not stubs.

## Threat Flags

None — no new network endpoint, auth path, file-access pattern, or schema change. T-99-03-01 (link-only `ck_button` dropping `phx-click`) is mitigated: every `phx-click` handler survives on a bare `.ck-btn` `<button>` (ExUnit asserts all six handlers; `<.ck_button>`=0 in both files). T-99-03-02 (`raw/1` XSS) is mitigated: `grep -c "raw(" = 0` in both files; `.ck-output` is a class swap only, HEEx auto-escape preserved.

## Self-Check: PASSED

- FOUND: examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex (<.ck_page)
- FOUND: examples/adoption_demo/lib/adoption_demo_web/live/account_live.ex (<.ck_page)
- FOUND: examples/adoption_demo/e2e/cohort-pages.spec.js (/ops + /account polish cases)
- FOUND: examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs (/ops + /account contract tests)
- FOUND commit: c00f541 (feat 99-03 /ops onto ck_page/1)
- FOUND commit: d7f9bb1 (feat 99-03 /account erasure onto ck_page/1)
- FOUND commit: df9a413 (test 99-03 polish cases + contract tests)
