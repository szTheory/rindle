# Phase 132: Measured Closure - Recovery Research

**Researched:** 2026-08-26
**Domain:** GitHub Actions required-path critical-path correction and API-backed timing evidence
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

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|---|---|---|
| CI-14 | Ten comparable non-cancelled PR runs must achieve median <=480s and p95 <=600s without weaker gates or newly introduced reruns. | Current receipt verifier already enforces exact-head, first-attempt, API-backed, ten-run evidence; this research identifies the graph constraint that prevents a blind replacement receipt. [VERIFIED: repository and GitHub Actions API] |
| COV-05 | Authoritative coverage remains >=82.13%, without percentage-only tests. | Plan 132-07 recorded 5,149/6,269 = 82.1343%; repeat the established single-run authority only after an approved CI correction. [VERIFIED: 132-07-SUMMARY.md] |
| SAFE-02 | Each correction retains focused proof, quality signals, SAFE-01, relevant integration/package lane, and bounded drift review. | The required correction must extend the existing workflow-topology contracts and run the established preservation authority. [VERIFIED: AGENTS.md, CONTEXT.md, and 132-07-SUMMARY.md] |
</phase_requirements>

## Summary

The repaired, authenticated FFmpeg release lookup at `f3476633fdc459779a937c5dc3c7234379bd8ce3` corrects a real repeated HTTP-403 failure mode, but it is not a demonstrated median-speed correction. Its only change is authenticated release lookup plus controller allowlisting; it preserves the required job graph. [VERIFIED: repository `git log`, `scripts/ci/install_ffmpeg.sh`, and `scripts/ci/collect_pr_timing_receipt.sh`]

The five successful first-attempt runs on immutable head `394550944bbff63c0e61c258528c8f8764298745` measure 510, 548, 591, 592, and 612 seconds: median 591 seconds and p95 612 seconds. Thus the current path misses CI-14 by 111 seconds at the median and 12 seconds at p95. [VERIFIED: GitHub Actions API run IDs 33003369940, 33004281315, 33005105221, 33005882907, and 33006773326]

**Primary recommendation:** Do not launch the ten-run sampler. First obtain an explicit recovery decision that either authorizes a narrowly proven required-job dependency-topology change, or declares CI-14 infeasible under D-02's unchanged-topology constraint and creates a follow-up contract; then plan the correction and only then collect exactly ten sequential first-attempt runs.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Required-result membership and merge decision | Frontend Server (CI orchestration) | API / Backend (GitHub branch protection) | `CI Summary` consumes declared `needs` results and is the sole branch-protection context. [VERIFIED: repository `ci.yml`, `eval_ci_summary.sh`, and `ci_lane_split_test.exs`] |
| Job start ordering / critical path | Frontend Server (CI orchestration) | CDN / Static (GitHub-hosted runners) | GitHub Actions `needs` is a scheduling prerequisite, not merely an aggregation label. [CITED: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs] |
| Native timing evidence | API / Backend (GitHub Actions API) | Frontend Server (CI observability job) | The observable source is run/job/step timestamps returned by Actions APIs; `ci-observability` publishes the same-run census. [VERIFIED: repository `ci.yml` and `collect_pr_timing_receipt.sh`] |
| CI-14 acceptance | API / Backend (receipt verifier) | Frontend Server (sampling controller) | Verify mode recomputes durations and thresholds from API identities, rather than accepting prose or local timings. [VERIFIED: repository `collect_pr_timing_receipt.sh` and `ci_timing_automation_test.exs`] |

## Standard Stack

### Core

| Component | Version | Purpose | Why Standard |
|---|---|---|---|
| GitHub Actions workflow `ci.yml` | repository-pinned actions | Required PR execution and `CI Summary` aggregation | It is the shipped, branch-protected CI surface; no dependency installation is proposed. [VERIFIED: repository `ci.yml` and `ci_lane_split_test.exs`] |
| GitHub CLI `gh` | 2.95.0 locally | Authenticated read-only run/job evidence and bounded controller actions | Existing receipt controller and test shim already use it. [VERIFIED: local environment and `collect_pr_timing_receipt.sh`] |
| `jq` | 1.7.1 locally | Deterministic extraction, chronology, and percentile recomputation | Existing controller uses it for all receipt integrity checks. [VERIFIED: local environment and `collect_pr_timing_receipt.sh`] |

**Installation:** None — the recovery should not add packages. [VERIFIED: phase boundary and repository]

## Architecture Patterns

### System Architecture Diagram

```text
pull_request event
       |
       v
parallel roots: Quality matrix + Optional Dependencies + Package Consumer
       |                         |
       |                         +--> currently gates Integration, Contract, Proof,
       |                               Adoption Smoke, and other required jobs
       v
Integration ----> Adopter
       |              |
       +--------------+------------------------+
Adoption Demo E2E Smoke -----------------------+--> CI Summary --> sole required check
Package Consumer -------------------------------+
other required jobs ----------------------------+
```

The diagram represents current scheduling topology, not a recommendation. `ci-summary.needs` contains Quality, Optional Dependencies, Integration, Contract, Proof, Package Consumer, Adoption Demo Unit, Adoption Demo E2E Smoke, Adopter, Brandbook Tokens, and CI Script Tests; its `always()` evaluation preserves the repository's skip-as-pass semantics. [VERIFIED: repository `ci.yml`, `eval_ci_summary.sh`, and `ci_lane_split_test.exs`]

### Pattern 1: Separate Membership, Gate Semantics, and Topology

**What:** Evaluate all three independently before changing YAML.

| Dimension | Current contract | May a recovery alter it? |
|---|---|---|
| Required-job membership | `CI Summary` stays sole required context and keeps its listed required jobs. [VERIFIED: repository] | No — D-01 forbids it. |
| Gate semantics | `CI Summary` runs with `if: always()` and its tested evaluator treats skipped prerequisite results as pass. [VERIFIED: repository] | No — D-01 forbids it. |
| Dependency ordering/topology | `needs` delays Integration/Contract/Proof/Adoption Smoke behind Quality plus Optional Dependencies; Adopter additionally waits for Integration and Contract. [VERIFIED: repository] | No under D-02; an explicit recovery contract must authorize any exception. |

**Why:** Retaining all names in `ci-summary.needs` can preserve required-job membership while a changed `needs` edge materially changes scheduling and failure propagation. GitHub documents that a job's `needs` must complete successfully before it runs. [CITED: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs]

### Pattern 2: Critical-path proof before remediation

**What:** Treat a CI Summary duration as `max(required predecessor completion) + summary overhead`; choose a correction only when the native API census identifies the repeated predecessor path.

**Current evidence:**

| Run | Barrier to downstream starts | Last workload finisher | CI Summary | Interpretation |
|---:|---:|---|---:|---|
| 33003369940 | 297s | Adoption Demo E2E Smoke, 280s | 591s | Smoke starts after the Quality barrier and completes at ~579s. [VERIFIED: GitHub Actions API] |
| 33004281315 | 296s | Adopter, 109s | 548s | Serial Quality → Integration → Adopter path is last. [VERIFIED: GitHub Actions API] |
| 33005105221 | 270s | Adopter, 100s | 510s | Same serial path gives the best observed result, yet remains 30s over target. [VERIFIED: GitHub Actions API] |
| 33005882907 | 319s | Adopter, 126s | 592s | Same serial path is last and exceeds target by 112s. [VERIFIED: GitHub Actions API] |
| 33006773326 | 267s | Adoption Demo E2E Smoke, 337s | 612s | Smoke variability alone breaches the p95 limit. [VERIFIED: GitHub Actions API] |

The current five-run median is 591s, not merely a single runner outlier. Three runs finish through the Adopter chain and two through E2E Smoke; that split prevents optimizing only one job from producing defensible median headroom. [VERIFIED: GitHub Actions API]

### Pattern 3: API-backed acceptance only

**What:** Keep the existing current-section receipt controller as the final authority. It requires exactly ten API-resolved PR runs on one SHA, attempt 1, success, exactly one successful `CI Summary`, non-overlap, table/manifest agreement, median ranks 5/6, p95 rank 10, and inclusive 480/600 limits. [VERIFIED: repository `collect_pr_timing_receipt.sh` and `ci_timing_automation_test.exs`]

**When to use:** After the recovery correction has passed all executable local preservation contracts. A re-sample by itself cannot establish causality or satisfy this research's recovery requirement. [VERIFIED: CONTEXT.md and repository controller]

## Concrete Recovery Options and Tradeoffs

| Option | Expected scheduling effect | Contract status | Recommendation |
|---|---|---|---|
| Re-sample `f347663` unchanged | Removes FFmpeg 403 risk but leaves the observed Quality → Integration → Adopter chain and Quality → Smoke start barrier. [VERIFIED: repository and GitHub Actions API] | Permitted mechanically, but no evidence of enough median headroom. | Reject — it is a blind re-sample. |
| Further tune one install step | Smoke steps include Playwright 78–111s, FFmpeg 17–111s, and libvips 21–172s; the current five-run median requires 111s total improvement. [VERIFIED: GitHub Actions API] | D-02 permits only if new data proves one bounded step is causal. | Reject now — no single demonstrated step has 111s repeatable median headroom across both critical branches. |
| Remove only Smoke's Quality/Optional `needs` | Makes Smoke independent while retaining it in `CI Summary`; it addresses Smoke-last runs, but not three Adopter-last runs. [VERIFIED: repository topology and GitHub Actions API] | Prohibited by D-02's unchanged-topology contract. | Insufficient even if authorized alone. |
| Remove Integration's Quality/Optional `needs` after proving it is self-contained | Lets Integration overlap the Quality barrier; Adopter still retains Quality, Integration, and Contract as required prerequisites, so completion can be bounded by Quality + its remaining short successor rather than Quality + Integration + Adopter. [INFERENCE from VERIFIED: repository graph and GitHub Actions API] | Prohibited by D-02 today; this is the smallest topology candidate that targets the Adopter branch. | Candidate only after an explicit topology recovery decision and dedicated proof that it does not hide a required precondition. |
| Decouple both Smoke and the proven self-contained Integration branch, preserving all `CI Summary` membership | Removes both observed last-finisher branches from the Quality-start barrier while retaining jobs, gate evaluator, and summary membership. [INFERENCE from VERIFIED: repository graph and GitHub Actions API] | Prohibited by D-02 today; a controlled topology change, not gate weakening. | Smallest evidence-backed path with plausible margin for <=480 median / <=600 p95; plan only after authorization. |
| External-runner exception | Does not improve time. | D-03 requires job evidence, named owner, and dated follow-up; the observed repeatable dependency-chain pattern is not such evidence. [VERIFIED: CONTEXT.md and GitHub Actions API] | Reject. |

### Feasibility Verdict

The unchanged-topology contract makes CI-14 infeasible on current evidence: its best observed 510s result already misses the median target, and its five-run median is 591s. The only shipped correction after those samples is an FFmpeg-authentication reliability fix, so there is no measured speed change that could support a ten-run attempt. [VERIFIED: GitHub Actions API and repository `git log`]

**Required explicit decision before planning:** choose one of the following, and record it in a recovery CONTEXT/roadmap amendment.

1. **Authorize a bounded topology exception:** retain every `CI Summary` need, the sole required check, skip-as-pass, and zero-rerun policy; permit removal of only identified prerequisite edges after an executable self-containment proof for each affected job. This supports a new Phase 132 recovery plan.
2. **Keep D-02 unchanged:** declare CI-14 not closable in Phase 132, retain the failed receipt, and charter a follow-up phase whose contract explicitly permits dependency-topology optimization with preservation tests. This is the honest path if graph change is not acceptable.

Do not select an external-runner exception or a sample-only Plan 132-08 recovery; neither resolves the demonstrated cause. [VERIFIED: CONTEXT.md, REQUIREMENTS.md, and GitHub Actions API]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| CI-14 timing proof | Manual spreadsheet, screenshots, or a one-off timing script | Existing `collect_pr_timing_receipt.sh verify` API-backed controller | It rejects mixed heads, retries, failed/cancelled runs, bad summary jobs, altered durations, overlaps, and threshold misses. [VERIFIED: repository controller and tests] |
| Required-gate evaluation | Ad hoc `needs` parsing in a new job | Existing `eval_ci_summary.sh` plus `test_ci_summary_gate.sh` | It preserves the tested skip-as-pass fork semantics. [VERIFIED: repository] |
| Package install retry | New unbounded mirror/retry logic | Existing bounded install-first `install_apt_packages.sh` | It has two 240-second-bounded attempts and refreshes only after initial failure. [VERIFIED: repository and 132-06-SUMMARY.md] |

## Common Pitfalls

### Pitfall 1: Calling membership preservation “unchanged topology”

**What goes wrong:** A plan leaves every `ci-summary.needs` entry intact but removes a job's earlier `needs`; it then falsely claims no topology changed. [VERIFIED: repository graph]

**How to avoid:** Test membership/gate semantics separately from each job's exact prerequisite set; describe any removed edge as a topology exception. [CITED: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs]

### Pitfall 2: Optimizing only the visible long standalone job

**What goes wrong:** `Package Consumer Proof Matrix` is roughly 371–393 seconds, but it was not the last required finisher in the supplied successful samples. [VERIFIED: supplied live census]

**How to avoid:** Select the correction using end-to-end finish time and predecessor chain, not duration alone. [VERIFIED: GitHub Actions API]

### Pitfall 3: Treating the 403 fix as timing evidence

**What goes wrong:** A successful authenticated FFmpeg release lookup is conflated with a measured speedup. [VERIFIED: repository diff and supplied anomaly]

**How to avoid:** Keep it as reliability preservation; collect native step timings after any authorized scheduling correction and require the normal ten-run acceptance receipt. [VERIFIED: repository controller]

### Pitfall 4: Human acceptance or reruns masking a miss

**What goes wrong:** A user acknowledgement, a rerun, a mixed-head sample, or choosing only fast runs appears to improve a metric while invalidating CI-14. [VERIFIED: REQUIREMENTS.md and repository controller]

**How to avoid:** Retain exactly ten chronological first-attempt successful PR runs from a single immutable head, with API verification as the phase gate. [VERIFIED: repository controller]

## Code Examples

### Required topology regression shape

```elixir
# Extend the shipped topology test; source: repository ci_lane_split_test.exs
summary_needs = ci_summary_needs_block(ci)
assert summary_needs =~ "- adoption-demo-e2e-smoke\n"
assert summary_needs =~ "- integration\n"
assert summary_needs =~ "- adopter\n"

# If a recovery exception is approved, assert the precise authorized prerequisite
# removal and retain all self-contained setup/proof steps in that job block.
```

### Final acceptance command

```bash
# Source: repository scripts/ci/collect_pr_timing_receipt.sh
bash scripts/ci/collect_pr_timing_receipt.sh verify \
  --repo szTheory/rindle --workflow ci.yml --summary-job "CI Summary" \
  --samples 10 --median-max 480 --p95-max 600 \
  --receipt .planning/phases/132-measured-closure/132-CI-TIMING-RECEIPT.md
```

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---:|---|---|
| `gh` authenticated CLI | API census and final receipt verification | ✓ | 2.95.0 | None — authentication is a runtime precondition, not acceptance. [VERIFIED: local environment and controller] |
| `jq` | Receipt parsing/recomputation | ✓ | 1.7.1 | None — controller requires it. [VERIFIED: local environment and controller] |
| `git` / Bash | Head checks and controller | ✓ | 2.41.0 / 5.2.37 | None. [VERIFIED: local environment] |
| Elixir/Mix | Executable topology and preservation tests | ✓ | OTP 28 / installed Mix | Repository test environment. [VERIFIED: local environment] |

**Missing dependencies with no fallback:** None. [VERIFIED: local environment]

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit (repository Mix project) [VERIFIED: repository tests] |
| Config file | `test/test_helper.exs` [VERIFIED: repository] |
| Quick run command | `mix test test/install_smoke/ci_lane_split_test.exs test/install_smoke/ci_observability_test.exs test/install_smoke/ci_timing_automation_test.exs --seed 0` [VERIFIED: repository] |
| Full preservation commands | `mix quality_signals && bash scripts/maintainer/refactor_contract.sh && bash scripts/install_smoke.sh image` [VERIFIED: 132-07-SUMMARY.md] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| CI-14 | Exact ten-run receipt identity, chronology, statistics, and inclusive threshold verification | Controller/integration fixture + live API verifier | `mix test test/install_smoke/ci_timing_automation_test.exs --seed 0` then controller `verify` command above | ✅ |
| CI-14 | Required membership and skip-as-pass survive any approved topology exception | Source-bound workflow and Bash gate regression | `mix test test/install_smoke/ci_lane_split_test.exs test/install_smoke/ci_observability_test.exs --seed 0 && bash scripts/ci/test_ci_summary_gate.sh` | ✅, extend for authorized edges |
| COV-05 | Coverage floor remains authoritative | Integration/coverage | `mix coveralls.multiple --type local --type json` | ✅ |
| SAFE-02 | Preservation and prohibited-surface boundaries | Integration/contract | `mix quality_signals && bash scripts/maintainer/refactor_contract.sh && bash scripts/install_smoke.sh image && ./scripts/maintainer/automation_first_contract.sh` | ✅ |

### Wave 0 Gaps

- [ ] Add a topology-specific regression only if the recovery decision authorizes named `needs` removals: assert all `CI Summary` membership and evaluator semantics remain, assert exactly the approved edge set changes, and assert the affected jobs retain their required self-contained setup/proof commands. [INFERENCE from VERIFIED: repository contracts]
- [ ] Add a deterministic critical-path assertion derived from fixture timestamps only if it verifies the approved decision; do not encode a local wall-clock performance target. [VERIFIED: AGENTS.md automation-first constraint and existing receipt method]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | Yes | Reuse authenticated `gh`; do not print tokens. [VERIFIED: controller and FFmpeg helper] |
| V3 Session Management | No | No application session surface changes. [VERIFIED: phase boundary] |
| V4 Access Control | Yes | Controller validates PR/head ancestry and owns/removes only its named label. [VERIFIED: controller] |
| V5 Input Validation | Yes | Shell option validation, SHA checks, exact repo/workflow/summary-job constraints, and API identity checks fail closed. [VERIFIED: controller] |
| V6 Cryptography | No | No cryptographic implementation is proposed. [VERIFIED: phase boundary] |

### Known Threat Patterns for CI receipt control

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Receipt/result tampering | Tampering | Re-resolve each run/job from Actions API and recompute values. [VERIFIED: controller] |
| Slow-run exclusion | Repudiation | Require one complete consecutive exact-head eligible slice of ten. [VERIFIED: controller] |
| Credential leak | Information disclosure | Use ephemeral `GITHUB_TOKEN` request header without outputting it. [VERIFIED: `install_ffmpeg.sh`] |
| Unauthorized PR mutation | Elevation of privilege | Refuse pre-existing label ownership and non-fast-forward publication. [VERIFIED: controller] |

## State of the Art

| Old Approach | Current Approach | Impact |
|---|---|---|
| Legacy timing blocks could document a failed sample. | Explicit `CI_TIMING_CURRENT_*` blocks are the only acceptance input, API-validated by verify mode. [VERIFIED: controller and timing tests] | Historical failure evidence remains immutable while current acceptance is unambiguous. |
| FFmpeg lookup used an unauthenticated release API call. | The helper sends the ephemeral Actions token when available. [VERIFIED: `install_ffmpeg.sh` and commit `4254165`] | Removes the supplied 403 failure mode; it is not a throughput claim. |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | The exact D-08 graph will retain enough real-run headroom to satisfy both inclusive thresholds. | Live acceptance | Medium — this is an explicit non-blocking live-acceptance assumption; only the fresh API-backed ten-run receipt may confirm or reject it. |

## Resolved Questions

1. **Which exact dependency edges are authorized? — RESOLVED by D-08.**
   - D-08 authorizes exactly six removals: `quality -> integration`, `optional-dependencies -> integration`, `quality -> contract`, `optional-dependencies -> contract`, `quality -> adoption-demo-e2e-smoke`, and `optional-dependencies -> adoption-demo-e2e-smoke`.
   - D-09 freezes every other topology edge, required-result membership, job body, proof command, runner, matrix, service, cache, test partition, rerun policy, and exception surface.

2. **Does Contract become the new Adopter blocker when Integration is decoupled? — RESOLVED by the five-run deterministic projection.**
   - The projection shows that removing only the Integration and Smoke barriers leaves the remaining Contract path at about a 486-second median, without defensible CI-14 headroom; removing D-08's exact six edges addresses both measured critical branches with material projected headroom.
   - This projection resolves topology selection only. It is not CI-14 acceptance evidence.

**Non-blocking live-acceptance assumption:** the exact D-08 graph will retain enough real-run headroom to satisfy the inclusive 480-second median and 600-second p95 limits. Only the fresh API-backed ten-run receipt can confirm or reject that assumption; it does not block implementing the already authorized and preservation-tested topology correction.

## Sources

### Primary (HIGH confidence)

- Repository `.github/workflows/ci.yml`, timing controller, and three CI contract tests — current membership, semantics, and verifier behavior. [VERIFIED: repository]
- GitHub Actions REST job payloads for runs 33003369940, 33004281315, 33005105221, 33005882907, and 33006773326 — actual barrier, job, and step timestamps. [VERIFIED: GitHub Actions API]
- `132-CONTEXT.md`, `132-CI-TIMING-RECEIPT.md`, and 132-05/06/07 summaries — locked phase boundaries and prior evidence. [VERIFIED: repository]

### Secondary (MEDIUM confidence)

- [GitHub Actions: Using jobs in a workflow](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs) — `needs` dependency semantics. [CITED: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — shipped repository tooling and local availability were inspected.
- Architecture: HIGH — job graph and five live Actions job payloads were read directly; the topology-change performance outcome remains explicitly inferential.
- Pitfalls: HIGH — grounded in the receipt verifier, required-gate tests, and observed samples.

**Research date:** 2026-08-26
**Valid until:** Until the recovery decision or CI topology changes; timing observations must be refreshed after either event.
