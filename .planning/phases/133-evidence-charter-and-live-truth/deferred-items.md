# Deferred Items

## Plan 133-47

- `mix ci` stops at `mix format --check-formatted` because untouched `test/install_smoke/nightly_policy_test.exs:206` differs from the formatter output. The file was outside Plan 47's changes; the required focused suites, default suite, Credo quality gate, and refactor contract passed. Re-run `mix ci` after that pre-existing formatter drift is resolved.
- The post-commit Elixir 1.15 compatibility tracer output included two invalid Doctor threshold tests caused by Doctor failing to load `Inspect.Rindle.Domain.MediaProviderAsset`. This is outside Plan 47's changed files. The current Elixir 1.17 default suite completed with zero failures and zero invalid tests.
