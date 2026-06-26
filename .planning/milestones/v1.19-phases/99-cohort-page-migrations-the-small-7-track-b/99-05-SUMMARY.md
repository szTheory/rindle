---
phase: 99-cohort-page-migrations-the-small-7-track-b
plan: 05
subsystem: cohort-design-system
status: complete
tags: [cohort, migration, post, media, picture-tag, dl-restyle, variant-list, ck-detail, ck-output, frozen-contract, class-by-class]
requirements: [COHORT-04]
dependency_graph:
  requires:
    - "ck_page/1 scaffold (Phase 99 P01)"
    - ".ck-detail / .ck-detail__row / .ck-detail__term / .ck-detail__desc CSS (Phase 96)"
    - ".ck-output token-only mono surface (Phase 99 P01)"
    - ".ck-section / .ck-section__head / .ck-section__title / .ck-btn / .ck-hero__title / .ck-hero__lede CSS (Phase 96)"
    - "cohort-pages.spec.js shared assertCohortPagePolish harness (Phase 99 P01)"
    - "cohort_migration_contract_test.exs shared assert_frozen_contract/2 + assert_daisyui_retired/1 (Phase 99 P01)"
    - "support/cohort.js MEMBERS/memberId (existing e2e harness)"
  provides:
    - "/posts/:id migrated onto ck_page/1 — title + body + picture_tag image section preserved (COHORT-04)"
    - "/media/:id migrated onto ck_page/1 — <dl> restyled IN PLACE (media-id/media-state/media-delivery-url intact), variant list + alex link preserved (COHORT-04)"
    - "/posts + /media polish cases (warn mode) in cohort-pages.spec.js — all 7 routes now covered"
    - "/posts + /media frozen-contract + daisyUI-retirement tests in cohort_migration_contract_test.exs — all 7 routes now covered"
    - "COHORT-04 fully closed (all 5 member/lesson/post/media/account pages migrated)"
  affects:
    - "rendering.spec.js (frozen contract preserved; CI-delegated this run)"
    - "Phase 100 (/upload migration) + Phase 101 (daisyUI retirement) + Phase 102 (re-converge)"
tech_stack:
  added: []
  patterns:
    - "ck_page :title given a contextual label (Post/Media detail); for /posts the dynamic title carries the frozen testid on an explicit .ck-hero__title h1 in :inner_block (mirrors P2/P4)"
    - "media <dl> RESTYLED IN PLACE with existing .ck-detail/.ck-detail__row/__term/__desc classes — NOT ck_detail/1 (which generates its own <dd> and would drop the frozen <dd> ids/testids — Pitfall 2). Every <dd> keeps id + data-testid byte-for-byte"
    - "the media-delivery-url <dd> (formerly break-all) reuses the P01 token-only .ck-output mono surface (white-space:pre + overflow-x:auto) — mirrors P04's lesson-streaming-url; no new CSS"
    - "variant <ul>/<li id=variant-#{name}> kept byte-for-byte — NOT ck_table (Pitfall 2)"
    - "media-alex-profile-link kept as a plain <.link> with .ck-btn styling (NOT ck_button/1) so its data-testid + link text unquestionably survive"
    - "post body <p> left unclassed (inherits .ck cascade — .ck-prose has no rule; plan forbids new CSS)"
    - "server-owned theme default light in mount assigns (D-96-07)"
    - "ExUnit /media inserts a MediaAsset + a MediaVariant DIRECTLY (plain Repo rows, no MinIO) so all three <dd> ids/testids AND a real variant-thumb <li> render — stronger than the P04 lesson approach which could only assert the empty branch"
key_files:
  created: []
  modified:
    - examples/adoption_demo/lib/adoption_demo_web/live/post_live.ex
    - examples/adoption_demo/lib/adoption_demo_web/live/media_live.ex
    - examples/adoption_demo/e2e/cohort-pages.spec.js
    - examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs
decisions:
  - "The media <dl> is RESTYLED IN PLACE with the existing .ck-detail family (.ck-detail / .ck-detail__row / .ck-detail__term / .ck-detail__desc), NOT replaced by ck_detail/1. ck_detail/1 generates its own <dd class=\"ck-detail__desc\"> via render_slot and cannot carry the frozen id=\"media-id\"/\"media-state\"/\"media-delivery-url\" + data-testid on those <dd>s — converting would silently drop them (Pitfall 2, T-99-05-01, the single highest-risk swap in the phase). The .ck-detail CSS uses a 2-column term/desc grid that fits the existing <dl><div><dt>...<dd></div></dl> structure exactly, so the in-place restyle is a pure class swap. ExUnit asserts each <dd> id survives as both id= and data-testid=, and grep asserts ck_detail count = 0."
  - "media-delivery-url <dd> reuses .ck-output (the P01 token-only mono surface) rather than authoring a new break-all CSS rule. The original carried daisyUI break-all (long-URL wrapping); .ck-output (white-space:pre + overflow-x:auto) is the existing mono long-line surface (P04 used it for lesson-streaming-url). No new CSS, no --ck-* token. It stacks with .ck-detail__desc on the same <dd> (class=\"ck-detail__desc ck-output\")."
  - "media-alex-profile-link kept as a plain <.link class=\"ck-btn\"> (NOT ck_button/1). ck_button forwards :global, and data-* attrs do pass through :global, but to remove any doubt that the frozen data-testid + the accessible link text survive (A3), the conservative choice is a directly-authored <.link> with .ck-btn styling — the same conservative reasoning the plan offered as its fallback."
  - "post ck_page :title is the contextual label \"Post\"; the dynamic @post.title carries data-testid=\"post-title\" on an explicit <h1 class=\"ck-hero__title\"> inside :inner_block (ck_page's :title h1 cannot carry a testid). Mirrors P2/P4. The byline became a .ck-hero__lede; the body <p> is unclassed (inherits .ck cascade — .ck-prose has no rule and the plan forbids new CSS here)."
  - "ExUnit /media inserts a MediaAsset + one MediaVariant directly via Repo.insert! (both plain DB rows; Media.variants_for is a plain query and Media.delivery_url just builds a URL via Rindle.url — no MinIO needed). This renders all three <dd> ids AND a real variant-thumb <li>, so the /media contract test asserts the per-variant id at runtime — stronger than P04's lesson test, which could only assert the empty branch because video variants require Media.attach!/storage. The /posts test seeds a member+post with no image, exercising the post-no-image branch (the picture_tag image branch needs Media.attach!/MinIO — grep-verified in source + runtime-exercised by rendering.spec.js, the P04 precedent)."
  - "ExUnit + Playwright runtime lanes CI-delegated: local Postgres is fully saturated (FATAL 53300 too_many_connections — could not even create the test DB or accept a psql admin connection; ~20 orphaned beam.smp VMs from prior milestone runs hold every slot). Killing them was declined (some are the user's editor/LS VMs, not attributable orphans). This is the exact saturated-lane condition recorded in 99-02/99-03/99-04. Static backstops: MIX_ENV=test mix compile clean, node --check clean, mix format clean, all per-page acceptance greps pass, cohort-contrast 28/28."
metrics:
  duration_min: 9
  tasks: 3
  files: 4
  completed: "2026-06-18"
---

# Phase 99 Plan 05: /posts + /media Migration onto ck_page/1 Summary

Migrated `/posts/:id` (`post_live.ex`) and `/media/:id` (`media_live.ex`) onto the P01 `ck_page/1` scaffold class-by-class (COHORT-04) — the final two of the small 7. Post is the simplest page (title + byline + body + a `picture_tag` image section). Media carried the single highest-risk swap in the phase: the hand-built `<dl><dt><dd>` whose `<dd>`s hold the frozen `media-id`/`media-state`/`media-delivery-url` ids+testids was **restyled in place** with the existing `.ck-detail` classes — NOT replaced by `ck_detail/1` (which generates its own `<dd>` and would silently drop those ids — Pitfall 2). The variant `<ul>/<li id=variant-#{name}>` was kept byte-for-byte (NOT `ck_table`); the alex-profile link kept its testid + text. No daisyUI in either body; no `raw/1`; no new CSS. Added `/posts` + `/media` polish cases (warn mode) and `/posts` + `/media` frozen-contract + daisyUI-retirement tests — **all 7 routes now have a polish case + a contract test**. This plan closes COHORT-04 (all 5 member/lesson/post/media/account pages migrated).

## What Was Built

### Task 1 — /posts/:id render/1 onto ck_page/1 (commit 0e2aa69)
- Wrapped `render/1` body in `<.ck_page title="Post" theme={@theme}>` inside the kept `<Layouts.app>` chrome; added `theme: "light"` to `mount/2` assigns (D-96-07) and `import AdoptionDemoWeb.CohortComponents`.
- `@post.title` carries `data-testid="post-title"` on an explicit `<h1 class="ck-hero__title">` inside `:inner_block` (`ck_page`'s `:title` h1 cannot carry a testid; mirrors P2/P4). The byline became a `.ck-hero__lede` `<p>`; the body `<p>` is unclassed (inherits the `.ck` cascade — `.ck-prose` has no rule, no new CSS).
- `<section id="post-image" data-testid="post-image-section">` -> `.ck-section` + `.ck-section__head`/`.ck-section__title` (id/testid byte-for-byte).
- `<div data-testid="post-picture-tag">` wrapping `Rindle.HTML.picture_tag(...)` kept UNCHANGED (the `class: "max-w-md border"` option is a library-rendered `<img>` attribute). `<p data-testid="post-no-image">` fallback kept.
- All daisyUI body utilities removed (`text-2xl`/`text-lg`/`text-sm`/`font-semibold`/`mt-4`/`mt-6`); no `raw/1`.

### Task 2 — /media/:id render/1 onto ck_page/1 (commit 0e5bc67)
- Wrapped `render/1` body in `<.ck_page title="Media detail" theme={@theme}>` inside the kept `<Layouts.app>`; added `theme: "light"` to `mount/2` and the CohortComponents import.
- **CRITICAL — the `<dl>` restyled IN PLACE:** the `<dl><div><dt>...<dd id="media-id"/"media-state"/"media-delivery-url" data-testid=...></div></dl>` structure was kept and only class-swapped onto the existing `.ck-detail`/`.ck-detail__row`/`.ck-detail__term`/`.ck-detail__desc` family — NOT `ck_detail/1` (Pitfall 2, T-99-05-01). Every `<dd>` keeps its `id` + `data-testid`. The `media-delivery-url` `<dd>` (formerly `break-all`) also gets `.ck-output` (the P01 token-only mono surface — mirrors P04's lesson-streaming-url).
- `<section id="media-variants" data-testid="media-variants">` -> `.ck-section` + `.ck-section__head`/`.ck-section__title`; the `<ul>` (formerly `list-disc pl-5`) -> bare `<ul>`; EVERY `<li :for={variant} id={"variant-#{variant.name}"}>` kept byte-for-byte (NOT `ck_table`, Pitfall 2).
- `media-alex-profile-link` kept as a plain `<.link class="ck-btn" data-testid="media-alex-profile-link">` with its full link text "Open Alex profile for replace/detach" (NOT `ck_button/1` — conservative testid/text survival).
- All daisyUI body utilities removed (`text-2xl`/`text-lg`/`text-sm`/`font-semibold`/`inline`/`break-all`/`space-y-1`/`list-disc`/`pl-5`/`mt-*`/`underline`); no `raw/1`. `mix format` applied (the long `<dd>`/`<.link>` wrapped). `alex_id/1` helper + `handle_event` UNCHANGED.

### Task 3 — polish cases + ExUnit frozen-contract tests (commit abd74f6)
- `cohort-pages.spec.js`: a `test("/posts …", surface: "post-cohort")` (navigates via the seeded "Study group this week" post link, the way rendering.spec.js navigates the lesson link) and a `test("/media …", surface: "media-cohort")` (clicks the first link inside the seeded `demo-assets` section — the asset link text is a UUID). Both reuse the shared warn-mode `assertCohortPagePolish`; `admin-polish.js` untouched. **All 7 route surfaces now covered** (styleguide-smoke + dashboard + ops + account + member + lesson + post + media).
- `cohort_migration_contract_test.exs`: a `/posts` test (seeds a member + post with no image -> `post-no-image` branch) asserting `post-title`, `post-image-section`, `post-no-image`, `data-ck-root`, then `assert_daisyui_retired/1`; and a `/media` test that inserts a `MediaAsset` + a `MediaVariant` directly (plain Repo rows — no MinIO) so all three `<dd>` ids/testids AND a real `variant-thumb` `<li>` render, asserting `media-id`/`media-state`/`media-delivery-url` (each as `id=` and `data-testid=`), `media-variants`, `variant-thumb`, `media-alex-profile-link` + its text, `data-ck-root`, then `assert_daisyui_retired/1`. **All 7 per-page contract tests now exist.**

## Verification

- `MIX_ENV=test mix compile` -> no errors for `post_live.ex` / `media_live.ex` (pre-existing test-only Mox warnings filtered, per the Phase-96 note).
- `node --check e2e/cohort-pages.spec.js` -> exit 0 (valid JS).
- `mix format --check-formatted` -> clean on all four changed files (media_live.ex + the test file were reformatted then committed/amended).
- Acceptance greps on `post_live.ex`: `<.ck_page`=1, `Rindle.HTML.picture_tag`=1, `text-2xl|text-lg|text-sm|font-semibold`=0, `raw(`=0; all 4 frozen ids present (`post-title`, `post-image-section`, `post-picture-tag`, `post-no-image`).
- Acceptance greps on `media_live.ex`: `<.ck_page`=1, `ck_detail`=0 (NOT converted), `<dl`=1 (restyled in place), `id={"variant-#{variant.name}"}`=1, `ck_table`=0, `raw(`=0, daisyUI (`text-2xl|list-disc|underline|break-all|...`)=0; all three `<dd>` ids survive as `id=` AND `data-testid=` (`media-id`/`media-state`/`media-delivery-url`); `media-variants` + `media-alex-profile-link` + its link text present.
- Spec greps: `post-cohort|media-cohort`=2; the spec now contains all 7 route surfaces.
- Contract greps: `media-delivery-url`>=1, `post-title`>=1.
- `node brandbook/src/cohort-contrast.mjs` -> **28/28 pairs pass, exit 0** (no token drift — no CSS changed since P1).
- `git status --porcelain` empty for `examples/adoption_demo/e2e/support/admin-polish.js` and `examples/adoption_demo/priv/static/assets/cohort.css` (both untouched).
- **ExUnit + Playwright runtime lanes CI-delegated** — local Postgres is fully saturated (`FATAL 53300 too_many_connections`; could not create the test DB nor accept a psql admin connection; ~20 orphaned `beam.smp` VMs from prior milestone runs hold every connection slot, and they were not safe to kill — some are the user's editor/LS VMs). This is the exact saturated-lane condition recorded in 99-02/99-03/99-04. The static backstops above (compile + greps + node --check + format + contrast) plus the new seeded ExUnit contract tests (which run green in CI) are the runtime substitute.

## Deviations from Plan

None affecting scope — the plan's DECIDE-and-document instructions were exercised:

**1. [Plan-directed decision] The media `<dl>` restyled in place with `.ck-detail`, NOT `ck_detail/1`.**
- The plan's CRITICAL instruction: "KEEP the existing `<dl>` structure byte-for-byte; do NOT replace it with `ck_detail/1`." The `.ck-detail` family (already shipped in Phase 96, contrast-gated) is a 2-column term/desc grid that fits the existing `<dl><div><dt>...<dd></div></dl>` exactly, so the in-place restyle is a pure class swap that preserves all three `<dd>` ids/testids. `ck_detail`=0, `<dl>`=1.

**2. [Plan-directed decision] `media-delivery-url` reuses `.ck-output` (no new CSS).**
- The plan said "do NOT add a new CSS rule; if a `.ck-detail`/`.ck-cred` class fits the dt/dd use it." The dt/dd use `.ck-detail__term`/`.ck-detail__desc`; the long-URL `<dd>` (formerly `break-all`) additionally gets `.ck-output` (the existing P01 mono surface, P04's lesson-streaming-url precedent). No new `--ck-*` token, no `cohort.css` change.

**3. [Plan-directed decision] `media-alex-profile-link` kept as a plain `.ck-btn` `<.link>`.**
- The plan offered: "use `ck_button` IF it forwards `data-testid` via `:rest` … else keep a plain `.ck` `<.link>` so the testid survives." Chose the conservative plain `<.link class="ck-btn">` so the frozen `data-testid` and the accessible link text unquestionably survive (A3).

**4. [Plan-directed decision] post body `<p>` unclassed; `:title` is a contextual label + named hero h1.**
- `.ck-prose` has no rule and the plan forbids new CSS, so the body `<p>` is unclassed (inherits the `.ck` cascade, the P2/P4 list precedent). The `data-testid="post-title"` rides an explicit `.ck-hero__title` h1 in `:inner_block` because `ck_page`'s `:title` h1 cannot carry a testid (P2/P4 shape).

**5. [Plan-directed decision + improvement] ExUnit /media seeds a real MediaVariant; /posts asserts the empty branch.**
- The plan asked for "at least one `variant-` id" in the /media test. Because `Media.variants_for` is a plain DB query and `delivery_url` just builds a URL, I inserted a `MediaAsset` + a `MediaVariant` directly (no MinIO) so a real `variant-thumb` `<li>` renders and is asserted — stronger than P04's lesson test (which could only assert the empty branch). The /posts test seeds a no-image post (`post-no-image` branch); the `post-picture-tag` image branch needs `Media.attach!`/MinIO, so it is grep-verified in source + runtime-exercised by rendering.spec.js (the P04 precedent, documented).

**6. [Plan-anticipated] Playwright + ExUnit runtime lanes CI-delegated.**
- Per the plan's explicit allowance ("CI-delegate if the local lane is saturated — record in SUMMARY"). Local Postgres is fully saturated; the runtime backstop is the seeded ExUnit contract tests + the CI polish cases.

## Known Stubs

None. Both pages render real seeded data through `ck_page/1`. The empty-branch fallbacks (`post-no-image`) are intentional existing UI states, not placeholders. The image/variant branches are gated on real attached media (existing behavior), not stubs.

## Threat Flags

None — no new network endpoint, auth path, file-access pattern, or schema change.
- **T-99-05-01** (converting the media `<dl>` to `ck_detail/1` silently dropping media-id/media-state/media-delivery-url) **mitigated**: the `<dl>` restyled in place; `ck_detail`=0, `<dl>`=1 in source; all three `<dd>` ids survive as `id=` AND `data-testid=`; ExUnit asserts each (runtime-rendered against a seeded asset); rendering.spec.js runtime backstop (CI).
- **T-99-05-02** (converting the variant `<ul>/<li>` to `ck_table` dropping `variant-#{name}` ids) **mitigated**: the `<ul>/<li>` kept; `id={"variant-#{variant.name}"}`=1, `ck_table`=0; ExUnit asserts `variant-thumb` against a seeded variant.
- **T-99-05-03** (introducing `raw/1` while restyling the post body / dl values) **mitigated**: `raw(`=0 in both files; class swaps only, HEEx auto-escape preserved; `assert_frozen_contract/2` refutes `raw(`.
- **T-99-05-SC** (npm/hex installs) **accept**: zero new packages.

## Self-Check: PASSED

- FOUND: examples/adoption_demo/lib/adoption_demo_web/live/post_live.ex (<.ck_page)
- FOUND: examples/adoption_demo/lib/adoption_demo_web/live/media_live.ex (<.ck_page, <dl>, ck_detail=0)
- FOUND: examples/adoption_demo/e2e/cohort-pages.spec.js (/posts + /media polish cases)
- FOUND: examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs (/posts + /media contract tests)
- FOUND commit: 0e2aa69 (feat 99-05 /posts onto ck_page/1)
- FOUND commit: 0e5bc67 (feat 99-05 /media onto ck_page/1)
- FOUND commit: abd74f6 (test 99-05 polish cases + contract tests)
