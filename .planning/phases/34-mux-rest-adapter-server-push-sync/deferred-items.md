# Deferred Items — Phase 34

## Pre-existing AV runtime-guard test flakiness (out of scope)

When running the full test suite (`mix test`), 4 tests fail with seemingly
unrelated AV/runtime errors:

- `test/rindle/probe/av_probe_test.exs:58` — ffprobe stderr capture flake
- `test/rindle/av/ffprobe_test.exs:13` — ffprobe failure-handling flake
- `test/rindle/processor/waveform_test.exs:14` — waveform JSON contract flake
- `test/rindle/application_test.exs:41,58` — AV runtime guard test pollution
  from `Rindle.Adopter.CanonicalApp.VideoProfile` leaking between modules

These are NOT caused by Phase 34 changes:

- Each of the four tests passes in isolation (`mix test path:line`).
- The mux test suite (`mix test test/rindle/streaming/provider/mux/`) is fully
  green (21/21).
- The streaming + domain test suites (`mix test test/rindle/streaming/
  test/rindle/domain/`) are fully green (148/148).
- The application_test failures show `affected_profiles:
  ["Elixir.Rindle.Adopter.CanonicalApp.VideoProfile", ...]` — a profile
  outside the test module that bleeds in via shared application
  configuration set during the integration/adopter test scaffolding.

This is a pre-existing test-isolation issue in the AV runtime guard layer
(Phase 23/Phase 28 territory). It manifests only when `mix test` runs with the
full module set in a non-deterministic order. Out of scope for Phase 34.

**Suggested follow-up:** open a separate stabilization plan that audits
`Rindle.Application.run_startup_checks/0` test setup to ensure
`Application.put_env`-style profile registration is reset between modules.
