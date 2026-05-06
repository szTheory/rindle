# Phase 28 Plan 01 Summary

## Outcome

Locked the public AV onboarding path into the shipped docs surface:

- `README.md` now stays narrow while teaching the AV quickstart order:
  `mix deps.get`, install `FFmpeg >= 6.0`, define the stock video/profile
  variants, run `mix rindle.doctor`, then follow the facade-first upload flow.
- `guides/getting_started.md` is now the canonical deep AV guide and points
  back to `test/adopter/canonical_app/lifecycle_test.exs` as the executable
  source of truth.
- `RUNNING.md` was added as the single public FFmpeg install/runtime matrix for
  macOS/Homebrew, Ubuntu/Debian, Alpine, Fly.io, Heroku, Render, and GitHub
  Actions via `FedericoCarboni/setup-ffmpeg`.

## Parity Guards

- `test/install_smoke/docs_parity_test.exs` now asserts the locked AV
  onboarding path, `mix rindle.doctor`, the stock `web_720p` / `poster`
  surface, the `kind: :video` declaration, and the runtime-matrix link.
- `test/install_smoke/release_docs_parity_test.exs` now asserts the public docs
  cross-link `RUNNING.md` without importing maintainer-only release guidance.

## Verification

Passed:

```bash
mix test test/install_smoke/docs_parity_test.exs test/install_smoke/release_docs_parity_test.exs
```

Result: `25 tests, 0 failures`

## Deviations

None beyond the plan-authorized addition of `RUNNING.md` as the linked install
surface.
