## Summary

The configured coverage gate allowed69percent while accepted coverage was82.1343percent, and maintainer evidence could become detached from its source. This change enforces monotone Credo metrics with removal proof, an exact-count coverage receipt and conservative82.2percent local gate, narrow Dialyzer policy, immutable source/runtime-bound collectors, and clean contributor bootstrap with bounded commands. CI consumers verify pinned FFmpeg, MinIO client and Playwright inputs before use; job timeouts and the sole CI Summary/release authority have behavioral mutation tests.

The measured source is `4dc73fa91c60ae870c7289a151d9d53460140906`. Earlier first-red attempts remain recorded; later planning evidence commits are local tails over that frozen source.

## Linked Issue

Phase136 — Measured Quality and CI Ratchets.

## Validation

- Supported host: Elixir1.17.3 / OTP27.3.4.15 / Node20.18.1.
- Canonical local+JSON run:1695tests and3doctests,zero failures; exact5206/6329=82.2563percent.
- Focused owner/consumer/whole-tree guard regression:60tests,zero failures; prior-phase regression:226tests,zero failures.
- Fresh/restored Dialyzer:54.847/2.973seconds, both green and receipt-verified.
- Clean full bootstrap:388.54seconds; all six documented commands green, including mix ci in333.031seconds.
- Fixed25seed async experiment is in progress. Live timing still requires exactly ten authenticated current-head PR runs, median<=480seconds andp95<=600seconds. These pending measurements have no qualification credit.

## Checklist

- [x] `mix ci` is green locally or in CI.
- [x] Docs are updated when behavior, setup, or contributor workflow changes.
- [x] Docs-only changes do not alter `lib/` behavior.
- [x] Security reports are routed through GitHub advisories, not public issues.
