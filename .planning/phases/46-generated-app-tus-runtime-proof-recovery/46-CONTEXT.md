# Phase 46: generated-app-tus-runtime-proof-recovery - Context

**Gathered:** 2026-05-24 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Close the last blocking tus milestone gap by restoring confidence in the
generated-app package-consumer proof for `TUS-14`. The phase is about the real
runtime proof lane: re-run the built-artifact `tus` install smoke against MinIO,
fix any remaining runtime or harness defect that still causes the live proof to
fail, and leave durable evidence showing the lane is reproducible and green.

This phase does **not** redesign the tus protocol edge, auth model, telemetry
family, or guide contract already locked in Phases 42 and 44. If the proof is
already green, the work is evidence reconciliation and durable re-verification,
not architecture churn.
</domain>

<decisions>
## Implementation Decisions

### Recovery scope
- **D-01:** Treat Phase 46 as a narrow proof-recovery phase, not a tus-contract
  redesign. The only valid fixes are in generated-app wiring, install-smoke
  harness behavior, runtime/environment setup, or reproducibility breadcrumbs.
- **D-02:** Re-run the real package-consumer command first:
  `bash scripts/install_smoke.sh tus`. Planning should assume "verify current
  truth before patching" because the current tree already contains a passing tus
  smoke artifact.

### Proof authority
- **D-03:** The authoritative success path remains the real generated-app
  package-consumer lane: packaged Rindle artifact, generated Phoenix app, real
  Node `tus-js-client`, real MinIO backing, one interrupted upload, then resume.
  Do **not** replace this with fake-only or repo-local-only coverage.
- **D-04:** The proof must continue asserting the user-visible contract that
  matters for `TUS-14`: upload creation succeeds, resume discovers at least one
  previous upload, the resulting asset reaches the expected `byte_size` and
  `content_type`, and downstream variants converge.

### Stale-vs-current evidence reconciliation
- **D-05:** Assume the earlier `ECONNRESET` / `socket hang up` failure recorded
  in Phase 44 verification is now potentially stale. The current planning
  baseline is: re-run the proof, compare the live result against the persisted
  artifact in `tmp/install_smoke_tus_last_run.json`, and then update verification
  artifacts to reflect the actual state.
- **D-06:** If the rerun is green, Phase 46 should capture that durable evidence
  explicitly in its own plan/summary/verification artifacts and point back to
  the generated-app smoke breadcrumbs, rather than reopening settled Phase 44
  implementation decisions.

### Failure-handling posture
- **D-07:** If the rerun is red, keep the diagnosis anchored to the saved proof
  breadcrumbs: generated workspace root, `install_smoke_tus_report.json`,
  `install_smoke_tus_debug_report.json`, and the failure phase fields already
  emitted by the Node proof harness.
- **D-08:** Any fix must preserve the locked no-silent-downgrade tus contract and
  the existing real-socket drop-and-resume semantics. Reliability is improved by
  making the live proof reproducible, not by weakening the contract.

### the agent's Discretion
- Exact wording and placement of the refreshed verification evidence.
- Whether Phase 46 closes entirely through rerun + artifact reconciliation, or
  needs a small harness/runtime patch first, depending on the live proof result.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase contract
- `.planning/ROADMAP.md` — Phase 46 goal and success criteria.
- `.planning/REQUIREMENTS.md` — `TUS-14` requirement contract and traceability.
- `.planning/PROJECT.md` — decision-making contract: do not escalate routine
  local choices, prefer one coherent recommendation set.
- `.planning/STATE.md` — current operational truth, including the earlier note
  that the milestone blocker was the generated-app tus proof.

### Prior locked tus decisions
- `.planning/phases/42-tus-protocol-edge-bare-plug/42-CONTEXT.md` — locked tus
  protocol, capability, schema, and completion-lane decisions.
- `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-CONTEXT.md`
  — locked auth, DX, telemetry, guide, and package-consumer proof posture.
- `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VALIDATION.md`
  — current retroactive validation stating the old `TUS-14` blocker is
  superseded by a passing generated-app artifact.
- `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md`
  — stale verification report that still records the older `ECONNRESET` gap.

### Proof harness and current evidence
- `scripts/install_smoke.sh` — built-artifact package-consumer entrypoint; must
  stay the real proof command.
- `test/install_smoke/generated_app_smoke_test.exs` — generated-app smoke
  contract surface for package-consumer proofs.
- `test/install_smoke/support/generated_app_helper.ex` — tus proof harness,
  generated app wiring, Node script, and artifact persistence.
- `tmp/install_smoke_tus_last_run.json` — latest persisted proof artifact showing
  `failure_phase: "none"` and successful drop-and-resume evidence.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/install_smoke.sh` already provides the canonical `tus` package-consumer
  entrypoint and prints artifact hints on failure.
- `test/install_smoke/support/generated_app_helper.ex` already contains the
  real-socket tus proof flow, including large fixture generation, pinned
  `tus-js-client@4.3.1`, explicit interrupt/resume phases, and persisted debug
  reports.
- `tmp/install_smoke_tus_last_run.json` already preserves the last known green
  run with workspace path and proof payload, which can be reused as audit
  evidence and as a comparison point for regressions.

### Established Patterns
- Generated-app/package-consumer proofs are treated as contract truth, not as
  optional CI extras.
- Verification artifacts can drift behind the filesystem; when they do, current
  executable evidence outranks stale narrative docs and should drive the next
  plan.
- The tus lane is intentionally real and end-to-end: package artifact, generated
  app, live socket, MinIO backing, interrupted upload, resumed completion.

### Integration Points
- `bash scripts/install_smoke.sh tus` drives `test/install_smoke/generated_app_smoke_test.exs`.
- The smoke test uses helper-generated Node scripts and emits
  `install_smoke_tus_report.json` plus `install_smoke_tus_debug_report.json`.
- Phase 46 planning must connect live reruns back into verification artifacts so
  milestone audit status for `TUS-14` is durable and unambiguous.
</code_context>

<specifics>
## Specific Ideas

- Prefer "rerun first, then patch only if red" as the execution order.
- Use the persisted proof artifact as a baseline, but do not treat it as a
  substitute for a fresh rerun when Phase 46 executes.
- If the proof is green, update the verification story so auditors do not need
  to infer that `44-VERIFICATION.md` is stale by reading `44-VALIDATION.md`.
</specifics>

<deferred>
## Deferred Ideas

- Reopening tus protocol, auth, telemetry, or guide design choices from Phases
  42 and 44 — out of scope for this recovery phase.
- Expanding the proof into a broader soak or matrix lane — future CI hardening,
  not required to close `TUS-14`.
- Any fake-only substitute for the generated-app package-consumer proof —
  explicitly rejected.

### Reviewed Todos (not folded)
None — `todo.match-phase` returned no Phase 46 matches.
</deferred>

---

*Phase: 46-generated-app-tus-runtime-proof-recovery*
*Context gathered: 2026-05-24*
