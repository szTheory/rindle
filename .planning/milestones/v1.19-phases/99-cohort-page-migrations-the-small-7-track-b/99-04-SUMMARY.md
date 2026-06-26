---
phase: 99-cohort-page-migrations-the-small-7-track-b
plan: 04
subsystem: cohort-design-system
status: complete
tags: [cohort, migration, member, lesson, picture-tag, video-tag, variant-list, ck-btn, ck-output, frozen-contract, class-by-class]
requirements: [COHORT-04]
dependency_graph:
  requires:
    - "ck_page/1 scaffold (Phase 99 P01)"
    - ".ck-output token-only mono surface (Phase 99 P01)"
    - ".ck-section / .ck-section__head / .ck-section__title / .ck-btn / .ck-btn--primary / .ck-toolbar CSS (Phase 96)"
    - "cohort-pages.spec.js shared assertCohortPagePolish harness (Phase 99 P01)"
    - "cohort_migration_contract_test.exs shared assert_frozen_contract/2 + assert_daisyui_retired/1 (Phase 99 P01)"
    - "support/cohort.js MEMBERS + memberId (existing e2e harness)"
  provides:
    - "/members/:id migrated onto ck_page/1 — avatar + replace/detach contracts preserved (COHORT-04)"
    - "/lessons/:id migrated onto ck_page/1 — video + variant-list contracts preserved (COHORT-04)"
    - "/members + /lessons polish cases (warn mode) in cohort-pages.spec.js"
    - "/members + /lessons frozen-contract + daisyUI-retirement tests in cohort_migration_contract_test.exs"
  affects:
    - "rendering.spec.js / replace-detach.spec.js (frozen contract preserved; CI-delegated this run)"
    - "Phase 99 P5 (remaining small-7 migrations follow this exact pattern)"
tech_stack:
  added: []
  patterns:
    - "ck_page :title given a contextual label (Member/Lesson); the dynamic name carries the frozen testid on an explicit .ck-hero__title h1 in :inner_block (mirrors P2's dashboard title-on-element decision)"
    - "interactive <button phx-click> keeps its element; only class swaps to bare .ck-btn / .ck-btn--primary (Pitfall 4 — NOT ck_button/1 which is link-only)"
    - "picture_tag / video_tag wrapper <div> + their library class: option strings left UNCHANGED (img/video attributes, not page chrome)"
    - "variant <ul>/<li id=variant-#{name} data-testid=variant-#{name}> kept byte-for-byte — NOT converted to ck_table (Pitfall 2)"
    - "single-line mono status / long URL lines (replace-status, lesson-streaming-url) reuse the P01 token-only .ck-output surface — no new CSS"
    - "server-owned theme default light in mount assigns (D-96-07)"
    - "ExUnit asserts the always-present static contract + empty media branch (member-no-avatar / lesson-no-video); the avatar/video/variant branches need the storage subsystem (MinIO) — grep-verified in source + runtime-exercised by rendering.spec.js (CI-delegated)"
key_files:
  created: []
  modified:
    - examples/adoption_demo/lib/adoption_demo_web/live/member_live.ex
    - examples/adoption_demo/lib/adoption_demo_web/live/lesson_live.ex
    - examples/adoption_demo/e2e/cohort-pages.spec.js
    - examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs
decisions:
  - "ck_page :title is a contextual label (\"Member\"/\"Lesson\") and the dynamic member.name/lesson.title carries the frozen data-testid on an explicit <h1 class=\"ck-hero__title\"> inside :inner_block. This mirrors P2's dashboard decision (ck_page title=\"Cohort\" + the testid on a hero element holding the dynamic content). It is required because replace-detach.spec.js asserts member-profile-title toContainText(\"Alex\") — the testid element MUST hold the name — and ck_page's :title h1 cannot carry a data-testid. The contextual hero label sits above the named h1."
  - "replace-status (a single-line mono <p>, formerly font-mono text-sm) and lesson-streaming-url (a break-all URL <p>) both reuse the P01 token-only .ck-output surface rather than authoring a new CSS rule — the plan forbids new CSS here (P01 owns CSS) and .ck-output is the existing token-backed mono surface (mirrors P03's <pre> usage). No new --ck-* token, no cohort.css change."
  - "ExUnit /members + /lessons tests assert the ALWAYS-PRESENT static contract (title, both sections, replace-status, both replace/detach phx-click buttons / lesson video+variants sections) PLUS the EMPTY media branch (member-no-avatar / lesson-no-video) against a freshly-seeded member/lesson with NO attached media. The avatar branch (member-picture-tag / member-avatar-state) and the video/variant branch (lesson-video-tag / lesson-asset-state / variant-#{name}) require Media.attach! which touches the storage subsystem (MinIO) — not bootable in the static ExUnit lane (P03 / Phase-98 precedent). Those branch-only selectors are grep-verified in source (per-page acceptance) and exercised at runtime by rendering.spec.js. This is the plan's offered 'assert always-present selectors statically + branch-specific against the appropriate seeded member' approach, documented."
  - "replace/detach + the two media sections wrap their button row / heads in .ck-toolbar / .ck-section__head (matching P03); replace-avatar gets .ck-btn--primary, detach gets bare .ck-btn — a presentation-only choice within the .ck-btn family."
metrics:
  duration_min: 6
  tasks: 3
  files: 4
  completed: "2026-06-18"
---

# Phase 99 Plan 04: /members + /lessons Migration onto ck_page/1 Summary

Migrated `/members/:id` (`member_live.ex`) and `/lessons/:id` (`lesson_live.ex`) onto the P01 `ck_page/1` scaffold class-by-class (COHORT-04) — the two media-detail pages reached from `/dashboard` by the upload/rendering behavior specs. Both share the media-attachment shape (a `Rindle.HTML.picture_tag`/`video_tag` wrapper `<div>` with a frozen id/testid, asset-state lines, an empty fallback); member adds the replace/detach `<button phx-click>` pair and lesson adds the variant `<ul>/<li>` list. Every media-tag wrapper id/testid, state line, variant `<li>` id/testid, and (member) replace/detach handler survived; the variant list was kept as `<ul>/<li>` (NOT ck_table — Pitfall 2); both buttons swapped `class="btn"` for bare `.ck-btn` (Pitfall 4 — no `ck_button/1`); no daisyUI in either body; no `raw/1`; no new CSS. Added `/members` + `/lessons` polish cases (warn mode) and `/members` + `/lessons` frozen-contract + daisyUI-retirement tests; all 6 ExUnit contract tests green.

## What Was Built

### Task 1 — /members/:id render/1 onto ck_page/1 (commit 115dcf8)
- Wrapped `render/1` in `<.ck_page title="Member" theme={@theme}>` inside the kept `<Layouts.app>` chrome; added `theme: "light"` to `mount/2` assigns (D-96-07) and `import AdoptionDemoWeb.CohortComponents`.
- The member name carries `data-testid="member-profile-title"` on an explicit `<h1 class="ck-hero__title">` inside `:inner_block` (replace-detach.spec.js asserts it `toContainText("Alex")`); the email/role line became a `.ck-hero__lede` `<p>`.
- `member-avatar` + `replace-detach` `<section>`s -> `.ck-section` + `.ck-section__head`/`.ck-section__title` (id/testid kept byte-for-byte).
- `<div id="member-picture-tag" data-testid="member-picture-tag">` wrapping `Rindle.HTML.picture_tag(...)` kept UNCHANGED (the `class: "max-w-xs border"` option is a library-rendered `<img>` attribute). `member-avatar-state` / `member-no-avatar` `<p>`s kept (daisyUI text classes stripped).
- `replace-status` `<p>` (formerly `font-mono text-sm`) -> the P01 token-only `.ck-output` mono surface; id/testid kept.
- Both `<button phx-click="replace_avatar"/"detach_avatar">` kept element + id + testid; `class="btn"` -> bare `.ck-btn`/`.ck-btn--primary` (Pitfall 4); the row wrapped in `.ck-toolbar`.
- All daisyUI body utilities removed (`text-2xl`/`text-lg`/`text-sm`/`font-mono`/`font-semibold`/`btn`/`mt-6`/`mt-8`/`space-y-3`); no `raw/1`; no new CSS. handle_event UNCHANGED.

### Task 2 — /lessons/:id render/1 onto ck_page/1 (commit 128bd26)
- Wrapped `render/1` in `<.ck_page title="Lesson" theme={@theme}>` inside the kept `<Layouts.app>`; added `theme: "light"` to `mount/2` and the CohortComponents import.
- The lesson title carries `data-testid="lesson-title"` on an explicit `<h1 class="ck-hero__title">` inside `:inner_block` (rendering.spec.js asserts it visible); the course line became a `.ck-hero__lede` `<p>`.
- `lesson-video` + `lesson-variants` `<section>`s -> `.ck-section` + `.ck-section__head`/`.ck-section__title` (id/testid kept).
- `<div id="lesson-video-tag" data-testid="lesson-video-tag">` wrapping `Rindle.HTML.video_tag(...)` kept UNCHANGED. `lesson-asset-state` / `lesson-no-video` `<p>`s kept; the `:if` `lesson-streaming-url` `<p>` (formerly `text-xs break-all mt-2`) -> the P01 token-only `.ck-output` surface (preserves the `:if` + testid).
- The variant `<ul class="list-disc pl-5">` -> bare `<ul>` (unclassed under `.ck`); EVERY `<li :for={variant} id={"variant-#{variant.name}"} data-testid={"variant-#{variant.name}"}>` kept BYTE-FOR-BYTE — NOT converted to ck_table (Pitfall 2).
- All daisyUI body utilities removed (`text-2xl`/`text-lg`/`text-sm`/`text-xs`/`opacity-80`/`font-semibold`/`break-all`/`list-disc`/`pl-5`/`mt-2`/`mt-6`); no `raw/1`; no new CSS.

### Task 3 — polish cases + ExUnit frozen-contract tests (commit 6136d6b)
- `cohort-pages.spec.js`: a `test("/members …", surface: "member-cohort")` (derives alex's id via `memberId(page, MEMBERS.alex)` after visiting `/dashboard`, the owner-erasure navigation idiom) and a `test("/lessons …", surface: "lesson-cohort")` (navigates via the seeded "Pattern matching basics" lesson link the way rendering.spec.js does, then runs the helper against `page.url()`). Both reuse the shared warn-mode `assertCohortPagePolish`; `admin-polish.js` untouched.
- `cohort_migration_contract_test.exs`: a `/members` test (seeds a member with no avatar) asserting `member-profile-title`, `member-avatar-section`, `member-no-avatar`, `replace-detach-section`, `replace-status`, both replace/detach buttons + `phx-click="replace_avatar"`/`"detach_avatar"`, `data-ck-root`, then `assert_daisyui_retired/1`; and a `/lessons` test (seeds a course + lesson with no video) asserting `lesson-title`, `lesson-video-section`, `lesson-no-video`, `lesson-variants`, `data-ck-root`, then `assert_daisyui_retired/1`.

## Verification

- `MIX_ENV=test mix compile` -> no errors for `member_live.ex` / `lesson_live.ex` (pre-existing test-only Mox warnings filtered, per Phase-96 note).
- `mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` -> **6 tests, 0 failures** (styleguide smoke + /dashboard + /ops + /account + /members + /lessons). The `Postgrex … too_many_connections` / Oban lines are noisy background logs, not test failures.
- `node --check e2e/cohort-pages.spec.js` -> exit 0 (valid JS).
- Acceptance greps on `member_live.ex`: `<.ck_page`=1, `phx-click="replace_avatar"/"detach_avatar"`=2, `<.ck_button`=0, `class="btn"`=0, `text-2xl|font-mono`=0, `raw(`=0, `Rindle.HTML.picture_tag`=1; all 9 frozen ids present; residual daisyUI (`text-lg|text-sm|font-semibold|mt-*|space-y-`)=0.
- Acceptance greps on `lesson_live.ex`: `<.ck_page`=1, `Rindle.HTML.video_tag`=1, `id={"variant-#{variant.name}"}`=1, `data-testid={"variant-#{variant.name}"}`=1, `ck_table`=0, `raw(`=0, `text-2xl|list-disc|opacity-80|break-all`=0; all 7 frozen ids present; residual daisyUI=0.
- `git status --porcelain examples/adoption_demo/e2e/support/admin-polish.js` empty (untouched). No `cohort.css` change (all CSS is P01).
- rendering.spec.js / replace-detach.spec.js: **CI-delegated** — the local Playwright lane cannot boot the web server (Postgres `FATAL 53300 too_many_connections` / Oban migration boot failure, the P03 / Phase-98 saturated-lane precedent). The static backstop is the seeded ExUnit `/members` + `/lessons` contract tests (green) plus the warn-mode polish cases that run in CI; the avatar/video/variant branch selectors are grep-verified in source and exercised at runtime by rendering.spec.js in CI.

## Deviations from Plan

None affecting scope — the plan's DECIDE-and-document instructions were exercised:

**1. [Plan-directed decision] ck_page :title is a contextual label; the dynamic name carries the frozen testid on an explicit hero h1.**
- The plan offered: "if `ck_page`'s `:title` cannot carry a testid, render `<h1 class="ck-hero__title" data-testid="…">` explicitly inside `:inner_block` (mirror the /dashboard decision from P2)." `ck_page`'s `:title` h1 cannot carry a `data-testid`, and replace-detach.spec.js asserts `member-profile-title toContainText("Alex")` (the testid element MUST hold the name). So `:title` is the contextual label `"Member"`/`"Lesson"` and the named h1 with the testid is the first child of `:inner_block` — exactly P2's shape (contextual hero + dynamic testid element).

**2. [Plan-directed decision] replace-status + lesson-streaming-url reuse the existing .ck-output surface.**
- The plan said for `replace-status`: "use an existing `.ck` mono class if one exists … do NOT add a new CSS rule." `.ck-output` (P01, token-only mono) is the existing mono surface; both the single-line `replace-status` and the `break-all` `lesson-streaming-url` reuse it. No new CSS, no `--ck-*` token.

**3. [Plan-directed decision] avatar/video/variant branches asserted via source-grep + behavior specs, not seeded in ExUnit.**
- The plan offered: "render a member known to have an avatar for the avatar branch … OR assert the always-present selectors statically and the branch-specific ones against the appropriate seeded member; document the seed choice." `Media.attach!` (avatar/video) touches the storage subsystem (MinIO) not bootable in the static ExUnit lane, so the ExUnit tests assert the always-present contract + the EMPTY branch (`member-no-avatar`/`lesson-no-video`) against a no-media seed; the media/variant branches are grep-verified in source (per-page acceptance) and runtime-exercised by rendering.spec.js (CI-delegated).

**4. [Plan-anticipated] Playwright behavior specs CI-delegated.**
- Per the plan's explicit allowance ("CI-delegate if local lane saturated — record in SUMMARY"). The local lane's web server fails to boot (Postgres `too_many_connections`); the runtime backstop is the seeded ExUnit contract tests + the CI polish cases.

## Known Stubs

None. Both pages render real seeded data through `ck_page/1`; the avatar/video branches are gated on real attached media (existing behavior), not stubs. The empty-branch fallbacks (`member-no-avatar`/`lesson-no-video`) are intentional existing UI states, not placeholders.

## Threat Flags

None — no new network endpoint, auth path, file-access pattern, or schema change.
- T-99-04-01 (variant `<ul>/<li>` -> ck_table dropping `variant-#{name}` ids) **mitigated**: the `<ul>/<li>` structure kept; `id={"variant-#{variant.name}"}`/`data-testid={"variant-#{variant.name}"}`=1 each in source, `ck_table`=0.
- T-99-04-02 (replace/detach link-only `ck_button` dropping `phx-click`) **mitigated**: both handlers survive on bare `.ck-btn` `<button>`s (`phx-click="replace_avatar"/"detach_avatar"`=2; `<.ck_button>`=0); ExUnit asserts both handlers.
- T-99-04-03 (`raw/1` XSS while restyling state/variant lines) **mitigated**: `raw(`=0 in both files; `.ck-output`/class swaps only, HEEx auto-escape preserved.
- T-99-04-SC (npm/hex installs) **accept**: zero new packages.

## Self-Check: PASSED

- FOUND: examples/adoption_demo/lib/adoption_demo_web/live/member_live.ex (<.ck_page)
- FOUND: examples/adoption_demo/lib/adoption_demo_web/live/lesson_live.ex (<.ck_page)
- FOUND: examples/adoption_demo/e2e/cohort-pages.spec.js (/members + /lessons polish cases)
- FOUND: examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs (/members + /lessons contract tests)
- FOUND commit: 115dcf8 (feat 99-04 /members onto ck_page/1)
- FOUND commit: 128bd26 (feat 99-04 /lessons onto ck_page/1)
- FOUND commit: 6136d6b (test 99-04 polish cases + contract tests)
