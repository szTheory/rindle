# Phase 139: Exact-Head Readiness Closure - Pattern Map

**Mapped:** 2026-10-22
**Files analyzed:** 6 proposed new/modified files
**Analogs found:** 6 / 6

The names below are proposed Phase 139 tooling paths. Phase 134–138 contracts now exist and `139-preflight.sh` validates their committed acceptance chain and current Phase 138 digest. Plan 00 is the scoped exception to the earlier no-runtime-edit assumption: public Doctor must inspect a host-owned versioned migration ledger correctly.

## File Classification

| Proposed new/modified file | Status | Role | Data flow | Closest tracked analog | Match |
|---|---|---|---|---|---|
| `scripts/maintainer/exact_head_readiness.sh` | proposed new | utility/orchestrator | batch, file-I/O | `scripts/ci/verify_nightly_run.sh` | same orchestration and proof flow, narrower event policy |
| `scripts/maintainer/collect_readiness_remote.sh` | proposed new | service/collector | request-response, file-I/O | `scripts/ci/verify_nightly_run.sh`; `scripts/ci/check_required_checks.sh` | same remote acquisition, new multi-source coverage |
| `scripts/maintainer/validate_exact_head_readiness.exs` | proposed new | utility/policy validator | transform, file-I/O | `scripts/maintainer/validate_evidence_census.exs` | same pure receipt validation |
| `scripts/ci/test_exact_head_readiness.sh` | proposed new | test | batch, file-I/O | `scripts/ci/test_nightly_summary_gate.sh` | same negative-fixture driver |
| `.github/workflows/ci.yml` | existing, proposed modification | config | event-driven | `.github/workflows/ci.yml` lines 1425–1465 | exact insertion seam |
| `RUNNING.md` | existing, proposed modification | documentation | request-response | `RUNNING.md` lines 111–155 | exact maintainer-command seam |

Other committed files are policy inputs or supporting evidence: `config/ci_required_checks.json`, `.github/workflows/nightly.yml`, `.github/workflows/release.yml`, `test/install_smoke/support/generated_app_helper.ex`, `.planning/INBOX-LEDGER.json`, the Phase 133 census scripts, and `scripts/maintainer/built_package_twin.py` with `twin_receipt.py` and `twin_cleanup.py`. Plan 00 owns the narrow Doctor correction in `runtime_checks.ex` and `ownership_checks.ex`; all other Phase 139 work remains maintainer tooling.

## Pattern Assignments

### `scripts/maintainer/exact_head_readiness.sh` — utility, batch and file-I/O

**Analog:** tracked `scripts/ci/verify_nightly_run.sh`. Copy its fail-closed shell structure and immutable object verification, adapting the policy to the closing `main` subject. The Nightly verifier itself describes a `workflow_dispatch` proof; it does not establish scheduled Nightly qualification.

**Subject and file identity pattern** (`scripts/ci/verify_nightly_run.sh:262-274`):

```bash
[[ "$commit" =~ ^[0-9a-f]{40}$ ]] || die "ledger commit identity is malformed"
actual_blob="$(git -C "$project_root" rev-parse "${commit}:${path}")" ||
  die "ledger path is absent from recorded commit"
[ "$actual_blob" = "$expected_blob" ] || die "ledger blob differs from recorded commit:path"
git -C "$project_root" show "${commit}:${path}" >"$output" ||
  die "could not materialize recorded ledger object"
actual_sha="$(sha256_file "$output")" || die "could not hash materialized ledger object"
```

**Preflight and error pattern** (`scripts/ci/verify_nightly_run.sh:277-292`): require tracked, clean source authority and fail on absent or malformed identity before collecting. Phase 139 should also initialize a nonpassing attempt record before commands, finalize only after observed cleanup and second remote-main resolution, and retain failed outcomes outside the subject checkout. Those are new Phase 139 requirements, not existing behavior of the analog.

**Qualification caveat:** derive exact supported toolchains and gate set from committed policy and completed upstream validators. Do not reuse a previous SHA's receipt by changing its subject field.

### `scripts/maintainer/collect_readiness_remote.sh` — service, request-response and file-I/O

**Primary analog:** tracked `scripts/ci/verify_nightly_run.sh`. **Secondary analog:** tracked `scripts/ci/check_required_checks.sh`.

**Remote reconstruction pattern** (`scripts/ci/verify_nightly_run.sh:379-399`):

```bash
jq -cnS --arg repository "$repo" --arg workflow "$workflow" \
  --arg subject_sha "$expected_sha" --arg remote_ref "$remote_ref" \
  --argjson run "$run_json" --argjson dialyzer "$dialyzer" --argjson preflight "$preflight" '
    {repository:$repository,workflow:$workflow,subject_sha:$subject_sha,
     remote_ref:$remote_ref,run_id:$run.databaseId,run_attempt:$run.attempt,
     conclusion:$run.conclusion,created_at:$run.createdAt,
     jobs:($run.jobs | sort_by(.name) | map({id:.databaseId,name,status,conclusion})),
     dialyzer:$dialyzer,preflight:$preflight}
  '
```

This excerpt omits the analog's hard-coded dispatch event and strict verdict for brevity; Phase 139 must record the real event and require the scheduled Nightly path. `scripts/ci/verify_nightly_run.sh:393-399` compares a receipt to a live reconstruction; apply that structure to a bounded second read of mutable facts.

**Read-only authenticated API pattern** (`scripts/ci/check_required_checks.sh:25-48`):

```bash
set -euo pipefail
if ! command -v gh >/dev/null 2>&1; then
  echo "[check-required-checks] gh CLI is required" >&2
  exit 1
fi
live="$(gh api \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "repos/${REPO}/branches/${BRANCH}/protection/required_status_checks" \
  --jq '.contexts[]' | sort)"
```

Use the auth/header/error shape, **not** its acceptance policy: this script observes only legacy `.contexts[]` and ends with tolerated `diff ... || true` (`scripts/ci/check_required_checks.sh:59-62`). The new collector must keep pagination, source-specific authorization/visibility, structured checks, active rulesets, run attempts, issues versus PRs, advisories, Dependabot, Hex audit, and response completeness separate. No close analog exists for that complete multi-source coverage; use `139-RESEARCH.md` and official API contracts for those new parts.

### `scripts/maintainer/validate_exact_head_readiness.exs` — utility, transform and file-I/O

**Analog:** tracked `scripts/maintainer/validate_evidence_census.exs`; the companion tracked collector `scripts/maintainer/evidence_census.exs` provides receipt formatting.

**Validation and CLI pattern** (`scripts/maintainer/validate_evidence_census.exs:49-65,97-108,110-141`):

```elixir
with {:ok, options} <- parse_options(argv),
     {:ok, ledger} <- decode_json(options.ledger, "ledger"),
     {:ok, receipt} <- decode_json(options.receipt, "receipt"),
     :ok <- validate_schema(ledger, receipt),
     :ok <- validate_authority(ledger, receipt, head),
     :ok <- validate_receipt(ledger, receipt, options.root) do
  :ok
end
```

The excerpt shows the control-flow shape; the original `run/1` also obtains `head` and validates more census-specific contracts before `validate_receipt/3`. Parse explicit options with `OptionParser.parse(..., strict: ...)` and decode one JSON object with `Jason.decode/1` as at lines 110–141. Expose a pure callable contract similar to `validate_receipt_contract/4` at lines 97–108 so deterministic fixtures can validate without remote access.

**Fail-closed identity and state pattern** (`scripts/maintainer/validate_evidence_census.exs:151-169,792-813`):

```elixir
defp validate_schema(%{"schema_version" => 1}, %{"schema_version" => 1}), do: :ok
defp validate_schema(_ledger, _receipt), do: {:error, "unsupported schema_version"}

defp nonempty_unique_strings?(values) when is_list(values),
  do: values != [] and Enum.all?(values, &nonempty_string?/1) and values == Enum.uniq(values)

{:error, message} ->
  IO.puts(:stderr, "[validate-evidence-census] #{message}")
  System.halt(1)
```

For the new validator, use a finite proof-ID registry, exact SHA/repository/package/digest-kind matching, complete attempts, verified receipt bytes, explicit applicability, post-cleanup residue, and synthetic adoption class. Reject malformed/unknown trust-bearing states, including partial or unavailable evidence. `scripts/maintainer/evidence_census.exs:197-215,239-250` shows versioned subject/tool/input receipts and SHA-256 of actual file bytes; `:crypto.hash/2` establishes byte identity only.

### `scripts/ci/test_exact_head_readiness.sh` — test, batch and file-I/O

**Analog:** tracked `scripts/ci/test_nightly_summary_gate.sh`.

**Fixture/result pattern** (`scripts/ci/test_nightly_summary_gate.sh:24-48,67-79`):

```bash
expect_exit() {
  local name="$1" want="$2" needs="$3" policy="$4" got=0 output_file verdict
  output_file="$(mktemp)"
  NEEDS_JSON="${needs}" NIGHTLY_POLICY_JSON="${policy}" \
    NIGHTLY_VERDICT_JSON="${output_file}" GITHUB_STEP_SUMMARY=/dev/null \
    bash "${evaluator}" >/dev/null 2>&1 || got=$?
  verdict="$(jq -r '.verdict // "missing"' "${output_file}" 2>/dev/null || printf 'missing')"
  rm -f "${output_file}"
  # Assert both process exit and machine-readable verdict.
}

for result in failure cancelled skipped unknown timed_out action_required neutral stale; do
  expect_exit "applicable ${result} is red" 1 \
    "$(mutate_needs ".dialyzer.result = \"${result}\"")" "${base_policy}"
done
```

Adapt the fixture driver to inspect both nonzero exit and `not_ready` reason IDs. Cover wrong subject, event, repository, package, duplicate/missing proofs, digest corruption, partial pages/attempts, protection drift, cleanup failure, changing remote facts, and synthetic adoption inflation. Use temporary external directories and remove only owned fixtures. The existing script test ends with counts plus a failing exit (`scripts/ci/test_nightly_summary_gate.sh:167-169`).

### `.github/workflows/ci.yml` — existing config, event-driven

**Analog and edit seam:** this same tracked workflow, `ci-script-tests` at `.github/workflows/ci.yml:1425-1439`. Its checkout is pinned, and it runs cheap script regressions. Add the new fixture command there when implemented. `ci-summary` needs `ci-script-tests` at lines 1441–1465, preserving `CI Summary` as the sole required PR context. Keep live remote collection and full checkout qualification outside this PR job.

### `RUNNING.md` — existing documentation, request-response

**Analog and edit seam:** `RUNNING.md:111-129` documents a maintainer-only command, its validation mode, where evidence belongs, and its stopping behavior. `RUNNING.md:135-155` lists reproducible gate commands and the planning-artifact contract check. Document one exact-head entry point with collection, offline read-only validation, bounded remote refresh, output location, failure reasons, and repair commands. Avoid claims that a historical manifest certifies a later `main` SHA.

## Shared Patterns

**Receipt identity and digest:** `scripts/maintainer/evidence_census.exs:203-215,239-250` binds schema, source SHA, dirty state, toolchain, inputs, and SHA-256 file digests. `test/install_smoke/support/generated_app_helper.ex:358-378` records `package_sha256` from `hex_metadata.config` and `unpacked_tree_sha256` separately. At Phase 139's boundary, retain the metadata hash under an honest digest kind and add a hash of the actual archive bytes; never call the metadata hash an archive hash.

**Authorization and sensitive data:** `scripts/ci/check_required_checks.sh:14-22,42-48` uses an existing `gh` session for read-only protection GETs. Phase 139 must record unauthorized/private-resource errors distinctly, keep raw sensitive responses restricted, and derive redacted portable receipts from actual collection. No new token handling or write API follows from this analog.

**Failing states and policy:** `scripts/maintainer/validate_evidence_census.exs:151-169,805-813` returns explicit errors and exits nonzero. `scripts/ci/test_nightly_summary_gate.sh:67-79` tests rejected states. Record a nonpassing attempt before work starts; only a complete, verified, cleaned, freshly reobserved attempt can become `ready`.

**CI topology:** `.github/workflows/ci.yml:1425-1465` makes script fixtures merge-blocking through `CI Summary`. `config/ci_required_checks.json` is the committed topology authority; live classic protection and active rulesets still need a new accepting comparison. `scripts/ci/check_required_checks.sh` is informational only.

## No Analog Found

| New behavior | Reason and planner action |
|---|---|
| Complete, paginated, source-separated GitHub/Hex inventory and effective protection comparison | Existing remote scripts cover selected runs or legacy protection only. Implement against Phase 139 research/API contracts and completed Phase 134 disposition schema; fixture every incomplete/unauthorized source. |
| Portable redacted bundle plus verified local historical copy and locator | Existing receipts provide byte-hash patterns, but no complete Phase 139 retention contract. Reuse pinned artifact infrastructure after checking the actual workflow and repository retention limits. |
| Completed Phase 134–138 adapters | Use `validate_inbox_ledger.sh`, `verify_phase136_qualification.sh`, and `built_package_twin.py verify` with retained inputs/receipt; requalify source-dependent evidence on the closing SHA. |

## Metadata

**Analog search scope:** tracked `scripts/maintainer`, `scripts/ci`, `test/install_smoke`, `.github/workflows`, `RUNNING.md`, and package-consumer support.
**Primary analog set:** census collector, census validator, Nightly run verifier, Nightly fixture driver, CI workflow; supporting tracked policy, protection, package, and documentation files as cited.
**Pattern extraction date:** 2026-10-22.
