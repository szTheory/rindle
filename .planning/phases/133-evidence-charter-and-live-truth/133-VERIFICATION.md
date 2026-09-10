---
phase: 133-evidence-charter-and-live-truth
verified: 2026-09-10T19:09:17Z
status: gaps_found
score: 30/38 must-haves verified
behavior_unverified: 0
overrides_applied: 0
decision_coverage:
  honored: 17
  total: 17
  not_honored: []
re_verification:
  previous_status: gaps_found
  previous_score: 26/29
  gaps_closed:
    - "Caller-controlled validated=true package-receipt shortcut removed and regression-tested."
    - "Persisted remote receipt fields now receive exact-key canonical live reconstruction and field mutation coverage."
    - "Elixir 11.17/1.170 and OTP 127 near-matches now fail anchored collection and receipt validation."
  gaps_remaining: []
  regressions:
    - "Six additional blocker defects from 133-REVIEW.md remain present after Plans 08-10."
gaps:
  - truth: "Nightly Dialyzer cleanup is confined to an approved PLT directory."
    status: failed
    reason: "PLT_DIR is caller-controlled and values such as .., ../.., /tmp, or the repository root reach rm -rf; only empty, /, and . are rejected."
    artifacts:
      - path: "scripts/ci/run_nightly_dialyzer.sh"
        issue: "reset_plt recursively deletes PLT_DIR without normalized containment or symlink protection."
      - path: "scripts/ci/test_nightly_dialyzer.sh"
        issue: "The 24-case suite always supplies a safe temporary child path and has no escape-path cases."
    missing:
      - "Remove the production override or enforce physical containment in a dedicated approved root before deletion."
      - "Add non-destructive rejection cases for parent traversal, repository root, external absolute paths, and symlink escape."
  - truth: "The exact-run collector tolerates GitHub list eventual consistency while selecting exactly one post-boundary matching run."
    status: failed
    reason: "During polling, any nonempty run list with zero exact matches aborts immediately as foreign identity, so ordinary older dispatches prevent waiting for the new run."
    artifacts:
      - path: "scripts/ci/verify_nightly_run.sh"
        issue: "Lines 380-382 fail on unrelated historical runs instead of continuing the bounded poll."
      - path: "scripts/ci/test_verify_nightly_run.sh"
        issue: "The timeout fixture returns an empty list and never exercises old runs visible before the new run appears."
    missing:
      - "Ignore nonmatching historical runs until the deadline; accept one qualifying post-boundary match and fail on multiple qualifying matches."
      - "Add an old-runs-first/new-run-later fixture."
  - truth: "Package and adoption claims derive from authenticated built-package/generated-consumer evidence rather than arbitrary directories and self-asserted booleans."
    status: failed
    reason: "A forged generated-app-helper map with arbitrary existing directories, two fake files, zero exit codes, lifecycle_proved=true, and an arbitrary adopter name is accepted, including authorizes_1_0=true."
    artifacts:
      - path: "scripts/maintainer/validate_live_truth.exs"
        issue: "normalize_package_receipt!/1 checks path existence and caller booleans but no subject/package digest, dependency lock/source, command/result receipt, or authenticated adopter provenance."
      - path: "test/install_smoke/live_truth_parity_test.exs"
        issue: "package_receipt_fixture!/0 constructs the same forgeable arbitrary-directory shape, so green negative tests do not prove provenance."
    missing:
      - "Bind canonical producer evidence to immutable subject/package content and generated-app dependency provenance."
      - "Define a distinct authenticated independent-adopter evidence type; do not accept a caller-provided name as authority."
  - truth: "The final Nightly receipt binds census and live-truth authority immutably to its exact subject SHA."
    status: failed
    reason: "Revalidation runs subject-pinned scripts against the mutable current-worktree census ledger; the receipt stores only pass statuses and no ledger digest/blob/commit identity. The current receipt also fails canonical verification because live incident state has changed."
    artifacts:
      - path: "scripts/ci/verify_nightly_run.sh"
        issue: "revalidate_local_authorities reads 133-EVIDENCE-CENSUS.json from project_root rather than an immutable recorded object."
      - path: ".planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-EVIDENCE.json"
        issue: "local_authorities contains only census/live_truth pass strings; the ledger did not exist at receipt subject 4f83e15 and no digest is recorded."
    missing:
      - "Record the ledger SHA-256 and immutable Git blob/commit identity in the receipt, materialize that exact object, and compare a detailed regenerated census receipt."
      - "Collect a new exact-subject Nightly receipt after all authority fixes; the present receipt is stale and cannot pass verify-receipt."
  - truth: "Every applicable census dimension retains its repository-owned detector authority even when another dimension is explicitly inapplicable."
    status: failed
    reason: "The hard-coded detector registry comparison runs only when every taxonomy dimension is applicable; one inapplicable dimension globally disables authority checking for all remaining detectors."
    artifacts:
      - path: "scripts/maintainer/validate_evidence_census.exs"
        issue: "Enum.all?(taxonomy, & &1[\"applicable\"]) guards the entire repository-owned registry comparison."
      - path: "test/install_smoke/evidence_census_test.exs"
        issue: "The minimal inapplicability fixture depends on the bypass and lacks a mixed-applicability mutation of another detector."
    missing:
      - "Validate each applicable dimension against its matching repository-owned detector record."
      - "Allow inapplicability only through an explicit repository-owned dimension allowlist and add a mixed-applicability mutation test."
  - truth: "Exact-SHA release coupling and the sole required check are derived from executable workflow/policy structure."
    status: failed
    reason: "The live-truth model accepts four inert comment substrings as exact-SHA release coupling and uses an unanchored source regex for required-check authority."
    artifacts:
      - path: "scripts/maintainer/validate_live_truth.exs"
        issue: "exact_sha_release_coupling?/1 uses raw text substrings; sole_required_check?/1 can match dead/commented text."
      - path: "test/install_smoke/live_truth_parity_test.exs"
        issue: "No comment-only/unreachable release gate or duplicate/dead required-check fixture exists."
    missing:
      - "Parse executable release workflow structure and test the exact-SHA gate evaluator with matching and mismatched SHA fixtures."
      - "Validate required-check output/argv from a structured producer or at minimum reject comment-only and duplicate matches."
---

# Phase 133: Evidence Charter and Live Truth Verification Report

**Phase Goal:** Maintainers can trust exact-head quality, Nightly, incident, release, support, and adoption evidence before any cleanup changes the baseline.
**Verified:** 2026-09-10T19:09:17Z
**Status:** gaps_found
**Re-verification:** Yes — after Plans 08-10 closed the three original gaps

## Goal Achievement

Plans 08-10 close the original forged `validated` shortcut, persisted-field comparison gap, and supported-version substring gap. The phase goal is nevertheless not achieved. Six blocker findings from `133-REVIEW.md` are confirmed in the current implementation, two through direct adversarial execution and four through unambiguous control/data-flow inspection. The sole persisted Nightly receipt also currently fails its canonical verifier because live incident state has advanced.

### Roadmap Success Criteria

| # | Roadmap truth | Status | Evidence |
|---|---|---|---|
| 1 | Exact-SHA census covers every applicable dimension, deduplicates candidates, and gives each one disposition | ✗ FAILED | Candidate/disposition tests pass, but making one dimension inapplicable disables repository-owned detector validation globally. Observation locations also accept `../` traversal. |
| 2 | Supported Nightly Dialyzer passes fresh/restored and rejects or rebuilds stale PLTs | ✗ FAILED | The runner behavior matrix passes, but its reset path can recursively delete an arbitrary caller-selected directory, the collector aborts during normal eventual consistency, and no currently valid exact-run receipt exists. |
| 3 | Strict Nightly aggregation and exact-run incident lifecycle fail closed | ✓ VERIFIED | 49-case verdict and 22-case incident suites pass; parsed workflow wiring uses the strict verdict and scheduled-only issue mutation. |
| 4 | Executable parity derives release/planning/support/adoption truth and rejects contradictions | ✗ FAILED | Arbitrary directories and caller booleans can forge package/independent-adopter authority; inert comments can forge release coupling. |

**Roadmap score:** 1/4 success criteria verified.

### Observable PLAN Truths

| Plan | Verified | Failed | Failure summary |
|---|---:|---:|---|
| 133-01 | 3/4 | 1 | Applicable detector authority can be disabled by one inapplicable taxonomy row. |
| 133-02 | 4/4 | 0 | Intended supported-cell/mode/cache/fingerprint behaviors exist, but CR-01 remains a blocker anti-pattern. |
| 133-03 | 3/3 | 0 | Strict result/applicability/execution verdict behavior is exercised. |
| 133-04 | 3/3 | 0 | Scheduled/current-main incident policy and least-privileged wiring are exercised. |
| 133-05 | 3/5 | 2 | Package/adoption evidence and release-coupling authority are forgeable. |
| 133-06 | 4/5 | 1 | Active claims inherit the forgeable package/release model. |
| 133-07 | 3/5 | 2 | Polling rejects ordinary older runs; the final local-authority binding is mutable/stale. |
| 133-08 | 1/2 | 1 | The discriminator shortcut is gone, but the remaining receipt facts are still self-asserted. |
| 133-09 | 3/4 | 1 | Remote fields are reconstructed, but census authority uses a mutable ledger outside the exact subject. |
| 133-10 | 3/3 | 0 | Anchored numeric component parsing and exact patch/cache binding are exercised. |

**Score:** 30/38 PLAN truths verified (0 present-but-behavior-unverified).

## Original Gap Re-verification

| Previous gap | Status | Current evidence |
|---|---|---|
| Caller `validated: true` bypass | ✓ CLOSED | `validate_package_claim!/2` always calls `normalize_package_receipt!/1`; the focused package-authority test rejects the old shortcut. |
| Persisted remote receipt fields accepted by shape/status only | ✓ CLOSED | Exact-key canonical reconstruction plus individual field mutations now run in the 84-case suite. The separate mutable-ledger defect remains a new gap. |
| 11.17/1.170/127 supported-toolchain near-matches | ✓ CLOSED | Shared anchored parsers reject all six collection/receipt near-match cases while retaining exact patch strings. |

## Required Artifacts and Wiring

| Plan | Artifact status | Wiring status | Details |
|---|---|---|---|
| 133-01 | ⚠ PARTIAL | ✓ WIRED | Collector/validator/tests are substantive; detector and observation trust boundaries are incomplete. |
| 133-02 | ⚠ PARTIAL | ✓ WIRED | Runner, workflow, setup outputs, fingerprint, and tests exist; unsafe recursive deletion remains. |
| 133-03 | ✓ VERIFIED | ✓ WIRED | Evaluator consumes exact `needs`/policy JSON and controls exported/enforced verdict. |
| 133-04 | ✓ VERIFIED | ✓ WIRED | Workflow calls `manage_nightly_incident.sh`, which calls the evaluator. Automated pattern misses are naming/transitive-link false negatives. |
| 133-05 | ✗ PARTIAL | ✓ WIRED | Live-truth validator is active but package/adoption and release authorities are forgeable. |
| 133-06 | ✗ PARTIAL | ✓ WIRED | Adoption gate and active docs are wired; they inherit the invalid authority model. Ledger exists but is not immutable in receipt revalidation. |
| 133-07 | ✗ PARTIAL | ⚠ PARTIAL | Collector and receipt exist; polling is defective and current receipt verification fails stale-incident comparison. |
| 133-08 | ⚠ PARTIAL | ✓ WIRED | All inputs normalize, but normalization still trusts arbitrary paths/self-reported results. |
| 133-09 | ✗ PARTIAL | ⚠ PARTIAL | Remote reconstruction is exact; local census revalidation consumes a mutable current-worktree ledger. |
| 133-10 | ✓ VERIFIED | ✓ WIRED | One anchored predicate protects collection and receipt boundaries. |

All 33 declared artifact entries exist. The automated artifact checker reports two literal-pattern misses (`expect_exit`) and one direct-link miss for Plan 04; manual inspection shows substantive alternate helper naming and the intentional workflow → adapter → evaluator path. These are not gaps.

## Evidence/Data-Flow Trace

| Evidence | Source → consumer | Status | Finding |
|---|---|---|---|
| Census observations/dispositions | Repository detectors → collector → ledger/receipt validator | ✗ HOLLOW AUTHORITY | Mixed applicability can bypass the registry; `../` observation locations remain accepted. |
| Dialyzer PLT evidence | setup-beam outputs/cache → fresh/restored runner → Nightly logs | ⚠ PARTIAL | Version/cache behavior is real, but caller-controlled cleanup is unsafe. |
| Strict Nightly verdict | GitHub `needs` + typed outputs → jq evaluator → summary conclusion/incident input | ✓ FLOWING | Exact-set failure semantics are exercised. |
| Incident lifecycle | Scheduled context/current-main/inventory → evaluator → thin `gh` adapter | ✓ FLOWING | Fake CLI proves cardinality, idempotency, no-op dispatch, and comment-before-close semantics. |
| Package/adoption proof | Caller receipt → normalization → claim validator | ✗ FORGEABLE | Existing arbitrary directories and self-reported success facts are accepted as independent evidence. |
| Release coupling | Raw release.yml text → substring checks → derived model | ✗ STATIC | Comments/unreachable text can satisfy authority. |
| Local authority in Nightly receipt | Exact-subject scripts + current-worktree ledger → `{status: pass}` | ✗ MUTABLE | Ledger bytes/identity are absent from the receipt and absent at the tested subject. |

## Behavioral Spot-Checks

| Behavior | Command/result | Status |
|---|---|---|
| Strict Nightly verdict matrix | `bash scripts/ci/test_nightly_summary_gate.sh` — 49 passed | ✓ PASS |
| Dialyzer behavior/workflow matrix | `bash scripts/ci/test_nightly_dialyzer.sh` — 24 passed | ✓ PASS, insufficient for path containment |
| Incident lifecycle matrix | `bash scripts/ci/test_nightly_incident.sh` — 22 passed | ✓ PASS |
| Exact-run/receipt mutation matrix | `bash scripts/ci/test_verify_nightly_run.sh` — 84 passed | ✓ PASS, insufficient for delayed listing and mutable ledger identity |
| Focused ExUnit policy set | 48 tests, 0 failures, 1 excluded on installed Elixir 1.19.5/OTP 28 | ✓ PASS, package-authority MinIO case excluded |
| Forged independent adopter | Arbitrary dirs/fake files/self-reported success with `authorizes_1_0: true` returned `:ok` | ✗ FAIL |
| Inert release workflow | Comment-only release file produced `exact_sha_release_coupling=true` | ✗ FAIL |
| Current exact receipt | Preflight passed; `verify-receipt` exited nonzero: incident evidence stale | ✗ FAIL |
| ShellCheck warning gate | Phase runner/verifier/test scripts exited 0 | ✓ PASS |

No probe scripts are declared beyond these repository-owned shell evidence suites.

## Requirements Coverage

| Requirement | Source plans | Status | Evidence |
|---|---|---|---|
| EVID-01 | 01, 06, 07, 09 | ✗ BLOCKED | SHA/candidate/disposition contracts pass, but mixed applicability bypasses detector authority and the final receipt consumes an unbound mutable ledger. |
| EVID-02 | 02, 06, 07, 10 | ✗ BLOCKED | Fresh/restored/stale behavior and anchored toolchains pass, but unsafe PLT deletion, defective delayed run selection, and absence of a currently valid receipt prevent trusted supported evidence. |
| EVID-03 | 03, 06, 07, 09 | ✓ SATISFIED | The exact declared set, strict applicability/execution semantics, terminal enforcement, and mutation tests pass. |
| EVID-04 | 04, 06, 07, 09 | ✓ SATISFIED | Pure policy/fake GitHub tests prove one rolling issue, exact-run evidence, qualifying recovery, duplicate failure, and diagnostic no-op. |
| TRUTH-08 | 05, 06, 07, 08, 09 | ✗ BLOCKED | Package/adoption and release-coupling claims do not derive from independently authenticated/executable authority. |

Every requirement ID declared in Plans 01-10 appears in `.planning/REQUIREMENTS.md`, maps to Phase 133, and is accounted for above. There are no orphaned Phase 133 requirement IDs.

## Prohibition Review

No human judgment is credited. Each descriptor-less prohibition is resolved from executable/static evidence.

| Plan | Prohibition result | Evidence |
|---|---|---|
| 01 | 2 verified | No cleanup authorization is emitted; retain/defer require evidence or trigger. |
| 02 | 2 verified, plus blocker safety defect | Retry remains exact old-PLT-only and support/ignore scope is unchanged; arbitrary PLT deletion is outside the wording but independently blocking. |
| 03 | 2 verified | Not-run remains explicit and PR permissive skip semantics are not reused. |
| 04 | 2 verified | Dispatch/stale/non-default state cannot mutate; cardinality and atomic recovery evidence are tested. |
| 05 | 1 verified, 1 failed | History is preserved; package/adoption authority can be overstated through forged receipts. |
| 06 | 1 verified, 1 failed | History is preserved; arbitrary caller evidence can be relabeled as an independent adopter. |
| 07 | 2 verified historically | Near-match/rerun/partial cases reject and diagnostic collection emitted no incident mutation; current receipt is stale for later incident changes. |
| 08 | 1 verified | The caller discriminator shortcut is removed. |
| 09 | 1 failed, 1 verified | Remote receipt fields are independently reconstructed, but local `{status:pass}` semantics depend on a mutable caller-worktree ledger; revalidation remains read-only. |
| 10 | 1 verified | No substring/unanchored support matcher remains. |

Three of 18 prohibitions are violated. Because automation-first acceptance forbids human closure, these failures remain structured implementation gaps.

## Test Quality Audit

| Test surface | Active evidence | Skipped | Assertion strength | Verdict |
|---|---:|---:|---|---|
| `evidence_census_test.exs` | 11 focused cases | 0 | Behavioral/value | ⚠ Insufficient: complete-registry mutation only; mixed applicability and `../` observations omitted. |
| `test_nightly_dialyzer.sh` | 24 | 0 | Behavioral order/count | ⚠ Insufficient: no PLT_DIR containment cases. |
| `test_nightly_summary_gate.sh` | 49 | 0 | Exhaustive behavioral truth table | ✓ Strong |
| `test_nightly_incident.sh` | 22 | 0 | Behavioral mutation/order | ✓ Strong |
| `test_verify_nightly_run.sh` | 84 | 0 | Canonical field mutation/fake CLI | ⚠ Insufficient: timeout uses empty lists; ledger identity is not part of schema. |
| `live_truth_parity_test.exs` | active focused cases | 0 | Behavioral/value | 🛑 Misleading fixture: arbitrary directories and self-reported booleans are the expected package oracle; inert release text is untested. |

Disabled requirement tests: 0. Circular/self-derived authority patterns: 1 (`package_receipt_fixture!/0`). Insufficient assertion surfaces: 5. The self-derived package oracle and missing authority-boundary tests are blocker-level because the phase goal is evidence trust.

## Anti-Patterns and Review Findings

| Finding | Status | Severity | Evidence |
|---|---|---|---|
| CR-01 arbitrary recursive PLT deletion | CONFIRMED | 🛑 BLOCKER | `PLT_DIR` reaches `rm -rf` after only empty/`/`/`.` checks. |
| CR-02 older runs abort polling | CONFIRMED | 🛑 BLOCKER | Nonempty `runs` + zero `matches` dies on first poll. |
| CR-03 forgeable package/adoption authority | CONFIRMED BY EXECUTION | 🛑 BLOCKER | Forged `independent-adopter`, arbitrary name, `authorizes_1_0: true` returned `:ok`. |
| CR-04 mutable ledger revalidation | CONFIRMED | 🛑 BLOCKER | Receipt has no ledger digest; ledger is read from current root and did not exist at subject SHA. |
| CR-05 mixed-applicability registry bypass | CONFIRMED | 🛑 BLOCKER | Entire registry comparison is guarded by all dimensions applicable. |
| CR-06 inert release-coupling text | CONFIRMED BY EXECUTION | 🛑 BLOCKER | Comment-only release file derived coupling `true`. |
| WR-01 parent-traversal observations | CONFIRMED | ⚠ WARNING | Only absolute locations are rejected; validator accepts any `Path.type == :relative`, including `../../outside`. |
| Debt markers in phase files | NONE | — | No unreferenced TBD/FIXME/XXX markers. Existing placeholder strings are bounded test/demo/release dry-run values. |

## Decision Coverage

All 17 trackable `133-CONTEXT.md` decisions are honored by shipped artifacts. This non-blocking heuristic does not supersede the confirmed authority defects.

## Deferred Item Filter

No gap is deferred. Phases 134-139 consume or build on the Phase 133 baseline; none explicitly owns repairing the PLT deletion boundary, live-run polling, package/adopter provenance, ledger immutability, detector registry, or release-coupling authority. Phase 139's readiness manifest is not a substitute for correcting this phase's evidence producers.

## Human Verification

N/A — infrastructure/evidence phase with no user-facing surface. Repository policy requires executable tests/evidence collectors; human observation cannot satisfy any Phase 133 requirement or prohibition.

## Gaps Summary

The three original gaps are closed, but six blocker defects remain and the only persisted Nightly receipt is currently stale. The phase cannot serve as the trusted pre-cleanup baseline: destructive input is insufficiently contained, normal dispatch selection can fail, package/adopter and release authority can be forged, census authority can be weakened through applicability, and local receipt authority depends on mutable bytes outside the tested subject.

---

_Verified: 2026-09-10T19:09:17Z_
_Verifier: the agent (gsd-verifier)_
