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

require_substring "adoption-demo-e2e" "CI job id"
require_substring "install_smoke.sh image" "image install smoke"
require_substring "install_smoke.sh tus" "tus install smoke"
require_substring "install_smoke.sh video" "video install smoke"
require_substring "canonical_app/lifecycle_test.exs" "canonical adopter lane"
require_substring "e2e/image-upload.spec.js" "image Playwright spec"
require_substring "e2e/tus-resume.spec.js" "tus Playwright spec"
require_substring "e2e/video-upload.spec.js" "video Playwright spec"
require_substring "e2e/ops-surfaces.spec.js" "ops Playwright spec"
require_substring "e2e/replace-detach.spec.js" "replace Playwright spec"
require_substring "e2e/owner-erasure.spec.js" "owner erasure Playwright spec"
require_substring "check_adoption_proof_matrix.sh" "drift gate script self-reference"
require_substring "MinIO" "MinIO realism label"
require_substring "Merge-blocking" "merge-blocking severity wording"

echo "check_adoption_proof_matrix: OK"
