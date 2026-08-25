# Phase 132: Measured Closure - Context

**Gathered:** 2026-08-25 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Close the measured CI-14 median gap on the existing required pull-request path, prove that the
behavior-preserving quality ratchets remain intact, and replace the failed timing measurement with a
fresh ten-run receipt. The phase does not broaden or weaken required proof, reopen deferred CI
redesigns, or change Admin, public API, schema/migration, telemetry/error, dependency, or release
surfaces.

</domain>

<decisions>
## Implementation Decisions

### Required-gate topology
- **D-01:** Preserve `CI Summary` as the sole required check and retain its current required-job set,
  including the independently starting image packed-consumer and adoption smoke proofs. Do not
  remove, rename, bypass, or weaken a required result or its skip-as-pass fork behavior.

### Evidence-guided required-path correction
- **D-02:** Use same-head native job and long-pole step timings to identify one demonstrated
  critical-path cause, then make the smallest correction inside an existing required PR job or step.
  Do not change topology, add reruns, or activate test partitions, cache redesign, or broad
  toolchain/dependency work without new causal evidence.
- **D-03:** An external-runner exception is valid only when job-level evidence, a named owner, and a
  dated follow-up satisfy CI-14. The observed median miss is not itself an external-runner exception.

### Fresh comparable timing receipt
- **D-04:** After the correction, collect a fresh sequence of ten successful, non-cancelled,
  first-attempt `pull_request` runs from one immutable implementation head. Measure workflow start
  through `CI Summary` completion.
- **D-05:** Closure requires both a median of at most 480 seconds and nearest-rank p95 of at most 600
  seconds. A partial, rerun-inclusive, mixed-head, or p95-only receipt does not satisfy CI-14.

### Preservation re-census
- **D-06:** Reconfirm COV-05 and SAFE-02 against the final correction with authoritative coverage,
  `mix quality_signals`, the established preservation contract, the relevant packed-consumer proof,
  and a bounded diff review for prohibited surface drift.
- **D-07:** Coverage must remain at or above 82.13%; do not add tests solely to raise the percentage.

### the agent's Discretion
- Select the exact long-pole job or step and smallest safe correction after inspecting native timing
  evidence from the immutable failing head.
- Choose the focused verification commands needed for the touched CI boundary in addition to the
  locked phase-level preservation proof.
- Organize the updated receipt and supporting timing evidence without changing its comparability or
  statistical rules.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase contract and current truth
- `.planning/ROADMAP.md` — Phase 132 boundary and its CI-14, COV-05, and SAFE-02 mapping.
- `.planning/REQUIREMENTS.md` — Exact timing, coverage, preservation, and external-runner exception
  requirements.
- `.planning/PROJECT.md` — v1.25 goal, behavior-preserving boundaries, and decide-by-default contract.
- `.planning/STATE.md` — Current measured failure and required next step.
- `.planning/METHODOLOGY.md` — Repo-truth, narrow-then-escalate, durable-memory, and
  diminishing-returns lenses governing the correction.

### Measurement and prior implementation evidence
- `.planning/phases/127-evidence-charter-quality-census/127-QUALITY-CENSUS.md` — Baselines, closure
  rules, retained topology, and explicitly deferred CI redesigns.
- `.planning/phases/131-signal-preserving-ci-velocity/131-IMPLEMENTATION-VERIFICATION.md` — Verified
  Phase 131 changes, preservation receipts, and the open external timing gate.
- `.planning/phases/132-measured-closure/132-CI-TIMING-RECEIPT.md` — Immutable-head ten-run method,
  observed 515.5-second median, passing 544-second p95, and failure disposition.

### Shipped CI contracts
- `.github/workflows/ci.yml` — Required job graph, `CI Summary`, and native timing observability.
- `scripts/ci/collect_ci_baseline.sh` — Read-only workflow-run collection and rerun classification.
- `scripts/ci/eval_ci_summary.sh` — Required-result evaluation used by `CI Summary`.
- `scripts/ci/test_ci_summary_gate.sh` — Executable gate-logic regression proof.
- `test/install_smoke/ci_lane_split_test.exs` — Required topology, package-consumer, adoption smoke,
  and release-coupling locks.
- `test/install_smoke/ci_observability_test.exs` — Job/step timing and coverage-observability locks.
- `scripts/maintainer/refactor_contract.sh` — SAFE-01 preservation authority used by SAFE-02.
- `scripts/install_smoke.sh` — Packed image-consumer proof entry point.

No external specs — the requirements and constraints are fully defined by the repository references
above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ci-observability` in `.github/workflows/ci.yml` already reports native per-job and per-step
  durations, so bottleneck selection can be evidence-driven without adding a new measurement system.
- `scripts/ci/collect_ci_baseline.sh` already provides read-only run collection and `run_attempt`
  classification suitable for receipt integrity checks.
- The CI lane-split, observability, and summary-gate tests provide focused regression coverage for
  topology-preserving workflow edits.

### Established Patterns
- `CI Summary` is the single branch-protection contract; required work fans out and rejoins there.
- The image-only packed consumer starts independently while the broader video/tus/Mux/GCS matrix
  remains on main and release paths.
- Speed claims are accepted only through comparable live GitHub Actions receipts; local timing cannot
  establish CI-14.
- Preservation is layered: focused proof, `mix quality_signals`, SAFE-01, and the relevant integration
  or packed-consumer lane.

### Integration Points
- Any correction will connect to an existing required job or step in `.github/workflows/ci.yml` and
  must continue to flow into `ci-summary` unchanged.
- Workflow changes are locked by `test/install_smoke/ci_lane_split_test.exs`,
  `test/install_smoke/ci_observability_test.exs`, and `scripts/ci/test_ci_summary_gate.sh`.
- Final closure updates the Phase 132 timing receipt only after the corrected immutable head produces
  ten qualifying live runs.

</code_context>

<specifics>
## Specific Ideas

No additional user-specific requirements; use the repository's native timing evidence and established
proof contracts.

</specifics>

<deferred>
## Deferred Ideas

- `mix test --partitions` parallelization remains evidence-gated on demonstrated core starvation.
- Cache redesign and broad dependency/toolchain upgrades remain separate risk-ranked work.
- Required-check topology changes, proof removal, and rerun-based timing improvements are not closure
  strategies for this phase.

</deferred>

---

*Phase: 132-measured-closure*
*Context gathered: 2026-08-25*
