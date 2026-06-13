#!/usr/bin/env bash
# Drift gate: adoption-proof-matrix.md must mention core lanes and E2E specs.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
matrix="${repo_root}/examples/adoption_demo/docs/adoption-proof-matrix.md"

if [[ ! -f "${matrix}" ]]; then
  echo "check_adoption_proof_matrix: missing ${matrix}" >&2
  exit 1
fi

require_substring() {
  local needle="$1"
  local label="$2"
  if ! grep -Fq "${needle}" "${matrix}"; then
    echo "check_adoption_proof_matrix: matrix missing ${label} (expected: ${needle})" >&2
    exit 1
  fi
}

require_file() {
  local rel_path="$1"
  local label="$2"
  if [[ ! -f "${repo_root}/examples/adoption_demo/${rel_path}" ]]; then
    echo "check_adoption_proof_matrix: missing ${label} (${rel_path})" >&2
    exit 1
  fi
}

require_substring "adoption-demo-e2e" "CI job id"
require_substring "generated_app_smoke_test.exs" "install bootstrap lane"
require_substring "install_smoke.sh image" "image install smoke"
require_substring "install_smoke.sh tus" "tus install smoke"
require_substring "install_smoke.sh video" "video install smoke"
require_substring "install_smoke.sh mux" "mux install smoke"
require_substring "install_smoke.sh gcs" "gcs install smoke"
require_substring "adoption_demo_gcs_live.sh" "GCS live companion script"
require_substring "canonical_app/lifecycle_test.exs" "canonical adopter lane"
require_substring "e2e/image-upload.spec.js" "image Playwright spec"
require_substring "e2e/tus-resume.spec.js" "tus Playwright spec"
require_substring "e2e/video-upload.spec.js" "video Playwright spec"
require_substring "e2e/multipart-upload.spec.js" "multipart Playwright spec"
require_substring "e2e/liveview-upload.spec.js" "liveview Playwright spec"
require_substring "e2e/rendering.spec.js" "rendering Playwright spec"
require_substring "e2e/mux-streaming.spec.js" "mux Playwright spec"
require_substring "e2e/gcs-resumable.spec.js" "gcs Playwright spec"
require_substring "e2e/batch-erasure.spec.js" "batch erasure Playwright spec"
require_substring "e2e/ops-surfaces.spec.js" "ops Playwright spec"
require_substring "e2e/replace-detach.spec.js" "replace Playwright spec"
require_substring "e2e/owner-erasure.spec.js" "owner erasure Playwright spec"
require_substring "e2e/admin-console.spec.js" "admin console Playwright spec"
require_substring "e2e/admin-theme.spec.js" "admin theme Playwright spec"
require_substring "e2e/admin-actions.spec.js" "admin actions Playwright spec"
require_substring "e2e/admin-screenshots.spec.js" "admin screenshots Playwright spec"
require_file "e2e/admin-console.spec.js" "admin console Playwright spec"
require_file "e2e/admin-theme.spec.js" "admin theme Playwright spec"
require_file "e2e/admin-actions.spec.js" "admin actions Playwright spec"
require_file "e2e/admin-screenshots.spec.js" "admin screenshots Playwright spec"
require_substring "test-results/admin-screenshots" "admin screenshot output path"
require_substring "check_adoption_proof_matrix.sh" "drift gate script self-reference"
require_substring "MinIO" "MinIO realism label"
require_substring "Merge-blocking" "merge-blocking severity wording"
require_substring "Cohort" "Cohort persona wording"

echo "check_adoption_proof_matrix: OK"
