# Phase 132 CI Timing Receipt

**Status:** complete — target missed

**Target:** ten consecutive non-cancelled PR runs, <=8 minutes median, <=10 minutes p95

| Run | Commit | Started (UTC) | Required-gate duration | Result | Exception evidence |
|-----|--------|---------------|------------------------|--------|--------------------|
| 1 | `005beae` | 2026-08-25 14:17:24 | 8m54s (534s) | [success](https://github.com/szTheory/rindle/actions/runs/32858555423), attempt 1 | None |
| 2 | `005beae` | 2026-08-25 14:26:35 | 8m29s (509s) | [success](https://github.com/szTheory/rindle/actions/runs/32859515636), attempt 1 | None |
| 3 | `005beae` | 2026-08-25 14:35:36 | 8m33s (513s) | [success](https://github.com/szTheory/rindle/actions/runs/32860468135), attempt 1 | None |
| 4 | `005beae` | 2026-08-25 14:44:32 | 8m29s (509s) | [success](https://github.com/szTheory/rindle/actions/runs/32861404367), attempt 1 | None |
| 5 | `005beae` | 2026-08-25 14:53:31 | 8m32s (512s) | [success](https://github.com/szTheory/rindle/actions/runs/32862350206), attempt 1 | None |
| 6 | `005beae` | 2026-08-25 15:02:29 | 8m41s (521s) | [success](https://github.com/szTheory/rindle/actions/runs/32863291301), attempt 1 | None |
| 7 | `005beae` | 2026-08-25 15:11:26 | 8m12s (492s) | [success](https://github.com/szTheory/rindle/actions/runs/32864238097), attempt 1 | None |
| 8 | `005beae` | 2026-08-25 15:19:51 | 8m38s (518s) | [success](https://github.com/szTheory/rindle/actions/runs/32865112915), attempt 1 | None |
| 9 | `005beae` | 2026-08-25 15:28:48 | 9m04s (544s) | [success](https://github.com/szTheory/rindle/actions/runs/32866045627), attempt 1 | None |
| 10 | `005beae` | 2026-08-25 15:38:19 | 8m55s (535s) | [success](https://github.com/szTheory/rindle/actions/runs/32867033821), attempt 1 | None |

## Method

- Draft PR [#96](https://github.com/szTheory/rindle/pull/96), immutable implementation head
  `005beae2ac335b5d896077aeb7996da4263f05ba`.
- Ten fresh `pull_request` runs were triggered sequentially; the next run was not started until the
  prior run completed. Every recorded run has `run_attempt: 1`, conclusion `success`, and no
  cancellation.
- Required-gate duration is workflow `startedAt` through the `CI Summary` job's `completedAt`.
- Median is the average of the fifth and sixth sorted values. P95 uses the repository collector's
  nearest-rank rule: `ceil(N * 0.95)`.

## Result

| Metric | Target | Observed | Verdict |
|--------|--------|----------|---------|
| Median | <=480s | 515.5s (8m35.5s) | **FAIL** (+35.5s) |
| P95 | <=600s | 544s (9m04s) | PASS (-56s) |
| Fresh-run integrity | no reruns/cancellations | 10/10 attempt 1; 0 cancelled | PASS |
| Required gate | preserved | `CI Summary` passed in 10/10 runs | PASS |

CI-14 remains open because the median target was missed. Phase 132 and milestone v1.25 must not
close on this receipt.

One qualification run immediately before the recorded window,
[32856653445](https://github.com/szTheory/rindle/actions/runs/32856653445), failed when
`Rindle.Workers.ProcessVariant` hit its 600-second Oban timeout during the adoption-demo E2E seed.
It was not counted and was not classified as an external-runner exception. The recorded window is
the ten consecutive successful runs that followed it.

External-runner exceptions require job-level evidence, a named owner, and a dated follow-up. Code
and local verification may be complete while this receipt remains open; the milestone may not close
without it.
