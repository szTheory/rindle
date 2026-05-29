#!/usr/bin/env bash
# Secret-gated GCS adoption proof companion for package-consumer-gcs-live.
# The Cohort demo host uses MinIO on PR CI; live GCS resumable ingest is canonical in install_smoke.
set -euo pipefail

if [[ -z "${GOOGLE_APPLICATION_CREDENTIALS_JSON:-}" || -z "${RINDLE_GCS_BUCKET:-}" ]]; then
  echo "adoption_demo_gcs_live: skip (GCS secrets not configured)"
  exit 0
fi

echo "adoption_demo_gcs_live: live GCS resumable proof is canonical via install_smoke.sh gcs in this job"
echo "adoption_demo_gcs_live: optional browser placeholder e2e/gcs-resumable.spec.js (RINDLE_GCS_LIVE=1)"
echo "adoption_demo_gcs_live: OK"
