# Smaller pages for historical Actions job evidence

**Observed:** 2026-11-18, while collecting Phase 139 remote evidence. Historical `GET /repos/szTheory/rindle/actions/runs/38836352011/jobs` returned HTTP 502 at `per_page=10`, `50`, and `100`; the same run succeeded at `per_page=1`, `2`, `3`, and `5` and reported 23 jobs. A second historical landing run (`38844854765`) also returned 502 at `per_page=100`. Run metadata and current-run job endpoints remained readable, so this was a response-size issue rather than an authentication failure.

**Collector rule:** Keep `per_page=100` for the normal path. For an exact historical Actions job-list endpoint only, after all three existing transient retries return 502, 503, or 504 without rate-limit exhaustion or `Retry-After`, restart the complete inventory at `per_page=5`. Preserve the existing `total_count`, cursor, identity, completeness, two-observation, and global time/request-budget checks. Do not use smaller pages for other endpoints or successful large-page responses.

This fallback adds requests only when the large response has already failed. For the 23-job example it reads five small pages per observation; those reads remain inside the collector's existing budgets. It avoids paying that pagination cost on healthy responses and avoids weakening the evidence requirements.

**Regression evidence:** `bash scripts/ci/test_readiness_remote.sh` passed with 19 transport tests and 87 remote evidence fixtures, including a repeated-gateway-failure case that proves both observations complete from three small pages in the fixture. This is local fixture evidence; merge CI and live acceptance remain separate gates.
