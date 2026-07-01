---
phase: 115-versioning-readme-positioning
reviewed: 2026-07-01T15:46:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - CONTRIBUTING.md
  - README.md
  - guides/upgrading.md
  - test/install_smoke/docs_parity_test.exs
findings:
  critical: 0
  warning: 3
  info: 0
  total: 3
status: issues_found
---

# Phase 115: Code Review Report

**Reviewed:** 2026-07-01T15:46:00Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Reviewed the listed docs and docs-parity test against Phase 115's VERSION-01, VERSION-02, README-01, and README-02 scope. The source diff is limited to the four requested files, the shared stability sentence appears exactly once in README and CONTRIBUTING, the image-first README ordering is present, and the targeted ExUnit/format checks pass.

The remaining issues are rendered-doc link regressions in `guides/upgrading.md`: the new changelog links point outside the generated HexDocs site, and the version index uses GitHub-style fragments that do not match ExDoc's generated heading ids. The new parity assertions do not cover those rendered link targets, so the broken upgrade-guide navigation passes green.

## Warnings

### WR-01: Upgrade Guide Changelog Links Break In HexDocs

**Classification:** WARNING
**File:** `guides/upgrading.md:3`
**Issue:** The new `[CHANGELOG.md](../CHANGELOG.md)` links at lines 3 and 21 are rendered by ExDoc as `href="../CHANGELOG.md"` from `upgrading.html`. `mix docs` warns that `../CHANGELOG.md` does not exist, and the published HexDocs link will route outside the package docs instead of to release history. This undercuts the Phase 115 requirement that the upgrade guide point adopters to the changelog before upgrading.
**Fix:**
```markdown
Use this guide with [CHANGELOG.md](https://github.com/szTheory/rindle/blob/main/CHANGELOG.md): the changelog names release
history, and this guide explains how existing apps should move safely.

Future releases that list adopter action items in [CHANGELOG.md](https://github.com/szTheory/rindle/blob/main/CHANGELOG.md).
```

### WR-02: Version Index Anchors Do Not Match ExDoc Heading IDs

**Classification:** WARNING
**File:** `guides/upgrading.md:14`
**Issue:** The version index links use `#unreleased--next` and `#013-and-earlier---current-av-aware-runtime`, but ExDoc generates heading ids `#unreleased-next` and `#0-1-3-and-earlier-current-av-aware-runtime` for the two target headings. In the rendered `doc/upgrading.html`, both index links point to non-existent anchors, so the page's primary version navigation is broken.
**Fix:**
```markdown
## Version index

- [Unreleased / Next](#unreleased-next)
- [0.1.3 and earlier -> current AV-aware runtime](#0-1-3-and-earlier-current-av-aware-runtime)
```

### WR-03: Docs Parity Does Not Validate Rendered Upgrade-Guide Links

**Classification:** WARNING
**File:** `test/install_smoke/docs_parity_test.exs:294`
**Issue:** The new upgrade-guide parity test asserts headings, ordering, and the substring `CHANGELOG.md`, but it never checks the Version index hrefs or rejects the broken `../CHANGELOG.md` links. That is why WR-01 and WR-02 pass with `28 tests, 0 failures`.
**Fix:**
```elixir
test "upgrade guide uses HexDocs-safe upgrade navigation links", %{upgrade: upgrade} do
  assert upgrade =~ "[Unreleased / Next](#unreleased-next)"
  assert upgrade =~
           "[0.1.3 and earlier -> current AV-aware runtime](#0-1-3-and-earlier-current-av-aware-runtime)"

  refute upgrade =~ "](../CHANGELOG.md)"
  assert upgrade =~ "https://github.com/szTheory/rindle/blob/main/CHANGELOG.md"
end
```

## Evidence

- `git diff --name-only 56cb935^..HEAD -- ...` is limited to `CONTRIBUTING.md`, `README.md`, `guides/upgrading.md`, and `test/install_smoke/docs_parity_test.exs`.
- `MIX_ENV=test mix test test/install_smoke/docs_parity_test.exs --trace` passed: 28 tests, 0 failures.
- `mix format --check-formatted test/install_smoke/docs_parity_test.exs` passed.
- `grep -R 'Rindle\.Migration\.' README.md CONTRIBUTING.md guides/upgrading.md` found no Phase 116 migration API docs.
- `mix docs` rendered `doc/upgrading.html` with `href="#unreleased--next"` / `href="#013-and-earlier---current-av-aware-runtime"` while the headings have ids `unreleased-next` / `0-1-3-and-earlier-current-av-aware-runtime`, and emitted the new `../CHANGELOG.md` missing-file warning.

---

_Reviewed: 2026-07-01T15:46:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
