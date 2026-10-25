---
quick_id: 261025-grp
status: complete
mode: quick-validate-inline
code_commit: b7b6fc4e
---

Implemented explicit Hex 2.5.1 verified ETS and 2.6.0 native CRC-cache snapshot support. Collector and immutable validator agree on the reviewed versions. Snapshot normalization and guaranteed ETS cleanup retain existing evidence semantics. The CI parser runtime now pins isolated Hex 2.6.0 and loads its real cache reader/writer for regressions.

Baseline live root audit reproduced cache.bin present, cache.ets absent, snapshot ENOENT. Baseline deterministic seam tests failed; final 7 cache tests cover old/new equivalent snapshots, timestamps, missing/corrupt/truncated caches, CRC and invalid terms, stale legacy fallback refusal, unsupported versions, changed data and table cleanup.

Verification: all 317 readiness fixtures passed in 74 seconds, including 68 immutable-validator/cache tests and 69 remote fixtures. Fresh pinned runtime bootstrap and repeated 68-test validator/cache run passed. Formatting, shell syntax, diff whitespace and automation-first contract passed.

Live signed online/TLS audit on current main lock bytes: root 67 packages / 17920 database records (exit 1 retains advisory findings), demo 49 packages / 14260 records (exit 0); both Hex 2.6.0 and output schema intact. Complete read-only remote collector against main 8651494743baea30732c40c5d1b6ca92991ce08e stopped at pulls with not_ready / pull_undispositioned. No source-completeness, qualification, scheduled or READY credit. No credentials, raw API bodies or raw logs committed or copied to Dropbox.

Raw evidence remains in restricted external /private/tmp/rindle-hex26-live-audits and /private/tmp/rindle-hex26-complete-remote. Logs stay external. Original dirty checkout and development todo remain untouched; this separate clean clone/branch owns the PR.
