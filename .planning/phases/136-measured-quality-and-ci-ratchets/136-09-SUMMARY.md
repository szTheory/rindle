---
phase: 136-measured-quality-and-ci-ratchets
plan: 09
status: complete
requirements-completed: [TYPE-03, TEST-08, DX-05]
---

# Plan 09: Supported measurements on 4dc73fa9

The frozen subject 4dc73fa91c60ae870c7289a151d9d53460140906 completed fresh/restored Dialyzer in 54.847/2.973 seconds, clean full bootstrap in 388.54 seconds (mix ci 333.031 seconds), and the fixed 25-seed experiment with zero failures. The async runner exited 0 after 8444.275 seconds. Its original JSONL SHA256 is 8663a6b2bbcdc65990e952f9cd89d43755a9db394a1d09a278a1438d7f46fcbd. The executable verify-async owner returned complete against the FINAL subject pin. All receipts and raw artifacts are retained.

This finite sample does not prove every schedule safe. Its recorded next trigger is a reproducible isolation failure or source change. No ad-hoc seeds or retries were used.

PR #162 initial CI passed both Quality cells, Integration, Package Consumer and Adopter; CI Script Tests found an unclassified Python collector and retained log files rejected by the artifact ledger. No timing samples started. These measurements remain attributable to the original source only. A gap-repair candidate requires separately named source-bound measurements; this summary does not close overall phase qualification.

Earlier first-red and superseded candidates remain historical evidence with no replacement-subject credit.
