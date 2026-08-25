# Phase 132: Measured Closure - Research

**Researched:** 2026-08-25
**Domain:** GitHub Actions required-path measurement and behavior-preserving packed-consumer proof
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

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

### Deferred Ideas (OUT OF SCOPE)

- `mix test --partitions` parallelization remains evidence-gated on demonstrated core starvation.
- Cache redesign and broad dependency/toolchain upgrades remain separate risk-ranked work.
- Required-check topology changes, proof removal, and rerun-based timing improvements are not closure
  strategies for this phase.
</user_constraints>

## Project Constraints (from AGENTS.md)

- Keep edits focused and run the checks named by `RUNNING.md` for the change. [VERIFIED: AGENTS.md]
- Preserve a green-main release train: Quality/coveralls, Integration, Proof, Package Consumer, and Adopter are merge-blocking through the required path. [VERIFIED: AGENTS.md; RUNNING.md]
- Follow `guides/release_publish.md`: exact-SHA GitHub Actions evidence is authoritative; local results are diagnostic. [VERIFIED: guides/release_publish.md]
- Do not alter `name: CI`, `ci.yml`, or the single required `CI Summary` check; release automation is coupled to them. [VERIFIED: RUNNING.md; test/install_smoke/ci_lane_split_test.exs]
- Do not change product scope or shipped claims; this phase is CI proof and a narrow CI-boundary correction only. [VERIFIED: AGENTS.md; 132-CONTEXT.md]

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CI-14 | Ten comparable non-cancelled PR runs achieve <=8m median and <=10m p95 without weaker gates or new reruns. | Exact ten-run job/step census identifies the packed image-consumer proof as the demonstrated long pole; receipt rules are already recorded. [VERIFIED: GitHub Actions API; 132-CI-TIMING-RECEIPT.md] |
| COV-05 | Authoritative coverage remains >=82.13%; no coverage chasing. | Existing authoritative command is the one-run `mix coveralls.multiple --type local --type json`; Phase 131 recorded 82.1343%. [VERIFIED: RUNNING.md; 131-IMPLEMENTATION-VERIFICATION.md] |
| SAFE-02 | Each slice passes focused proof, quality signals, SAFE-01, relevant integration/package lane, and bounded drift review. | Existing CI policy and SAFE-01 script define the preservation checks and prohibited surfaces. [VERIFIED: REQUIREMENTS.md; scripts/maintainer/refactor_contract.sh] |
</phase_requirements>

## Summary

The failed receipt is comparable and must be retained as a failed baseline: ten successful first-attempt PR runs at immutable head `005beae2…` measured a 515.5-second median and a 544-second nearest-rank p95. Only the median misses the CI-14 target, by 35.5 seconds; no external-runner exception is justified by that result. [VERIFIED: 132-CI-TIMING-RECEIPT.md]

The native GitHub Actions jobs API re-census of those exact ten run IDs makes the correction target unambiguous. `Package Consumer Proof Matrix + Release Preflight` was the long pole in every run; its required `Run built-artifact image-only package-consumer proof against MinIO` step averaged 392.6 seconds (292–424 seconds). The next-longest required job, canonical Quality, averaged 250.4 seconds. [VERIFIED: GitHub Actions API]

Within that long-pole step, the generated-app helper first invokes `mix phx.new ... --install`, then patches the generated project and explicitly runs `mix deps.get` and `mix compile`. Plan the smallest proof-preserving correction there: remove the pre-patch generator install only after a focused regression test locks that the generator command remains minimal and the post-patch dependency fetch/compile, migrations, boot, and image lifecycle proof still run. This avoids a topology, cache, test-partition, or dependency redesign. [VERIFIED: test/install_smoke/support/generated_app/workspace.ex; test/install_smoke/support/generated_app_helper.ex; test/install_smoke/support/generated_app/smoke_source.ex]

**Primary recommendation:** Replace the generated-app pre-patch `mix phx.new --install` work with generation followed by the existing post-patch fetch/compile path, preserve the packed image proof unchanged, then collect a new exact-head ten-run PR receipt. [VERIFIED: codebase grep; GitHub Actions API]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Required PR gate evaluation | CI workflow / GitHub Actions | Branch protection | `ci-summary` evaluates its required job results; branch protection requires only its `CI Summary` check. [VERIFIED: .github/workflows/ci.yml; scripts/ci/eval_ci_summary.sh; RUNNING.md] |
| Packed image-consumer behavior | CI workflow / existing required job | Generated Phoenix app | The required package-consumer job owns runner setup and invokes the clean-room generated-app proof. [VERIFIED: .github/workflows/ci.yml; scripts/install_smoke.sh] |
| Generated-app setup correction | Test/support code | Existing CI job | Command construction belongs in the helper; CI keeps the same job, step, and gate wiring. [VERIFIED: test/install_smoke/support/generated_app/workspace.ex; .github/workflows/ci.yml] |
| Timing receipt and percentile decision | Maintainer evidence artifact | GitHub Actions API | Live PR run timestamps and CI Summary completion are authoritative; the receipt records the comparable-window calculation. [VERIFIED: 132-CI-TIMING-RECEIPT.md; scripts/ci/collect_ci_baseline.sh] |

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|---|---:|---|---|
| GitHub Actions `ci.yml` | repository-pinned actions | Required PR orchestration and native job/step timing | It is the existing, release-coupled required path; no new CI system is authorized. [VERIFIED: .github/workflows/ci.yml; RUNNING.md] |
| Elixir / Mix | repository toolchain | Generate, patch, compile, and execute the packed clean-room consumer | All existing proof commands use Mix; no package installation is required for this phase. [VERIFIED: scripts/install_smoke.sh; test/install_smoke/support/generated_app_helper.ex] |
| ExUnit | project test framework | Locks generated-app and workflow contracts | Existing install-smoke and CI-policy tests are the focused regression surface. [VERIFIED: test/install_smoke/generated_app_smoke_test.exs; test/install_smoke/ci_lane_split_test.exs] |

### Supporting

| Tool | Purpose | When to Use |
|---|---|---|
| `gh` + `jq` | Read live Actions runs/jobs and classify attempts | Receipt collection and job-level exception evidence only; never mutate protection. [VERIFIED: scripts/ci/collect_ci_baseline.sh] |
| `scripts/maintainer/refactor_contract.sh` | SAFE-01 compile-cycle and contract preservation authority | Run for every implementation slice and final correction. [VERIFIED: scripts/maintainer/refactor_contract.sh; RUNNING.md] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| Narrow generated-app setup correction | Test partitions, cache redesign, or required-job topology changes | Deferred or prohibited: none is supported by this evidence, and each changes more risk surface than the demonstrated nested setup cost. [VERIFIED: 132-CONTEXT.md; GitHub Actions API] |
| Fresh ten-run PR receipt | Local timing or a rerun/mixed-head sample | Invalid for CI-14 because live first-attempt PR timing from one immutable head is required. [VERIFIED: 132-CONTEXT.md; 132-CI-TIMING-RECEIPT.md] |

**Installation:** None — use the repository’s existing Elixir/Mix, GitHub Actions, `gh`, and `jq` tooling. [VERIFIED: package manifest and existing scripts]

## Architecture Patterns

### System Architecture Diagram

```text
pull_request event at immutable SHA
        |
        +--> Quality / optional dependencies --> Integration, Contract, Proof, Adopter
        |                                                   |
        +--> Package Consumer (starts independently) ------+
        |       -> install_smoke.sh image
        |       -> generated app: generate -> patch -> deps -> compile -> migrate -> boot -> lifecycle
        |
        +--> Adoption unit / E2E smoke / CI script tests / brandbook tokens
                         |
                         v
                  CI Summary (success or intentional skip only)
                         |
                   branch protection
                         |
                  receipt: start -> CI Summary completion
```

The diagram mirrors the present required path; the correction is contained within the generated-app setup sequence and must not change any arrows or `ci-summary.needs`. [VERIFIED: .github/workflows/ci.yml; scripts/ci/eval_ci_summary.sh]

### Recommended Project Structure

```text
.github/workflows/ci.yml                         # unchanged required-job topology
scripts/install_smoke.sh                         # unchanged profile entry point
test/install_smoke/support/generated_app/
  workspace.ex                                   # generator command construction
test/install_smoke/support/generated_app_helper.ex # patch -> fetch -> compile -> proof orchestration
test/install_smoke/generated_app_smoke_test.exs  # observable generated-app contracts
.planning/phases/132-measured-closure/
  132-CI-TIMING-RECEIPT.md                       # final immutable-head receipt
```

### Pattern 1: Patch before the one authoritative generated-app dependency installation

**What:** Generate the bare Phoenix project, patch it with the local unpacked Rindle package/profile/migrations, then use the already-existing `mix deps.get` and `mix compile` operations as the one post-patch setup path. [VERIFIED: test/install_smoke/support/generated_app/workspace.ex; test/install_smoke/support/generated_app_helper.ex]

**When to use:** Only in the required image consumer after a focused test proves the package provenance, generated migration, boot, and lifecycle checks remain identical. [VERIFIED: test/install_smoke/generated_app_smoke_test.exs; 132-CONTEXT.md]

### Pattern 2: Evidence-only timing closure

**What:** Make the correction, validate it locally, then trigger one `pull_request` run at a time from the same immutable PR head. Include only `success`, `run_attempt == 1`, non-cancelled runs; measure workflow `startedAt` to `CI Summary.completedAt`, sort ten seconds values, average ranks 5 and 6 for median, and use rank 10 for p95. [VERIFIED: 132-CI-TIMING-RECEIPT.md]

**When to use:** After the correction has merged into the candidate PR head; not as a substitute for implementation verification. [VERIFIED: guides/release_publish.md; 132-CI-TIMING-RECEIPT.md]

### Anti-Patterns to Avoid

- **Changing `ci-summary.needs`, its name, or skip-as-pass semantics:** this weakens/redefines the release-coupled required path rather than shortening it. [VERIFIED: 132-CONTEXT.md; scripts/ci/eval_ci_summary.sh]
- **Adding `--slowest` to the Quality coverage command:** it enables trace mode and serializes async tests. [VERIFIED: .github/workflows/ci.yml; test/install_smoke/ci_observability_test.exs]
- **Counting a rerun, cancellation, different SHA, or local timing:** each breaks CI-14 comparability. [VERIFIED: 132-CONTEXT.md; 132-CI-TIMING-RECEIPT.md]
- **Calling the median miss an external-runner exception:** the existing receipt expressly rejects that disposition absent evidence, owner, and dated follow-up. [VERIFIED: 132-CI-TIMING-RECEIPT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Required-check aggregation | A second aggregate check or custom branch-protection rule | Existing `ci-summary` plus `scripts/ci/eval_ci_summary.sh` | It already implements the single required check and skip-as-pass rule. [VERIFIED: .github/workflows/ci.yml; scripts/ci/eval_ci_summary.sh] |
| Timing API client / percentile convention | A new telemetry system or alternate statistic | Existing Actions jobs API workflow plus documented receipt rules | The repo already defines run-attempt filtering, start/summary timestamps, and nearest-rank p95. [VERIFIED: scripts/ci/collect_ci_baseline.sh; 132-CI-TIMING-RECEIPT.md] |
| Generated-app proof replacement | A lightweight mock of package installation | Existing `scripts/install_smoke.sh image` / generated-app lifecycle | The required lane deliberately proves build/unpack, install, migrations, boot, and lifecycle in a clean room. [VERIFIED: .github/workflows/ci.yml; 131-IMPLEMENTATION-VERIFICATION.md] |

**Key insight:** CI-14 needs less duplicated work inside an already-required proof, not less proof. [VERIFIED: 132-CONTEXT.md; GitHub Actions API]

## Common Pitfalls

### Pitfall 1: Optimizing a non-critical job

**What goes wrong:** A plan edits Quality or parallelism even though the required package-consumer job governs completion. [VERIFIED: GitHub Actions API]

**How to avoid:** Keep the correction inside the image packed-consumer step unless new same-head timings disprove this census. [VERIFIED: 132-CONTEXT.md; GitHub Actions API]

### Pitfall 2: Removing cold-install proof while removing duplicate setup

**What goes wrong:** A shortcut makes the generated consumer reuse repository artifacts or omits post-patch dependency resolution. [VERIFIED: test/install_smoke/support/generated_app_helper.ex; test/install_smoke/generated_app_smoke_test.exs]

**How to avoid:** Lock package-root provenance, `deps/rindle` absence for package mode, compile, migrations, boot, and the canonical presigned-PUT lifecycle before/with the command change. [VERIFIED: test/install_smoke/generated_app_smoke_test.exs; test/install_smoke/support/generated_app/smoke_source.ex]

### Pitfall 3: Replacing the failed receipt instead of preserving it

**What goes wrong:** The prior valid window is overwritten or mixed into the new head’s sample, obscuring the true before/after evidence. [VERIFIED: 132-CI-TIMING-RECEIPT.md]

**How to avoid:** Retain the failed baseline and add a distinct final receipt section/table keyed to the corrected immutable SHA. [VERIFIED: 132-CONTEXT.md]

### Pitfall 4: Misclassifying an infrastructure event

**What goes wrong:** A slow run is excluded merely for missing the target. [VERIFIED: 132-CONTEXT.md]

**How to avoid:** An exception needs job-level evidence, a named owner, and a dated follow-up; otherwise the run remains evidence or the collection restarts as required. [VERIFIED: REQUIREMENTS.md; 132-CONTEXT.md]

## Code Examples

### Preserve the patch-then-setup ordering

```elixir
# Source: test/install_smoke/support/generated_app_helper.ex
generate_phoenix_app!(workspace_root, generated_app_root)
patch_generated_app!(generated_app_root, app_name, app_module, package_root, network_version, :image, [])
fetch_deps!(generated_app_root, shared_env, network_version)
compile_result = run_cmd!(generated_app_root, ["mix", "compile"], shared_env)
```

The implementation change belongs only in the generator argv; preserve the following post-patch operations. [VERIFIED: test/install_smoke/support/generated_app_helper.ex]

### Keep the aggregate gate evaluator unchanged

```bash
# Source: scripts/ci/eval_ci_summary.sh
case "${result}" in
  success|skipped) ;;
  *) failed=1 ;;
esac
```

Do not alter this evaluator or change what it receives in `needs`. [VERIFIED: scripts/ci/eval_ci_summary.sh; 132-CONTEXT.md]

## State of the Art

| Old Approach | Current Approach | Impact |
|---|---|---|
| Quality waited for package-consumer | Image packed-consumer starts independently while still joining `CI Summary` | The gate retains the proof and removes avoidable inter-job queueing. [VERIFIED: git show a07eaff; .github/workflows/ci.yml] |
| Quality coverage used `--slowest` | Coverage runs once without trace serialization; slow-test diagnostics remain separate | Prevents the coverage lane from serializing async tests. [VERIFIED: git show a07eaff; .github/workflows/ci.yml] |
| Timing target was unproven | A failed but comparable ten-run receipt now exists | The next phase action is a causal correction plus fresh receipt, not further baseline work. [VERIFIED: 132-CI-TIMING-RECEIPT.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | Removing `--install` from `mix phx.new` will save enough time to close the 35.5-second median gap. | Summary / Architecture Patterns | The correction could preserve behavior but fail CI-14, requiring a new evidence-guided investigation. |

The candidate is deliberately a testable hypothesis, not a performance guarantee: native timing proves the enclosing step is the bottleneck but does not expose its nested command durations. [VERIFIED: GitHub Actions API; GitHub Actions log for run 32863291301]

## Open Questions

1. **How much of the nested proof is spent in Phoenix’s pre-patch install versus the post-patch lifecycle?**
   - What we know: the parent step takes 292–424 seconds and the nested generated-app proof accounted for 411.7 synchronous seconds in one representative run. [VERIFIED: GitHub Actions API; GitHub Actions log for run 32863291301]
   - What's unclear: the current command runner captures child output but does not emit per-child timing in a successful test log. [VERIFIED: test/install_smoke/support/generated_app/command_runner.ex]
   - Recommendation: make the minimal `--install` removal with focused proof first; if it misses the receipt target, add only bounded stage timing to the existing helper before considering another correction. [ASSUMED]

2. **Can the new receipt be collected without a maintainer action on the draft PR?**
   - What we know: the workflow accepts `pull_request` `labeled` events and the prior receipt used sequential PR runs. [VERIFIED: .github/workflows/ci.yml; 132-CI-TIMING-RECEIPT.md]
   - What's unclear: the exact maintainer trigger cadence/label procedure is not encoded as a committed script. [VERIFIED: codebase grep]
   - Recommendation: include a human checkpoint to trigger/observe each run sequentially and document the exact operation in the final receipt. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| Elixir/Mix | focused and quality verification | ✓ | OTP 28 runtime detected | — [VERIFIED: local command probe] |
| `gh` | live receipt and job-evidence collection | ✓ | 2.95.0 | — [VERIFIED: local command probe] |
| `jq` | collector/receipt processing | ✓ | 1.7.1 | — [VERIFIED: local command probe] |
| Docker | packed-consumer local proof services | ✓ | 29.5.2 | GitHub Actions for authoritative timing only. [VERIFIED: local command probe] |
| GitHub Actions PR runner | CI-14 receipt | available externally | live API returned all ten recorded run/job payloads | No local substitute for CI-14. [VERIFIED: GitHub Actions API; guides/release_publish.md] |

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit (project-native) [VERIFIED: test/install_smoke/generated_app_smoke_test.exs] |
| Config file | `test/test_helper.exs` [VERIFIED: test/install_smoke/ci_observability_test.exs] |
| Quick run command | `mix test test/install_smoke/generated_app_smoke_test.exs --include minio` [VERIFIED: scripts/install_smoke.sh] |
| Full preservation commands | `mix quality_signals`; `bash scripts/maintainer/refactor_contract.sh`; `mix coveralls.multiple --type local --type json`; `bash scripts/install_smoke.sh image` [VERIFIED: RUNNING.md; scripts/maintainer/refactor_contract.sh] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| CI-14 | Generator change preserves clean-room package/image lifecycle before live receipt | focused integration | `mix test test/install_smoke/generated_app_smoke_test.exs --include minio` | ✅ |
| CI-14 | Required-gate topology and skip-as-pass remain unchanged | contract | `mix test test/install_smoke/ci_lane_split_test.exs test/install_smoke/ci_observability_test.exs && bash scripts/ci/test_ci_summary_gate.sh` | ✅ |
| CI-14 | Ten exact-head first-attempt PR runs meet percentile targets | live acceptance | read-only `gh api` receipt collection | manual/external acceptance |
| COV-05 | Authoritative coverage stays >=82.13% | integration | `mix coveralls.multiple --type local --type json` | ✅ |
| SAFE-02 | No behavior/prohibited-surface drift | contract + packed consumer | `mix quality_signals && bash scripts/maintainer/refactor_contract.sh && bash scripts/install_smoke.sh image` | ✅ |

### Sampling Rate

- **Per task commit:** focused generated-app proof plus CI topology/gate tests. [VERIFIED: 132-CONTEXT.md]
- **Per wave merge:** `mix quality_signals` and SAFE-01. [VERIFIED: RUNNING.md]
- **Phase gate:** authoritative coverage, packed image consumer, bounded prohibited-surface diff review, then a complete green ten-run exact-head receipt. [VERIFIED: REQUIREMENTS.md; 132-CONTEXT.md]

### Wave 0 Gaps

- [ ] Add a focused contract that detects regression to generator pre-patch dependency installation, while asserting downstream package provenance/lifecycle behavior; this must land before or with the helper correction. [ASSUMED]
- [ ] No new framework or dependency install is needed. [VERIFIED: codebase grep]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | no | CI receipt reads use the maintainer’s existing `gh` authentication; no product auth change. [VERIFIED: scripts/ci/collect_ci_baseline.sh] |
| V3 Session Management | no | No application-session change. [VERIFIED: phase boundary] |
| V4 Access Control | yes | Keep branch protection’s sole required check and the workflow’s existing least-privilege `contents: read` default. [VERIFIED: RUNNING.md; .github/workflows/ci.yml] |
| V5 Input Validation | yes | Preserve quoted shell variables and trusted GitHub-context use; do not introduce PR title/body/branch shell interpolation. [VERIFIED: .github/workflows/ci.yml] |
| V6 Cryptography | no | No cryptographic implementation or dependency change. [VERIFIED: phase boundary] |

### Known Threat Patterns for CI workflow changes

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Required-proof bypass | Elevation of privilege | Keep `CI Summary` sole required check and unchanged required-job set; run topology and summary-gate tests. [VERIFIED: 132-CONTEXT.md; scripts/ci/test_ci_summary_gate.sh] |
| Rerun/mixed-head timing manipulation | Tampering | Include only first-attempt, successful, non-cancelled runs from one SHA and record source URLs/timestamps. [VERIFIED: 132-CI-TIMING-RECEIPT.md] |
| Runner incident hidden as performance success | Repudiation | Require job-level evidence, named owner, and dated follow-up for any exception. [VERIFIED: REQUIREMENTS.md] |
| Shell injection from PR metadata | Tampering | Do not add untrusted event-field interpolation; current concurrency logic uses only event name. [VERIFIED: .github/workflows/ci.yml] |

## Sources

### Primary (HIGH confidence)

- [GitHub Actions API](https://api.github.com/repos/szTheory/rindle/actions/runs/32863291301/jobs) - exact-head run/job/step timing census across the ten receipt runs.
- [.github/workflows/ci.yml](../../.github/workflows/ci.yml) - required workflow graph, entry trigger, package-consumer job, observability, and CI Summary.
- [132-CI-TIMING-RECEIPT.md](132-CI-TIMING-RECEIPT.md) - existing measurement method, failed result, and integrity criteria.
- [RUNNING.md](../../../RUNNING.md) and [release_publish.md](../../../guides/release_publish.md) - release and CI lane authorities.

### Secondary (MEDIUM confidence)

- Context7 lookup was planned but unavailable in this runtime (`ctx7` and Context7 MCP are absent); no external framework claim is relied on for the recommendation. [VERIFIED: local command probe]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new package/tool choice; all components are repository-owned. [VERIFIED: codebase grep]
- Architecture: HIGH — existing workflow and exact live job data establish the path and long pole. [VERIFIED: .github/workflows/ci.yml; GitHub Actions API]
- Pitfalls: HIGH — preserved constraints and receipt invalidation rules are explicit. [VERIFIED: 132-CONTEXT.md; 132-CI-TIMING-RECEIPT.md]

**Research date:** 2026-08-25
**Valid until:** 2026-09-01 (fast-moving live CI evidence)
