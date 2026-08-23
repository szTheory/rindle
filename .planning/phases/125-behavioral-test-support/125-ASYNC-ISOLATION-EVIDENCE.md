# Phase 125 Async-Isolation Evidence

head_sha: eb7da78e1dd9d1e2ce3e3089e3c82bc2d1307cbe
toolchain: elixir-1.19.5 / OTP 28
command_template: mix coveralls.multiple --type local --type json --seed SEED --slowest 20
planned_runs: 25
ordered_seeds: 0,17,43,71,101,131,173,211,257,307,353,401,449,503,557,601,653,701,757,809,863,911,967,1013,1061
completed_runs: 1
status: local_failure
first_failure_seed: 0
first_failure_exit: 2
first_failure_location: credo_policy_test.exs:78

The single authorized matrix attempt stopped at its first failing process, as designed. The failure
was the Phase 121 Credo inventory gate observing a new complexity identity in the refactored test
facade; it was not an async-isolation failure. Commit `88cd6e7` subsequently reduced that helper below
the blocking threshold, and the focused Credo policy and 100-iteration causal isolation tests pass.

The 25-seed matrix was not restarted or retried. Because only 1/25 planned runs completed, this receipt
cannot authorize closing issue #42 even if the final supported CI run passes. The issue must remain open
with this concrete incomplete-evidence disposition.

The companion JSONL file is the runner-emitted, sanitized source record for this receipt. It contains
no environment values, credentials, temporary configuration, database identifiers, or raw command
output.
