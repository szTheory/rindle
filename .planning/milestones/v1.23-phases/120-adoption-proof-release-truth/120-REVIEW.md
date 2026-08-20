---
phase: 120-adoption-proof-release-truth
reviewed: 2026-08-20T15:45:45Z
depth: standard
files_reviewed: 14
files_reviewed_list:
  - examples/adoption_demo/mix.exs
  - examples/adoption_demo/priv/repo/migrations/20260528120100_add_oban.exs
  - examples/adoption_demo/priv/repo/migrations/20260809000000_install_rindle.exs
  - examples/adoption_demo/test/rindle_migration_contract_test.exs
  - guides/getting_started.md
  - guides/release_publish.md
  - guides/troubleshooting.md
  - guides/upgrading.md
  - lib/rindle/migration.ex
  - scripts/ci/cohort_demo_smoke.sh
  - test/install_smoke/docs_parity_test.exs
  - test/install_smoke/generated_app_smoke_test.exs
  - test/install_smoke/release_docs_parity_test.exs
  - test/install_smoke/support/generated_app_helper.ex
findings:
  critical: 0
  warning: 1
  info: 0
  total: 1
status: issues_found
---

# Phase 120: Code Review Report

**Reviewed:** 2026-08-20T15:45:45Z
**Depth:** standard
**Files Reviewed:** 14
**Status:** issues_found

## Summary

Reviewed the Phase 120 migration, Cohort proof, generated-install proof, release-runbook, and parity-test changes in their committed context. The 0.4.0 network provenance repair correctly reports the generated app's fetched `deps/rindle` path rather than the unused local package path. One release-parity test, however, hard-codes the two transient manifest states used while cutting 0.4.0 and will turn every later valid release into a CI failure.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: Release parity test rejects every post-0.4.0 manifest

**Classification:** WARNING

**File:** `/tmp/rindle-phase120-closeout.oztwyr/test/install_smoke/release_docs_parity_test.exs:48-69`

**Issue:** The test permits only manifest version `0.3.2` (staging) or `0.4.0` (released), and explicitly fails for all other versions. Once Release Please creates the next legitimate release PR, such as `0.4.1`, the manifest changes and this merge-blocking parity test fails even if the 0.4.0 release notes and schema-isolation contract remain correct. That makes the completed 0.4.0 release leave the release train unable to advance without editing this test.

**Fix:** Keep the historical 0.4.0 assertion independent of the mutable manifest, or parse the manifest's current version and verify the appropriate generated section dynamically. For example, assert the 0.4.0 section exists and preserves its required facts, while separately asserting that the manifest has a valid semver version:

```elixir
manifest = Jason.decode!(release_manifest)
assert get_in(manifest, ["."]) =~ ~r/^\d+\.\d+\.\d+$/

release_notes = changelog_section(changelog, "[0.4.0]")
for fact <- required_contract, do: assert(release_notes =~ fact)
```

---

_Reviewed: 2026-08-20T15:45:45Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
