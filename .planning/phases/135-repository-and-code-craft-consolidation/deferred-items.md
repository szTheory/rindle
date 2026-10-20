# Phase 135 deferred items

Out-of-scope discoveries logged by executors. Not fixed in the plan that found them.

## From 135-13

- **`ci.yml` docs-truth guard: negated greps do not fail the step.** In the Quality
  job step `TRUTH-01 docs-truth guard (PROJECT.md invariant 13)`, the two
  `! grep -q ...` lines run under `set -euo pipefail`. Bash does not apply errexit to a
  `!`-negated pipeline, so a regression that reintroduces `FFmpex + MuonTrap` or
  `Rambo on macOS` would print nothing and the step would still pass. Only the positive
  `grep -q` line actually gates. actionlint/shellcheck flags both lines as SC2251. The
  same finding is present on origin/main 30a59ef5. A follow-up fix would be
  `if grep -q ...; then exit 1; fi`, which is a non-comment workflow change. That is
  outside the comment-only 135-13 tranche, and a fix there would need a `fix:`-free
  subject plus a check that `quality_signal_policy_test` or `live_truth_parity_test`
  is not pinned to the exact `!` lines.
- **`ci.yml` run-summary heading keeps a decision id.** `echo "## CI per-step timing
  (D-04 long-pole jobs)"` in the CI Observability job is printed text. No consumer
  reads it, but it is executable workflow text, so the comment-only tranche kept it
  and classed it `contract`. Rewording it, for example to `(long-pole jobs)`, is a
  one-line follow-up that also removes its allowlist entry.
