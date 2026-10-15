#!/usr/bin/env bash
# Evaluate Nightly's declared job set without consulting GitHub or secret values.
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "[eval-nightly-summary] jq is required" >&2
  exit 1
fi

needs_json="${NEEDS_JSON-}"
policy_json="${NIGHTLY_POLICY_JSON-}"
summary_file="${GITHUB_STEP_SUMMARY:-/dev/null}"
verdict_file="${NIGHTLY_VERDICT_JSON:-}"

valid_needs=false
valid_policy=false

if [ -n "${needs_json}" ] && jq -e 'type == "object" and length > 0' >/dev/null 2>&1 <<<"${needs_json}"; then
  valid_needs=true
else
  needs_json='{}'
fi

if [ -n "${policy_json}" ] && jq -e 'type == "object" and length > 0' >/dev/null 2>&1 <<<"${policy_json}"; then
  valid_policy=true
else
  policy_json='{}'
fi

evaluation="$({
  jq -n -S -c \
    --argjson needs "${needs_json}" \
    --argjson policy "${policy_json}" \
    --argjson valid_needs "${valid_needs}" \
    --argjson valid_policy "${valid_policy}" '
      def allowed_result: type == "string" and IN("success", "failure", "cancelled", "skipped");
      def allowed_rule: type == "string" and IN("always", "upstream-repository-and-required-secrets");
      def allowed_reason: type == "string" and IN("not-upstream-repository", "required-secrets-unavailable");

      ($needs | keys) as $observed |
      ($policy | keys) as $declared |
      (($observed + $declared) | unique | sort) as $job_names |

      [
        $job_names[] as $name |
        ($needs[$name] // null) as $need |
        ($policy[$name] // null) as $claim |
        ($need.result) as $result |
        ($claim.applicable) as $applicable |
        ($claim.applicability_rule) as $rule |
        ($claim.execution) as $execution |
        ($claim.reason) as $reason |
        (
          if ($observed | index($name) | not) then ["missing observed job"]
          elif ($declared | index($name) | not) then ["unexpected observed job"]
          else
            ([
              if ($need | type) != "object" or (($need | keys) - ["outputs", "result"] | length) != 0 or ($need | has("result") | not) then "invalid observed job shape" else empty end,
              if ($result | allowed_result) then empty else "unknown or missing result" end,
              if ($claim | type) != "object" or ($claim | keys | sort) != ["applicability_rule", "applicable", "execution", "reason"] then "invalid policy job shape" else empty end,
              if ($rule | allowed_rule) then empty else "unknown or missing applicability rule" end,
              if ($applicable | type) == "boolean" then empty else "applicable must be a JSON boolean" end,
              if $result == "failure" then "job failed"
              elif $result == "cancelled" then "job cancelled"
              elif $applicable == true and $result != "success" then "applicable job did not succeed"
              elif $applicable == true and $execution != "passed" then "applicable success lacks passed execution evidence"
              elif $applicable == true and $reason != "" then "applicable job must not claim an exemption reason"
              elif $applicable == false and $rule == "always" then "always-applicable job claimed inapplicability"
              elif $applicable == false and $execution != "not-run" then "inapplicable job must be visibly not-run"
              elif $applicable == false and ($reason | allowed_reason | not) then "inapplicable job lacks an allowlisted reason"
              elif $applicable == false and ($result | IN("success", "skipped") | not) then "inapplicable job has an impermissible result"
              else empty end
            ])
          end
        ) as $errors |
        {
          name: $name,
          result: $result,
          applicable: $applicable,
          applicability_rule: $rule,
          execution: $execution,
          reason: $reason,
          status: (if ($errors | length) == 0 then (if $applicable then "passed" else "not-run" end) else "failed" end),
          errors: $errors
        }
      ] as $jobs |
      ([
        if $valid_needs then empty else "NEEDS_JSON must be a non-empty JSON object" end,
        if $valid_policy then empty else "NIGHTLY_POLICY_JSON must be a non-empty JSON object" end,
        if $observed == $declared then empty else "declared and observed job sets differ" end
      ] + [$jobs[].errors[]]) as $errors |
      {
        verdict: (if ($errors | length) == 0 then "green" else "red" end),
        jobs: $jobs,
        errors: $errors
      }
    '
} 2>/dev/null)"

if [ -n "${verdict_file}" ]; then
  printf '%s\n' "${evaluation}" >"${verdict_file}"
fi
printf '%s\n' "${evaluation}"

{
  echo "## Nightly Summary"
  echo ""
  echo "**Verdict:** $(jq -r '.verdict' <<<"${evaluation}")"
  echo ""
  echo "| Job | Result | Applicable | Execution | Status | Reason |"
  echo "| --- | --- | --- | --- | --- | --- |"
  jq -r '.jobs[] | "| \(.name) | \(.result // "missing") | \(.applicable | if . == null then "missing" else tostring end) | \(.execution // "missing") | \(.status) | \(.reason // "") |"' <<<"${evaluation}"
} >>"${summary_file}"

while IFS= read -r error; do
  echo "[eval-nightly-summary] ${error}" >&2
done < <(jq -r '.errors[]' <<<"${evaluation}")

[ "$(jq -r '.verdict' <<<"${evaluation}")" = green ]
