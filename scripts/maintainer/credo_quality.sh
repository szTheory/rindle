#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
baseline_path="${CREDO_QUALITY_BASELINE:-$repo_root/scripts/maintainer/credo_complexity_baseline.json}"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/rindle-credo-quality.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

fail() {
  echo "[credo-quality] $*" >&2
  exit 1
}

normalize_issues() {
  jq -S -e '
    if (.issues | type) != "array" then error("Credo JSON must contain an issues array") else . end
    | .issues
    | map(
        if .check == "Credo.Check.Refactor.CyclomaticComplexity" then
          {
            check: .check,
            file: .filename,
            trigger: .trigger,
            observed_metric: (.message | capture("cyclomatic complexity is (?<metric>[0-9]+)").metric | tonumber)
          }
        elif .check == "Credo.Check.Refactor.Nesting" then
          {
            check: .check,
            file: .filename,
            trigger: .trigger,
            observed_metric: (.message | capture("was (?<metric>[0-9]+)").metric | tonumber)
          }
        else
          error("unexpected Credo check: \(.check)")
        end
      )
    | if all(.[]; (.file | type) == "string" and (.trigger | type) == "string") then . else error("Credo issue identity is malformed") end
    | sort_by(.check, .file, .trigger, .observed_metric)
    | group_by([.check, .file, .trigger, .observed_metric])
    | map(.[0] + {count: length})
  '
}

normalize_baseline() {
  jq -S -e '
    if (.entries | type) != "array" then error("baseline must contain an entries array") else . end
    | .entries
    | if length == 33 and (map(.count) | add) == 37 then . else error("baseline must contain 33 identities and 37 occurrences") end
    | if all(.[];
        (keys | sort) == ["check", "count", "file", "observed_metric", "owner", "removal_trigger", "trigger"] and
        (.check | type) == "string" and .check != "" and
        (.file | type) == "string" and .file != "" and
        (.trigger | type) == "string" and .trigger != "" and
        (.observed_metric | type) == "number" and
        (.count | type) == "number" and .count > 0 and (.count | floor) == .count and
        (.owner | type) == "string" and .owner != "" and
        (.removal_trigger | type) == "string" and .removal_trigger != ""
      ) then . else error("baseline entries require stable identity, count, owner, and removal trigger") end
    | map({check, file, trigger, observed_metric, count})
    | sort_by(.check, .file, .trigger, .observed_metric)
    | if (group_by([.check, .file, .trigger, .observed_metric]) | all(length == 1)) then . else error("baseline identities must be unique") end
  '
}

command -v jq >/dev/null 2>&1 || fail "jq is required"
[ -f "$baseline_path" ] || fail "baseline not found: $baseline_path"

cd "$repo_root"
mix credo suggest --config-name blocking_warnings --format oneline
mix credo suggest --config-name public_contract --format oneline

issues_json="$tmp_dir/complexity.json"
actual_json="$tmp_dir/actual.json"
expected_json="$tmp_dir/expected.json"

mix credo suggest --config-name complexity_inventory --format json --mute-exit-status > "$issues_json" ||
  fail "Credo complexity inventory failed"

normalize_issues < "$issues_json" > "$actual_json" ||
  fail "Credo emitted malformed complexity inventory JSON"
normalize_baseline < "$baseline_path" > "$expected_json" ||
  fail "complexity baseline is malformed"

cmp -s "$expected_json" "$actual_json" || {
  diff -u "$expected_json" "$actual_json" >&2 || true
  fail "complexity/nesting identity multiset differs from the reviewed baseline"
}

echo "[credo-quality] blocking warnings, public contract, and complexity inventory passed"
