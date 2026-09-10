#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
evaluator="${here}/eval_nightly_summary.sh"

pass=0
fail=0

base_needs='{
  "compat-matrix":{"result":"success"},
  "dialyzer":{"result":"success"},
  "gcs-soak":{"result":"skipped"},
  "package-consumer-gcs-live":{"result":"success"}
}'

base_policy='{
  "compat-matrix":{"applicable":true,"applicability_rule":"always","execution":"passed","reason":""},
  "dialyzer":{"applicable":true,"applicability_rule":"always","execution":"passed","reason":""},
  "gcs-soak":{"applicable":false,"applicability_rule":"upstream-repository-and-required-secrets","execution":"not-run","reason":"required-secrets-unavailable"},
  "package-consumer-gcs-live":{"applicable":true,"applicability_rule":"upstream-repository-and-required-secrets","execution":"passed","reason":""}
}'

expect_exit() {
  local name="$1" want="$2" needs="$3" policy="$4" got=0 output_file verdict
  output_file="$(mktemp)"

  NEEDS_JSON="${needs}" NIGHTLY_POLICY_JSON="${policy}" \
    NIGHTLY_VERDICT_JSON="${output_file}" GITHUB_STEP_SUMMARY=/dev/null \
    bash "${evaluator}" >/dev/null 2>&1 || got=$?

  verdict="$(jq -r '.verdict // "missing"' "${output_file}" 2>/dev/null || printf 'missing')"
  rm -f "${output_file}"

  if [ "${got}" -eq "${want}" ] &&
     { [ "${want}" -eq 0 ] && [ "${verdict}" = green ] ||
       [ "${want}" -ne 0 ] && [ "${verdict}" = red ]; }; then
    echo "ok   — ${name} (exit ${got}, verdict ${verdict})"
    pass=$((pass + 1))
  else
    echo "FAIL — ${name}: expected exit/verdict ${want}, got ${got}/${verdict}" >&2
    fail=$((fail + 1))
  fi
}

mutate_needs() { jq -c "$1" <<<"${base_needs}"; }
mutate_policy() { jq -c "$1" <<<"${base_policy}"; }

expect_exit "exact declared jobs with executed applicable successes and visible exemption" 0 "${base_needs}" "${base_policy}"
expect_exit "all applicable jobs executed successfully" 0 \
  "$(mutate_needs '."gcs-soak".result = "success"')" \
  "$(mutate_policy '."gcs-soak" = {applicable:true, applicability_rule:"upstream-repository-and-required-secrets", execution:"passed", reason:""}')"
expect_exit "repository-gated skip is explicit not-run" 0 \
  "$(mutate_needs '."package-consumer-gcs-live".result = "skipped"')" \
  "$(mutate_policy '."package-consumer-gcs-live" = {applicable:false, applicability_rule:"upstream-repository-and-required-secrets", execution:"not-run", reason:"not-upstream-repository"}')"
expect_exit "inapplicable successful no-op remains visibly not-run" 0 \
  "$(mutate_needs '."package-consumer-gcs-live".result = "success"')" \
  "$(mutate_policy '."package-consumer-gcs-live" = {applicable:false, applicability_rule:"upstream-repository-and-required-secrets", execution:"not-run", reason:"required-secrets-unavailable"}')"

for result in failure cancelled skipped unknown timed_out action_required neutral stale; do
  expect_exit "applicable ${result} is red" 1 \
    "$(mutate_needs ".dialyzer.result = \"${result}\"")" "${base_policy}"
done

expect_exit "failed inapplicable job stays red" 1 \
  "$(mutate_needs '."gcs-soak".result = "failure"')" "${base_policy}"
expect_exit "cancelled inapplicable job stays red" 1 \
  "$(mutate_needs '."gcs-soak".result = "cancelled"')" "${base_policy}"
expect_exit "missing declared job is red" 1 \
  "$(mutate_needs 'del(.dialyzer)')" "${base_policy}"
expect_exit "unexpected observed job is red" 1 \
  "$(mutate_needs '.unexpected = {result:"success"}')" "${base_policy}"
expect_exit "missing observed result is red" 1 \
  "$(mutate_needs 'del(.dialyzer.result)')" "${base_policy}"
expect_exit "non-string observed result is red" 1 \
  "$(mutate_needs '.dialyzer.result = true')" "${base_policy}"

for field in applicable applicability_rule execution reason; do
  expect_exit "missing ${field} is red" 1 "${base_needs}" \
    "$(mutate_policy "del(.dialyzer.${field})")"
done

for value in false null '"true"' 1; do
  expect_exit "always job requires applicable boolean true (${value})" 1 "${base_needs}" \
    "$(mutate_policy ".dialyzer.applicable = ${value}")"
done

for execution in not-run skipped missing unknown; do
  expect_exit "applicable success requires passed execution (${execution})" 1 "${base_needs}" \
    "$(mutate_policy ".dialyzer.execution = \"${execution}\"")"
done
expect_exit "applicable success requires passed execution (empty)" 1 "${base_needs}" \
  "$(mutate_policy '.dialyzer.execution = ""')"

expect_exit "applicable success rejects an exemption reason" 1 "${base_needs}" \
  "$(mutate_policy '.dialyzer.reason = "required-secrets-unavailable"')"
expect_exit "always rule cannot claim inapplicability" 1 "${base_needs}" \
  "$(mutate_policy '.dialyzer = {applicable:false, applicability_rule:"always", execution:"not-run", reason:"required-secrets-unavailable"}')"
expect_exit "unknown applicability rule is red" 1 "${base_needs}" \
  "$(mutate_policy '.dialyzer.applicability_rule = "secret-ish"')"
expect_exit "gated applicable job requires passed execution" 1 "${base_needs}" \
  "$(mutate_policy '."package-consumer-gcs-live".execution = "not-run"')"
expect_exit "inapplicable job requires not-run execution" 1 "${base_needs}" \
  "$(mutate_policy '."gcs-soak".execution = "passed"')"
expect_exit "inapplicable job requires an allowlisted reason" 1 "${base_needs}" \
  "$(mutate_policy '."gcs-soak".reason = "secret maybe missing"')"
expect_exit "inapplicable job rejects empty reason" 1 "${base_needs}" \
  "$(mutate_policy '."gcs-soak".reason = ""')"
expect_exit "applicable skipped job cannot borrow an exemption reason" 1 \
  "$(mutate_needs '."gcs-soak".result = "skipped"')" \
  "$(mutate_policy '."gcs-soak" = {applicable:true, applicability_rule:"upstream-repository-and-required-secrets", execution:"passed", reason:"not-upstream-repository"}')"

expect_exit "empty needs is red" 1 '{}' "${base_policy}"
expect_exit "empty policy is red" 1 "${base_needs}" '{}'
expect_exit "needs array is red" 1 '[]' "${base_policy}"
expect_exit "policy array is red" 1 "${base_needs}" '[]'
expect_exit "malformed needs is red" 1 '{' "${base_policy}"
expect_exit "malformed policy is red" 1 "${base_needs}" '{'

expect_absent_env_red() {
  local name="$1" unset_name="$2" got=0 output_file verdict
  output_file="$(mktemp)"
  if [ "${unset_name}" = NEEDS_JSON ]; then
    NIGHTLY_POLICY_JSON="${base_policy}" NIGHTLY_VERDICT_JSON="${output_file}" \
      GITHUB_STEP_SUMMARY=/dev/null bash "${evaluator}" >/dev/null 2>&1 || got=$?
  else
    NEEDS_JSON="${base_needs}" NIGHTLY_VERDICT_JSON="${output_file}" \
      GITHUB_STEP_SUMMARY=/dev/null bash "${evaluator}" >/dev/null 2>&1 || got=$?
  fi
  verdict="$(jq -r '.verdict // "missing"' "${output_file}" 2>/dev/null || printf 'missing')"
  rm -f "${output_file}"
  if [ "${got}" -ne 0 ] && [ "${verdict}" = red ]; then
    echo "ok   — ${name} (exit ${got}, verdict ${verdict})"
    pass=$((pass + 1))
  else
    echo "FAIL — ${name}: expected red nonzero, got ${got}/${verdict}" >&2
    fail=$((fail + 1))
  fi
}

expect_absent_env_red "absent NEEDS_JSON is red" NEEDS_JSON
expect_absent_env_red "absent NIGHTLY_POLICY_JSON is red" NIGHTLY_POLICY_JSON

diagnostic_file="$(mktemp)"
verdict_file="$(mktemp)"
red_needs="$(mutate_needs '.dialyzer.result = "failure" | ."package-consumer-gcs-live".result = "cancelled"')"
NEEDS_JSON="${red_needs}" NIGHTLY_POLICY_JSON="${base_policy}" \
  NIGHTLY_VERDICT_JSON="${verdict_file}" GITHUB_STEP_SUMMARY="${diagnostic_file}" \
  bash "${evaluator}" >/dev/null 2>&1 || true
if grep -q '| dialyzer | failure |' "${diagnostic_file}" &&
   grep -q '| package-consumer-gcs-live | cancelled |' "${diagnostic_file}"; then
  echo "ok   — all red job diagnostics render before exit"
  pass=$((pass + 1))
else
  echo "FAIL — collect-all diagnostics omitted a red job" >&2
  fail=$((fail + 1))
fi
rm -f "${diagnostic_file}" "${verdict_file}"

echo "—"
echo "passed: ${pass}  failed: ${fail}"
[ "${pass}" -gt 0 ] && [ "${fail}" -eq 0 ]
