# Independent adversarial review — main matrix overlap prototype

No concrete severity findings. The prototype is consistent with the narrow scheduling experiment and preserves the existing proof inventory and release authority. This is a local review result, not hosted acceptance, a measured speedup, merge authorization or Phase139 credit.

Reviewed checkout: `/Users/jon/projects/rindle/.claude/worktrees/ci-main-matrix-overlap-20261029`, working diff against `b2a60c51687293df5498920cc2bddb4e25349251`. Reviewed at 2026-10-29T12:02:40.499719+00:00. Five tracked changed files: `.github/workflows/ci.yml`, `scripts/maintainer/validate_exact_head_readiness.exs`, `test/install_smoke/ci_lane_split_test.exs`, `RUNNING.md`, `AGENTS.md`. Diff SHA256: `a5b2cf78ac9329aade260f7a3e58a20183d1570df514ac8439d3aba20e6eeaf0`.

## Gate checks

| Gate | Result and evidence |
|---|---|
| Sole workflow behavior change | Independently parsed baseline/current YAML and normalized only `jobs.package-consumer-full.needs` from `[quality, optional-dependencies]` to `[optional-dependencies]`; entire parsed documents then compared equal. Profile order, steps/commands, event conditions, job budgets, permissions, fail-fast behavior and no-error-masking policy are unchanged. YAML comments add explanation only. |
| Optional prerequisite and five proofs | Full matrix still waits for Optional Dependencies, remains off PRs, keeps `fail-fast: false` and exactly `[video, image, tus, mux, gcs]`. It owns setup/checkout and has no Quality output/artifact handoff. Common preflight remains image-only; every profile's consumer/hygiene/version/Hex dry-run stays intact. No duplicate-image optimization is included. |
| Quality and aggregate failure/cancel | `ci-summary` retains Quality in its unchanged needs graph and `if: always()`. The unchanged shipped evaluator rejects failure/cancelled outcomes. Earlier green full profiles do not change those results. Full matrix remains intentionally outside PR Summary; a green early Summary alone still cannot authorize release. |
| Whole-run release authority | `.github/workflows/release.yml` is byte-identical to baseline. The actual JS queries `ci.yml` by exact source SHA, waits for completed state and rejects every non-success conclusion. Publish still requires successful `gate-ci-green`. Failed/cancelled Quality, preflight or any full profile therefore cannot become successful release evidence. The new helper executes this extracted JS with only the GitHub response replaced; it does not reimplement the decision. |
| Semantic pin | Executed actual `Rindle.ReadinessWorkflow.guard_identity` under explicit Elixir1.17.3/OTP27.3.4.15 with existing parser beams. Output: `PASS: actual workflow guard projection equals updated semantic pin 75bedd220f51673361e824a61cfb98468bbf5490e94a68606193ed61da2c5187`. Validator diff changes only this expected digest. |
| Tests exercise meaningful boundaries | New topology test enforces Optional-only matrix start, Quality aggregation and maintained documentation. New behavior test runs the extracted preflight/consumer strings through owned shell stand-ins, then actual aggregate shell and actual release JS for success/failure/cancelled. Existing tests inject preflight failure and each profile failure. They check orchestration and failure propagation, while real package/native behavior remains in the retained full jobs. |
| Claims and tradeoffs | Added RUNNING text says this establishes no measured improvement and can spend more runner work on failed Quality. No numeric speed, p95, billing savings, requirement closure or proof deletion is claimed. AGENTS additions preserve active evidence, separate wall/runtime/billing and stop analysis at diminishing returns; product scope is unchanged. |
| Frozen inputs and producer | Recomputed frozen source SHA and every source-file hash retained in `timing-source.json`: unchanged. Prototype producer workflow and aggregate evaluator are byte-identical to baseline. Active producer40864930767/1 was neither read nor modified during this review. |
| Whitespace | `git diff --check` exited0. |

Independent deterministic verification also printed:

```
PASS: sole parsed workflow delta is full-matrix Quality prerequisite removal; five profiles and all other workflow bytes/commands semantically unchanged
PASS: release, aggregate evaluator and producer workflow byte-identical to baseline; frozen source evidence hashes unchanged
```

## Limits and sequencing

The new failure tests supply completed remote outcomes; they do not emulate GitHub's scheduler, waiting queues, cache races, pending/no-run retries or actual publication. Existing release authority is unchanged, so lack of a new broad simulator is not a defect in this scheduling-only diff. No full suite or remote run was repeated by this reviewer; the implementation owner retains responsibility for its broader validation record.

The runtime default shim initially could not select the checkout's unavailable OTP27.2; the bounded guard check explicitly used the installed supported OTP27.3.4.15 and Elixir1.17.3. This did not alter `.tool-versions` or install anything.

Moving full profiles earlier may duplicate cold compilation, increase contention or waste completed profile work on later red Quality. No hosted benefit is yet measured, and successful summed runner work is not reduced by changing ordering alone. The timing report's fixed-duration model remains an estimate. A later ordinary exact-source main run should supply actual whole-run timing and all five real profile outcomes.

The validator pin is a snapshot control. Keep this independent prototype out of the active producer's frozen source and preserve the accepted subject's verifier when later inspecting historical evidence. Reassess source/control eligibility before any merge; this report itself grants no sequencing exception or producer rerun.

No code, configuration, workflow, active planning status, frozen source or remote state was edited by this reviewer. Only this requested review document was written.
