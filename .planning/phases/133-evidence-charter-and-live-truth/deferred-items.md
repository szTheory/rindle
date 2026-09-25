# Deferred Items

## Plan 133-47

- `mix ci` stops at `mix format --check-formatted` because untouched `test/install_smoke/nightly_policy_test.exs:206` differs from the formatter output. The file was outside Plan 47's changes; the required focused suites, default suite, Credo quality gate, and refactor contract passed. Re-run `mix ci` after that pre-existing formatter drift is resolved.
