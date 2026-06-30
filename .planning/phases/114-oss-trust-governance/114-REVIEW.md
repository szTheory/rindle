---
phase: 114-oss-trust-governance
reviewed: 2026-06-30T15:03:04Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - SECURITY.md
  - CODE_OF_CONDUCT.md
  - .github/ISSUE_TEMPLATE/bug_report.yml
  - .github/ISSUE_TEMPLATE/feature_proposal.yml
  - .github/ISSUE_TEMPLATE/config.yml
  - .github/PULL_REQUEST_TEMPLATE.md
  - test/install_smoke/governance_files_test.exs
  - mix.exs
  - test/install_smoke/package_metadata_test.exs
findings:
  critical: 1
  warning: 0
  info: 0
  total: 1
status: issues_found
---

# Phase 114: Code Review Report

**Reviewed:** 2026-06-30T15:03:04Z
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Reviewed the Phase 114 governance docs, GitHub templates/config, install-smoke tests, and Hex package metadata changes against TRUST-01/02/03 and META-01/02. The security policy routes vulnerability reports privately through GitHub advisories with no email/public issue disclosure path, the release-train drift template remains present, and the package file list still excludes repo-only governance paths.

One blocker remains: the new maintainer metadata is only asserted in local Mix config and is not emitted into the unpacked Hex metadata produced by `mix hex.build --unpack`, so META-02 is not actually verified as a published Hex trust signal.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Maintainer Metadata Is Not Published Or Verified

**Classification:** BLOCKER
**File:** `mix.exs:282`, `test/install_smoke/package_metadata_test.exs:79`
**Issue:** `mix.exs` adds `maintainers: ["szTheory"]`, but Hex 2.5's package configuration does not serialize that key into the unpacked `hex_metadata.config`. A local `mix hex.build --unpack` for this tree emitted `links`, `name`, `version`, `description`, `licenses`, `files`, requirements, and build tools, but no maintainer field. The test then asserts `Mix.Project.config()[:package][:maintainers] == ["szTheory"]`, which proves only that the unsupported local key exists. It can pass while the generated Hex package metadata and hex.pm page still expose no maintainer signal, leaving META-02 unmet.
**Fix:** Do not keep a config-only assertion for a published metadata requirement. If the target Hex release supports serialized maintainer metadata, assert the generated artifact instead:

```elixir
compact_metadata = String.replace(metadata, ~r/\s+/, "")
assert compact_metadata =~ ~s({<<"maintainers">>,[<<"szTheory">>]})
```

If Hex maintainer display is owner-derived rather than package-config-derived, remove the unsupported `maintainers:` key from `package/0` and move META-02 to a release/owner verification gate, for example a release script that checks `mix hex.owner list rindle` or the Hex API for `szTheory`.

---

_Reviewed: 2026-06-30T15:03:04Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
