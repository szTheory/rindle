---
phase: 107-reliability-security-dx-hardening
plan: 02
subsystem: ci-cd-supply-chain
status: complete
tags: [security, supply-chain, ci, dependabot, sha-pin, mix_audit, permissions]
requires:
  - "107-01 settled CI lane shape (CI Summary sole required check)"
provides:
  - "SHA-pinned third-party actions (immutable refs) across all workflows + composite actions"
  - ".github/dependabot.yml (github-actions + mix, grouped/weekly)"
  - "mix_audit advisory dependency scan in the quality lane"
  - "verified least-privilege permissions posture"
affects:
  - ".github/workflows/*.yml"
  - ".github/actions/setup-elixir/action.yml"
  - "mix.exs deps/0 + quality lane"
tech-stack:
  added:
    - "mix_audit ~> 2.1 (dev/test, runtime: false)"
  patterns:
    - "Full-length 40-hex SHA pins with trailing # vX.Y.Z comment (StepSecurity/OpenSSF)"
    - "dependabot grouped weekly updates with non-release commit prefix"
    - "advisory (continue-on-error) static/security steps in the quality lane"
key-files:
  created:
    - ".github/dependabot.yml"
  modified:
    - ".github/workflows/ci.yml"
    - ".github/workflows/nightly.yml"
    - ".github/workflows/release.yml"
    - ".github/workflows/branch-protection-apply.yml"
    - ".github/actions/setup-elixir/action.yml"
    - "mix.exs"
    - "mix.lock"
decisions:
  - "Omitted optional npm dependabot ecosystem — kept HARD-02 scoped; HARD-04 owns the Playwright pin"
  - "mix deps.audit wired advisory (continue-on-error: true) per house default + Open-Q2, gated by matrix.lint"
  - "D-06 was pure verification — ci-observability already declared actions: read; no blocks added (Pitfall 6 avoided)"
metrics:
  duration: "~12m"
  completed: 2026-06-22
  tasks: 2
  files: 8
---

# Phase 107 Plan 02: CI/CD Supply-Chain Hardening Summary

SHA-pinned every third-party GitHub Action to an immutable 40-hex commit (11 distinct actions, 52 `uses:` occurrences across 5 files), landed a grouped/weekly `dependabot.yml` for the github-actions + mix ecosystems with non-release commit prefixes, and added the `mix_audit` advisory dependency scan to the `quality` lane — a pure-config supply-chain hardening pass with ZERO `lib/` change and no new required check.

## What Was Built

### Task 1 — SHA pins + permissions audit (D-03, D-06) — commit `c38f4ed`
- Pinned all 11 mutable third-party action tags to full-length 40-hex SHAs, each carrying a canonical one-space `# vX.Y.Z` trailing comment, across `ci.yml`, `nightly.yml`, `release.yml`, `branch-protection-apply.yml`, and `.github/actions/setup-elixir/action.yml`.
- Pinned the CURRENT major's latest SHA only — no major bumps (Pitfall 3); dependabot will surface major bumps as separate reviewable PRs.
- `actions/cache/restore` and `actions/cache/save` correctly pinned to the SAME SHA as `actions/cache` (subpaths of one repo).
- Left all `uses: ./...` LOCAL composite refs unchanged (not pinnable).
- D-06 permissions: VERIFICATION only — confirmed every workflow declares a workflow-level `permissions: { contents: read }` default and that `ci-observability` already declares `actions: read` (for `gh api --paginate`). No job-scoped blocks were added; no `contents: read` cargo-culting (Pitfall 6).

### Task 2 — dependabot + mix_audit (D-04, D-05) — commit `8113066`
- New `.github/dependabot.yml`: two ecosystems (`github-actions`, `mix`), `directory: "/"`, weekly (monday), `open-pull-requests-limit: 5`, grouped (minor+patch), labeled. Non-release commit prefixes — `ci` (actions) / `build` (mix) — so dependabot PRs never trigger a spurious release-please minor (Pitfall 2). Optional `npm` ecosystem omitted (out of HARD-02 scope; HARD-04 owns the Playwright pin).
- `mix.exs` `deps/0`: added `{:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}` alongside the existing tool-dep pattern.
- `ci.yml` `quality` lane: added an `Audit dependencies (advisory)` step running `mix deps.audit` with `continue-on-error: true`, gated by `matrix.lint` (runs once on the lint cell). It is NOT a separate required check; `CI Summary` stays the sole gate. A step comment documents how to flip it to gating later.
- `mix.lock` updated by `mix deps.get` (mix_audit + its `yaml_elixir`/`yamerl` transitive deps).

## Settled CI check / job names (for Wave 2 — 107-03 / 107-04)

No job or check names changed in this plan. The settled shape Wave 2 should reference:
- Workflow file: `.github/workflows/ci.yml`, workflow `name: CI` (UNCHANGED — release-train coupling preserved).
- Sole required check: **`CI Summary`** (the `ci-summary` job). `skipped` == pass. Unchanged.
- `quality` job (`name: Quality`) now contains an advisory `Audit dependencies (advisory)` step (`mix deps.audit`, `continue-on-error: true`, `if: matrix.lint`) — advisory, NOT in any `needs:` / not a gate.
- `ci-observability` job retains its job-scoped `permissions: { actions: read }`.
- Merge-blocking PR lane set is unchanged from 107-01 (quality, optional-dependencies, integration, contract, proof, package-consumer, adoption-demo-unit, cohort-demo-smoke, adopter, brandbook-tokens → gated transitively via `ci-summary`).

## Actions pinned (action → SHA → version)

| Action | SHA | Version |
|--------|-----|---------|
| actions/checkout | `34e114876b0b11c390a56381ad16ebd13914f8d5` | v4.3.1 |
| actions/setup-node | `49933ea5288caeca8642d1e84afbd3f7d6820020` | v4.4.0 |
| actions/cache (+ /restore, /save) | `0057852bfaa89a56745cba8c7296529d2fc39830` | v4.3.0 |
| actions/upload-artifact | `ea165f8d65b6e75b540449e92b4886f43607fa02` | v4.6.2 |
| actions/github-script | `f28e40c7f34bde8b3046d885e986cb6290c5673b` | v7.1.0 |
| erlef/setup-beam | `fc68ffb90438ef2936bbb3251622353b3dcb2f93` | v1.24.0 |
| google-github-actions/auth | `c200f3691d83b41bf9bbd8638997a462592937ed` | v2.1.13 |
| google-github-actions/setup-gcloud | `e427ad8a34f8676edf47cf7d7925499adf3eb74f` | v2.2.1 |
| googleapis/release-please-action | `5c625bfb5d1ff62eadeeb3772007f7f66fdcf071` | v4.4.1 |

## Verify-gate outcomes

- `! grep -rEn 'uses: [^@./][^@]*@v[0-9]' .github/workflows .github/actions` → **PASS** (no mutable third-party tag survives).
- YAML parse (PyYAML) for all 7 edited/new YAML files → **PASS**.
- `actionlint` → no errors from the pins; only PRE-EXISTING baseline warnings (SC2209 shellcheck on `MIX_ENV=test mix ...` run lines; `matrix.elixir` expression notes) — out of scope, untouched.
- `mix deps.get --check-locked` → **PASS** (exit 0, lockfile consistent).
- `mix deps.audit` → runs and reports advisories (decimal moderate DoS, cowlib low) — this is the intended ADVISORY surfacing; the step is `continue-on-error: true` so it does not gate.
- dependabot.yml: 2 `package-ecosystem` entries, no `feat`/`fix` prefix → **PASS**.
- `name: CI` count = 5, `ci.yml` filename intact → **PASS**.
- `git diff c38f4ed^..HEAD --name-only | grep '^lib/'` → empty → **PASS** (zero lib change).

## Deviations from Plan

**None functionally.** Two plan-listed files carried no third-party `uses:` and were correctly left untouched (RESEARCH anticipated this — noting as verification, not a deviation):
- `.github/actions/setup-minio/action.yml` — contains no `uses:` lines; nothing to pin.
- `.github/workflows/release-please-automerge.yml` — contains no `uses:` lines (no third-party action); nothing to pin.

D-06 turned out to be entirely verification (no construction): `ci-observability` already had `actions: read` from 106 work, so no permissions edits were required.

## Known Stubs

None.

## Threat Flags

None — no new network endpoint, auth path, file-access pattern, or trust-boundary schema change. All four register mitigations (T-107-02 SHA pins, T-107-03 least-privilege permissions, T-107-04 dependabot, T-107-05 mix_audit) are implemented as planned.

## Self-Check: PASSED

- FOUND: `.github/dependabot.yml`
- FOUND: `.planning/phases/107-reliability-security-dx-hardening/107-02-SUMMARY.md`
- FOUND commit `c38f4ed` (SHA pins)
- FOUND commit `8113066` (dependabot + mix_audit)
