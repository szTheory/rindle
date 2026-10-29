# Census child-scheduler pilot — 2026-10-29

Restore the original helper. All four runs passed, and the child-only scheduler override worked, but this small local sample did not establish a consistent worthwhile benefit. No implementation change remains. Do not infer hosted, coverage-loop, CI-16 or READY credit from this experiment.

The source was local branch `perf/main-package-matrix-overlap-261029`, committed HEAD `aeb8cf646f920b15c369e703e1a45ac3b30aaf87`, with the scheduling prototype already committed. The only temporary implementation change added `{"ERL_FLAGS", "+S 1:1 +SDcpu 1:1 +SDio 1"}` to `test/install_smoke/evidence_census_test.exs:run_script/2`'s child `System.cmd` environment. Every fresh real Mix command/argument, Mix dependency/build environment, filesystem/Git probe, test case, assertion and timeout was retained. No fixture cache, shared VM, production/workflow/control change or dependency was introduced. Frozen source11 and its caches were not used or modified.

The full module ran exactly four times, sequentially in ABBA order, on Elixir 1.17.3 / OTP 27.3.4.15, local Darwin arm64. Each parent had `ERL_FLAGS='+S 4:4'`, MIX_ENV=test, seed 173 and max_cases 8. The same sanitizing ExUnit formatter recorded only test identifier, source line, pass/fail and duration. The application/database test helper was not started; this is the complete Census module with its real collector/validator subprocesses, not a default-suite or coverage run.

| Order | Variant | Elapsed seconds | Existing cases |
|---|---|---:|---|
|1|A1, original child environment|92.030|23 passed |
|2|B1, child scheduler cap|90.884|23 passed |
|3|B2, child scheduler cap|75.378|23 passed |
|4|A2, original child environment|88.551|23 passed |

All 23 test identifiers and terminal results matched. Existing assertions covering positive, malformed, dirty, foreign-source, symlink/path, copied-receipt and nested-Mix dependency behavior remained and passed on every run. This is parity of those actual exit/diagnostic assertions, not a claim that all unasserted volatile output bytes were equal. No raw subprocess output or private/API body was retained.

The descriptive mean is 90.290 seconds for A versus 83.131 seconds for B, a 7.159 second/7.93% difference. That is not a causal saving estimate. B1 is slower than final A2, and the two capped observations differ by 15.506 seconds. OS/cache/host-order effects are unknown; the brief baseline scope probe also ran during A1 and could add contention. The apparent mean benefit depends heavily on B2. There are only two observations per variant, with no coverage instrumentation or shared-suite contention. This is insufficient to project a saving across 25 fresh coverage processes or to justify carrying an uncertain optimization.

**Actual runtime-scope check.** `census-scope-probe.exs` parses the test source and compiles the exact `run_script/2` AST body as a disposable public probe; it does not copy a replacement environment implementation. That helper launches a fresh real Mix child executing a tiny owned Elixir script that reports scheduler values. Baseline child: normal 4, dirtyCPU 4, dirtyIO 10. Temporarily capped child: normal 1, dirtyCPU 1, dirtyIO 1. Parent before and after both remain normal 4/dirtyCPU 4/dirtyIO 10 with the identical `+S 4:4` flag. This verifies actual scoped execution rather than matching a configuration string. The temporary cap was restored immediately after the probe, with no source hunk left.

The full-run command, from the isolated prototype worktree, was:

```sh
ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 \
ASDF_NODEJS_VERSION=20.18.1 MIX_ENV=test ERL_FLAGS='+S 4:4' \
CENSUS_PILOT_RECORD=<canonical-research>/census-<A1|B1|B2|A2>-cases.json \
mix run --no-start --no-compile --no-deps-check \
  <canonical-research>/census-runner.exs
```

The two short scope probes used the same runtime flags and Mix invocation with `census-scope-probe.exs` instead of the runner. Full runtime/source/command records are in `census-summary.json`, `census-{A1,B1,B2,A2}.json` and their matching `-cases.json` files. `census-scope-before.json` and `census-scope-after.json` retain actual scheduler results. The formatter/runner and exact baseline source are retained alongside them. The baseline/restored source SHA256 is `7dea3984b8f524e09c02ca94ba375b35fd98c72d47f937a601a8715a11d6f00b`; capped source was `db5ef9c0b63a4649fe98cd091efa72c61d3efd424166776a84e9d75f21a151f3`.

Stop this pilot here. No fifth full module run, default coverage suite or 25-seed loop ran. The original Census helper now byte-matches committed HEAD, and no permanent scope regression is needed for a change that was rejected. Revisit only if naturally collected hosted evidence makes this exact startup cost materially clearer.
