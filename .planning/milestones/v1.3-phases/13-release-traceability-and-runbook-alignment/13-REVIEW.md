---
phase: 13-release-traceability-and-runbook-alignment
reviewed: 2026-04-28T00:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - guides/release_publish.md
  - test/install_smoke/release_docs_parity_test.exs
findings:
  critical: 0
  warning: 3
  info: 1
  total: 4
status: issues_found
---

# Phase 13: Code Review Report

**Reviewed:** 2026-04-28
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Two files were reviewed: the maintainer release runbook (`guides/release_publish.md`) and its
parity test (`test/install_smoke/release_docs_parity_test.exs`). The runbook contains two
factual inaccuracies about the release workflow: the `bash scripts/public_smoke.sh` command is
documented without its required `$VERSION` argument, and the "Routine Releases" section implies
all four monitored steps execute within a single job when one of them belongs to a separate job.
The parity test has a substring-match weakness that allows the argument-omission inaccuracy to go
undetected, and the "Rollback and Revert" section is entirely uncovered by tests.

## Warnings

### WR-01: Guide omits required `$VERSION` argument from `public_smoke.sh` command

**File:** `guides/release_publish.md:119`

**Issue:** The "Release Workflow Contract" code block shows:

```bash
bash scripts/public_smoke.sh
```

The actual workflow command (`release.yml:194`) is:

```bash
bash scripts/public_smoke.sh "$VERSION"
```

`scripts/public_smoke.sh` requires the version as `$1` or via the
`RINDLE_INSTALL_SMOKE_NETWORK_VERSION` environment variable and exits with an error if neither is
provided (lines 7-11 of the script). The documented command would fail if copied and run verbatim
by a maintainer who did not read the workflow source. This is an inaccurate representation of the
shipped contract.

**Fix:** Update the code block to show the argument:

```bash
bash scripts/public_smoke.sh "$VERSION"
```

---

### WR-02: "Routine Releases" section implies all four monitored steps run in a single job

**File:** `guides/release_publish.md:31-36`

**Issue:** Lines 31-36 instruct the maintainer to:

> Monitor GitHub Actions until the `Release` workflow completes these step names in order:
> - `Run release preflight`
> - `Verify version alignment`
> - `Live publish to Hex`
> - `Verify public Hex.pm artifact`

The first three steps belong to the `release` job; `Verify public Hex.pm artifact` belongs to the
separate `public_verify` job (`release.yml:121`, `release.yml:189`). The `public_verify` job runs
after the `release` job completes (`needs: release`). A maintainer reading this list would expect
all four steps to appear in the same job's step log, and may look in the wrong place when
troubleshooting a failure.

**Fix:** Distinguish the two jobs:

```
5. Monitor GitHub Actions until both workflow jobs succeed:
   - In the **`Release Check`** job: `Run release preflight`, `Verify version alignment`,
     `Live publish to Hex`
   - In the **`Public Verify`** job (runs after `Release Check`): `Verify public Hex.pm artifact`
```

---

### WR-03: Parity test substring match fails to catch the missing `$VERSION` argument

**File:** `test/install_smoke/release_docs_parity_test.exs:107-109`

**Issue:** The `"release guide includes all shipped repo commands"` test checks:

```elixir
assert release_workflow =~ command
```

where `command` is `"bash scripts/public_smoke.sh"`. Because this is a substring match, it matches
the actual workflow line `bash scripts/public_smoke.sh "$VERSION"` even though the guide
documents the command without the argument. The test passes, masking the discrepancy identified
in WR-01. The test was designed to catch drift between the guide and the workflow, but it cannot
detect when the guide documents a partial (incorrect) form of the command.

**Fix:** Assert against the full command string as it appears in the workflow:

```elixir
commands = [
  "bash scripts/release_preflight.sh",
  "bash scripts/assert_version_match.sh",
  "mix hex.publish --yes",
  ~s(bash scripts/public_smoke.sh "$VERSION")
]
```

This will force the guide to be updated (WR-01) to include the argument in its code block, or
require the test and guide to agree on an alternate form.

---

## Info

### IN-01: Rollback and Revert section is entirely uncovered by the parity test

**File:** `test/install_smoke/release_docs_parity_test.exs` (no covering test)

**Issue:** The "Rollback and Revert" section of `guides/release_publish.md` (lines 144-159)
documents the `mix hex.revert` command, a 1-hour standard revert window, and a 24-hour extended
window for the first release. None of this content is asserted by any test in the parity suite.
If the section is deleted, rewritten, or its factual claims change, no automated check will fail.

**Fix:** Add a test that asserts the presence of the key rollback claims:

```elixir
test "release guide documents the rollback and revert procedure", %{
  release_guide: release_guide
} do
  for snippet <- [
        "mix hex.revert rindle VERSION",
        "1-hour window",
        "24 hours"
      ] do
    assert release_guide =~ snippet,
           "release_publish.md is missing rollback claim: #{inspect(snippet)}"
  end
end
```

---

_Reviewed: 2026-04-28_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
