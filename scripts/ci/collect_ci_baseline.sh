#!/usr/bin/env bash
# collect_ci_baseline.sh — capture a reproducible CI timing baseline (OBS-03).
#
# WHY THIS EXISTS
# ---------------
# Phase 103 is the [BASELINE FIRST] gate of the v1.20 CI/CD-performance milestone:
# before any topology change (cache hygiene, aggregate required check, lane split),
# we must record what the pipeline costs *today*, reproducibly, so Phase 107's
# "regression vs baseline" check has a real reference instead of an eyeballed
# memory of a few reruns.
#
# This is a maintainer-LOCAL collector (D-08), NOT a new CI job — it adds zero new
# CI surface and no new required check (threat T-103-05). It is READ-ONLY: it only
# GETs runs/jobs from the GitHub Actions API; it never mutates branch protection or
# any CI state.
#
# WHAT IT COMPUTES
# ----------------
# Over the last N `ci.yml` runs on a branch (default: last 50 on `main`):
#   * a per-job  avg(s) + p95(s)  duration table (from each job's
#     started_at/completed_at), and
#   * a rerun rate, DERIVED from `run_attempt` / `previous_attempt_url`
#     (GitHub exposes NO direct `rerun_count` field — see 103-RESEARCH.md Pitfall 2).
# The Markdown table is printed to stdout; Plan 04 captures it into 103-BASELINE.md.
#
# Auth: uses the maintainer's authed `gh` session. Reading runs/jobs needs no admin
# scope (only branch-protection reads do — see check_required_checks.sh).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${repo_root}"

# Fail loud (matching scripts/setup_branch_protection.sh) if tooling is missing,
# instead of producing an empty/garbled table deep in the run.
if ! command -v gh >/dev/null 2>&1; then
  echo "[collect-ci-baseline] gh CLI is required" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "[collect-ci-baseline] jq is required" >&2
  exit 1
fi

# Parameterized window (D-08): override via env for PR-realism vs main-stability runs.
REPO="${GITHUB_REPOSITORY:-szTheory/rindle}"
BRANCH="${BASELINE_BRANCH:-main}"
N="${BASELINE_RUNS:-50}"

echo "[collect-ci-baseline] window: last ${N} ci.yml runs on ${REPO}@${BRANCH}" >&2

# 1. Recent runs. The listing returns the latest attempt per run; run_attempt /
#    previous_attempt_url reveal which were reruns (Pitfall 2).
runs_json="$(gh api --paginate \
  -H "Accept: application/vnd.github+json" \
  "repos/${REPO}/actions/workflows/ci.yml/runs?branch=${BRANCH}&per_page=100" \
  --jq "[.workflow_runs[] | {id, head_sha, run_attempt, conclusion, previous_attempt_url}] | .[:${N}]")"

# 2. Rerun rate over the window (NO rerun_count field — derive from attempts).
total="$(jq 'length' <<<"${runs_json}")"
reran="$(jq '[.[] | select(.run_attempt > 1 or .previous_attempt_url != null)] | length' <<<"${runs_json}")"
echo "Rerun rate (last ${N} ${BRANCH} runs): ${reran}/${total}"
echo ""

# 3. Per-job durations across those runs → emit "job_name<TAB>duration_seconds".
durations_tsv="$(mktemp)"
trap 'rm -f "${durations_tsv}"' EXIT
for id in $(jq -r '.[].id' <<<"${runs_json}"); do
  gh api --paginate -H "Accept: application/vnd.github+json" \
    "repos/${REPO}/actions/runs/${id}/jobs?per_page=100" \
    --jq '.jobs[]
          | select(.started_at != null and .completed_at != null)
          | [ .name,
              ((.completed_at|fromdateiso8601) - (.started_at|fromdateiso8601)) ]
          | @tsv' >>"${durations_tsv}" || true
done

# 4. avg + p95 per job name (awk: collect, sort each job's samples, index p95).
awk -F'\t' '
  { sum[$1]+=$2; n[$1]++; vals[$1]=vals[$1] $2 " " }
  END {
    print "| Job | runs | avg(s) | p95(s) |"
    print "| --- | ---: | ---: | ---: |"
    for (j in sum) {
      c=split(vals[j], a, " ")-1
      for(i=1;i<=c;i++) for(k=i+1;k<=c;k++) if(a[k]<a[i]){t=a[i];a[i]=a[k];a[k]=t}
      p95idx=int((c*0.95)+0.999); if(p95idx<1)p95idx=1; if(p95idx>c)p95idx=c
      printf "| %s | %d | %.0f | %.0f |\n", j, n[j], sum[j]/n[j], a[p95idx]
    }
  }' "${durations_tsv}"
