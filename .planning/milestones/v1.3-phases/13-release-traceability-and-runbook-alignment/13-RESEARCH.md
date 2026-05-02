# Phase 13: Release Traceability and Runbook Alignment - Research

**Researched:** 2026-04-28
**Domain:** planning-artifact traceability, summary frontmatter normalization, and release runbook/workflow parity
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

No explicit `## Decisions`, `## Claude's Discretion`, or `## Deferred Ideas` sections exist in `13-CONTEXT.md`; treat the scoped phase context below as locked. [VERIFIED: .planning/phases/13-release-traceability-and-runbook-alignment/13-CONTEXT.md]

### Locked Scope (verbatim from CONTEXT.md)

#### Why This Phase Exists

The `v1.2` milestone audit dated `2026-04-29` found no broken release flows,
but it did leave the milestone at `tech_debt` because the planning artifacts do
not tell one consistent story about requirement completion.

The audit called out four closure items:

1. `RELEASE-04` and `RELEASE-05` are verified in Phase 10 artifacts, but
   `.planning/REQUIREMENTS.md` still leaves them pending.
2. Phase 11 summaries do not declare `requirements-completed`, so
   `RELEASE-06` and `RELEASE-07` stay partial in the strict three-source audit.
3. Phase 12 summaries use `requirement:` / `requirements:` rather than
   `requirements-completed`, so `RELEASE-08` and `RELEASE-09` stay partial in
   the strict audit.
4. `guides/release_publish.md` and the release workflow need an explicit
   parity guard so future runbook drift is caught automatically.

#### Phase Goal

Make the release milestone fully traceable across requirements, summaries,
verification, and maintainer docs so a follow-up audit can pass without manual
interpretation.

#### Planned Work

- Normalize requirement completion metadata across the Phase 11 and Phase 12
  summary frontmatter.
- Reconcile `.planning/REQUIREMENTS.md` checkbox and traceability state with
  the already-shipped release milestone evidence.
- Align `guides/release_publish.md` with the live release workflow contract.
- Add or extend an automated release-doc parity check so this drift cannot
  silently recur.

#### Requirements In Scope

- `RELEASE-04`
- `RELEASE-05`
- `RELEASE-06`
- `RELEASE-07`
- `RELEASE-08`
- `RELEASE-09`

#### Exit Condition

The milestone audit can mark all six release requirements as satisfied using
its strict three-source cross-check, and the maintainer runbook matches the
shipped workflow contract.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| RELEASE-04 | Maintainer can prepare Rindle for its first public `Hex.pm` publish with explicit package metadata, owner/auth setup, and a documented versioning/release checklist | Mark the existing Phase 10 evidence as complete in `.planning/REQUIREMENTS.md`; do not re-implement release behavior. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/milestones/v1.2-phases/10-publish-readiness/10-01-SUMMARY.md] [VERIFIED: .planning/milestones/v1.2-phases/10-publish-readiness/10-VERIFICATION.md] |
| RELEASE-05 | Maintainer can inspect the exact package tarball and docs build output before any live publish occurs | Same as RELEASE-04: reconcile traceability metadata against already-passing Phase 10 artifacts. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/milestones/v1.2-phases/10-publish-readiness/10-02-SUMMARY.md] [VERIFIED: .planning/milestones/v1.2-phases/10-publish-readiness/10-VERIFICATION.md] |
| RELEASE-06 | Protected release automation can publish Rindle to `Hex.pm` with a scoped publish credential without requiring ad hoc local maintainer auth | Normalize Phase 11 summary frontmatter to `requirements-completed` so the existing verified workflow evidence becomes machine-consumable. [VERIFIED: .planning/milestones/v1.2-phases/11-protected-publish-automation/11-VERIFICATION.md] [VERIFIED: .planning/milestones/v1.2-phases/11-protected-publish-automation/11-01-SUMMARY.md] |
| RELEASE-07 | Release automation fails before publication when package contents, docs generation, or package-consumer install proof drift from the expected release path | Preserve the existing preflight/version-check/public-proof contract and only align summary metadata plus parity assertions. [VERIFIED: scripts/release_preflight.sh] [VERIFIED: scripts/assert_version_match.sh] [VERIFIED: test/install_smoke/package_metadata_test.exs] |
| RELEASE-08 | Maintainer can verify a freshly published Rindle version by resolving it from `Hex.pm` in a fresh consumer flow instead of only from a local package path | Normalize Phase 12 summary frontmatter to `requirements-completed`; no new public verification path is needed. [VERIFIED: .planning/phases/12-public-verification-and-release-operations/12-VERIFICATION.md] [VERIFIED: .planning/phases/12-public-verification-and-release-operations/12-01-SUMMARY.md] |
| RELEASE-09 | Maintainer-facing docs describe the first-publish flow, future routine release flow, and the immediate rollback/revert path for a bad release | Remove the stale “Phase 11 will add automation” sentence and extend the existing release-doc parity test to assert the live workflow contract. [VERIFIED: guides/release_publish.md] [VERIFIED: test/install_smoke/release_docs_parity_test.exs] [VERIFIED: .github/workflows/release.yml] |
</phase_requirements>

## Summary

Phase 13 is not a new release-system build. It is a metadata and documentation repair pass over already-shipped Phase 10, 11, and 12 work. The milestone audit says the release path itself passes, but the strict three-source requirement audit fails because `.planning/REQUIREMENTS.md`, summary frontmatter, and verification reports disagree on completion state for `RELEASE-04` through `RELEASE-09`. [VERIFIED: .planning/v1.2-MILESTONE-AUDIT.md]

The repo already has the canonical schema and the canonical parity-test pattern. The GSD summary template requires `requirements-completed`, the summary extractor reads `requirements-completed`, and the milestone audit consumes that key explicitly. Phase 10 summaries follow that contract; Phase 11 summaries omit it; Phase 12 summaries use `requirement:` / `requirements:` instead. [CITED: /Users/jon/.codex/get-shit-done/templates/summary.md] [CITED: /Users/jon/.codex/get-shit-done/bin/lib/commands.cjs] [CITED: /Users/jon/.codex/get-shit-done/workflows/audit-milestone.md] [VERIFIED: .planning/milestones/v1.2-phases/10-publish-readiness/10-01-SUMMARY.md] [VERIFIED: .planning/milestones/v1.2-phases/11-protected-publish-automation/11-01-SUMMARY.md] [VERIFIED: .planning/phases/12-public-verification-and-release-operations/12-01-SUMMARY.md]

The smallest correct implementation is: update requirement checkboxes/traceability in `.planning/REQUIREMENTS.md`, normalize every relevant Phase 11 and Phase 12 summary to `requirements-completed`, and extend `test/install_smoke/release_docs_parity_test.exs` so `guides/release_publish.md` must stay aligned with the live workflow contract in `.github/workflows/release.yml`. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: test/install_smoke/release_docs_parity_test.exs] [VERIFIED: .github/workflows/release.yml]

**Primary recommendation:** Treat `requirements-completed` as the only supported summary key, reconcile `RELEASE-04` through `RELEASE-09` in `.planning/REQUIREMENTS.md`, and extend the existing ExUnit release-doc parity gate rather than building new audit tooling. [CITED: /Users/jon/.codex/get-shit-done/templates/summary.md] [CITED: /Users/jon/.codex/get-shit-done/workflows/audit-milestone.md] [VERIFIED: test/install_smoke/release_docs_parity_test.exs]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Requirement completion truth for `RELEASE-04`..`RELEASE-09` | Planning artifacts | Audit tooling | `.planning/REQUIREMENTS.md` is the milestone trace table source, while the audit only reads and reports that state. [VERIFIED: .planning/REQUIREMENTS.md] [CITED: /Users/jon/.codex/get-shit-done/workflows/audit-milestone.md] |
| Machine-readable summary completion metadata | Planning artifacts | GSD summary extractor | `requirements-completed` lives in summary frontmatter and is extracted by `summary-extract`. [CITED: /Users/jon/.codex/get-shit-done/templates/summary.md] [CITED: /Users/jon/.codex/get-shit-done/bin/lib/commands.cjs] |
| Maintainer release workflow contract | Maintainer docs | GitHub Actions workflow | `guides/release_publish.md` describes the human-facing contract, but `.github/workflows/release.yml` is the executable source of truth. [VERIFIED: guides/release_publish.md] [VERIFIED: .github/workflows/release.yml] |
| Drift prevention for runbook/workflow parity | ExUnit contract tests | CI/package-consumer job | `test/install_smoke/release_docs_parity_test.exs` already enforces release-doc policy, and `scripts/release_preflight.sh` plus CI already run it before publish. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] [VERIFIED: scripts/release_preflight.sh] [VERIFIED: .github/workflows/ci.yml] |
| Milestone closure evidence | Verification reports | Milestone audit | `*-VERIFICATION.md` remains the narrative evidence layer; the milestone audit cross-checks it with requirements and summaries. [VERIFIED: .planning/milestones/v1.2-phases/10-publish-readiness/10-VERIFICATION.md] [VERIFIED: .planning/milestones/v1.2-phases/11-protected-publish-automation/11-VERIFICATION.md] [VERIFIED: .planning/phases/12-public-verification-and-release-operations/12-VERIFICATION.md] [VERIFIED: .planning/v1.2-MILESTONE-AUDIT.md] |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ExUnit | bundled with Mix 1.19.5 in this environment | Executable parity checks for release docs and package metadata | The repo already uses targeted ExUnit tests for release-doc parity and package metadata instead of separate custom audit binaries. [VERIFIED: mix --version] [VERIFIED: test/install_smoke/release_docs_parity_test.exs] [VERIFIED: test/install_smoke/package_metadata_test.exs] |
| GitHub Actions workflow YAML | repo-native | Executable release contract | The live release path and the CI dry-run path are already expressed in `.github/workflows/release.yml` and `.github/workflows/ci.yml`. [VERIFIED: .github/workflows/release.yml] [VERIFIED: .github/workflows/ci.yml] |
| GSD summary/audit conventions | repo + installed GSD tooling | Canonical schema for summary frontmatter and milestone audit extraction | The template and extractor both standardize on `requirements-completed`. [CITED: /Users/jon/.codex/get-shit-done/templates/summary.md] [CITED: /Users/jon/.codex/get-shit-done/bin/lib/commands.cjs] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Bash scripts | repo-native | Release preflight, version assertion, and public smoke probes | Reuse existing scripts when parity checks need to reference the shipped release contract. [VERIFIED: scripts/release_preflight.sh] [VERIFIED: scripts/assert_version_match.sh] [VERIFIED: scripts/public_smoke.sh] |
| `rg` / `grep` verification commands | system utilities | Fast file-level traceability checks in docs/planning files | Use for task acceptance checks and verification tables, not as the primary parity framework. [VERIFIED: .planning/phases/12-public-verification-and-release-operations/12-02-SUMMARY.md] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Extending `release_docs_parity_test.exs` | New standalone shell audit script | Worse fit; the repo already runs the ExUnit parity test in `scripts/release_preflight.sh` and CI, so a new script duplicates enforcement paths. [VERIFIED: scripts/release_preflight.sh] [VERIFIED: .github/workflows/ci.yml] |
| Normalizing summary files to `requirements-completed` | Teaching tooling to accept `requirement:` / `requirements:` aliases | Higher long-term drift risk; the installed template, extractor, and audit already document one canonical key. [CITED: /Users/jon/.codex/get-shit-done/templates/summary.md] [CITED: /Users/jon/.codex/get-shit-done/bin/lib/commands.cjs] [CITED: /Users/jon/.codex/get-shit-done/workflows/audit-milestone.md] |

**Installation:**
```bash
# No new packages are required for this phase.
```

**Version verification:** No new package dependency should be introduced for Phase 13; the existing local toolchain includes Mix `1.19.5`, Node `v22.14.0`, and npm `11.1.0`. [VERIFIED: mix --version] [VERIFIED: node --version] [VERIFIED: npm --version]

## Architecture Patterns

### System Architecture Diagram

```text
.planning/REQUIREMENTS.md
  -> milestone requirement checkbox + traceability state
  -> .planning/v1.2-MILESTONE-AUDIT.md cross-check

Phase 10/11/12 *-SUMMARY.md frontmatter
  -> summary extractor reads requirements-completed
  -> milestone audit compares summary metadata vs verification vs requirements

guides/release_publish.md
  -> release_docs_parity_test.exs assertions
  -> scripts/release_preflight.sh
  -> .github/workflows/ci.yml package-consumer lane

.github/workflows/release.yml
  -> shipped release contract step names
  -> release_docs_parity_test.exs contract assertions
  -> guides/release_publish.md text must match
```

The important data flow is requirements table -> summary metadata -> audit verdict, plus workflow contract -> runbook text -> parity test. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/v1.2-MILESTONE-AUDIT.md] [VERIFIED: test/install_smoke/release_docs_parity_test.exs] [VERIFIED: .github/workflows/release.yml]

### Recommended Project Structure
```text
.planning/
├── REQUIREMENTS.md                      # checkbox + traceability truth
├── v1.2-MILESTONE-AUDIT.md              # strict three-source audit consumer
├── milestones/v1.2-phases/11-.../       # historical Phase 11 summaries to normalize
└── phases/12-.../                       # active Phase 12 summaries to normalize

guides/
└── release_publish.md                   # maintainer runbook

test/install_smoke/
└── release_docs_parity_test.exs         # executable parity gate to extend

.github/workflows/
├── release.yml                          # shipped release workflow contract
└── ci.yml                               # package-consumer shift-left contract
```

### Pattern 1: Canonical Summary Frontmatter
**What:** Use `requirements-completed` in every summary that participates in requirement traceability. [CITED: /Users/jon/.codex/get-shit-done/templates/summary.md]
**When to use:** Any `*-SUMMARY.md` that closes or documents requirement coverage. [CITED: /Users/jon/.codex/get-shit-done/workflows/execute-plan.md]
**Example:**
```yaml
# Source: .planning/milestones/v1.2-phases/10-publish-readiness/10-01-SUMMARY.md
requirements-completed: [RELEASE-04]
```

### Pattern 2: Executable Runbook/Workflow Parity
**What:** Read the runbook and workflow files directly in ExUnit and assert exact workflow-step names and commands. [VERIFIED: test/install_smoke/release_docs_parity_test.exs]
**When to use:** Whenever release-process text must stay aligned with CI/release automation. [VERIFIED: scripts/release_preflight.sh] [VERIFIED: .github/workflows/ci.yml]
**Example:**
```elixir
# Source: test/install_smoke/package_metadata_test.exs
assert workflow =~ "public_verify:"
assert workflow =~ ~s(name: Verify public Hex.pm artifact)
assert workflow =~ ~s(bash scripts/public_smoke.sh "$VERSION")
```

### Pattern 3: Shift-Left Release Contract Reuse
**What:** Reuse the same parity and preflight checks in CI before tag-time. [VERIFIED: scripts/release_preflight.sh] [VERIFIED: .github/workflows/ci.yml]
**When to use:** Any release-doc or release-workflow guard that should fail in PR CI instead of only on real tags. [VERIFIED: .github/workflows/ci.yml]
**Example:**
```bash
# Source: scripts/release_preflight.sh
MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs
MIX_ENV=dev mix docs --warnings-as-errors
bash scripts/assert_release_docs_html.sh
```

### Anti-Patterns to Avoid
- **Alias drift in summary metadata:** Do not use `requirement:` or `requirements:` as substitutes for `requirements-completed`; the audit does not treat them as equivalent. [VERIFIED: .planning/phases/12-public-verification-and-release-operations/12-01-SUMMARY.md] [VERIFIED: .planning/phases/12-public-verification-and-release-operations/12-02-SUMMARY.md] [CITED: /Users/jon/.codex/get-shit-done/workflows/audit-milestone.md]
- **Phase-relative prose in evergreen docs:** Do not leave statements like “Phase 11 will add automation” in a maintainer runbook after the workflow has shipped. [VERIFIED: guides/release_publish.md] [VERIFIED: .github/workflows/release.yml]
- **Audit-by-memory:** Do not rely on the milestone audit author to interpret mismatched planning metadata manually; make all three sources agree. [VERIFIED: .planning/v1.2-MILESTONE-AUDIT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Summary schema compatibility | A new alias layer in the extractor for `requirement:` / `requirements:` | Normalize the summaries to `requirements-completed` | The template and audit already document one canonical key; extra aliases preserve drift. [CITED: /Users/jon/.codex/get-shit-done/templates/summary.md] [CITED: /Users/jon/.codex/get-shit-done/bin/lib/commands.cjs] |
| Release-doc parity enforcement | A second custom audit script | Extend `test/install_smoke/release_docs_parity_test.exs` | Existing preflight and CI already execute that test; new tools add another enforcement surface. [VERIFIED: scripts/release_preflight.sh] [VERIFIED: .github/workflows/ci.yml] |
| Requirement closure proof | New release automation or new verification reports | Reuse the existing Phase 10–12 verification artifacts and update planning metadata | The audit already states the release system passes; the gap is traceability, not missing runtime behavior. [VERIFIED: .planning/v1.2-MILESTONE-AUDIT.md] |

**Key insight:** This phase should repair metadata around existing truth, not create a second truth source. [VERIFIED: .planning/v1.2-MILESTONE-AUDIT.md]

## Common Pitfalls

### Pitfall 1: Fixing Only The Checkboxes
**What goes wrong:** `.planning/REQUIREMENTS.md` gets updated to `[x]`, but the corresponding summaries still do not expose `requirements-completed`, so the audit stays partial. [VERIFIED: .planning/v1.2-MILESTONE-AUDIT.md]
**Why it happens:** The milestone audit requires three sources, not one. [CITED: /Users/jon/.codex/get-shit-done/workflows/audit-milestone.md]
**How to avoid:** Update requirements, summaries, and then re-run the strict cross-check logic against all six IDs. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/v1.2-MILESTONE-AUDIT.md]
**Warning signs:** `REQUIREMENTS.md` shows `[x]`, but audit notes still say “missing” in the SUMMARY frontmatter column. [VERIFIED: .planning/v1.2-MILESTONE-AUDIT.md]

### Pitfall 2: Normalizing Only The Obvious Summary Files
**What goes wrong:** `11-01` and `11-02` get fixed, but `11-03-SUMMARY.md` remains on a non-canonical schema and keeps Phase 11 inconsistent. [VERIFIED: .planning/milestones/v1.2-phases/11-protected-publish-automation/11-03-SUMMARY.md]
**Why it happens:** Phase 11 lives under the archived milestone path, not the active `.planning/phases/` path, so it is easy to miss during a narrow edit sweep. [VERIFIED: .planning/milestones/v1.2-phases/11-protected-publish-automation/11-01-SUMMARY.md] [VERIFIED: .planning/phases/12-public-verification-and-release-operations/12-01-SUMMARY.md]
**How to avoid:** Audit all Phase 11 and Phase 12 summary files before editing, then normalize every one that should participate in the canonical template. [VERIFIED: .planning/milestones/v1.2-phases/11-protected-publish-automation/11-01-SUMMARY.md] [VERIFIED: .planning/milestones/v1.2-phases/11-protected-publish-automation/11-02-SUMMARY.md] [VERIFIED: .planning/milestones/v1.2-phases/11-protected-publish-automation/11-03-SUMMARY.md] [VERIFIED: .planning/phases/12-public-verification-and-release-operations/12-01-SUMMARY.md] [VERIFIED: .planning/phases/12-public-verification-and-release-operations/12-02-SUMMARY.md]
**Warning signs:** Mixed keys like `requirements:`, `requirement:`, `patterns_established`, or `performance_metrics` appear in adjacent summaries. [VERIFIED: .planning/milestones/v1.2-phases/11-protected-publish-automation/11-03-SUMMARY.md] [VERIFIED: .planning/phases/12-public-verification-and-release-operations/12-02-SUMMARY.md]

### Pitfall 3: Updating The Runbook Without Updating The Parity Gate
**What goes wrong:** `guides/release_publish.md` gets fixed once, but a later workflow change reintroduces drift and nobody notices until a milestone audit. [VERIFIED: .planning/v1.2-MILESTONE-AUDIT.md]
**Why it happens:** The current parity test still focuses on Phase 10 concerns and does not assert the stale Phase 12 automation sentence away. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] [VERIFIED: guides/release_publish.md]
**How to avoid:** Add assertions for the shipped release step names and refute the stale “Phase 11 will add automation” language. [VERIFIED: .github/workflows/release.yml] [VERIFIED: guides/release_publish.md]
**Warning signs:** The runbook contains “Phase 11” language or claims `HEX_API_KEY` automation is deferred while `release.yml` already runs `mix hex.publish --yes`. [VERIFIED: guides/release_publish.md] [VERIFIED: .github/workflows/release.yml]

## Code Examples

Verified patterns from repo sources:

### Canonical requirement completion frontmatter
```yaml
# Source: .planning/milestones/v1.2-phases/10-publish-readiness/10-02-SUMMARY.md
requirements-completed: [RELEASE-05]
```

### Existing release-doc parity test extension point
```elixir
# Source: test/install_smoke/release_docs_parity_test.exs
test "release guide includes package metadata review and preflight commands", %{
  release_guide: release_guide
} do
  for snippet <- [
        "Package metadata review",
        "mix hex.build --unpack",
        "hex_metadata.config",
        "guides/release_publish.md",
        "mix docs --warnings-as-errors"
      ] do
    assert release_guide =~ snippet
  end
end
```

### Existing workflow-contract parity assertions
```elixir
# Source: test/install_smoke/package_metadata_test.exs
test "release workflow automates public verification on a fresh runner", %{
  release_workflow: workflow
} do
  assert workflow =~ "public_verify:"
  assert workflow =~ "needs: release"
  assert workflow =~ ~s(name: Verify public Hex.pm artifact)
  assert workflow =~ ~s(HEX_API_KEY: "")
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Summary metadata varied by phase (`requirements`, `requirement`, omitted) | `requirements-completed` is the canonical schema | Current installed GSD template and extractor | Phase 13 should normalize files to the canonical key, not broaden parser behavior. [CITED: /Users/jon/.codex/get-shit-done/templates/summary.md] [CITED: /Users/jon/.codex/get-shit-done/bin/lib/commands.cjs] |
| Release guide said live `HEX_API_KEY` automation was deferred | Release workflow already performs live publish under `environment: release` | Phase 11 workflow shipped before the 2026-04-29 audit | The stale sentence is now incorrect and must be guarded by test coverage. [VERIFIED: guides/release_publish.md] [VERIFIED: .github/workflows/release.yml] [VERIFIED: .planning/v1.2-MILESTONE-AUDIT.md] |
| Human/manual interpretation during audit | Strict three-source cross-check | Current audit workflow | Planning artifacts must be machine-readable and aligned. [CITED: /Users/jon/.codex/get-shit-done/workflows/audit-milestone.md] |

**Deprecated/outdated:**
- `requirement:` and `requirements:` as summary-level requirement-completion markers are outdated for this repo’s audit flow. [VERIFIED: .planning/phases/12-public-verification-and-release-operations/12-01-SUMMARY.md] [VERIFIED: .planning/phases/12-public-verification-and-release-operations/12-02-SUMMARY.md] [CITED: /Users/jon/.codex/get-shit-done/workflows/audit-milestone.md]
- The runbook sentence deferring live `HEX_API_KEY` automation to Phase 11 is outdated relative to the shipped workflow. [VERIFIED: guides/release_publish.md] [VERIFIED: .github/workflows/release.yml]

## Assumptions Log

All research claims were verified in this session. No user confirmation is required before planning.

## Open Questions

1. **Should `11-03-SUMMARY.md` carry `requirements-completed: []` or remain outside traceability normalization?**
   - What we know: `11-03-PLAN.md` has no `requirements:` frontmatter, but `11-03-SUMMARY.md` is still on a non-canonical schema. [VERIFIED: .planning/milestones/v1.2-phases/11-protected-publish-automation/11-03-PLAN.md] [VERIFIED: .planning/milestones/v1.2-phases/11-protected-publish-automation/11-03-SUMMARY.md]
   - What's unclear: Whether Phase 13 wants to normalize only requirement-bearing summaries or every summary in the affected phases.
   - Recommendation: Prefer adding `requirements-completed: []` and aligning the rest of the frontmatter to the template if the file is touched, because the template marks the field required. [CITED: /Users/jon/.codex/get-shit-done/templates/summary.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `mix` | ExUnit parity tests, docs build, release scripts | ✓ | 1.19.5 | — |
| `node` | GSD tooling / local audit helpers | ✓ | v22.14.0 | — |
| `npm` | Auxiliary JS tooling if needed by GSD helpers | ✓ | 11.1.0 | — |
| GitHub Actions runtime | End-to-end release workflow execution | ✗ local / ✓ remote-by-design | — | Verify by static workflow assertions locally and rely on CI for live execution |

**Missing dependencies with no fallback:**
- None for planning or implementation research. [VERIFIED: mix --version] [VERIFIED: node --version] [VERIFIED: npm --version]

**Missing dependencies with fallback:**
- GitHub Actions runners are not locally available, but the repo already uses static workflow assertions in ExUnit plus CI execution for parity checks. [VERIFIED: test/install_smoke/package_metadata_test.exs] [VERIFIED: .github/workflows/ci.yml]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit + shell/grep verification [VERIFIED: .planning/phases/12-public-verification-and-release-operations/12-VALIDATION.md] |
| Config file | `mix.exs`, `test/test_helper.exs` [VERIFIED: .planning/phases/12-public-verification-and-release-operations/12-VALIDATION.md] |
| Quick run command | `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs test/install_smoke/package_metadata_test.exs` [VERIFIED: test/install_smoke/release_docs_parity_test.exs] [VERIFIED: test/install_smoke/package_metadata_test.exs] |
| Full suite command | `mix test` [VERIFIED: .planning/phases/12-public-verification-and-release-operations/12-VALIDATION.md] |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| RELEASE-04 | `.planning/REQUIREMENTS.md` marks `RELEASE-04` complete and still points at the shipped Phase 10 evidence | static traceability | `rg -n '\\[x\\].*RELEASE-04|RELEASE-04 \\| Phase 10 \\| Satisfied' .planning/REQUIREMENTS.md` | ✅ |
| RELEASE-05 | `.planning/REQUIREMENTS.md` marks `RELEASE-05` complete and still points at the shipped Phase 10 evidence | static traceability | `rg -n '\\[x\\].*RELEASE-05|RELEASE-05 \\| Phase 10 \\| Satisfied' .planning/REQUIREMENTS.md` | ✅ |
| RELEASE-06 | Phase 11 summary metadata exposes `requirements-completed` for the verified publish automation requirement | static frontmatter | `rg -n '^requirements-completed:.*RELEASE-06' .planning/milestones/v1.2-phases/11-protected-publish-automation/*SUMMARY.md` | ✅ |
| RELEASE-07 | Phase 11 summary metadata exposes `requirements-completed` for the verified fail-fast automation requirement | static frontmatter | `rg -n '^requirements-completed:.*RELEASE-07' .planning/milestones/v1.2-phases/11-protected-publish-automation/*SUMMARY.md` | ✅ |
| RELEASE-08 | `12-01-SUMMARY.md` uses the canonical key instead of `requirement:` | static frontmatter | `rg -n '^requirements-completed:.*RELEASE-08' .planning/phases/12-public-verification-and-release-operations/12-01-SUMMARY.md` | ✅ |
| RELEASE-09 | Runbook text matches the live release contract and rejects stale automation language | contract test | `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs` | ✅ |

### Sampling Rate
- **Per task commit:** Run the targeted `rg` or `mix test test/install_smoke/release_docs_parity_test.exs` command that matches the file class touched. [VERIFIED: test/install_smoke/release_docs_parity_test.exs]
- **Per wave merge:** Run `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs test/install_smoke/package_metadata_test.exs`. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] [VERIFIED: test/install_smoke/package_metadata_test.exs]
- **Phase gate:** Re-run the strict audit logic against `RELEASE-04` through `RELEASE-09` before `/gsd-verify-work`. [VERIFIED: .planning/v1.2-MILESTONE-AUDIT.md] [CITED: /Users/jon/.codex/get-shit-done/workflows/audit-milestone.md]

### Wave 0 Gaps
- None — existing test infrastructure already has the right extension point in `test/install_smoke/release_docs_parity_test.exs`, and static planning-file checks can be added without new framework setup. [VERIFIED: test/install_smoke/release_docs_parity_test.exs]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | N/A — this phase does not add auth flows. [VERIFIED: .planning/phases/13-release-traceability-and-runbook-alignment/13-CONTEXT.md] |
| V3 Session Management | no | N/A — no session state changes. [VERIFIED: .planning/phases/13-release-traceability-and-runbook-alignment/13-CONTEXT.md] |
| V4 Access Control | yes | Keep release-credential claims aligned with `.github/workflows/release.yml` `environment: release` contract and test for drift. [VERIFIED: .github/workflows/release.yml] [VERIFIED: guides/release_publish.md] |
| V5 Input Validation | yes | Treat frontmatter keys and requirement IDs as strict schema, not free-form aliases. [CITED: /Users/jon/.codex/get-shit-done/templates/summary.md] |
| V6 Cryptography | no | No cryptographic changes in scope. [VERIFIED: .planning/phases/13-release-traceability-and-runbook-alignment/13-CONTEXT.md] |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Runbook says credentials are deferred when live publish is already enabled | Spoofing / Tampering | Parity assertions against exact workflow step names and credential posture. [VERIFIED: guides/release_publish.md] [VERIFIED: .github/workflows/release.yml] |
| Summary metadata aliases hide requirement completion from audit tooling | Tampering | Use only `requirements-completed` and verify with extractor-compatible frontmatter. [CITED: /Users/jon/.codex/get-shit-done/bin/lib/commands.cjs] [CITED: /Users/jon/.codex/get-shit-done/workflows/audit-milestone.md] |
| CI/release contract changes without corresponding doc updates | Repudiation | Keep `release_docs_parity_test.exs` in `scripts/release_preflight.sh` and CI package-consumer flow. [VERIFIED: scripts/release_preflight.sh] [VERIFIED: .github/workflows/ci.yml] |

## Sources

### Primary (HIGH confidence)
- `.planning/phases/13-release-traceability-and-runbook-alignment/13-CONTEXT.md` - locked phase scope and audit debt items
- `.planning/REQUIREMENTS.md` - requirement definitions and current checkbox/traceability state
- `.planning/STATE.md` - project state and recent release decisions
- `.planning/v1.2-MILESTONE-AUDIT.md` - strict three-source audit findings and closure target
- `.planning/milestones/v1.2-phases/10-publish-readiness/10-01-SUMMARY.md` and `10-02-SUMMARY.md` - canonical `requirements-completed` examples
- `.planning/milestones/v1.2-phases/11-protected-publish-automation/11-01-SUMMARY.md`, `11-02-SUMMARY.md`, `11-03-SUMMARY.md` - current schema drift in Phase 11
- `.planning/phases/12-public-verification-and-release-operations/12-01-SUMMARY.md` and `12-02-SUMMARY.md` - current schema drift in Phase 12
- `.planning/milestones/v1.2-phases/11-protected-publish-automation/11-VERIFICATION.md` and `.planning/phases/12-public-verification-and-release-operations/12-VERIFICATION.md` - existing verified evidence
- `guides/release_publish.md`, `.github/workflows/release.yml`, `.github/workflows/ci.yml` - shipped release/runbook contract
- `test/install_smoke/release_docs_parity_test.exs`, `test/install_smoke/package_metadata_test.exs`, `scripts/release_preflight.sh`, `scripts/assert_version_match.sh`, `scripts/public_smoke.sh` - current parity and workflow enforcement

### Secondary (MEDIUM confidence)
- `/Users/jon/.codex/get-shit-done/templates/summary.md` - canonical summary schema
- `/Users/jon/.codex/get-shit-done/bin/lib/commands.cjs` - `summary-extract` requirement-completion field extraction
- `/Users/jon/.codex/get-shit-done/workflows/audit-milestone.md` - strict milestone audit cross-check rules

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - the phase reuses existing repo-native ExUnit/workflow/planning patterns and adds no new dependencies.
- Architecture: HIGH - the audit, summary template, extractor, and current tests all point to one canonical flow.
- Pitfalls: HIGH - each pitfall is evidenced directly by the current milestone audit or existing file drift.

**Research date:** 2026-04-28
**Valid until:** 2026-05-05
