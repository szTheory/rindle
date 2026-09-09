# Phase 133: Evidence Charter and Live Truth - Context

**Gathered:** 2026-09-09 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish the immutable evidence authority for v1.26 and restore truthful exact-head quality,
Nightly, incident, release, support, and adoption signals before later phases mutate dependencies,
repository artifacts, code craft, tests, or CI. This phase creates the census and validators, repairs
the supported Nightly Dialyzer and incident lifecycle, and reconciles live claims. It does not perform
the candidate cleanup or quality ratchets owned by Phases 135 and 136, remote/dependency disposition
owned by Phase 134, or synthetic-twin work owned by Phases 137–139.

</domain>

<decisions>
## Implementation Decisions

### Evidence census authority
- **D-01:** Use one versioned, machine-validated census manifest bound to the current immutable Git SHA,
  resolved toolchain, and detector/configuration inputs. A prose-only extension of the Phase 127 census
  is not authoritative.
- **D-02:** Cover the finite applicable taxonomy: correctness, maintainability, security, performance,
  reliability, compatibility, testing, documentation/accessibility, packaging, CI/CD, release
  engineering, and repository hygiene.
- **D-03:** Normalize and deduplicate candidate identity, then require every unique candidate to have
  exactly one `fix`, `retain`, or trigger-bound `defer` disposition. Missing, duplicate, open, or
  untriggered-defer entries fail validation.
- **D-04:** Freeze this census before Phases 135 and 136 change the baseline; later work must preserve
  candidate identity and trace each mutation back to the frozen ledger.

### Supported Nightly Dialyzer evidence
- **D-05:** Keep the single Elixir 1.17 / OTP 27 Nightly cell as the supported Dialyzer authority; do
  not widen the support matrix or move Dialyzer onto the PR critical path in this phase.
- **D-06:** Require independent automated evidence for both cold/fresh PLT construction and restored-PLT
  analysis. A warm-only pass, a cache-miss-only repair, or a green result obtained by widening
  `.dialyzer_ignore.exs` is insufficient.
- **D-07:** Preserve the existing narrow, identity-specific suppression policy. Stale or incompatible
  PLT evidence must be detected and rejected or rebuilt rather than retried into an unexplained green.
- **D-08:** Capture the current pre-mutation failure fingerprint through authenticated read-only GitHub
  evidence. Public metadata proves Nightly #94–#101 failed on SHA
  `45ebde5e1bb851eb6e8a943ef68c52a714684661` through the restored-cache path, but the exact Dialyzer
  warning and cache contents remain unknown until job logs are collected.

### Nightly verdict and incident lifecycle
- **D-09:** Add a Nightly-specific, fail-closed aggregate policy distinct from PR `CI Summary`. Every
  declared gating job must have explicit applicability; `failure`, `cancelled`, missing/unexpected
  results, and impermissible `skipped` results are non-green.
- **D-10:** An explicitly inapplicable repository- or secret-gated job may be exempted only through a
  machine-checked applicability rule. Configuration absence must not silently become passing evidence.
- **D-11:** The aggregate verdict controls both the Nightly workflow conclusion and incident eligibility;
  the human-readable summary alone is not evidence authority.
- **D-12:** Maintain one rolling `nightly-failure` incident. A qualifying scheduled failure opens it or
  appends exact-run evidence; a later scheduled all-green run on current `main` closes it with exact
  recovery-run evidence.
- **D-13:** `workflow_dispatch` remains diagnostic and cannot open, update, or close the incident. The
  lifecycle job must inspect all dependency results under scheduled-only gating rather than rely on
  `failure()` alone, which does not cover cancellation or skipped-only outcomes.

### Release, support, and adoption truth
- **D-14:** Derive the current version from release authorities (`mix.exs` and
  `.release-please-manifest.json`), lane severity/applicability from parsed workflow topology, and
  package-proof claims from built/unpacked consumer evidence. Literal string-presence tests may remain
  supplementary but are not authoritative.
- **D-15:** Reconcile active/live planning, maintainer, support, adoption, guide, test, and workflow
  surfaces. Preserve `.planning/milestones/**` and explicitly marked historical release receipts as
  immutable evidence rather than rewriting valid history.
- **D-16:** Reject unmarked 0.4.5/0.4.6 contradictions, false merge-blocking or live-lane claims, and
  package-proof claims that can fall back to repository source or prebuilt local artifacts.
- **D-17:** Preserve the existing `ci.yml`, workflow `CI`, sole required `CI Summary`, exact-SHA release
  coupling, fork safety, public contracts, and accepted PR timing envelope while repairing truth.

### the agent's Discretion
- Exact manifest filename, schema serialization, and whether narrow collectors are implemented in
  Elixir, shell, or both, provided the locked evidence and validation semantics above remain executable.
- Internal helper boundaries and test-fixture organization for Nightly aggregation and incident tests.
- The presentation format of human-readable census and Nightly summaries, provided machine verdicts
  remain authoritative and fail closed.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and milestone evidence model
- `.planning/ROADMAP.md` — Phase 133 goal, requirements, boundary, and executable success criteria.
- `.planning/REQUIREMENTS.md` — exact EVID-01 through EVID-04 and TRUTH-08 contracts.
- `.planning/PROJECT.md` — v1.26 boundaries, decision contract, immutable contracts, and starting signals.
- `.planning/METHODOLOGY.md` — repo-truth, research-first, automation-first, and durable-memory lenses.
- `.planning/research/SUMMARY.md` — evidence-plane architecture, implementation ordering, and
  anti-theater constraints.
- `.planning/research/PITFALLS.md` — census, Nightly/PLT, skipped-state, incident, and claims-integrity
  failure modes.
- `.planning/research/ARCHITECTURE.md` — evidence-plane components and integration boundaries.
- `.planning/research/FEATURES.md` — finite quality taxonomy and Phase 133 proof expectations.
- `.planning/research/STACK.md` — approved repository-owned tooling and no-new-platform boundary.

### Prior evidence and truth precedents
- `.planning/milestones/v1.25-phases/127-evidence-charter-quality-census/127-QUALITY-CENSUS.md` — nearest
  finite census and disposition precedent.
- `.planning/milestones/v1.23-phases/120-adoption-proof-release-truth/120-CONTEXT.md` — packed-artifact,
  immutable-SHA release authority and parity topology.
- `.planning/milestones/v1.24-phases/122-live-truth-compile-clarity/122-RESEARCH.md` — live-versus-historical
  truth boundary and prior reconciliation pattern.

### Active workflows and proof contracts
- `.github/workflows/nightly.yml` — current Dialyzer PLT flow, aggregation weakness, applicability gates,
  and incident behavior.
- `.github/workflows/ci.yml` — authoritative lane topology and sole `CI Summary` integration contract.
- `RUNNING.md` — maintained lane severity, supported toolchain, and contributor verification contract.
- `scripts/ci/eval_ci_summary.sh` — reusable aggregate-policy shape whose permissive skip semantics must
  not be copied unchanged into Nightly.
- `scripts/ci/test_ci_summary_gate.sh` — executable aggregate truth-table testing precedent.
- `test/install_smoke/quality_signal_policy_test.exs` — YAML-parsed workflow policy test precedent.
- `test/install_smoke/release_docs_parity_test.exs` — release/version/guide/workflow parity precedent.
- `scripts/maintainer/check_adoption_proof_matrix.sh` — current shallow adoption-proof drift gate.
- `test/install_smoke/generated_app_smoke_test.exs` — unpacked-package provenance and no-checkout-fallback
  proof.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/ci/eval_ci_summary.sh` and `scripts/ci/test_ci_summary_gate.sh` provide a pure policy-plus-truth-
  table pattern; Nightly needs stricter applicability and skipped-state rules.
- `test/install_smoke/quality_signal_policy_test.exs` already parses workflow YAML and asserts job,
  condition, masking, and topology semantics.
- `scripts/maintainer/credo_quality.sh` and its normalized baseline demonstrate stable candidate identity
  and exact-multiset quality enforcement.
- `test/install_smoke/release_docs_parity_test.exs` and
  `test/install_smoke/package_metadata_test.exs` already connect release authorities, guides, workflows,
  package metadata, and public verification.
- `test/install_smoke/generated_app_smoke_test.exs` already proves unpacked-package consumption and
  rejects repository-path fallback.

### Established Patterns
- Evidence-producing policy is repository-owned, deterministic, fail-closed, and exercised by executable
  tests.
- Required CI roots start independently and converge only through the unchanged sole `CI Summary`.
- Nightly Dialyzer is owned and gating but remains outside the PR critical path.
- Accepted quality debt is identity-specific, rationale-bearing, and removal-only rather than a raw-count
  target.
- Archived milestone content is immutable evidence; active planning and maintainer surfaces are live truth.
- Packed Hex-equivalent artifacts, not checkout-local success, are release and adoption proof authority.

### Integration Points
- Census authority feeds Phase 135 craft dispositions and Phase 136 measured ratchets without allowing
  identity substitution.
- The Nightly aggregate verdict feeds both the workflow conclusion and incident open/update/close action.
- Dialyzer PLT evidence crosses `.github/workflows/nightly.yml`, `.dialyzer_ignore.exs`, `RUNNING.md`, and
  later TYPE-03 ratchets.
- Version truth crosses `mix.exs`, `.release-please-manifest.json`, `CHANGELOG.md`, active `.planning/`
  surfaces, release guides, and parity tests.
- Lane severity crosses `.github/workflows/ci.yml`, `.github/workflows/nightly.yml`, `RUNNING.md`, and
  `examples/adoption_demo/docs/adoption-proof-matrix.md`.
- Package-proof truth crosses release preflight, package metadata tests, generated-app smoke, and the
  adoption-proof matrix.

</code_context>

<specifics>
## Specific Ideas

- Use the existing policy-script plus executable truth-table pattern for Nightly aggregation, but give it
  stricter skip/applicability semantics than PR `CI Summary`.
- Treat issue #88 as the live incident specimen: preserve exact-run auditability while adding scheduled
  recovery closure.
- Prefer one evidence plane around existing repository tooling over a new runtime dependency, application,
  or general-purpose quality platform.

</specifics>

<deferred>
## Deferred Ideas

- Candidate cleanup and readability mutations remain in Phase 135.
- Complexity, Dialyzer suppression, coverage, async-isolation, and CI ratchets remain in Phase 136.
- Remote issue/PR and dependency disposition remains in Phase 134; Phase 133 only repairs the Nightly
  incident lifecycle already in scope.
- Synthetic adopter twin, lifecycle recovery matrix, and exact-head readiness manifest remain in Phases
  137–139.
- LIFE-06, STREAM-10, TRANS-01, PRIV-01, tus 2.0/RUFH, GCS-as-tus-backend, and uploader kits remain
  demand-gated future scope.

</deferred>

---

*Phase: 133-evidence-charter-and-live-truth*
*Context gathered: 2026-09-09*
