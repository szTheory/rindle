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

## Fresh corrected-head receipt

Corrected implementation SHA: `1161029d5403088d19f4a5017daf3048ecf159aa`
Preserved subject SHA: `5001e2a05f378c4fb3b0db9abefc316f8652d3c2`
Measured immutable PR head: `24c17783bbc080a085e398164450b7c3f475781e`

CI_TIMING_TABLE_BEGIN
| Sequence | Run ID | Source | Started (UTC) | Duration seconds | Attempt | Result | Exception disposition |
| ---: | ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | 32899635815 | https://github.com/szTheory/rindle/actions/runs/32899635815 | 2026-08-25T21:11:17Z | 499 | 1 | success | none |
| 2 | 32900433539 | https://github.com/szTheory/rindle/actions/runs/32900433539 | 2026-08-25T21:20:00Z | 519 | 1 | success | none |
| 3 | 32901253399 | https://github.com/szTheory/rindle/actions/runs/32901253399 | 2026-08-25T21:29:13Z | 410 | 1 | success | none |
| 4 | 32901888556 | https://github.com/szTheory/rindle/actions/runs/32901888556 | 2026-08-25T21:36:24Z | 542 | 1 | success | none |
| 5 | 32902703631 | https://github.com/szTheory/rindle/actions/runs/32902703631 | 2026-08-25T21:45:36Z | 503 | 1 | success | none |
| 6 | 32903456697 | https://github.com/szTheory/rindle/actions/runs/32903456697 | 2026-08-25T21:54:19Z | 525 | 1 | success | none |
| 7 | 32904266058 | https://github.com/szTheory/rindle/actions/runs/32904266058 | 2026-08-25T22:03:34Z | 514 | 1 | success | none |
| 8 | 32904999937 | https://github.com/szTheory/rindle/actions/runs/32904999937 | 2026-08-25T22:12:18Z | 543 | 1 | success | none |
| 9 | 32905752635 | https://github.com/szTheory/rindle/actions/runs/32905752635 | 2026-08-25T22:21:33Z | 461 | 1 | success | none |
| 10 | 32906413809 | https://github.com/szTheory/rindle/actions/runs/32906413809 | 2026-08-25T22:29:48Z | 543 | 1 | success | none |
CI_TIMING_TABLE_END

Sorted duration seconds: `410, 461, 499, 503, 514, 519, 525, 542, 543, 543`

- Median: (rank 5 + rank 6) / 2 = 516.5 seconds (target <= 480).
- Nearest-rank p95: rank 10 = 543 seconds (target <= 600).

| Metric | Target | Observed | Verdict |
| --- | ---: | ---: | --- |
| Median | <= 480 | 516.5 | FAIL |
| p95 | <= 600 | 543 | PASS |
| Verdict | FAIL | FAIL | FAIL |

CI_TIMING_SOURCE_BEGIN
{"sha":"24c17783bbc080a085e398164450b7c3f475781e","runs":[{"id":32899635815,"duration_seconds":499},{"id":32900433539,"duration_seconds":519},{"id":32901253399,"duration_seconds":410},{"id":32901888556,"duration_seconds":542},{"id":32902703631,"duration_seconds":503},{"id":32903456697,"duration_seconds":525},{"id":32904266058,"duration_seconds":514},{"id":32904999937,"duration_seconds":543},{"id":32905752635,"duration_seconds":461},{"id":32906413809,"duration_seconds":543}],"median_seconds":516.5,"p95_seconds":543}
CI_TIMING_SOURCE_END
