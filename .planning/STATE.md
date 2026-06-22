---
gsd_state_version: 1.0
milestone: v1.20
milestone_name: CI/CD Performance
current_phase: 107
status: verifying
stopped_at: Completed 107-04-PLAN.md
last_updated: "2026-06-22T20:26:55.665Z"
last_activity: 2026-06-22
last_activity_desc: Phase 107 complete
progress:
  total_phases: 13
  completed_phases: 13
  total_plans: 47
  completed_plans: 47
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-19)

**Core value:** Media, made durable.
**Current focus:** Phase 107 — reliability-security-dx-hardening

## Current Position

Phase: 107
Plan: Not started
Status: Phase complete — ready for verification
Last activity: 2026-06-22 — Phase 107 complete

### v1.20 roadmap (Phases 103–107) — load-bearing dependency order

Chartered 2026-06-20 from SEED-003. **Non-feature / DX-infrastructure milestone — ZERO `lib/`
public-API change.** Phase numbering continues from v1.19's Phase 102. The order is
research-unanimous and must not be reversed: reversing the aggregate-check (105) and lane-split
(106) steps forces a second branch-protection migration.

- **Phase 103 — Observability / Baseline** (OBS-01..03): self-reporting CI + committed baseline +
  live required-check names captured **before any change**; no gate-behavior change. Gates everything else.

- **Phase 104 — Cache & Tooling Hygiene** (CACHE-01..05): composite setup action, correct cache
  keys, PLT restore/save split, lockfile drift gates, lint de-dup. Single-workflow shape; low risk.

- **Phase 105 — Aggregate Required Check + Branch-Protection Flip** (GATE-01..02): `CI Summary`
  (`needs:` all, `if: always()`, skipped==pass) becomes the sole required check; script updated in
  the same PR. Isolated; MUST precede any lane rename.

- **Phase 106 — Trigger Split + Matrix/Lane Refinement** (LANE-01..04): fast PR lane + scoped
  package-consumer + nightly lane + concurrency. The headline 15→≤7min cut.

- **Phase 107 — Reliability, Security & DX Hardening** (HARD-01..04): async-safety/partitioning,
  action SHA-pinning + supply-chain, `mix ci` + CONTRIBUTING, faithful Linux-Chromium repro.

**Hard invariants (highest blast radius):** never rename `ci.yml`'s file or `name: CI`
(release-train coupling via `release-please-automerge.yml` + `gate-ci-green`); `CI Summary` must
treat `skipped` as pass (fork-PR safety); never weaken the release full-verification gate.

## Recently Shipped Milestone

**v1.19 Design-System Stress-Test** (SEED-002) — maintainer-pull **quality** milestone; likely
ships as hex **0.3.x**. Elevate the whole design system to an award-winning bar — fractally and
**without regressions** — across the mountable admin/operator console **and** the Cohort demo's
inner pages, in service of real user flows.

- **Two tracks on a hardened pipeline:** Track A (admin DS: component → meta-component → page) and
  Track B (Cohort restyle: `.ck-*` component layer + net-new dark/reduced-motion contract →
  page-by-page migration → daisyUI retirement). Parallel after the Phase 94 foundation;
  re-converge in Phase 102.

- **Near-zero new deps:** extend `tokens.json → .mjs → rindle-admin.css` (admin) + hand-authored
  `cohort.css`/`CohortComponents` (demo). No Tailwind in `rindle`, no JS animation lib, no SaaS
  visual-regression, no Storybook.

- **Proof (resolved):** the deterministic `admin-polish.js` computed-style gate (generalized over
  admin + Cohort) is the **single merge-blocking** visual gate; golden-PNG pixel baselines are
  optional / non-blocking only.

- **Archive:** `.planning/milestones/v1.19-ROADMAP.md` and
  `.planning/milestones/v1.19-REQUIREMENTS.md`

- **Requirements:** 20/20 archived complete (PIPE-01/02, UPLIFT-01..08, COHORT-01..06,
  VIS-01..04)

- **Post-ship reconcile (2026-06-19):** a strict re-audit raised the "every phase needs its own
  `*-VERIFICATION.md`" bar and flagged Phase 95. Closed: `95-VERIFICATION.md` written → surfaced a
  real mobile sticky-table defect → fixed in 95-05 (`2960883`, 24 tests/0 failures); UPLIFT-01 now
  independently verified, milestone holds 20/20. Re-audit + resolution archived at
  `milestones/v1.19-MILESTONE-REAUDIT.md`; the `v1.19` tag (`ece7cbd`) is intentionally not moved.

- **Post-ship demo polish (2026-06-20, demo/tooling-only — no Hex release, no re-tag).** Hands-on
  use of the live Cohort demo surfaced polish gaps beyond the v1.19 frozen scope, landed as
  standalone PRs on `main`:

  - **#27** — chrome (`.ck-nav`/`.ck-footer`) brand-font continuity on all inner pages (COHORT-02
    re-audit, gate blind-spot closed) + Traefik auto-default in `up.sh` + mobile nav wrap (fixed a
    3px Atkinson-on-Linux/freetype overflow the mobile `stable-dimensions` gate caught).

  - **#28** — `/upload` restyled onto the `.ck-*` DS (branded dropzone + `::file-selector-button`,
    lifecycle status badges, per-tab proof framing, result/error cards, `.ck-reveal` motion,
    brand-voice microcopy) + `ck_page` **theme tri-state** (`auto` default follows the OS like home;
    light/dark toggle pins it) across all inner pages. Frozen DOM contract preserved; token-only CSS;
    verified for mobile overflow + AA contrast under the CI Linux Chromium.

  - **In flight (#29):** the same DS polish sweep across the remaining inner pages
    (`/dashboard`, `/ops`, member/lesson/post/account/media) — raw lists → `.ck_table`, bare state
    → `.ck-badge`, output dumps → `.ck-result`, brand-voice labels, `.ck-empty`/`.ck-reveal`.

  - Lesson banked: the **runtime** `admin-polish.js` text-contrast check is stricter than the
    token-pair `cohort-contrast.mjs` gate (it caught `--ck-faint` used as real text) — verify both,
    and measure mobile under Linux Chromium (Atkinson renders wider than on macOS), before pushing.

> ✅ **v1.18 closed.** v1.18 Admin Console & Adoption Lab was advanced from `tech_debt` to
> `shipped` on 2026-06-20 after maintainer HUMAN-UAT sign-off (Phases 90/91/92); roadmap +
> requirements archived to `milestones/v1.18-*.md`. Tag `v1.18` left at `c58db9e` (pre-v1.19
> lineage, intentionally not re-pointed). Both v1.18 and v1.19 now shipped & archived.

## Next Step

**Plan Phase 103 (Observability / Baseline):** `/gsd-plan-phase 103`. It is the [BASELINE FIRST]
gate — capture the committed per-job avg/p95/rerun baseline AND the live branch-protection
required-check names before any topology change, and surface timing/cache/slowest-tests/cores in
`$GITHUB_STEP_SUMMARY` with zero gate-behavior change.

## Accumulated Context

### Pending Todos

- [2026-06-19] Fix Docker demo startup warnings — `./scripts/demo/up.sh` logs missing Mox warnings from `AdoptionDemo.MuxCassette` and missing `inotify-tools` / `fs_inotify_bootstrap_error` for Phoenix live-reload inside the Cohort demo container.

- [2026-06-20] **SEED-003 planted** — CI/CD pipeline performance + reliability audit (`.planning/seeds/SEED-003-ci-cd-performance-audit.md`). PR CI wall-clock ~15–17 min, long pole = `Package Consumer Proof Matrix + Release Preflight` (~15m). Embeds the maintainer's full audit prompt; surface at next `gsd new milestone` (v1.20 candidate) or sooner if CI time/flakiness drags velocity.

- **v1.19 build order (research-locked, repo-verified):** Foundation (94) → parallel Track A
  (95 admin L1 → 97 admin L2 → 98 admin L3+motion/mobile/a11y/IA/microcopy) + Track B (96 Cohort
  component layer + dark/reduced-motion → 99 small-7 page migrations → 100 /upload migration →
  101 daisyUI retirement) → re-converge (102 matrix + idempotency + audit). Level 1→2→3 is a hard
  intra-track dependency; pages compose only from finished primitives.

- **The structural prerequisite is closed:** Phase 94's `brandbook-tokens` job gates the
  `.mjs` token→CSS pipeline, and branch protection now requires that check.

- **Two design systems stay separate but coherent:** `rindle-admin` (`.rindle-admin-*` BEM,
  generated, host-Tailwind-independent) and `cohort.css` (`.ck-*`, hand-authored, emerald brand)
  share vocabulary but **never** a stylesheet, token file, or build step. Generated
  `rindle-admin.css` is never hand-edited (generator is the only writer).

- **Migration discipline:** class-by-class, never element-by-element; preserve every
  `id`/`data-testid`/`phx-hook` as a frozen behavior contract; run behavior e2e per page; delete
  `default.css` only once grep is clean (Phase 101).

- **Cohort net-new work:** `cohort.css` has **no** dark `[data-theme]` contract and **no**
  `prefers-reduced-motion` block today — both authored in Phase 96.

- **Anti-features (hard no):** metrics/charting dashboard, dark-by-inversion, color-only status,
  animate-everything, generating `cohort.css` from `tokens.json`, adding Tailwind/JS-anim-lib to
  `rindle`, golden-PNG as a merge blocker.

### Carried from v1.18 (shipped 2026-06-20 — substrate for v1.19+)

- v1.18 closed `shipped` 2026-06-20 after HUMAN-UAT sign-off on phases 90/91/92 (90
  destructive-action UX, 91 logo+lifecycle display, 92 screenshot-review matrix). Roadmap +
  requirements archived to `milestones/v1.18-ROADMAP.md` / `-REQUIREMENTS.md`; audit flipped to
  `shipped`. Tag `v1.18` kept at `c58db9e` (pre-v1.19 lineage, not re-pointed to `main`).

- **v1.18 surfaces are the substrate v1.19 polishes:** token-generated `rindle-admin` CSS,
  mountable console (`Rindle.Admin.Router.rindle_admin/2`), `Rindle.Admin.Queries`, deterministic
  `adoption-demo-e2e` Playwright lane (`admin-polish.js` + 22-PNG matrix), Cohort demo with full
  lifecycle-state seeds + audio/document profiles.

- **b1.0 brand system** in `brandbook/` (Confluence e1 logo, tokens with WCAG gate, HTML brand
  book) is the token source of truth for `rindle-admin`.

- **Do not** reopen tus protocol, Mux surfaces, owner-erasure semantics, or any console lifecycle
  / write path beyond the v1.18 surface — v1.19 is DS quality only.

- **Do not** add force-delete (LIFE-06) or a second provider (STREAM-10) — demand-gated, v1.20+.
- Default `mix coveralls` and `adoption-demo-e2e` are merge-blocking per `ci.yml` (source of truth).

## Decisions

- 107-01 (HARD-01): Landed `test/async_safety_guard_test.exs` — an `async: true` AST meta-test
  (glob `test/**/*_test.exs` → `Code.string_to_quoted!` → `Macro.prewalk`) that red-gates any
  `async: true` module using an unsafe shared-state primitive (`Application/System.put_env`,
  `set_mox_global`, fixed-name process, fixed-path `File` mutation, public/named ETS,
  `:persistent_term.put`, `{:shared, _}` sandbox); fail-closed with `@async_safety_allow [...]`
  escape hatch + transitive tmp-var dataflow tracking. Drove it GREEN by resolving its 4
  pre-existing offenders (orchestrator-approved Option A): `profile_test` + `http_cancel_upload_test`
  flipped to `async: false` (genuine `Application.put_env` races); `storage/local_test` +
  `install_smoke/package_metadata_test` annotated with justified `@async_safety_allow [:file_mutation]`
  (tmp-scoped writes the static tracker can't bridge). Detector logic NOT weakened. Converted the
  15 RESEARCH-CLEAN modules to `async: true` (`owner_erasure_batch_opts` sibling pairing preserved).
  `--partitions` DEFERRED (D-01). Full suite 1160 tests; the sole failure is a PRE-EXISTING,
  out-of-scope docs-parity test from the parked docs-archive cleanup (deferred-items.md).

- 106-04 (LANE-03/LANE-01): Stood up separate `.github/workflows/nightly.yml` (`name: Nightly`,
  cron 27 7 UTC, no PR/push trigger) — curated 6-cell OTP×Elixir compat matrix (straddles the
  json_polyfill_dep/0 OTP<27 branch), owned GATING Dialyzer (literal `otp27-elixir1.17` PLT-key
  segment — never a bare matrix.* ref that would render empty and collapse PLT lineages, D-20),
  moved gcs-soak + package-consumer-gcs-live (BOTH continue-on-error dropped → real nightly signal,
  D-14), Nightly Summary + least-privilege `issues: write`-only nightly-failure-issue (schedule-only,
  D-16). Separate file is structurally invisible to release-please-automerge workflow_run:[CI] /
  gate-ci-green / branch-protection (D-12). Extracted Dialyzer + GCS lanes from ci.yml (mux-soak
  kept as label-gated PR lane). Moved `adoption-demo-e2e` + `cohort-demo-smoke` to push:main (repo
  gate preserved, composed with `event_name != 'pull_request'`) and out of ci-summary/observability
  needs (D-04/D-05/D-09) — the ~502s demo chain off PR lands p95 under ≤7 min; adoption-demo-unit
  stays PR-gating (D-02); D-03 guardrail intact (integration/adopter/contract/proof stay PR-gating).
  `name: CI` + both filenames + eval_ci_summary.sh + setup_branch_protection.sh byte-unchanged.

- 106-03 (LANE-02): Split the 887s-p95 `package-consumer` long pole — lean image-only
  install-smoke + version-alignment job (gating, all triggers, stays in CI Summary.needs) +
  new off-PR `package-consumer-full` 5-profile [video,image,tus,mux,gcs] matrix (fail-fast:false)
  carrying release_preflight + repo_hygiene + hex.publish --dry-run with NO failure-masking.
  Full lane OMITTED from CI Summary.needs / ci-observability.needs (D-09 omit-from-needs);
  release readiness proven by the push:main run conclusion via release.yml gate-ci-green (D-11),
  not by any check name. eval_ci_summary.sh + setup_branch_protection.sh byte-unchanged.

- v1.19 proof strategy: deterministic computed-style `admin-polish.js` gate is the SINGLE
  merge-blocking visual gate (generalized over admin + Cohort); golden-PNG `toHaveScreenshot()`
  baselines stay optional / non-blocking (never merge-blocking until proven CI-stable).

- v1.19 keeps the two design systems separate (no shared stylesheet/token file/build step);
  coherence enforced by shared vocabulary + parallel gallery/contrast gate, not a shared file.

- v1.19 collapses the research's Cohort B1+B2 (Level-1 + Level-2 `.ck-*` layers) into a single
  Phase 96 anchored on COHORT-06, keeping a clean 1:1 requirement→phase mapping; the small-7 page
  migrations (Phase 99) and `/upload` (Phase 100) compose those finished primitives.

<details>
<summary>v1.18 phase-88..93 implementation decisions (carried, collapsed)</summary>

- 88: `rindle-admin` is vanilla generated CSS, no runtime UI dep / host asset-pipeline dep; gallery
  is static generated HTML linking only `../tokens/rindle-admin.css`; review screenshots gitignored.

- 89: production mounts require non-empty `:on_mount` or explicit `auth_guarded?: true`; packaged
  static assets are byte-identical to `brandbook/tokens/rindle-admin.css` (brandbook generators are
  source of truth); admin read composition lives in `Rindle.Admin.Queries` (7 `/1` query fns +
  `actions_directory/0`), not the public facade; `phoenix_live_view` optional, compile-away proven
  in a dedicated CI matrix job.

- 90: owner/batch erasure + non-destructive ops (variant regen, lifecycle repair, quarantine
  triage) implemented within `ActionsLive` with strict typed confirmation.

- 91: Cohort logo = `logo_opt2.svg`; console mounted at `/admin` via `allow_unauthenticated?: true`
  (demo only).

- 92: shared CommonJS admin helper inside the existing `adoption_demo` Playwright harness; only
  semantic `data-rindle-admin-*` selectors in shipped admin source; live screenshot artifacts under
  ignored Playwright `test-results` with an exact 22-file PNG contract; screenshot polish fixed at
  the brandbook generator source (CSS kept byte-identical across brandbook/priv).

- 93: TRUTH-07 docs parity CI-locked in `docs_parity_test.exs`; JTBD T4 admin-UI exclusion reversed
  (shipped job 39 cites `rindle_admin/2`); v1.18 traceability closed 19/19; milestone audit recorded
  at `status: tech_debt` pending HUMAN-UAT.

</details>

- [Phase ?]: Phase 94: token CSS pipeline gets a single committed sync mechanism (brandbook/src/sync-admin-css.mjs) mirroring generator output to the shipped priv copy; sync is a discrete invokable step (not folded into admin-css-build.mjs) so the Plan 04 CI gate calls it in D-94-02 order. Drift-free baseline established (stale dark text-on-brand corrected to #101417).
- [Phase ?]: Phase 94 Plan 02: admin-polish.js generalized over { root, interactiveSelectors } with admin defaults (D-94-07: no auto-detection — root always explicit). admin-screenshots spec byte-for-byte unchanged is the backward-compat acceptance test; the seam Phase 102 uses to run the same computed-style gate over Cohort ([data-ck-root] / .ck-*).
- [Phase ?]: Phase 94 Plan 03: four new token categories wired into tokens.json + admin generators via the 3-touchpoint pattern (source object -> emit loop -> parity registration). diagram kept out of MOTION_TOKENS (only the 3 new easings join, each consumed by a rule); elevation hexes placed in color.raw so both deref and WCAG resolve() find them; differentiated dark status surfaces are a tokens.json value change with no .map() edit. admin-contrast 44/44, base 47/47, both CSS copies byte-identical.
- [Phase ?]: Phase 94 Plan 04: standalone merge-blocking brandbook-tokens CI job lands (PIPE-01) — regen -> WCAG contrast -> gallery proof -> sync-admin-css -> tree-wide git diff --exit-code; closes the un-gated token->CSS pipeline gap. Surfaced + fixed stale committed tokens.css (Plan 03 ran admin-css-build but not the base tokens-build); the gate now lands on an empty-diff tree.
- [Phase 96]: Plan 01 — cohort.css gains the net-new dark [data-theme] contract (D-96-11 shape: `:root, [data-theme="light"]` + `[data-theme="dark"]` + `@media (prefers-color-scheme: dark) { :root:not([data-theme]) }` auto fallback), per-theme `color-scheme`, the `--ck-surface-overlay` lightness ladder step, per-theme bare-channel `--ck-shadow-ink`/`--ck-glow-ink` feeding one shared `rgb(var(--ink) / <alpha>)` shadow/glow formula (D-96-12), and the file's only `!important` site: a `prefers-reduced-motion: reduce` block using `.001ms` not `0` (D-96-13). All rule-body color/font literals removed (`#fff`→`--ck-on-brand`, usage-site rem→nearest `--ck-step-*`); literals now live only in token blocks. No `--ck-*` palette value changed (D-96-23). Overlay values: light `#f4faf7`, dark `#16261f`. Note: default-env `mix compile --warnings-as-errors` fails on pre-existing test-only Mox warnings (logged to phase deferred-items.md); no-template-breakage verified via `MIX_ENV=test`.
- [Phase 96]: Plan 02 — the six Level-1 .ck-* primitives shipped as CohortComponents function components + .ck-scoped CSS: ck_table (real <button> sort header carrying aria-sort on the <th>, server-owned sort_by/sort_dir/sort_event, badge reuse, empty + loading-skeleton), ck_stat (tabular-nums + em-dash empty + status accent + skeleton), ck_detail (real <dl><dt><dd>), ck_toolbar (role=group + trailing :actions slot); ck_field/ck_input/ck_select integrate Phoenix.HTML.FormField with aria-describedby + aria-invalid and a non-color warning-icon error (D-96-15); ck_tabs is full WAI-ARIA APG (roving tabindex, server-owned select via phx-click) backed by a net-new keyboard-only phx-hook=Tabs in app.js (D-96-17). Every interactive control has a token-backed :focus-visible (no bare outline:none) and a 44px min target.
- [Phase ?]: Phase 96 Plan 04: RESOLVED (Option A) the light --ck-faint on --ck-bg contradiction — decorative/non-text role (WCAG 1.4.3/1.4.11 exempt) floor set to its measured 2.7; locked --ck-* color values unchanged (D-96-23); dark twin stays 3.0 (4.74:1). cohort-contrast.mjs gate exits 0 (28/28). [Rule 1] fixed a theme-blind coverage loop and a no-op self-comparison parity check (now byte-equal asserts the explicit dark block vs the prefers-color-scheme :root:not([data-theme]) duplicate). Wired into adoption-demo-e2e before Playwright.
- [Phase ?]: Phase 96 Plan 03: /styleguide reachable :browser LiveView on .ck shell with data-ck-root + data-theme seam (D-96-05, not body); theme/sort/tab SERVER state (enum-guarded, no client storage, D-96-07/15/16); 10 data-ck-section groups (6 L1 + 4 L2) full state sets on stable data-ck-state markers separate from .ck-* (D-96-16) + real seeded fiction with never-populated/filtered empty copy (D-96-22). [Rule 1] split disabled field into member_disabled to_form to avoid duplicate FormField DOM id. Composes only Plan 02 primitives.
- [Phase ?]: 96-05: cohort-styleguide.spec.js drives /styleguide in the D-96-21 order and reuses assertAdminPolish in warn mode over [data-ck-root]
- [Phase ?]: 96-05: ported the missing parseColor into admin-polish.js + made the outline-color check offender-safe (pre-existing ReferenceError surfaced by running the gate over a focusable surface; non-special-casing, admin unchanged)
- [Phase 97]: Plan 02 (UPLIFT-02) — all 8 META_COMPONENTS render as labeled `data-rindle-admin-meta` cohesion panels in the brandbook admin gallery (full-width "Cohesion units" region after the Level-1 grid + meta nav links M01..M08 + new exact() parity guard; Level-1 literals byte-unchanged). data-table shows STATIC sorted/selected/sticky/bulk state via fixture markup only (no client JS): th[aria-sort="ascending|none"] + .rindle-admin-table__sort glyph spans, three [data-rindle-admin-selected] rows + header select-all checkbox, .rindle-admin-table--sticky, role=toolbar .rindle-admin-bulk-bar in active state; sticky internal viewport opts into the no-h-scroll skip via explicit data-rindle-admin-scroll-region (D-94-07, never auto-detected). requiredSnippets extended with the 8 meta markers + meta section ids + aria-sort + selected + scroll-region. admin-gallery-check.mjs gains assertMetaUnits (loops META_COMPONENTS, asserts visible; re-run after each selectTheme light/dark/auto for per-theme proof) + assertMetaNoLeakage (every class under [data-rindle-admin-meta] must startsWith('rindle-admin-'), D-97-07) + 8 meta element screenshots (expectedScreenshots 10->18; existing 10 unchanged, terminal "18 screenshots written"). **ExUnit @screenshots / "18 screenshots" pinned literal is bumped in 97-04 BY DESIGN** (not here); priv sync drift gate also remains 97-04. This plan touches no CSS (no drift).
- [Phase 97]: Plan 01 (UPLIFT-02) — added META_COMPONENTS inventory of record (8 slugs: toolbar, data-table, filter-bar, action-panel, detail-drilldown, confirm-panel, drawer, toast-stack) beside COMPONENTS (Level-1 literals byte-unchanged, new exact() parity line). admin-css-build.mjs emits token-backed Level-2 composition CSS for all 8 units; data-table state is static/no-JS: th[aria-sort] visible ::after direction glyph (active column tinted --rindle-accent, direction-by-glyph not color), .rindle-admin-table--sticky position:sticky head inside an explicit overflow:auto scroll region, [data-rindle-admin-selected] selected surface + contextual .rindle-admin-bulk-bar. New fail-closed requiredMetaSelectors self-check (12 selectors). Contrast 58/58, 0 outline:none, 0 btn/card/dark class substrings. Drawer meta root named .rindle-admin-drawer-panel to avoid collision with the Level-1 .rindle-admin-drawer primitive. **priv sync + drift gate deferred to 97-04 BY DESIGN** (plan success criteria + files_modified excludes priv/): the ADMIN-02 `priv==brandbook` byte-equality test in admin_design_system_validation_test.exs is RED until 97-04 runs sync-admin-css.mjs — logged in phase deferred-items.md.
- [Phase 97]: Plan 03 (UPLIFT-02 SC2) — added two offender-returning sub-assertions to admin-polish.js: assertConsistentRhythm (walks [data-rindle-admin-meta] subtrees; checks rowGap/columnGap/top-bottom margin/four padding sides vs the 4px grid {4,8,16,24,32,48,64} ∪ documented exceptions {12,44}; 0px valid; ±SUBPIXEL_TOLERANCE; excludes sizing/line-height) and assertNoHorizontalScroll (per-meta-unit-root scrollWidth>clientWidth+CLIP_TOLERANCE, skips [data-rindle-admin-scroll-region] opt-in, D-94-07). Both wired into assertAdminPolish as HARD (non-warnOnly) checks feeding violations + exported; OVERLAP_ENFORCED stays false (97-04 flips it after a green cycle, D-97-11). admin-gallery-check.mjs loads both via the SAME adoptionRequire(createRequire over examples/adoption_demo) used for playwright and runs assertMetaCohesion (vacuous-pass guard: asserts META_COMPONENTS.length units under the gallery root, then zero-offender asserts on both checks) under the light theme. **[Rule 1] the rhythm walk is scoped to rindle-admin-*-classed elements**: the first real-data run surfaced 20 UA-stylesheet false positives (option 1-2px padding, checkbox 3px margin, bare p/h2 17px/21.165px em-margins) the generated CSS never sets — Pitfall 1's documented warning sign. Gallery check passes — 18 screenshots, zero rhythm + zero no-h-scroll offenders (sticky data-table excepted via its data-rindle-admin-scroll-region marker). This plan touches no CSS (no drift). The ExUnit 18-screenshot literal bump + priv sync drift gate + OVERLAP_ENFORCED flip all remain 97-04 by design.
- [Phase ?]: 97-04: phase seal — OVERLAP_ENFORCED flipped true (D-97-11) after a documented green warn cycle; priv rindle-admin.css synced byte-identical via sync-admin-css.mjs (ADMIN-02 drift gate resolved, cmp -s exit 0, empty drift); ExUnit literal moved atomically 10->18 screenshots + @screenshots extended by the 8 meta names, contrast kept 58/58; full gate green (4 tests 0 failures). Maintainer Option A: the warn-only lane's separate pre-existing assertFocusVisibleTokens host-cascade defect (adoption_demo daisyUI .menu{outline:none}/3px beats the shipped 2px #123A35 token) is deferred to a dedicated follow-up + logged in deferred-items.md, NOT masked with POLISH_EXEMPTIONS; adoption-demo-e2e lane stays red until that fix lands.
- [Phase ?]: 98-01: page/1 Level-3 scaffold authored existing-but-UNUSED (D-98-01)
- [Phase ?]: 98-01: ALL Phase-98 generated CSS landed in admin-css-build.mjs (scaffold §A, two-pane @1024-only, mobile-first two-stop responsive §C, stacked-table td::before, motion catalog §B GPU-only opacity/transform, :focus-visible+skip-link §D); first var(--rindle-shadow-card) consumer + extended fail-closed guards; byte-identical priv sync, deterministic, contrast 58/58; [Rule 1] theme-picker motion dropped background-color/color (gallery-check pressed-bg snapshot was mid-tween)
- [Phase ?]: 98-02b: row-header cell kept as <td scope=row> (not <th>) so it participates in the P1 §C stacked-card td-only flip
- [Phase ?]: 98-02b: six surfaces migrated onto page/1, one atomic commit per surface; P3-owned IA/route/confirm/microcopy held out by scope guards
- [Phase ?]: 98-03: variant_run_detail/1 resolves :id as run-id then asset-id fallback (latest run) for index deep-links, redaction parity = asset_detail/1; variants-jobs/:id :show added inside the existing live_session (auth macro byte-unchanged)
- [Phase ?]: 98-03: Actions verb-bucket REALLY distributed (handlers+forms removed) — regenerate->Processing via confirm_dialog/1, reconcile->Doctor, quarantine->asset detail; Maintenance keeps only owner/batch erasure; owner-erasure confirm rewired to confirm_dialog/1 (inert off @action_state==:preview)
- [Phase ?]: 98-03: Overview = GDS triage home off home_status/1 (no query change) — needs-attention deep-links to already-parsed filters (no new routes), health chips, recent activity, vanity totals last, affirmative all-clear; inspect/1 removed; §F off-voice strings replaced
- [Phase ?]: 98-04: phase seal — both merge-gate homes now executable over real surfaces. ExUnit 4->24 brandbook clauses (static §A/§B/§D/§E/§F + contrast 58/58 + drift + ADMIN-02 byte-equality); five non-inferable computed-style Playwright backstops in admin-polish.js (two-pane band @~900px, stacked-card ::before attr @759/761, reduced-motion 0s read UN-FROZEN, dialog inert reset-on-reconnect, focus-visible-vs-pointer); toHaveLength 22->24 lockstep (N=2). No warn->fail flip / no Cohort generalization (Phase 102 boundary held). visually-hidden carryover authored through the generator. Live adoption-demo-e2e lane CI-delegated (local Postgres saturated); maintainer approved.
- [Phase ?]: 99-01: ck_page/1 scaffold authored existing-but-UNUSED (Cohort analog of Phase 98 page/1); the .ck/data-ck-root/server-data-theme/.ck__wrap/.ck-hero shell centralized in one component so the 7 page migrations do not drift 7 copies (D-96-05/07/09)
- [Phase ?]: 99-01: one token-only .ck-output rule added to hand-authored cohort.css for ops/account <pre> panels (mirrors .ck-cred__value tokens; padding via --ck-3/--ck-4 to stay literal-free); cohort-pages.spec.js shares assertCohortPagePolish (assertAdminPolish reused UNCHANGED, warn mode, Pitfall-5 guard) + ExUnit module shares frozen-contract + page-body-scoped daisyUI-retirement helpers; both green vs /styleguide
- [Phase ?]: 99-03: /ops + /account migrated onto ck_page/1; phx-click buttons keep their element with bare .ck-btn (Pitfall 4, no ck_button/1); <pre> panels swap to P01 .ck-output
- [Phase ?]: 99-03: ExUnit /ops + /account contract tests assert always-present static contract + every phx-click handler; <pre :if> panels are the ops/batch/owner-erasure behavior-spec backstop (CI-delegated)
- [Phase ?]: 99-04: /members + /lessons onto ck_page/1; contextual ck_page title + named testid h1 in inner_block (mirrors P2); picture_tag/video_tag wrappers + variant <ul>/<li> kept byte-for-byte (NOT ck_table); replace/detach bare .ck-btn (Pitfall 4); replace-status + lesson-streaming-url reuse .ck-output; no new CSS
- [Phase ?]: 99-05: /posts + /media onto ck_page/1 closes COHORT-04 (all 5 small-7 pages). Media <dl> RESTYLED IN PLACE with .ck-detail (NOT ck_detail/1, Pitfall 2) so media-id/media-state/media-delivery-url <dd> ids/testids survive; delivery <dd> reuses .ck-output; variant <ul>/<li> kept (NOT ck_table); alex link plain .ck-btn <.link>; ExUnit /media seeds a real MediaVariant so variant-thumb renders
- [Phase ?]: 100-01: /upload migrated onto ck_page/1 + .ck-* across all 6 tabs; routed tab links + aria-current (no role=tablist/ck_tabs); tab_class/2 deleted; tus error = .ck-error+icon+role=alert; validated ?theme=dark enum-gated read enables Plan 02; one new token-only CSS rule; per-tab contract test (DB lane CI-delegated)
- [Phase ?]: 100-02: /upload proven at runtime — 6 per-tab + 1 dark polish case in cohort-pages.spec.js reusing assertCohortPagePolish UNCHANGED (D-96-06); dark drives server ?theme=dark not media emulation; 6 behavior specs incl tus-resume ?tab=tus ran GREEN LOCALLY (supersedes Plan-01 CI-delegation); contrast 28/28; COHORT-02 SC1/SC2/SC3 closed
- [Phase 101]: Plan 01 — shared Phoenix flash/error paths now render Cohort `.ck-flash`/`.ck-alert` markup with inline currentColor SVGs, split polite/assertive ARIA semantics, keyed `lv:clear-flash` dismissal, and `.ck-btn` button defaults. The only new CSS primitive is token-backed `.ck-flash`/`.ck-alert` using local `--_accent` mapped to existing `--ck-info` / `--ck-quarantine`; no token values, `tokens.json`, admin CSS, package deps, or build steps changed.
- [Phase 101]: Plan 02 — `Layouts.app/1` is now a bare app shell (nav, main slot, footer, flash) and routed page dimensions stay owned by each page's `ck_page/1` / `.ck__wrap`; dead Phoenix generator landing files (`PageController`, `PageHTML`, `home.html.heex`) and the obsolete controller test were deleted rather than migrated or scan-excluded.
- [Phase 101]: Plan 03 — full composed Cohort route renders are now the daisyUI retirement scan surface; root no longer links `default.css` while the asset remains for Plan 04's final destructive deletion.
- [Phase 101]: Delete default.css as the final destructive step after the Plan 03 render/source gate was green. — Preserves teardown ordering and keeps the irreversible file deletion behind the deterministic Cohort contract.
- [Phase 102]: Plan 01 — adminRoot now targets .rindle-admin-shell[data-rindle-admin-root] and expectAdminShell asserts one shell root before reading attributes; no root fallback or inference was added.
- [Phase 102]: Plan 01 — admin-screenshots matrix/backstops stayed unchanged (24 entries plus Phase 98 backstop calls); targeted browser checks now get past duplicate roots but expose out-of-scope focus-token and Doctor-checks strict locator failures logged in 102 deferred-items.md.
- [Phase ?]: Phase 102 Plan 02: Focus contracts resolve CSS custom properties from the explicit surface root first; documentElement fallback remains limited to the default admin contract.
- [Phase ?]: Phase 102 Plan 02: Admin dialog-inert backstops default on only for the default admin root; Cohort callers can opt into admin backstops explicitly but do not inherit them.
- [Phase 102]: Plan 03: Cohort route theme normalization uses a shared string-only allowlist helper; invalid values fall back before reaching data-theme.
- [Phase 102]: Plan 03: Dashboard, ops, and account erasure dark coverage is proven via rendered ?theme=dark route state plus existing Cohort contract ratchets.
- [Phase 102]: Member, lesson, post, and media route theme state reuses the Plan 03 shared normalizer instead of adding per-LiveView allowlists. — Keeps URL theme normalization string-only and consistent across Cohort route surfaces.
- [Phase 102]: Detail dark-mode proof is rendered route state (?theme=dark) paired with existing frozen DOM and daisyUI-retirement ratchets, not media emulation. — D-102-06 requires explicit rendered Cohort theme proof for the hard-fail visual matrix.
- [Phase 102]: Plan 05: Cohort visual proof is route/theme/viewport-driven and asserts rendered data-theme state; colorScheme media emulation is not used as routed Cohort dark proof.
- [Phase 102]: Plan 05: Admin/gallery PNG screenshots remain audit/reference artifacts; the blocking visual gate is DOM/computed-style assertions, not pixel diffs.
- [Phase 102]: Plan 06: Full `bash scripts/ci/adoption_demo_e2e.sh` is green after stale admin E2E expectations were updated to Phase 98's distributed action contract; final wrapper result 86 passed, 1 intentional live-GCS skip.
- [Phase 102]: Plan 06: Existing generated-asset/static idempotency proof ran twice consecutively and both runs ended with `git diff --exit-code` returning 0; no Cohort CSS generator was added and Cohort CSS stayed outside `tokens.json`.
- [Phase 102]: Plan 06: v1.19 audit records 20/20 requirements mapped and complete, including stale UPLIFT-01 traceability corrected from Phase 95 summaries; VIS-01..VIS-04 are complete.
- [Phase ?]: Phase 103 Plan 03: ci.yml instrumented additively/observationally — cache id:s + hit/miss tables, OBS-02 evidence, JUnit+coverage artifact upload, job-scoped ci-observability aggregator (per-job + per-step native timing from one jobs API read); name:CI/filename/workflow contents:read/run: gates unchanged; zero lib/ change; per-step jq matches display-name prefixes not job keys.
- [Phase 103]: Plan 04: OBS-03 baseline (103-BASELINE.md) captured before restructuring — per-job avg/p95 + 8/50 rerun over last 50 main runs, verbatim 12 live required-check contexts, brandbook-tokens drift recorded NOT fixed (D-09/D-14); fixed --paginate per-page slice bug in collect_ci_baseline.sh; internal .planning/ only, zero lib/ change.
- [Phase ?]: 104-01: setup-elixir composite shipped (uses: ./.github/actions/setup-elixir) — inputs elixir-version/otp-version required, mix-env(test)/cache-prefix(default)/install-deps(true); outputs deps-cache-hit/build-cache-hit; CACHE-02 key carries OS+arch+resolved-OTP+resolved-Elixir+MIX_ENV+hashFiles('mix.lock')+v1; cache-prefix=no-optional yields deps-no-optional/build-no-optional (D-05/D-06); no compile step.
- [Phase ?]: 104-01: setup-minio composite shipped — docker run minio/minio + health-ready wait + mc install + 'mc mb --ignore-existing local/rindle-test' byte-identical to ci.yml; lone input cors-allow-origin(default empty) gates -e MINIO_API_CORS_ALLOW_ORIGIN for adoption-demo-e2e; no job env/if-gate baked in (D-02).
- [Phase ?]: 104-01: .tool-versions landed (elixir 1.17.3-otp-27/erlang 27.2/nodejs 20.18.1) local-dev-only, NO setup-beam version-file wiring (D-13); patches PINNED-FOR-CONFIRMATION (asdf list-all blocked in sandbox) — confirm vs next CI setup-beam resolution. Side effect: file shadows local asdf node resolution.
- [Phase ?]: 104-02: quality job migrated onto the setup-elixir composite (D-03 canary); composite called install-deps:false so quality owns its CACHE-04-gated deps.get
- [Phase ?]: 104-02: PLT split = restore/save with save-before-analysis (D-08), keyed on mix.exs+.dialyzer_ignore.exs (D-07); PLT prefix uses coarse matrix.otp/elixir since setup-elixir does not surface resolved versions at job scope
- [Phase ?]: 104-03: setup-elixir adopted across the 7 literal-1.17/27 jobs + optional-dependencies (cache-prefix:no-optional, D-06) + package-consumer-gcs-live (secret-gate guard intact, D-03); install-deps:false everywhere preserves each job's existing deps.get
- [Phase ?]: 104-03: gcs-soak composite adoption DECLINED (plan-optional) — no existing deps/_build cache + fully secret-gated; left byte-identical. Only remaining inline setup-beam: gcs-soak (declined) + mux-soak (MinIO trio = Plan 04)
- [Phase ?]: [Phase 105]: Plan 01 — ci-summary aggregate job (name: CI Summary) is pure/network-free/zero-permission (D-02); needs: exactly the 11 gating jobs (mux/gcs-soak + package-consumer-gcs-live excluded, D-04); success+skipped pass, failure+cancelled fail (D-05); collect-all-then-exit (D-06). setup_branch_protection.sh collapsed to single CI Summary context (matches job name:, not id). Live branch-protection flip deferred to post-merge human checkpoint (Task 4, D-11).
- [Phase ?]: [Phase 106]: Plan 01 — LANE-04 A–E classification uses 5 buckets (keep/optimize/move-to-nightly/label-gated-PR-lane/off-critical-path); quarantine (D)/delete (E) empty (none identified, not invented). mux-soak bucketed label-gated PR lane (stays in ci.yml, NOT nightly, D-14); coverage off the PR critical path as advisory telemetry, mix coveralls stays the gating test invocation (D-07). CONTRIBUTING carries copy-pasteable trust/speed block + /gsd-ship PR-body paste handoff (LANE-04 PR-side half). Docs-only: zero workflow YAML, zero lib/ change.
- [Phase 106]: Plan 02 — ci.yml gains a top-level concurrency group keyed per-workflow+per-ref (`group: ${{ github.workflow }}-${{ github.ref }}`) with `cancel-in-progress: ${{ github.event_name == 'pull_request' }}`: stale PR runs cancel; push:main/workflow_dispatch serialize and are never cancelled (preserves the release-coupling full-matrix push:main run conclusion that `release.yml gate-ci-green` reads, D-06/LANE-01). `name: CI` + filename unchanged; no job-level concurrency; no continue-on-error added. Single-file YAML edit, zero lib/ change.
- [Phase ?]: 107-02: SHA-pinned all third-party actions; dependabot grouped/weekly non-release prefixes; mix_audit advisory in quality lane
- [Phase ?]: 107-03: mix ci alias mirrors the merge-blocking PR set; MinIO/Playwright legs documented in CONTRIBUTING not embedded; README badge reflects CI Summary, no custom endpoint

## Blockers/Concerns

- ~~v1.18 milestone-close gated on HUMAN-UAT sign-off for phases 90/91/92.~~ RESOLVED
  2026-06-20: maintainer signed off all three; v1.18 advanced `tech_debt` → `shipped` and
  archived. No remaining milestone-close blockers.

- ~~98-02b filed P1 CSS defect: missing .rindle-admin-visually-hidden utility (captions render visibly at >=760px until P1 adds it).~~ RESOLVED in 98-04 (commit b637710): utility authored through the full brandbook pipeline (regen → contrast 58/58 → gallery-check → sync), byte-identical priv copy, added to requiredSelectors + asserted by a new ExUnit §D clause.
- ~~adoption-demo-e2e red-gate concerns from Phases 97/101.~~ RESOLVED in 102-06: the full wrapper passed after stale admin E2E expectations were aligned with the shipped Phase 98 action distribution and current error copy.
- ~~107-01 HARD-01: async-safety guard implemented and working but reveals 4 pre-existing async:true modules using shared-state primitives (2 genuine Application.put_env races: profile_test, http_cancel_upload_test; 2 safe-but-unprovable File mutations: local_test, package_metadata_test) all OUT OF files_modified scope.~~ RESOLVED 2026-06-22 (orchestrator-approved Option A, commit e4e3186): the 2 genuine races flipped to async:false; the 2 safe modules annotated with justified `@async_safety_allow [:file_mutation]`. Guard logic NOT weakened. Guard is GREEN against the full tree; 15 CLEAN modules converted (a583040). Carry-forward (separate owner): `release_docs_parity_test.exs:319` fails PRE-EXISTING/unrelated from the parked docs-archive cleanup state — see 107 deferred-items.md.

## Deferred Items

| Category | Item | Status |
|----------|------|--------|
| lifecycle | Force-delete policy (LIFE-06) | demand-gated (v1.20+ on compliance ticket) |
| streaming | Second provider (Cloudflare/Bunny) | demand-gated (v1.20+ on named adopter) |
| tus | IETF RUFH / tus 2.0 | deferred |
| tus | GCS-as-tus-backend / R2-native tus proxying | out of scope |
| tus | Rindle-owned standalone tus JS client package | out of scope |
| tus | Richer reusable uploader abstractions | deferred |
| polish | Signed dynamic image transforms (TRANS-01 / job 33) | deferred |
| polish | EXIF privacy stripping (PRIV-01 / job 34) | deferred |
| v1.19 | Pixel-baseline `toHaveScreenshot()` as merge-blocker | confirmed non-blocking audit/reference signal; no second merge-blocking visual lane |

## Session Continuity

Last session: 2026-06-22T20:17:40.088Z
Stopped at: Completed 107-04-PLAN.md
Resume file: None

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| Phase 106 P04 | 14 min | 4 tasks | 2 files |
| Phase 86 P01 | 10 min | 2 tasks | 2 files |
| Phase 86 P02 | 2 min | 2 tasks | 2 files |
| Phase 86 P03 | 2 min | 3 tasks | 3 files |
| Phase 87 P01 | 8 min | 2 tasks | 2 files |
| Phase 87 P02 | 2 min | 2 tasks | 1 files |
| Phase 87 P03 | 3 min | 2 tasks | 2 files |
| Phase 88 P01 | 7 min | 2 tasks | 4 files |
| Phase 88 P02 | 6 min | 2 tasks | 4 files |
| Phase 88 P03 | 12 min | 2 tasks | 6 files |
| Phase 89 P01 | 6 min | 2 tasks | 3 files |
| Phase 89 P02 | 5 min | 2 tasks | 8 files |
| Phase 89 P03 | 7 min | 2 tasks | 3 files |
| Phase 89 P04 | 16 min | 2 tasks | 9 files |
| Phase 89 P05 | 8 min | 2 tasks | 5 files |
| Phase 89 P06 | 9 min | 2 tasks | 5 files |
| Phase 89 P07 | 7 min | 2 tasks | 4 files |
| Phase 90 P01 | 10 min | 3 tasks | 3 files |
| Phase 90 P02 | 15 min | 3 tasks | 3 files |
| Phase 91 P01 | 2 min | 3 tasks | 4 files |
| Phase 91 P02 | 5 min | 2 tasks | 3 files |
| Phase 91 P03 | 5 min | 2 tasks | 2 files |
| Phase 92 P01 | 5 min | 2 tasks | 6 files |
| Phase 92 P02 | 70 min | 2 tasks | 10 files |
| Phase 92 P04 | 25 min | 2 tasks | 5 files |
| Phase 92 P05 | 8min | 2 tasks | 7 files |
| Phase 93 P01 | 2min | 3 tasks | 4 files |
| Phase 93 P02 | 6min | 2 tasks | 2 files |
| Phase 93 P03 | 4min | 2 tasks | 3 files |
| Phase 93 P04 | 12min | 3 tasks | 6 files |
| Phase 94 P01 | 7min | 2 tasks | 2 files |
| Phase 94 P02 | 6 min | 1 tasks | 1 files |
| Phase 94 P03 | 5min | 2 tasks | 6 files |
| Phase 94 P04 | 4min | 1 tasks | 2 files |
| Phase 94 P05 | 6min | 2 tasks | 3 files |
| Phase 96 P01 | 3min | 2 tasks | 1 files |
| Phase 96 P02 | 4min | 2 tasks | 3 files |
| Phase 96 P04 | 14 min | 2 tasks tasks | 3 files files |
| Phase 96 P03 | 5min | 2 tasks | 2 files |
| Phase 96 P05 | 22min | 1 tasks | 3 files |
| Phase 97 P01 | 5min | 2 tasks | 3 files |
| Phase 97 P02 | 4min | 2 tasks | 3 files |
| Phase 97 P03 | 6min | 2 tasks | 2 files |
| Phase 97 P04 | 5min | 2 tasks | 3 files |
| Phase 98 P01 | 14min | 2 tasks | 5 files |
| Phase 98 P02a | 9min | 2 tasks | 1 files |
| Phase 98 P02b | 8min | 2 tasks | 6 files |
| Phase 98 P03 | 16min | 3 tasks | 12 files |
| Phase 98 PP04 | 15min | 3 tasks | 8 files |
| Phase 99 P01 | 3 min | 2 tasks | 4 files |
| Phase 99 P02 | 4 | 2 tasks | 3 files |
| Phase 99 P03 | 5 | 3 tasks | 4 files |
| Phase 99 P04 | 6 | 3 tasks | 4 files |
| Phase 99 P05 | 9 min | 3 tasks | 4 files |
| Phase 100 P01 | 8 min | 3 tasks | 3 files |
| Phase Phase 100 PP02 | 12min | 2 tasks tasks | 1 files files |
| Phase 101 P01 | 7 min | 3 tasks | 3 files |
| Phase 101 P02 | 6 min | 2 tasks | 7 files |
| Phase 101 P03 | 5 min | 2 tasks | 2 files |
| Phase 101 P04 | 6 min | 2 tasks | 3 files |
| Phase 102 P01 | 6 min | 2 tasks | 3 files |
| Phase 102 P02 | 7 min | 2 tasks | 2 files |
| Phase 102 P03 | 7 min | 2 tasks | 5 files |
| Phase 102 P04 | 5 min | 2 tasks | 5 files |
| Phase 102 P05 | 26 min | 3 tasks | 7 files |
| Phase 102 P06 | 55 min | 3 tasks | 5 files |
| Phase 95 P05 | 12min | 3 tasks | 7 files |
| Phase 103 P01 | 2 min | 2 tasks | 3 files |
| Phase 103 P02 | 4 min | 2 tasks | 2 files |
| Phase 103 P03 | 9 min | 3 tasks | 1 files |
| Phase 103 P04 | 9 min | 2 tasks | 2 files |
| Phase 104 P01 | 1 min | 3 tasks | 3 files |
| Phase 104 P02 | 4 min | 3 tasks | 1 files |
| Phase 104 P03 | 4min | 2 tasks | 1 files |
| Phase 104 P04 | 3min | 2 tasks | 2 files |
| Phase 105 P01 | 8 min | 3 tasks | 3 files |
| Phase 106 P01 | 2 min | 3 tasks | 3 files |
| Phase 106 P02 | 3 min | 1 tasks | 1 files |
| Phase 106 P03 | 8 min | 2 tasks | 1 files |
| Phase 107 P02 | 12m | 2 tasks | 8 files |
| Phase 107 P03 | 8min | 2 tasks | 3 files |
| Phase 107 P04 | 5 min | 2 tasks | 8 files |

## Operator Next Steps

- Start the next milestone with /gsd-new-milestone
