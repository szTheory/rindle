# Bounded test hotspot review — 2026-10-29

No measured safe speedup is established from this diagnostic. One small test-only experiment is justified: limit scheduler pools in the pure evidence-census child VMs while preserving their actual fresh Mix/Elixir subprocesses. Repeated real package authority, behavior-test execution, timeout and regeneration proof should remain intact. Do not change the parent coverage scheduler settings, the 25 fresh coverage invocations, their seeds, tests, assertions, budgets or coverage gates.

This review read frozen source `48407bac7691c459395760b06f7714bbb6c3545b` and the existing local repair-head seed173 diagnostic only. No suite was rerun, source/cache changed or active acceptance touched. The local diagnostic has different subject/environment from retained producer `40609107572/1` and is not current-source or hosted acceptance evidence. Only sanitized test identifiers, locations and durations were extracted into `hotspot-evidence.json`; no raw test/API/secret payload was retained.

Before examining historical coverage output, I verified the retained manifest against `687495cf43220e872e5c7ec122583e7eab17cab72874b474e110b28723f9b232`, then verified its coverage receipt reference and that receipt's output reference. That ordinary coverage command has no `--slowest` argument or slowest section. Thus it supplies no independent hosted test ranking. The parent's verified retained-native measurement establishes that async-isolation occupied 190.766 minutes, 75.87% of collection and 82.40% of local-gate intervals; it does not establish which individual tests dominate each of its 25 seeds.

The local seed173 run reports 435 seconds and 20 slowest tests totaling 186.299 seconds (42.8%). Those 20 entries span:

| Module | Listed tests' summed durations | Interpretation |
|---|---:|---|
| CredoPolicyTest |69.779s|Real aggregate scans, normalizer subprocesses and deliberately executed behavior tests |
| EvidenceCensusTest |51.705s|Many repeated collector/validator subprocesses over isolated Git fixtures |
| LiveTruthParityTest |36.982s|Canonical package authority rebuilds and real executable fake-package fixtures |
| CoverageFloorPolicyTest |13.956s|Fresh Elixir entrypoint → Python receipt validation calls over mutation fixtures |
| CiTimingAutomationTest |7.423s|Real deadline/terminal-state negative cases |
| LiveResidueScanTest |6.455s|Two actual regeneration runs and byte-idempotence comparison |

These are partial per-module totals, not whole-module timings or additive wall-time savings. The diagnostic reports 146.6 seconds async and 288.4 seconds sync. The 186.299/435 comparison is descriptive only: individual async test intervals can overlap, so 42.8% is not exclusive wall-time attribution. Census is already async; its listed case durations can overlap. No causal startup/fixture/scanner breakdown is present. The slowest individual Credo case is 25.335 seconds, followed by baseline mutation 17.123 seconds and package-forgery rejection 12.552 seconds. None identifies a slow media algorithm or database query worth rewriting.

**Rank 1 — a pure-child scheduler cap, as a measured test-only prototype.**

`test/install_smoke/evidence_census_test.exs:run_script/2` launches actual `mix run --no-compile --no-start` for every collector/validator request, explicitly retaining test MIX_ENV and dependency/build paths. It does not limit scheduler pools. The module already isolates roots and declares `async:true`; broad async conversion cannot improve that. The collector and validator use JSON/filesystem/Git policies and must keep those real boundaries.

Smallest candidate: add explicit `ERL_FLAGS=+S 1:1 +SDcpu 1:1 +SDio 1` only to this test helper's child environment. Keep the command, each fresh VM, Mix environment/dependencies, argument list, filesystem/Git calls, actual CLI exit/output, fixtures and all assertions unchanged. The existing `prepare_readiness_fixture_runtime.sh` demonstrates this repo-local scheduler-cap idiom for parser-only fixtures; do not reuse its fake Mix-command adapter here. This is a runtime setting experiment, not a claim that one scheduler must be faster. A JSON validator can still lose CPU throughput with fewer schedulers.

Why prefer it: one helper edit, no new dependency/framework, no cached verdict, no shared VM state and no production change. It cannot remove the exact25 fresh top-level coverage processes. Limit the first prototype to Census; do not globally export these flags into real behavior tests, package consumers, media, DB or the parent coverage process.

Falsifier/acceptance: on one immutable prototype subject, fresh uncapped/capped subprocesses must give identical exit codes and public diagnostic strings for every existing positive, dirty, malformed, symlink/path and copied-receipt case. Keep the nested-Mix dependency inheritance case. Capture child scheduler values separately to prove the override is scoped; parent flags must remain unchanged. Compare elapsed time for these same cases under sequential and existing async execution; stop if gain is absent or queue/CPU effects offset it. A later complete unchanged seed matrix remains required for acceptance. Current evidence supplies neither net seconds saved nor a justification to merge without that proof.

CoverageFloorPolicyTest's `invoke/3` likewise launches a fresh Elixir wrapper which invokes the actual Python checker. It may be a second small child-cap experiment if Census demonstrates benefit, keeping supported/unsupported runtime-probe cases and both CLI modes. Do not replace it with direct Python calls merely to avoid testing the contributor-facing Elixir boundary.

**Rank 2 — immutable fixture construction reuse, only if separately measured material.**

Census `registry_fixture!/1` repeatedly writes the same small detector-source tree and performs real Git init/config/add/commit before creating its per-case ledger and receipt. An immutable once-per-module template, fully copied into each independently owned root, could reduce repeated construction without changing actual Git/file validation in collector and validator. Keep .git and source directories independent; no symlinks/shared mutable indexes/worktrees, receipt sharing or shared ledger state. Retain all actual repository probes and the wrong-SHA/dirty/path mutations.

Defer this now. The diagnostic does not isolate template construction; previous broader research found pure fixture construction too small to justify machinery. A template can introduce cleanup and state-leak work larger than its gain. Required falsifiers would include A→mutated B→A byte/HEAD/dirty-state independence, altered template refusal and async root isolation, plus time spent specifically in fixture construction. This is not grounds for adding a general fixture framework.

**Do not remove the expensive boundaries merely because they appear in the slow list.**

- Credo's `assert_fails_with_baseline/1` runs real aggregate profiles; `fixture_aggregate/3` already stubs only Credo issue production for pure policy cases, then delegates actual normalizers and `mix test` behavior proof. The slowest reduction case deliberately executes good, stale, mismatched, recursive, failed, skipped and excluded behavior cases. Replaying current-source results or replacing them with in-memory verdicts would alter the contract. Its test writes a repo-owned fixture and is `async:false`; broad async conversion is unsafe. A normalizer-only cap is a later possibility, but compare-mode launches real nested behavior tests; scoped restoration of their original flags would need explicit lifecycle tests. It is not the first one-line experiment.
- LiveTruth's `verify_package_evidence!/2` deliberately rebuilds the source-bound real package before rejecting caller-supplied fake package digests. Executable fake fixtures compile/boot/run their own smoke to prove that runnable fake evidence still cannot replace the committed package. Caching the trusted rebuild or replacing those cases with trivial invalid input would undermine authority. One receipt-argument test may overconstruct its fixture, but equivalence of its path/purpose is not proven by the timing list; no deletion is recommended.
- Coverage floor mutation cases exercise the public Elixir shim, Python verifier, exact boundary ratios, immutable write refusal and actual probe environment. Keep the million-line ratio cases; their large input is intentional numeric-boundary proof, not evidence of waste.
- Timing rate-limit cases intentionally wait for owned deadlines and assert terminal cleanup/state preservation. No fake clock seam or timeout reduction is authorized by this sample.
- Residue regeneration runs twice to catch byte/order/idempotence drift; the earlier PR189 ordering failure demonstrated why this is valuable. Preserve both runs and exact committed-byte comparison.

Stop here. The next material result is whether a one-helper pure-child cap improves measured Census time without changing verdicts or process/native boundaries. No suite rerun was needed for this research, and no safe aggregate savings estimate can be inferred by multiplying these 20 local durations by 25.
