---
phase: 133-evidence-charter-and-live-truth
plan: "43"
subsystem: live-truth-package-authority
requirements: [TRUTH-08]
status: complete
commits: []
---

# Plan 133-43: Rebuild Package Authority from the Authenticated Subject

## Completed

- Package proof is rebuilt from the authenticated subject and checked against the independently derived release version.
- The verifier resolves its own Mix, Elixir, Erlang, and Git executables and supplies a restricted environment to package commands.
- Generated secret and signing salt values are canonicalized for stable generated-app tree comparisons.
- Forged command results fail in execution order; a trivial caller-supplied package is rejected. The generated package consumer positive case exercises the rebuilt Rindle archive.

## Verification

- `mix test test/install_smoke/live_truth_parity_test.exs --only package_authority --include minio --seed 0` — 34 tests, 0 failures, 14 excluded.

## Notes

- The package-authority selection took 560.3 seconds because the verifier builds and runs a generated Phoenix consumer. The local MinIO test service was used.
