---
phase: 115-versioning-readme-positioning
verified: 2026-07-01T15:57:38Z
status: passed
score: 6/6 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 115: Versioning & README Positioning Verification Report

**Phase Goal:** Versioning & README Positioning: state SemVer/pre-1.0 stability contract; generalize upgrade guide into reusable versioned sections; lead README with an image-only first attachment path; add clear when-not-to-use/product-fit boundary.  
**Verified:** 2026-07-01T15:57:38Z  
**Status:** passed  
**Re-verification:** No - initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | README and CONTRIBUTING both include the exact shared pre-1.0 SemVer stability sentence required by D-03. | VERIFIED | Node source check counted the exact sentence once in `README.md` and once in `CONTRIBUTING.md`; source lines: `README.md:36-38`, `CONTRIBUTING.md:11-13`. |
| 2 | README places `## Versioning and stability` near the top, above first-run/install content. | VERIFIED | `README.md:36` appears before `README.md:40` `## Install`; CONTRIBUTING also places the same heading before the `mix ci` gate section at `CONTRIBUTING.md:15`. |
| 3 | `guides/upgrading.md` is a reusable newest-first upgrade home with `## Version index`, `## Unreleased / Next`, `## 0.1.3 and earlier -> current AV-aware runtime`, required subsection labels, preserved proof commands, HexDocs-safe anchors, and safe changelog links. | VERIFIED | `guides/upgrading.md:13-38` has the index and newest-first sections; `:20/:25/:29/:34` and `:40/:45/:52/:155` have subsection labels; preserved proof tokens appear at `:78-165`; anchors at `:15-16`; GitHub changelog links at `:4` and `:23`; no `../CHANGELOG.md` source link. |
| 4 | README's first hands-on section is `## First Attachment in ~2 Minutes` before AV/dependency tokens and includes the original-only facade flow. | VERIFIED | `README.md:111` precedes `README.md:153`; `libvips`, `FFmpeg >= 6.0`, `kind: :video`, `Rindle.Profile.Presets.Web`, `web_720p`, and `poster` first occur after the image-first heading; `variants: []`, `allow_mime`, `max_bytes`, `Rindle.initiate_upload`, `Rindle.Upload.Broker.sign_url`, `Rindle.verify_completion`, `Rindle.attach`, and `Rindle.url` are in `README.md:117-145`. |
| 5 | README includes `## When Not to Use Rindle` with the Phoenix/Ecto library boundary and explicit non-goals from `guides/user_flows.md`. | VERIFIED | `README.md:318-325` states the Phoenix/Ecto library boundary and names hosted media platform, daemon, CDN replacement, DRM, HLS/DASH, AI/GPU, and PDF/Office boundaries; source truth exists in `guides/user_flows.md:20-26` and `:357-359`. |
| 6 | `test/install_smoke/docs_parity_test.exs` asserts the stability sentence, upgrade guide structure/link fix, README image-before-AV ordering, and product-fit boundary. | VERIFIED | Test coverage at `test/install_smoke/docs_parity_test.exs:49-67`, `:205-244`, `:246-260`, `:294-353`; local run passed: `MIX_ENV=test mix test test/install_smoke/docs_parity_test.exs --trace` -> 29 tests, 0 failures. |

**Score:** 6/6 truths verified (0 present-but-behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `README.md` | Versioning section, image-first path, demoted AV quickstart, when-not-to-use section | VERIFIED | Exists, substantive, and exercised by docs parity assertions. Key headings at lines 36, 111, 153, and 318. |
| `CONTRIBUTING.md` | Contributor-facing versioning and stability section | VERIFIED | Exists, substantive, exact sentence once, heading before CI detail; exercised by docs parity. |
| `guides/upgrading.md` | Reusable versioned upgrade guide | VERIFIED | Exists, substantive, newest-first structure, preserved proof sequence, safe anchors and changelog URLs; exercised by docs parity and read-only generated HTML check. |
| `test/install_smoke/docs_parity_test.exs` | Regression locks for Phase 115 contracts | VERIFIED | Exists, substantive, has `@contributing_path`, Phase 115 assertion groups, and passes targeted ExUnit run. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `README.md` | `RUNNING.md` | `running.html` links for FFmpeg/libvips details | VERIFIED | `README.md:151`, `:158`, `:333`; RUNNING contains libvips and FFmpeg matrices. |
| `README.md` | `guides/user_flows.md` | Product-fit boundary copy | VERIFIED | README boundary matches library-not-platform and non-goal source truth from `guides/user_flows.md`. |
| `guides/upgrading.md` | `CHANGELOG.md` | Release history reference while upgrade guide stays action-oriented | VERIFIED | Uses GitHub changelog URLs at `guides/upgrading.md:4` and `:23`; inline `CHANGELOG.md` reference at `:31`; no unsafe `../CHANGELOG.md` link. |
| `test/install_smoke/docs_parity_test.exs` | `README.md` | File read plus string/order assertions | VERIFIED | `@readme_path` and setup read at lines 7 and 38; Phase 115 README assertions at lines 49-67, 205-260. |
| `test/install_smoke/docs_parity_test.exs` | `CONTRIBUTING.md` | File read plus shared sentence assertion | VERIFIED | `@contributing_path` and setup read at lines 8 and 39; stability assertion at lines 49-67. |
| `test/install_smoke/docs_parity_test.exs` | `guides/upgrading.md` | File read plus version/link assertions | VERIFIED | `@upgrade_path` and setup read at lines 10 and 41; upgrade assertions at lines 294-353. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| README / CONTRIBUTING / upgrading guide | N/A | Static Markdown docs | N/A | Not applicable - no dynamic data-rendering artifact. |
| `test/install_smoke/docs_parity_test.exs` | Loaded doc strings | `File.read!` of repo docs in `setup_all` | Yes | VERIFIED - assertions run against current files. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Stability sentence count and order | Node source check over README/CONTRIBUTING | Counts were 1 and heading order was true for both files | PASS |
| README image-before-AV and boundary tokens | Node source check over README | Image heading index precedes AV and all dependency/AV tokens; required flow and boundary tokens present | PASS |
| Upgrade guide structure, anchors, proof commands, changelog URL | Node source check over `guides/upgrading.md` | Required headings, labels, proof commands, safe anchors, and GitHub changelog URL present; bad relative changelog link absent | PASS |
| Phase 115 docs parity regression locks | `MIX_ENV=test mix test test/install_smoke/docs_parity_test.exs --trace` | 29 tests, 0 failures | PASS |
| Test formatting | `mix format --check-formatted test/install_smoke/docs_parity_test.exs` | Exit 0 | PASS |
| Rendered link fix read-only check | `rg` over existing ignored `doc/upgrading.html` | Rendered IDs `unreleased-next` and `0-1-3-and-earlier-current-av-aware-runtime` plus GitHub changelog URL present; relative changelog link absent | PASS |

### Probe Execution

| Probe | Command | Result | Status |
|-------|---------|--------|--------|
| N/A | `find scripts -path '*/tests/probe-*.sh'` plus phase PLAN/SUMMARY probe grep | No phase-declared or conventional probe files found for this docs phase | SKIPPED |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| VERSION-01 | `115-01-PLAN.md` | README and CONTRIBUTING state SemVer/pre-1.0 stability contract and 1.0 meaning | SATISFIED | Exact shared sentence appears once in each file and is locked by docs parity test lines 49-67. |
| VERSION-02 | `115-01-PLAN.md` | `guides/upgrading.md` generalized into reusable versioned upgrade notes | SATISFIED | Version index, Unreleased/Next, 0.1.3-and-earlier section, labels, proof commands, safe anchors, and changelog URL verified in source and test lines 294-353. |
| README-01 | `115-01-PLAN.md` | README leads with image-only first attachment and demotes AV quickstart | SATISFIED | `README.md:111` image-first section precedes AV/dependency tokens; docs parity test lines 205-244 enforce it. |
| README-02 | `115-01-PLAN.md` | README has clear when-not-to-use/product-fit boundary | SATISFIED | `README.md:318-325` contains boundary and non-goals; docs parity test lines 246-260 enforces tokens. |

No orphaned Phase 115 requirements were found: REQUIREMENTS maps only VERSION-01, VERSION-02, README-01, and README-02 to Phase 115, and all four are claimed by the plan.

### Scope Guard And Prohibitions

| Guard | Status | Evidence |
|-------|--------|----------|
| No `lib/`, `priv/`, runtime behavior, dependency, version file, docs tooling/styling, or migration API work introduced | VERIFIED | `git diff --name-only 64d0560^..HEAD` outside planning artifacts is limited to `README.md`, `CONTRIBUTING.md`, `guides/upgrading.md`, and `test/install_smoke/docs_parity_test.exs`. |
| No `Rindle.Migration.*` / Phase 116 migration API docs introduced | VERIFIED | `rg` over README, CONTRIBUTING, and upgrading guide found no `Rindle.Migration`, `Rindle.Migration.`, `Migration.up`, or `Migration.down` matches. |
| No new docs component system, CSS, JS, dependency, or docs-theme files introduced | VERIFIED | Changed non-planning file set contains only Markdown docs plus one ExUnit parity test. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None | - | - | - | Word-boundary debt marker scan for `TBD`, `FIXME`, `XXX`, `TODO`, `HACK`, and `PLACEHOLDER` was clean. Empty/stub implementation scan was clean. |

`guides/upgrading.md:27` "No upgrade notes for this version yet" is the intentional `Unreleased / Next` empty state, not a stub; it is paired with upgrade-step guidance and future release instructions.

### Human Verification Required

None. The editorial concerns called out in validation were mechanically checked where possible: README avoids overclaiming by saying original-only first attachment first, then requiring libvips for image variants/background image processing and FFmpeg for AV work; the upgrade guide separates changelog history from adopter actions and keeps the existing proof sequence.

### Residual Warnings

- The verifier reran targeted source checks, docs parity, format, and read-only generated-doc link checks. It did not rerun full `mix ci` or regenerate docs, to avoid a long full-suite run and ignored `doc/` churn. The phase handoff reports those broader checks passed after the link fix.

### Gaps Summary

No gaps found. All roadmap success criteria, plan must-haves, requirement IDs, key links, tests, and scope guardrails are verified.

---

_Verified: 2026-07-01T15:57:38Z_  
_Verifier: the agent (gsd-verifier)_
