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

## Platform anomaly ledger (2026-08-26)

The following GitHub Actions runs are historical platform anomalies on superseded head
`458458aa6712e148a1290177029cfa2783760855`. They are not samples, do not participate in any
sequence, and must never be used for CI-14 statistics or threshold evaluation.

| Run | URL | Observed API state | Contradictory cancel response | Owner | Disposition |
| ---: | --- | --- | --- | --- | --- |
| 32985544318 | https://github.com/szTheory/rindle/actions/runs/32985544318 | `queued`; no started jobs | `gh run cancel` reported the run already completed | GitHub Actions | Platform anomaly; excluded permanently |
| 32985757005 | https://github.com/szTheory/rindle/actions/runs/32985757005 | `queued`; no started jobs | `gh run cancel` reported the run already completed | GitHub Actions | Platform anomaly; excluded permanently |

For context only, runs `32985742147` and `32985837362` terminated as `startup_failure` on the
same superseded head. The owned `ci-timing-sample` label was absent and no local controller process
was active when this record was made. This is an evidence record, not an external-runner exception
or a substitute for a fresh API-backed receipt.

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

## Gap-closure causal census

The failed immutable-head sample above remains unchanged. This census is a read-only
same-head follow-up used only to identify one repeated required-path cost before the
correction; it does not replace the final ten-run receipt or alter its arithmetic.

- **Measured head:** `24c17783bbc080a085e398164450b7c3f475781e`
- **Source run IDs:** `32899635815`, `32900433539`, `32901253399`, `32901888556`,
  `32902703631`, `32903456697`, `32904266058`, `32904999937`, `32905752635`, and
  `32906413809`
- **Source:** `GET /repos/szTheory/rindle/actions/runs/{run_id}/jobs` for each exact
  recorded run, restricted to successful jobs and steps at the measured head.

The causal census recomputes the failed receipt's source identities before aggregating
native timestamps. Among the two workload jobs that alternated as the last required
finisher before the aggregator, `Adoption Demo E2E Smoke` finished last in 4/10 runs
and `Adopter` finished last in 6/10. Their native job-duration summaries were:

| Job | Samples | Median | Min | Max |
| --- | ---: | ---: | ---: | ---: |
| `Adoption Demo E2E Smoke` | 10 | 204.5s | 178s | 256s |
| `Adopter` | 10 | 94.5s | 77s | 135s |

The shared `Install libvips` step occurred successfully in eight required jobs across
each of the ten runs (80 sequential, first-attempt samples): **25s median, 11s min,
68s max**. This repeated setup cost is the bounded correction target. The install-first
helper retains a single refresh-on-failure recovery path for stale indexes; it neither
removes a proof nor changes the required-job topology.

Reproducible aggregation (after saving the ten API responses as JSON) is:

```sh
jq -s '[.[] | .jobs[] | select(.conclusion == "success") |
  {job: .name, steps: [.steps[] | select(.name == "Install libvips" and .conclusion == "success") |
  ((.completed_at | fromdateiso8601) - (.started_at | fromdateiso8601))]}] |
  map(.steps[]) | {count: length, median: (sort | .[39:41] | add / 2), min: min, max: max}' jobs-*.json
```

## Failed recovery-run diagnosis (2026-08-26)

Read-only GitHub Actions API evidence identifies a deterministic required-path failure in both
authorized first-attempt recovery runs at the same immutable head. These are failed runs, not
timing samples: they admit **zero timing rows** and cannot be characterized as runner variance.

| Run | Immutable head | Event | Attempt | Conclusion | Sole required-path failure | Formatter target |
| ---: | --- | --- | ---: | --- | --- | --- |
| [33016605029](https://github.com/szTheory/rindle/actions/runs/33016605029) | `7f025dfdf55d612861610a10773d86761a374277` | `pull_request` | 1 | `failure` | `Quality (1.17, 27, true)` / `Check formatting` | `test/install_smoke/ci_lane_split_test.exs` |
| [33017105225](https://github.com/szTheory/rindle/actions/runs/33017105225) | `7f025dfdf55d612861610a10773d86761a374277` | `pull_request` | 1 | `failure` | `Quality (1.17, 27, true)` / `Check formatting` | `test/install_smoke/ci_lane_split_test.exs` |

The observed evidence authorizes only `mix format` normalization of that exact contract file.
It does not authorize a workflow, topology, fixture, assertion-value, timing-policy, dependency,
or product-surface change. The formatter remediation must be verified locally before the final
subject is preserved or another live sample is attempted.

## Fresh corrected-head receipt

Corrected implementation SHA: `1671cdde1c42231a8a958c8f2771a24edb8b444e`
Preserved subject SHA: `a4bbbd1bba6077134934a4e6b9a9bf63924b47e9`
Measured immutable PR head: `869ca9cd7450dd6785aefa1fdb4bba457ce336f0`

CI_TIMING_CURRENT_TABLE_BEGIN
| Sequence | Run ID | Source | Started (UTC) | Duration seconds | Attempt | Result | Exception disposition |
| ---: | ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | 33108596297 | https://github.com/szTheory/rindle/actions/runs/33108596297 | 2026-08-27T19:28:24Z | 446 | 1 | success | none |
| 2 | 33109213864 | https://github.com/szTheory/rindle/actions/runs/33109213864 | 2026-08-27T19:36:01Z | 418 | 1 | success | none |
| 3 | 33109785773 | https://github.com/szTheory/rindle/actions/runs/33109785773 | 2026-08-27T19:43:07Z | 436 | 1 | success | none |
| 4 | 33110400721 | https://github.com/szTheory/rindle/actions/runs/33110400721 | 2026-08-27T19:50:44Z | 481 | 1 | success | none |
| 5 | 33111089118 | https://github.com/szTheory/rindle/actions/runs/33111089118 | 2026-08-27T19:59:08Z | 404 | 1 | success | none |
| 6 | 33111678168 | https://github.com/szTheory/rindle/actions/runs/33111678168 | 2026-08-27T20:06:13Z | 453 | 1 | success | none |
| 7 | 33112319591 | https://github.com/szTheory/rindle/actions/runs/33112319591 | 2026-08-27T20:14:05Z | 479 | 1 | success | none |
| 8 | 33112983558 | https://github.com/szTheory/rindle/actions/runs/33112983558 | 2026-08-27T20:22:16Z | 479 | 1 | success | none |
| 9 | 33113664858 | https://github.com/szTheory/rindle/actions/runs/33113664858 | 2026-08-27T20:30:36Z | 473 | 1 | success | none |
| 10 | 33114333757 | https://github.com/szTheory/rindle/actions/runs/33114333757 | 2026-08-27T20:38:47Z | 453 | 1 | success | none |
CI_TIMING_CURRENT_TABLE_END

Sorted duration seconds: `404, 418, 436, 446, 453, 453, 473, 479, 479, 481`

- Median: (rank 5 + rank 6) / 2 = 453 seconds (target <= 480).
- Nearest-rank p95: rank 10 = 481 seconds (target <= 600).

| Metric | Target | Observed | Verdict |
| --- | ---: | ---: | --- |
| Median | <= 480 | 453 | PASS |
| p95 | <= 600 | 481 | PASS |
| Verdict | PASS | PASS | PASS |

CI_TIMING_CURRENT_SOURCE_BEGIN
{"repo":"szTheory/rindle","pr":96,"sha":"869ca9cd7450dd6785aefa1fdb4bba457ce336f0","population_boundary_ids":[33108069978,33107367974,33106697965,33105948783,33105376700,33104713930,33104105124,33102345203],"runs":[{"id":33108596297,"url":"https://github.com/szTheory/rindle/actions/runs/33108596297","started_at":"2026-08-27T19:28:24Z","started_epoch":1787858904,"summary_completed_at":"2026-08-27T19:35:50Z","summary_completed_epoch":1787859350,"duration_seconds":446,"attempt":1,"conclusion":"success"},{"id":33109213864,"url":"https://github.com/szTheory/rindle/actions/runs/33109213864","started_at":"2026-08-27T19:36:01Z","started_epoch":1787859361,"summary_completed_at":"2026-08-27T19:42:59Z","summary_completed_epoch":1787859779,"duration_seconds":418,"attempt":1,"conclusion":"success"},{"id":33109785773,"url":"https://github.com/szTheory/rindle/actions/runs/33109785773","started_at":"2026-08-27T19:43:07Z","started_epoch":1787859787,"summary_completed_at":"2026-08-27T19:50:23Z","summary_completed_epoch":1787860223,"duration_seconds":436,"attempt":1,"conclusion":"success"},{"id":33110400721,"url":"https://github.com/szTheory/rindle/actions/runs/33110400721","started_at":"2026-08-27T19:50:44Z","started_epoch":1787860244,"summary_completed_at":"2026-08-27T19:58:45Z","summary_completed_epoch":1787860725,"duration_seconds":481,"attempt":1,"conclusion":"success"},{"id":33111089118,"url":"https://github.com/szTheory/rindle/actions/runs/33111089118","started_at":"2026-08-27T19:59:08Z","started_epoch":1787860748,"summary_completed_at":"2026-08-27T20:05:52Z","summary_completed_epoch":1787861152,"duration_seconds":404,"attempt":1,"conclusion":"success"},{"id":33111678168,"url":"https://github.com/szTheory/rindle/actions/runs/33111678168","started_at":"2026-08-27T20:06:13Z","started_epoch":1787861173,"summary_completed_at":"2026-08-27T20:13:46Z","summary_completed_epoch":1787861626,"duration_seconds":453,"attempt":1,"conclusion":"success"},{"id":33112319591,"url":"https://github.com/szTheory/rindle/actions/runs/33112319591","started_at":"2026-08-27T20:14:05Z","started_epoch":1787861645,"summary_completed_at":"2026-08-27T20:22:04Z","summary_completed_epoch":1787862124,"duration_seconds":479,"attempt":1,"conclusion":"success"},{"id":33112983558,"url":"https://github.com/szTheory/rindle/actions/runs/33112983558","started_at":"2026-08-27T20:22:16Z","started_epoch":1787862136,"summary_completed_at":"2026-08-27T20:30:15Z","summary_completed_epoch":1787862615,"duration_seconds":479,"attempt":1,"conclusion":"success"},{"id":33113664858,"url":"https://github.com/szTheory/rindle/actions/runs/33113664858","started_at":"2026-08-27T20:30:36Z","started_epoch":1787862636,"summary_completed_at":"2026-08-27T20:38:29Z","summary_completed_epoch":1787863109,"duration_seconds":473,"attempt":1,"conclusion":"success"},{"id":33114333757,"url":"https://github.com/szTheory/rindle/actions/runs/33114333757","started_at":"2026-08-27T20:38:47Z","started_epoch":1787863127,"summary_completed_at":"2026-08-27T20:46:20Z","summary_completed_epoch":1787863580,"duration_seconds":453,"attempt":1,"conclusion":"success"}],"median_seconds":453,"p95_seconds":481}
CI_TIMING_CURRENT_SOURCE_END
