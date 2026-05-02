# Phase 21: verify-02-hexdocs-reachability-probe - Pattern Map

**Mapped:** 2026-05-01
**Files analyzed:** 4
**Analogs found:** 4 / 4

## Scope Recommendation

This phase should stay **one plan**, not multiple.

Reason:
- The workflow step name, runbook step list, workflow-contract command list, and parity assertions form one release-contract change.
- Splitting workflow/doc/test updates would create temporary parity failures by design.
- The smallest coherent change set is one vertical slice across `.github/workflows/release.yml`, `guides/release_publish.md`, `test/install_smoke/release_docs_parity_test.exs`, and `test/install_smoke/package_metadata_test.exs`.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `.github/workflows/release.yml` | config | request-response | `.github/workflows/release.yml` `public_verify` wait + smoke steps | exact |
| `guides/release_publish.md` | config | request-response | `guides/release_publish.md` routine release + workflow contract sections | exact |
| `test/install_smoke/release_docs_parity_test.exs` | test | request-response | `release guide names all live workflow step names...` and `...all shipped repo commands...` tests | exact |
| `test/install_smoke/package_metadata_test.exs` | test | request-response | `release workflow automates public verification on a fresh runner` test | exact |

## Pattern Assignments

### `.github/workflows/release.yml` (config, request-response)

**Analog:** `.github/workflows/release.yml`

**Job topology and placement pattern** ([`.github/workflows/release.yml`](/Users/jon/projects/rindle/.github/workflows/release.yml:370), lines 370-373):
```yaml
  public_verify:
    name: Public Verify
    needs: [gate-ci-green, publish]
    if: ${{ always() && needs.publish.result == 'success' }}
```

Planner guidance:
- Keep the docs probe inside `public_verify`.
- Insert it between the existing index wait and public smoke step.
- Do not move the probe into `publish` or into `scripts/public_smoke.sh`.

**Existing bounded retry loop to copy** ([`.github/workflows/release.yml`](/Users/jon/projects/rindle/.github/workflows/release.yml:447), lines 447-461):
```yaml
      - name: Wait for Hex.pm index (post-publish)
        env:
          VERSION: ${{ needs.publish.outputs.release_version }}
        run: |
          set -euo pipefail
          DEADLINE=$(( SECONDS + 300 ))
          until mix hex.info rindle "$VERSION" >/dev/null 2>&1; do
            if [ "$SECONDS" -ge "$DEADLINE" ]; then
              echo "Release blocked: Hex.pm did not index rindle $VERSION within 5 minutes."
              exit 1
            fi
            echo "Waiting for Hex.pm to index rindle $VERSION..."
            sleep 15
          done
          echo "Hex.pm indexed rindle $VERSION."
```

Planner guidance:
- Mirror this retry posture exactly for the HexDocs probe: `set -euo pipefail`, `DEADLINE`, `SECONDS`, `sleep 15`, explicit success/failure `echo`.
- Prefer adding a new `curl`-based loop inline rather than introducing a helper script. Context explicitly says no new script by default.

**Existing post-publish public-check step naming pattern** ([`.github/workflows/release.yml`](/Users/jon/projects/rindle/.github/workflows/release.yml:463), lines 463-467):
```yaml
      - name: Verify public Hex.pm artifact
        env:
          HEX_API_KEY: ""
          VERSION: ${{ needs.publish.outputs.release_version }}
        run: bash scripts/public_smoke.sh "$VERSION"
```

Planner guidance:
- New step names should use imperative title case like the existing workflow: `Wait for ...`, `Verify ...`, `Publish ...`, `Check whether ...`.
- Keep the name literal and stable because tests assert on raw strings, not parsed YAML structure.
- Use `VERSION: ${{ needs.publish.outputs.release_version }}` in the probe step env, matching the surrounding steps.

**Boundary analog for shell style** ([`scripts/assert_release_docs_html.sh`](/Users/jon/projects/rindle/scripts/assert_release_docs_html.sh:1), lines 1-20):
```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${RINDLE_PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DOC_DIR="${1:-$ROOT_DIR/doc}"
```

Planner guidance:
- Use the same shell discipline in YAML `run: |` blocks: fail-fast shell, simple env-driven inputs, plain `echo` diagnostics.
- This script is only a style analog. Do not factor the HexDocs probe into this file.

### `guides/release_publish.md` (config, request-response)

**Analog:** `guides/release_publish.md`

**Routine step-list parity pattern** ([`guides/release_publish.md`](/Users/jon/projects/rindle/guides/release_publish.md:72), lines 72-85):
```markdown
Run this sequence on every release after the inaugural publish:

1. Merge the Release Please PR on `main`.
2. Wait for the `Release` workflow to complete these step names in order:
   - `Release Please`
   - `Wait for CI to finish green on release SHA`
   - `Run release preflight`
   - `Verify version alignment`
   - `Check whether Hex.pm release already exists`
   - `Dry run Hex publish`
   - `Publish to Hex.pm (live)`
   - `Wait for Hex.pm index (post-publish)`
   - `Verify public Hex.pm artifact`
```

Planner guidance:
- Add the new docs probe here by exact step name.
- Preserve order and bullet formatting exactly; parity tests assert literal membership of step names.

**Workflow-contract command-list parity pattern** ([`guides/release_publish.md`](/Users/jon/projects/rindle/guides/release_publish.md:87), lines 87-104):
```markdown
## Release Workflow Contract

The repository workflow runs these shipped commands:

```bash
bash scripts/release_preflight.sh
bash scripts/assert_version_match.sh
bash scripts/hex_release_exists.sh
mix hex.publish --dry-run --yes
mix hex.publish --yes
bash scripts/public_smoke.sh
```
```

Planner guidance:
- This section must mention the docs probe contract too.
- Since the probe is likely inline `curl`, document the observable command or behavior in the same concrete style as the current list.
- Keep the wording imperative and factual; avoid speculative prose.

### `test/install_smoke/release_docs_parity_test.exs` (test, request-response)

**Analog:** `test/install_smoke/release_docs_parity_test.exs`

**Shared file-loading pattern** ([`test/install_smoke/release_docs_parity_test.exs`](/Users/jon/projects/rindle/test/install_smoke/release_docs_parity_test.exs:11), lines 11-20):
```elixir
  setup_all do
    {:ok,
     %{
       mix_exs: File.read!(@mix_exs_path),
       release_guide: File.read!(@release_guide_path),
       release_workflow: File.read!(@release_workflow_path),
       operations: File.read!(@operations_path),
       readme: File.read!(@readme_path),
       getting_started: File.read!(@getting_started_path)
     }}
  end
```

Planner guidance:
- Extend existing parity assertions; do not add filesystem parsing helpers unless necessary.
- This file favors whole-file string assertions loaded once in `setup_all`.

**Step-name parity assertion pattern** ([`test/install_smoke/release_docs_parity_test.exs`](/Users/jon/projects/rindle/test/install_smoke/release_docs_parity_test.exs:104), lines 104-124):
```elixir
  test "release guide names all live workflow step names matching the shipped release workflow",
       %{
         release_guide: release_guide,
         release_workflow: release_workflow
       } do
    step_names = [
      "Release Please",
      "Wait for CI to finish green on release SHA",
      "Run release preflight",
      "Verify version alignment",
      "Check whether Hex.pm release already exists",
      "Dry run Hex publish",
      "Publish to Hex.pm (live)",
      "Wait for Hex.pm index (post-publish)",
      "Verify public Hex.pm artifact"
    ]

    for step_name <- step_names do
      assert release_guide =~ step_name
      assert release_workflow =~ step_name
    end
  end
```

Planner guidance:
- Add the new step name to this single `step_names` list.
- Preserve the `for ... assert ...` style instead of splitting into many one-off assertions.
- This file is the primary place for release-guide/workflow naming parity.

**Command parity assertion pattern** ([`test/install_smoke/release_docs_parity_test.exs`](/Users/jon/projects/rindle/test/install_smoke/release_docs_parity_test.exs:127), lines 127-143):
```elixir
  test "release guide includes all shipped repo commands matching the live workflow contract", %{
    release_guide: release_guide,
    release_workflow: release_workflow
  } do
    commands = [
      "bash scripts/release_preflight.sh",
      "bash scripts/assert_version_match.sh",
      "bash scripts/hex_release_exists.sh",
      "mix hex.publish --dry-run --yes",
      "mix hex.publish --yes",
      "bash scripts/public_smoke.sh"
    ]

    for command <- commands do
      assert release_guide =~ command
      assert release_workflow =~ command
    end
  end
```

Planner guidance:
- If the docs probe is documented as a concrete command snippet, assert it here too.
- Keep string-based parity tests. Do not introduce YAML parsing or Markdown parsing for this phase.

### `test/install_smoke/package_metadata_test.exs` (test, request-response)

**Analog:** `test/install_smoke/package_metadata_test.exs`

**Workflow topology assertion style** ([`test/install_smoke/package_metadata_test.exs`](/Users/jon/projects/rindle/test/install_smoke/package_metadata_test.exs:130), lines 130-151):
```elixir
  test "release workflow automates public verification on a fresh runner", %{
    release_workflow: workflow
  } do
    assert workflow =~ "Release Please"
    assert workflow =~ "Gate on Exact-SHA Green CI"
    assert workflow =~ "workflow_dispatch:"
    assert workflow =~ "recovery_reason:"
    assert workflow =~ "recovery_ref:"
    assert workflow =~ "Wait for CI to finish green on release SHA"
    assert workflow =~ "workflow_id: 'ci.yml'"
    assert workflow =~ "name: Check whether Hex.pm release already exists"
    assert workflow =~ "mix hex.publish --dry-run --yes"
    assert workflow =~ "name: Publish to Hex.pm (live)"
    assert workflow =~ "mix hex.publish --yes"
    assert workflow =~ "public_verify:"
    assert workflow =~ "needs: [gate-ci-green, publish]"
    assert workflow =~ "name: Wait for Hex.pm index (post-publish)"
    assert workflow =~ "name: Verify public Hex.pm artifact"
    assert workflow =~ ~s(HEX_API_KEY: "")
    assert workflow =~ ~s(mix hex.info rindle "$VERSION")
    assert workflow =~ ~s(bash scripts/public_smoke.sh "$VERSION")
  end
```

Planner guidance:
- This is the right analog for wiring assertions inside `public_verify`.
- Add assertions here for the new step name and for its core probe snippet, likely `curl` plus the HexDocs URL.
- Keep the style flat: direct `assert workflow =~ ...` lines, no helper abstractions.

**Existing env/string assertion style** ([`test/install_smoke/package_metadata_test.exs`](/Users/jon/projects/rindle/test/install_smoke/package_metadata_test.exs:153), lines 153-186):
```elixir
  test "release workflow gates publish on idempotency probe", %{release_workflow: workflow} do
    assert workflow =~ "bash scripts/hex_release_exists.sh"
    assert workflow =~ "id: idempotency"
    assert workflow =~ "if: ${{ steps.idempotency.outputs.already_published != 'true' }}"
  end
```

Planner guidance:
- Use this file for exact workflow-snippet guarding, not for docs prose parity.
- Prefer checking for a few distinctive substrings from the probe loop rather than asserting the entire multi-line block verbatim.

## Shared Patterns

### Assertion Style
**Sources:** [`test/install_smoke/release_docs_parity_test.exs`](/Users/jon/projects/rindle/test/install_smoke/release_docs_parity_test.exs:104), [`test/install_smoke/package_metadata_test.exs`](/Users/jon/projects/rindle/test/install_smoke/package_metadata_test.exs:130)
```elixir
for step_name <- step_names do
  assert release_guide =~ step_name
  assert release_workflow =~ step_name
end

assert workflow =~ "public_verify:"
assert workflow =~ "name: Wait for Hex.pm index (post-publish)"
```

Apply to:
- New workflow-step parity checks
- New runbook/workflow contract checks

Recommendation:
- Use string membership assertions.
- Avoid parser-heavy tests for this phase.
- Keep one responsibility split: `release_docs_parity_test.exs` for runbook parity, `package_metadata_test.exs` for workflow wiring.

### YAML Step Naming Convention
**Source:** [`guides/release_publish.md`](/Users/jon/projects/rindle/guides/release_publish.md:75), [`test/install_smoke/release_docs_parity_test.exs`](/Users/jon/projects/rindle/test/install_smoke/release_docs_parity_test.exs:109)
```text
Release Please
Wait for CI to finish green on release SHA
Check whether Hex.pm release already exists
Wait for Hex.pm index (post-publish)
Verify public Hex.pm artifact
```

Apply to:
- The new HexDocs probe step name

Recommendation:
- Use imperative title case.
- Include the external system name when relevant (`Hex.pm`, `HexDocs`).
- Keep parenthetical qualifiers only when they disambiguate timing, as with `(post-publish)`.

### Retry/Failure Messaging Pattern
**Source:** [`release.yml`](/Users/jon/projects/rindle/.github/workflows/release.yml:450), [`scripts/assert_release_docs_html.sh`](/Users/jon/projects/rindle/scripts/assert_release_docs_html.sh:18)
```bash
set -euo pipefail
DEADLINE=$(( SECONDS + 300 ))
if [ "$SECONDS" -ge "$DEADLINE" ]; then
  echo "Release blocked: ..."
  exit 1
fi
echo "Waiting for ..."
```

Apply to:
- The new docs reachability probe loop

Recommendation:
- Use the same 300-second / 15-second cadence.
- Emit one clear wait message and one clear terminal failure message.
- Follow redirects and fail on final non-2xx response.

## Planner Recommendations

- Treat this as **one plan** with four coordinated edits.
- Primary file order:
  1. `.github/workflows/release.yml`
  2. `guides/release_publish.md`
  3. `test/install_smoke/release_docs_parity_test.exs`
  4. `test/install_smoke/package_metadata_test.exs`
- Keep `scripts/public_smoke.sh` unchanged unless implementation reveals a hard blocker. Current context says the phase should not absorb the docs probe into that script.
- Do not add a standalone probe script unless the inline YAML becomes materially unreadable. Existing repo convention for this exact contract change favors inline workflow logic plus parity tests.

## No Analog Found

None. All expected edits have direct in-repo analogs.

## Metadata

**Analog search scope:** `.github/workflows`, `guides`, `test/install_smoke`, `scripts`
**Files scanned:** 7
**Pattern extraction date:** 2026-05-01
