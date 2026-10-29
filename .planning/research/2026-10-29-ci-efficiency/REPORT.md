# CI/CD efficiency decisions — October 29, 2026

The next small implementation is **overlap the full main package matrix with Quality**, retaining Optional Dependencies as its prerequisite and every existing proof/release gate. The current whole-DAG model predicts **4m54s–8m46s less main latency**, with **no runner-time saving on successful runs**. This is a local experiment, not a measured improvement. The best candidate for reducing actual repeated work is a second image consumer execution, but its dev/test package equivalence must be proved before removing it.

Treat the multi-hour readiness producer separately from ordinary CI. One historical successful producer took **254m38s**, including **251m27s** in collection and only **2m28s** in outer prerequisites. The now-completed current acceptance is recorded separately in [current acceptance timing](current-acceptance-timings.md), without changing the original selected sample. Smaller setup caches cannot plausibly explain or remove that long pole.

## Evidence and completed fanout

Three independent reviews covered runtime accounting, workflow/Elixir/package architecture, and security/reliability/cost semantics. Each considered the current design, a minimal alternative, adverse cases and an observable stop condition. Their recommendations were reconciled below; more generic framework comparisons would not change the decisions.

- [Measured timing and critical-path analysis](live-timings.md), with eight complete exact-attempt run inventories and a reproducible DAG model.
- [Workflow and qualifier design](workflow-design.md), with 13 source fingerprints, PR189 inspection and actual observer-failure reproduction.
- [Primary sources and adversarial assessment](primary-and-adversarial.md), with dated official references and current-main Git identities.

Current frozen source is `48407bac7691c459395760b06f7714bbb6c3545b`; research-start main is compatible metadata `b2a60c51687293df5498920cc2bddb4e25349251`. The canonical planning checkout is older and dirty, so it was not used as the implementation base. No current acceptance input was edited, canceled, rerun or replaced by research.

The sample is diagnostic: different source revisions, cache histories and load; two recent PRs, two full main runs, a dispatch Nightly, an actual schedule, and two historical producers. It is not an exact-ten benchmark, p95, causal before/after study or reliability estimate. CI-16 remains deferred unfinished with zero credit.

| Workload | Observed wall latency | Interpretation |
|---|---:|---|
| PR CI | 9m37s–12m44s | Bottleneck alternates between Quality→Unit and Proof |
| Full main CI | 20m24s–23m23s | Image package/preflight path finishes after CI Summary |
| Dispatch / scheduled Nightly | 8m43s / 10m24s | Different event obligations; dispatch does not supply scheduled recovery |
| Historical successful readiness producer | 254m38s | Native collection dominates; current completed acceptance is analyzed separately below |

## Newly recovered native gate timings

[The retained historical breakdown](retained-native-timings.md) now identifies the long pole without a new run. Hash checks against the retained producer sidecar, manifest and all24 receipts passed. Async isolation took **190.77 minutes**, **75.9% of collection** and **82.4% of local gate intervals**. Twin recovery and contributor bootstrap each took about10–12 minutes. Gate intervals are nested within the parent job and must not be added to it. This is a different historical source, not current-run or before/after proof.

This strengthens the case for per-seed progress/timing before a larger isolated-sharding design, and further deprioritizes outer setup caching. The exact25 fresh full-coverage processes remain required. Parallelization could reduce wall time but needs independently isolated DB/ports/services/output, complete fixed-matrix aggregation and measured failure-adjusted runner cost; it is not the present small scheduling change.

## One coherent recommendation per decision

| Priority | Decision | Value and decisive tradeoff | Acceptance / reason to stop |
|---|---|---|---|
| **1 — prepare now; publish after owned acceptance** | Start the full main consumer matrix after Optional Dependencies, without waiting for Quality. Keep Quality in CI Summary and whole-run release authority. | Smallest clear scheduling-only change; modeled 4m54s–8m46s less wall latency. No green-run compute reduction; failing Quality can consume more matrix work. | Unchanged five profiles/commands/preflight/hygiene/dry-runs; late Quality failure/cancellation and every profile failure remain red. Recompute semantic guard deliberately. Later hosted evidence must show real overlap and complete run success. Stop if queue/cache contention erases value. |
| **2 — prove equivalence before deleting work** | Retain the complete default release preflight and investigate removing only the later duplicate image consumer invocation. | Direct image step costs 230–317s in the samples. The preflight's dev-built unpacked package and the later test-built package are different inputs until shown equivalent. This is a gross opportunity, not established saving. | Compare package payload/metadata, selected scenarios, MinIO/host-migration behavior and cold generated-consumer boundaries. Packed-byte or scenario differences stop deletion. Inject metadata/docs/image and all other profile failures; all must propagate. |
| **3 — instrument the long path using a small local protocol** | Add bounded gate/seed progress and duration observation, leaving authority receipts unchanged. | Makes multi-hour failures diagnosable and identifies the next real bottleneck. Existing `QUALIFY` output is captured by Closure; flushing alone does not fix visibility. This is diagnosis, not a speed claim. | Fixed IDs/seeds/state/durations only; secret canaries, forged workflow commands, unknown/oversized/partial records stay private. Preserve deadlines, signal disposal and exactly 25 fresh coverage processes. Observation failure grants no proof. |
| **4 — align advisory reporting with every authority** | Treat a failed timing API read as unavailable observation inside the existing observer job; keep semantic failures strict. | Avoids redoing green semantic work because an advisory API request failed. Job-level `continue-on-error` alone is insufficient: readiness checks each applicable job conclusion. | Tolerate only the observer step, retain its raw outcome, always render an unavailable result, and verify actual hosted job success plus topology acceptance. A semantic failure must still fail Summary/full CI/release/readiness. Missing data is unknown, never zero. |
| **5 — profile existing duplicate fixtures, then consolidate only equivalent ownership** | Two Nightly shell harnesses are invoked in both Proof and CI Script Tests. Preserve one authoritative invocation if environments are equivalent. | Possible runner-time reduction, presently unmeasured. The combined parallel step is not the exclusive cost of either duplicate. The CI Script group already approached its 240s budget. | Preserve case/outcome inventory, unique Proof harnesses and failure propagation. Use existing group timing JSON first; keep timeout/disposal tests and the same bound. Stop if environments intentionally provide different signal. |
| **Defer** | Outer bootstrap trimming, npm consolidation, more caches/images/runners, seed parallelization, retention changes. | Outer prerequisites cost only about 2½ minutes total. New cache/image infrastructure has setup, trust and maintenance costs. Parallel seeds need independently isolated DBs/ports/runtime/output and complete aggregation. Storage benefit is unknown without an inventory/billing context. | Reopen only for material measured cost, explicit proof-policy decisions or a concrete incident. Preserve native cold qualification, fresh/restored PLTs, all 25 seeds, signed/current inventories and replay/retention authority. |

These gains are **not additive**. After any change, recompute the complete DAG: browser/E2E or another profile can become the critical path. Deleting test coverage, widening deadlines, accepting partial jobs or reusing old authority receipts is not an efficiency improvement.

## One bounded follow-up was tested and rejected

The [Census scheduler pilot](census-pilot.md) ran the same23 existing cases four times in ABBA order: baseline92.030s, cap90.884s, cap75.378s, baseline88.551s. All cases passed; the real child scope probe confirmed1/1/1 scheduler pools while the parent stayed4/4/10. The apparent mean difference was inconsistent and had order/contention uncertainty, so no reliable saving is established. The helper was restored byte-for-byte to HEAD, and the local implementation worktree is clean. No fifth module run, full coverage, seed-matrix run or hosted benchmark was launched. This closes that branch of investigation; reopen only for new material evidence.

## Cost, security and contributor experience

The inspected repository is public and uses standard Ubuntu hosted runners. Their compute is currently free under [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions). Therefore report runner-minutes as resource use, not dollars saved. Larger runners and storage have separate treatment; no account-level billing or artifact byte-hour inventory was collected. Self-hosting shifts infrastructure/security work elsewhere and is not justified by this sample.

Keep exact toolchain/ABI/environment/native-mode cache boundaries and normal restore validation. Cache hits do not certify correctness; base caches are readable in fork contexts. See [official cache semantics](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching). Keep fail-closed archive/sidecar checks: GitHub's generic [artifact digest validation](https://docs.github.com/en/actions/tutorials/store-and-share-data#validating-artifacts) warns on mismatch rather than providing this repository's acceptance contract.

Keep owned producer nonces/run/attempts and the Nightly event/checkpoint replay. Current [concurrency documentation](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency) supports larger queues, but queue capacity does not establish execution ownership or scheduled recovery. Blanket cancellation, privileged cache writers and a new queue service would introduce larger risks than the measured problem.

No new dependency is needed for the chosen scheduling change or the learning loop. Prefer a short, understood local implementation over another package unless a concrete benefit pays for its maintenance and transitive surface.

## Ongoing learning without another platform

During a long CI wait, read already-completed run/job/step evidence and look for the next material decision. At a CI-affecting change or incident closeout, retain one bounded record under the existing dated research convention:

- Exact source/workflow identity, event/run/attempt, outcome and command inventory.
- Wall, dependency/queue and summed runner durations; include failing/canceled work when evaluating policy.
- Known toolchain, runner/cache/native-mode context; unknown values stay unknown.
- Before/after evidence or an explicitly labeled model, one decision, adverse test and stop condition.
- Storage size/expiry/purpose only when assessing retention or billing.

Reuse existing Python/jq, timing outputs, job APIs and validators. Use naturally occurring completed runs instead of launching extra qualification or the deferred side-effecting exact-ten sampler. Record only new lessons; repeated observations need a new fact that changes a decision. A compact agent instruction is prepared in the isolated draft so this becomes an ongoing practice, rather than another dashboard, SDK or dependency.

## Implementation and acceptance sequencing

Root prepared local branch `perf/main-package-matrix-overlap-261029` at `/Users/jon/projects/rindle/.claude/worktrees/ci-main-matrix-overlap-20261029`, based on actual main `b2a60c51`. The scheduling-only draft and concise ongoing-learning/dependency instructions are now saved as local commits `93ca114f` and `aeb8cf64`. Worker checks passed55 focused tests,69 readiness tests,64 collector fixtures and6 CI Summary cases; root reran55 focused tests and automation-first successfully. Independent review found no concrete issue, verified the sole workflow semantic delta and recomputed pin, and checked all frozen controller hashes. Actionlint has the same six baseline findings, with zero new. This is verified local preparation, not hosted delivery or a measured speedup.

The current normal acceptance remains owned by producer `40864930767/1` and local session `43982`, with durable output `~/Library/Application Support/Rindle/readiness/accept-v3-48407bac-renewed-20261029`. A new remote PR would alter the live inbox inventory, and CI control changes can invalidate snapshot compatibility. Keep the draft local until this owner has an actual terminal result and any successful historical acceptance has been independently verified. Preserve PR185/188 holds and PR189 draft/unmerged/no-auto posture.

READY-01–05 remain open. Research, local fixture success, a modeled speedup and credential replacement grant no acceptance credit. The named independent Phoenix pilot, 1.0, publication and deferred numeric-speed claim remain outside this work.

## Completed current acceptance and delivery update

Actual normal controller40864930767/1 exited0 and retained execution-mode historical ready for48407bac7691c459395760b06f7714bbb6c3545b, interval2026-10-29T11:22:36.801043Z–2026-10-29T15:56:53.252718Z; its original-source claim-status passed historical_ready/current_readiness=false. Earlier running/open notes above are preserved research chronology, superseded by this verified result. No repeat qualification was launched for research.

[Independent current timing](current-acceptance-timings.md) verifies8 terminal references and158 graph objects. The normal controller took274m16s, including candidate collection255m52s. Async isolation took191m53s,82.3% of native command intervals;25 seeds passed. Host refresh took14m05s; four serial complete collectors account for13m32s. This confirms the long pole without turning a different-source comparison into a speedup claim. API acquisition is a secondary concrete opportunity: future experiments should reduce redundant authenticated reads while retaining two complete observations, identity checks, freshness and all negative tests. It is deferred behind the bounded progress protocol; API concurrency is not justified by latency alone or without rate-limit/failure accounting.

Protected CI maintenance PR[219](https://github.com/szTheory/rindle/pull/219) now contains the scheduling improvement, ongoing learning/dependency guidance and already-approved removal of the temporary annual recovery cron. The ordinary daily Nightly remains. Hosted PR/main verification is pending; modeled5–9minute latency reduction and no successful-run compute reduction remain the correct claims until observed. No billing saving or CI-16 completion is claimed.

## Initial hosted CI failure and focused repair

PR219 CI40919944407 completed with both Quality jobs failing only two residue tests: the new AGENTS research-path instruction was not in the exact policy allowlist. No matrix/gate bypass was used. One existing-shard entry now permits that exact legitimate policy line with count1; all31 residue-scanner tests, including planted negatives and byte-idempotent regeneration, passed in29.1s using the supported Mix harness. An initial direct-Elixir invocation lacked Mix.State and failed its harness setup; it is preserved and superseded by the real Mix test run. No new production regression or cache/runner speedup follows from this failure. The final combined head must pass the complete ordinary CI again.

The historical phase verifier passed15/15 must-haves. Independent code review found two preexisting Doctor schema-drift warnings, explicitly tracked in the phase review disposition and pending todo; it identified no evidenced phase regression. Final archival metadata is combined with the CI maintenance PR to avoid an additional full main CI cycle while retaining complete PR and main gates.
