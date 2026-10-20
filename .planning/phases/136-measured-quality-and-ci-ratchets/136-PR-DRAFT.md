## Summary

The configured coverage gate allowed 69% while accepted coverage was 82.1343%, and maintainer evidence could become detached from its source. This change enforces monotone Credo metrics with removal proof, an exact-count coverage receipt and conservative 82.2% local gate, narrow Dialyzer policy, immutable source/runtime-bound collectors, and clean contributor bootstrap with bounded commands. CI consumers verify pinned FFmpeg, MinIO client and Playwright inputs before use; job timeouts and the sole CI Summary/release authority have behavioral mutation tests.

The measured source is `4dc73fa91c60ae870c7289a151d9d53460140906`.

## Linked Issue

Phase 136 — Measured Quality and CI Ratchets.

## Validation

- Supported host: Elixir 1.17.3 / OTP 27.3.4.15 / Node 20.18.1.
- Canonical local+JSON run: 1,695 tests and 3 doctests, zero failures; exact 5,206 / 6,329 = 82.2563%.
- Focused owner/consumer/whole-tree guard regression: 60 tests, zero failures; prior-phase regression: 226 tests, zero failures.
- Fresh/restored Dialyzer: 54.847 / 2.973 seconds, both green and receipt-verified.
- Clean full bootstrap: 388.54 seconds; all six documented commands green, including mix ci in 333.031 seconds.
- Fixed 25-seed async experiment is in progress. Live timing still requires exactly ten authenticated current-head PR runs, median ≤ 480 seconds and p95 ≤ 600 seconds. These pending measurements have no qualification credit.

## Checklist

- [x] `mix ci` is green locally or in CI.
- [x] Docs are updated when behavior, setup, or contributor workflow changes.
- [x] Docs-only changes do not alter `lib/` behavior.
- [x] Security reports are routed through GitHub advisories, not public issues.
