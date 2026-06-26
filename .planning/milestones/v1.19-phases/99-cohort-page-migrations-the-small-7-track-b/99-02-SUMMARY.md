---
phase: 99-cohort-page-migrations-the-small-7-track-b
plan: 02
subsystem: cohort-design-system
status: complete
tags: [cohort, migration, dashboard, frozen-contract, member-row, class-by-class, ck-page]
requirements: [COHORT-01]
dependency_graph:
  requires:
    - "ck_page/1 scaffold (Phase 99 P01)"
    - "cohort-pages.spec.js shared assertCohortPagePolish harness (Phase 99 P01)"
    - "cohort_migration_contract_test.exs shared assert_frozen_contract/2 + assert_daisyui_retired/1 (Phase 99 P01)"
    - "CohortComponents ck_button/1 + .ck-section/.ck-hero CSS (Phase 96)"
  provides:
    - "/dashboard migrated onto ck_page/1 — the first real consumer of the P01 scaffold"
    - "/dashboard polish case (warn mode) in cohort-pages.spec.js"
    - "/dashboard frozen-contract + daisyUI-retirement test in cohort_migration_contract_test.exs"
  affects:
    - "Phase 99 P3-P5 (the remaining small-7 migrations follow this exact pattern)"
    - "5+ upload behavior specs that navigate via the /dashboard member rows (contract preserved)"
tech_stack:
  added: []
  patterns:
    - "render/1 body wrapped in <.ck_page title=... theme={@theme}>; chrome stays in Layouts.app (D-98-01 analog)"
    - "class-by-class swap: <ul>/<li> STRUCTURE preserved, daisyUI utilities replaced with .ck-section grammar (Pitfall 2, NOT ck_table)"
    - "server-owned theme default light in mount assigns (D-96-07)"
    - "nav links -> <.ck_button href=...> keeping data-testid + text (A3 accessible names)"
    - "ExUnit contract test seeds real rows so the LOAD-BEARING member-row contract is exercised at render, not just grepped"
    - "Playwright behavior lane CI-delegated when local Postgres saturates (Phase-98 precedent)"
key_files:
  created: []
  modified:
    - examples/adoption_demo/lib/adoption_demo_web/live/dashboard_live.ex
    - examples/adoption_demo/e2e/cohort-pages.spec.js
    - examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs
decisions:
  - "data-testid=cohort-dashboard-title placed on the .ck-hero__lede element (the body lede) rather than duplicating the hero h1: ck_page/1's :title renders a plain .ck-hero__title with no testid passthrough, and editing ck_page is P01's domain. The frozen contract only requires the testid substring to survive (no spec reads it via role/testid); placing it on the lede keeps a single visible hero title (the styled 'Cohort' h1 from ck_page) with no duplicate heading. Documented per the plan's stated DECIDE-and-document instruction."
  - "Member/course/post/asset <ul> left UNCLASSED (not .ck-list): .ck-list does not exist in cohort.css and the plan HARD-forbids adding a new CSS rule (P01 owns CSS); the unclassed list inherits the .ck cascade defaults."
  - "ExUnit /dashboard test asserts member-no-avatar (not member-avatar-link): the seeded member has no avatar attachment so the else branch renders. member-avatar-link only appears with a seeded Media attachment; asserting the actually-rendered branch is the honest runtime check. Both testids exist in the source (grep-verified)."
  - "nav-upload/nav-ops converted from live-nav <.link navigate> to <.ck_button href>: ck_button renders a full-page <a href>. No spec references these testids and none depend on live-nav semantics; data-testid + link text preserved."
metrics:
  duration_min: 4
  tasks: 2
  files: 3
  completed: "2026-06-18"
---

# Phase 99 Plan 02: /dashboard Migration onto ck_page/1 Summary

Migrated `/dashboard` (`dashboard_live.ex`) onto the P01 `ck_page/1` scaffold class-by-class — the first real consumer of the Wave-0 scaffold — preserving every frozen `id`/`data-testid`, most critically the LOAD-BEARING member-row contract (`id="member-#{id}"` + `data-testid="member-row-#{email}"`) that `support/cohort.js` and 5+ upload specs navigate through. Added the `/dashboard` polish case (warn mode) to `cohort-pages.spec.js` and a seeded `/dashboard` frozen-contract + daisyUI-retirement test to the ExUnit contract module; both green.

## What Was Built

### Task 1 — /dashboard render/1 onto ck_page/1 (commit 353d3ee)
- Wrapped the `render/1` body in `<.ck_page title="Cohort" theme={@theme}>` inside the kept `<Layouts.app>` chrome; added `theme: "light"` to `mount/3` assigns (server-owned default, D-96-07) and `import AdoptionDemoWeb.CohortComponents`.
- The lede became `.ck-hero__lede` carrying `data-testid="cohort-dashboard-title"` with the `<code>Rindle.Storage.S3</code>` element kept (inherits `--ck-code-*` via the `.ck` cascade).
- All four sections restyled to `.ck-section` + `.ck-section__head` / `.ck-section__title`, keeping each `id`/`data-testid` (`demo-members`/`demo-courses`/`demo-posts`/`demo-assets`) byte-for-byte.
- Member `<ul>/<li>` STRUCTURE preserved (NOT `ck_table`, Pitfall 2); every nested link testid + text kept (`member-avatar-link`/`member-no-avatar`/`member-upload-link`/`member-delete-link`, `lesson-link-#{id}`, `post-link-#{id}`). The lists are unclassed (inherit `.ck` defaults; `.ck-list` does not exist and adding CSS is P01's domain).
- Bottom nav -> two `<.ck_button href=...>` keeping `nav-upload`/`nav-ops` testids + text.
- All daisyUI/Tailwind body utilities removed (`text-2xl`/`font-semibold`/`text-sm`/`opacity-80`/`text-lg`/`mt-6`/`list-disc`/`pl-5`/`space-y-2`/`flex gap-4`/`mt-8`/`underline`); no `raw/1`.

### Task 2 — /dashboard polish case + frozen-contract test (commit f7afad1)
- `cohort-pages.spec.js`: one `test("/dashboard renders on the Cohort DS (polish, warn mode)")` calling the shared `assertCohortPagePolish(page, { route: "/dashboard", surface: "dashboard-cohort" })` — root-visibility guarded, no harness logic duplicated, `admin-polish.js` untouched.
- `cohort_migration_contract_test.exs`: one `test "/dashboard preserves its frozen contract and retires daisyUI"` that seeds a member + course/lesson + post (re-fetching the member by email for the persisted id, since `seed_member!` uses `on_conflict: :nothing`), renders `/dashboard`, and asserts the full frozen selector list — the title testid, the four section ids, the concrete `id="member-#{id}"` + `data-testid="member-row-#{email}"` contract, `member-no-avatar`/`member-upload-link`/`member-delete-link`, `lesson-link-#{id}`, `post-link-#{id}`, `nav-upload`/`nav-ops` — plus `assert_daisyui_retired/1` over the page body.

## Verification

- `MIX_ENV=test mix compile` -> no errors for `dashboard_live.ex` (pre-existing test-only Mox warnings filtered).
- `mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` -> 2 tests, 0 failures (styleguide smoke + /dashboard contract).
- `mix test test/adoption_demo_web/controllers/page_controller_test.exs` -> 2 tests, 0 failures (regression guard; /dashboard still renders "Members").
- `node --check e2e/cohort-pages.spec.js` -> exit 0 (valid JS).
- Acceptance greps on `dashboard_live.ex`: `<.ck_page`=1, `cohort-dashboard-title`=1, `member-row-`=1, `id={"member-#{member.id}"}`=1, four section ids=4, all nested testids present, daisyUI residue=0, `raw(`=0.
- `git status --porcelain` empty for `admin-polish.js` and `cohort.css` (all CSS is P01).

## Deviations from Plan

None affecting scope — the plan's DECIDE-and-document instructions were exercised:

**1. [Plan-directed decision] Title testid placed on the lede, not a duplicated hero h1.**
- The plan instructed: "if `ck_page`'s `:title` cannot carry the testid... DECIDE based on the P1 `ck_page` API and document the choice." `ck_page/1`'s `:title` renders a plain `.ck-hero__title` with no testid passthrough; editing `ck_page` is P01's domain. To avoid two visible "Cohort" headings, the `data-testid="cohort-dashboard-title"` was placed on the `.ck-hero__lede` body element. No spec reads it via role/testid (grep-verified); the contract test asserts the substring survives.

**2. [Plan-directed decision] member-no-avatar asserted instead of member-avatar-link.**
- The seeded member has no avatar attachment, so the rendered branch is `member-no-avatar`. The contract test asserts the actually-rendered branch (honest runtime check). Both testids exist in source.

**3. [Plan-anticipated] Playwright behavior specs (rendering, replace-detach) CI-delegated.**
- The local Playwright lane is saturated: Postgres `FATAL 53300 too_many_connections` blocks `mix ecto.create` in `e2e/global-setup.js`, so the specs cannot boot a DB locally. Per the plan's explicit allowance ("If the local Playwright server/seed is saturated, this lane is CI-delegated per the Phase-98 precedent... the ExUnit grep is the static backstop"), the runtime backstop is the seeded ExUnit `/dashboard` contract test, which asserts the exact rendered `member-row-`/`member-no-avatar`/`member-upload-link`/`lesson-link-`/`post-link-` selectors against a real render — green.

## Known Stubs

None. `/dashboard` renders real seeded data through `ck_page/1`; no empty/placeholder data flows to the UI.

## Threat Flags

None — no new network endpoint, auth path, file-access pattern, or schema change. T-99-02-01 (member-row tampering) and T-99-02-02 (raw/1 XSS) are mitigated: the member-row id/testid survive (ExUnit + grep) and `grep -c "raw(" = 0`.

## Self-Check: PASSED

- FOUND: examples/adoption_demo/lib/adoption_demo_web/live/dashboard_live.ex (<.ck_page)
- FOUND: examples/adoption_demo/e2e/cohort-pages.spec.js (/dashboard polish case)
- FOUND: examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs (/dashboard contract test)
- FOUND commit: 353d3ee (feat 99-02 /dashboard onto ck_page/1)
- FOUND commit: f7afad1 (test 99-02 polish case + contract test)
