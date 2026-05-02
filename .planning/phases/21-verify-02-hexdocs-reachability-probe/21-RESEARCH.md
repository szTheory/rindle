# Phase 21: VERIFY-02 hexdocs.pm Reachability Probe - Research

**Researched:** 2026-05-01 [VERIFIED: 2026-05-01 session date]
**Domain:** GitHub Actions post-publish verification for HexDocs reachability [VERIFIED: .github/workflows/release.yml] [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md]
**Confidence:** HIGH [VERIFIED: repo artifacts + official docs + live host probe]

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Add the hexdocs reachability check as its own step inside `public_verify`, after `Wait for Hex.pm index (post-publish)` and before `Verify public Hex.pm artifact`. [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md]
- **D-02:** Probe `https://hexdocs.pm/rindle/$VERSION` as a public HTTP request that follows redirects and fails on final non-2xx status. [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md]
- **D-03:** Use `GET`, not `HEAD`, for the probe. Live checks on 2026-05-01 showed both `https://hexdocs.pm/rindle/0.1.4` and `https://hexdocs.pm/rindle` return `301` redirects to `/index.html`; a non-following or HEAD-only check would risk false negatives. [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md] [VERIFIED: curl -I https://hexdocs.pm/rindle/0.1.4] [VERIFIED: curl -I https://hexdocs.pm/rindle]
- **D-04:** Reuse the same bounded propagation posture already trusted for `mix hex.info` indexing: keep the docs probe aligned to the existing 5-minute / 15-second retry window rather than introducing a materially different timeout policy. [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md] [VERIFIED: .github/workflows/release.yml]
- **D-05:** Assert the probe through the existing install-smoke parity suite, primarily in `test/install_smoke/release_docs_parity_test.exs` and `test/install_smoke/package_metadata_test.exs`, not through a live network test. [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md]
- **D-06:** Update `guides/release_publish.md` in the same parity style as prior release changes so the step list and workflow-contract section both mention the docs reachability probe. [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md]

### Claude's Discretion
- Exact step name for the hexdocs probe, provided it stays clear in workflow logs and can be mirrored in parity tests. [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md]
- Exact `curl` flags and shell wording inside the probe loop. [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md]
- Whether the parity assertion lives entirely in `release_docs_parity_test.exs` or is split between that file and `package_metadata_test.exs`, so long as the workflow wiring is explicitly gated. [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md]

### Deferred Ideas (OUT OF SCOPE)
- If docs propagation proves materially slower than Hex index propagation in real releases, revisit whether the docs probe needs a separate retry envelope in a future phase. That is not pre-decided here. [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md]
- If maintainers later want stronger encapsulation, a dedicated shell helper for the hexdocs probe could be introduced in a future cleanup pass. This phase does not require a new script by default. [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| VERIFY-02 | Adopter can browse `hexdocs.pm/rindle` and find module documentation immediately after publish completes. [VERIFIED: .planning/REQUIREMENTS.md] | Add a redirect-following public HTTP probe to `public_verify`, mirror it in install-smoke parity tests, and document it in `guides/release_publish.md`. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/v1.3-MILESTONE-AUDIT.md] [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md] |
</phase_requirements>

## Summary

Phase 21 is a narrow CI-observability change, not a release-flow redesign. The existing release workflow already proves package availability by polling `mix hex.info rindle "$VERSION"` for up to 5 minutes and then running `bash scripts/public_smoke.sh "$VERSION"` on a fresh runner, but it never performs an HTTP request against the public HexDocs URL. That gap is explicit in the roadmap, the milestone audit, Phase 16 verification, and the phase context. [VERIFIED: .github/workflows/release.yml] [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/v1.3-MILESTONE-AUDIT.md] [VERIFIED: .planning/phases/16-live-publish-execution-and-post-publish-verification/16-VERIFICATION.md] [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md]

The implementation should stay in the existing `public_verify` job as one dedicated shell step between Hex index wait and package smoke. Official Hex docs state that `mix hex.publish` builds and publishes documentation automatically and that versioned docs are accessible at `https://hexdocs.pm/my_package/1.0.0`, while the unversioned package URL redirects to the latest published version. Live checks in this session also confirmed that both `https://hexdocs.pm/rindle/0.1.4` and `https://hexdocs.pm/rindle` return `301` first, so the probe must follow redirects and judge success on the final response. [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html] [VERIFIED: curl -I https://hexdocs.pm/rindle/0.1.4] [VERIFIED: curl -I https://hexdocs.pm/rindle] [VERIFIED: curl -sSL -o /dev/null -w 'code=%{http_code}' https://hexdocs.pm/rindle/0.1.4]

The repo already has the right backstops. `release_docs_parity_test.exs` asserts shipped step names and workflow-contract commands against `guides/release_publish.md`, and `package_metadata_test.exs` asserts `public_verify` topology and key snippets inside `.github/workflows/release.yml`. Planning should extend those existing tests instead of adding a live network test or a new standalone probe script. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] [VERIFIED: test/install_smoke/package_metadata_test.exs] [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md]

**Primary recommendation:** Add one inline `curl`-based GET probe step in `public_verify` that reuses the existing 5-minute/15-second retry envelope, then update the two install-smoke parity tests and `guides/release_publish.md` to lock that contract in place. [VERIFIED: .github/workflows/release.yml] [CITED: https://curl.se/docs/manpage.html] [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Post-publish docs reachability check | API / Backend | CDN / Static | The check is executed by GitHub Actions shell logic, but what it proves is reachability of the published static docs endpoint on `hexdocs.pm`. [VERIFIED: .github/workflows/release.yml] [VERIFIED: curl -I https://hexdocs.pm/rindle/0.1.4] |
| Hex.pm propagation wait | API / Backend | Database / Storage | The workflow polls Hex package index state via `mix hex.info`, which is already the repo’s trusted propagation gate. [VERIFIED: .github/workflows/release.yml] |
| Public package install smoke | API / Backend | CDN / Static | `scripts/public_smoke.sh` runs on a fresh runner and proves public package resolution after publish. [VERIFIED: scripts/public_smoke.sh] [VERIFIED: .github/workflows/release.yml] |
| Workflow/runbook parity enforcement | API / Backend | — | ExUnit install-smoke tests read workflow YAML and markdown to enforce drift detection before release time. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] [VERIFIED: test/install_smoke/package_metadata_test.exs] |

## Standard Stack

### Core
| Library / Tool | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| GitHub Actions workflow shell steps | Existing repo pattern; no new dependency. [VERIFIED: .github/workflows/release.yml] | Owns `public_verify` and is already where public release assertions run. [VERIFIED: .github/workflows/release.yml] | The probe belongs beside the existing Hex index wait and public smoke checks, not in application runtime code. [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md] |
| `curl` CLI | Local machine has `curl 8.7.1`; runner version is not pinned in repo. [VERIFIED: curl --version] | Perform an HTTPS GET, follow redirects, and fail the step on final non-2xx/transport failure. [CITED: https://curl.se/docs/manpage.html] [CITED: https://curl.se/docs/faq.html] | `curl` is already used in the workflow for MinIO setup, so it adds no new dependency surface. [VERIFIED: .github/workflows/release.yml] |
| ExUnit install-smoke tests | Elixir/Mix 1.19.5 locally; ExUnit is the repo’s existing test framework. [VERIFIED: mix --version] [VERIFIED: elixir --version] [VERIFIED: test/test_helper.exs] | Lock step names, workflow snippets, and runbook parity. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] [VERIFIED: test/install_smoke/package_metadata_test.exs] | The repo already uses these tests to guard release automation drift. [VERIFIED: test/install_smoke/package_metadata_test.exs] |

### Supporting
| Library / Tool | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `mix hex.info` | Hex task from installed Hex; version not pinned in repo. [VERIFIED: .github/workflows/release.yml] | Existing package-index propagation signal before public verification. [VERIFIED: .github/workflows/release.yml] | Keep using it for package availability; do not replace it with the docs probe. [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md] |
| `guides/release_publish.md` | Repo doc, no version. [VERIFIED: guides/release_publish.md] | Maintainer-facing release contract that parity tests already enforce. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] | Update whenever workflow step names or shipped commands change. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Inline workflow shell probe | New standalone script | Adds another artifact to maintain for a one-step loop the workflow already expresses clearly; the phase context explicitly says a new script is not required by default. [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md] |
| Parity tests | Live ExUnit network test | Would make local/unit CI flaky and violates the phase decision to assert wiring through install-smoke parity, not live network calls. [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md] |
| Dedicated docs probe step | Expanding `scripts/public_smoke.sh` | The context marks that expansion out of scope; package install smoke and docs HTTP reachability should stay separate observability checks. [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md] |

**Installation:** No new package installation is required for this phase. [VERIFIED: .github/workflows/release.yml] [VERIFIED: test/install_smoke/package_metadata_test.exs]

## Architecture Patterns

### System Architecture Diagram

```text
Release workflow trigger
  -> gate-ci-green
  -> publish
  -> public_verify
       -> Wait for Hex.pm index (mix hex.info loop)
       -> Probe https://hexdocs.pm/rindle/$VERSION (curl GET + redirects + bounded retry)
       -> Verify public Hex.pm artifact (scripts/public_smoke.sh)
       -> job success/failure

Runbook + parity tests
  -> guides/release_publish.md
  -> release_docs_parity_test.exs
  -> package_metadata_test.exs
  -> CI fails on workflow/doc drift
```
[VERIFIED: .github/workflows/release.yml] [VERIFIED: test/install_smoke/release_docs_parity_test.exs] [VERIFIED: test/install_smoke/package_metadata_test.exs]

### Recommended Project Structure
```text
.github/workflows/release.yml                  # add one docs probe step in public_verify
guides/release_publish.md                     # add step name + shipped command text
test/install_smoke/release_docs_parity_test.exs # assert step name and runbook/workflow command parity
test/install_smoke/package_metadata_test.exs  # assert public_verify topology and curl wiring snippet
```
[VERIFIED: .github/workflows/release.yml] [VERIFIED: guides/release_publish.md] [VERIFIED: test/install_smoke/release_docs_parity_test.exs] [VERIFIED: test/install_smoke/package_metadata_test.exs]

### Pattern 1: Inline Bounded Probe in `public_verify`
**What:** Add a shell loop in `.github/workflows/release.yml` that mirrors the existing Hex index wait envelope and uses `curl` to prove the public versioned docs URL. [VERIFIED: .github/workflows/release.yml] [CITED: https://curl.se/docs/manpage.html]
**When to use:** Use for post-publish checks that depend on eventually-consistent public infrastructure and must fail the workflow only after bounded retries. [VERIFIED: .github/workflows/release.yml]
**Example:** Inference from the existing Hex index wait loop plus official curl semantics for `--fail` and `--location`. [VERIFIED: .github/workflows/release.yml] [CITED: https://curl.se/docs/manpage.html]

```yaml
# Source basis: .github/workflows/release.yml wait loop + curl docs for --fail/--location.
- name: Verify HexDocs reachability
  env:
    VERSION: ${{ needs.publish.outputs.release_version }}
  run: |
    set -euo pipefail
    DEADLINE=$(( SECONDS + 300 ))
    URL="https://hexdocs.pm/rindle/$VERSION"

    until curl --silent --show-error --fail --location --output /dev/null "$URL"; do
      if [ "$SECONDS" -ge "$DEADLINE" ]; then
        echo "Release blocked: HexDocs did not serve $URL within 5 minutes."
        exit 1
      fi
      echo "Waiting for HexDocs to serve $URL..."
      sleep 15
    done

    echo "HexDocs is reachable at $URL."
```

### Pattern 2: Dual-Layer Parity Guard
**What:** Extend both install-smoke parity files so one test suite protects human-facing release docs and the other protects workflow topology/snippets. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] [VERIFIED: test/install_smoke/package_metadata_test.exs]
**When to use:** Use when a release-flow change must stay synchronized across workflow YAML and maintainer runbook prose. [VERIFIED: test/install_smoke/release_docs_parity_test.exs]
**Example:** The existing tests already assert literal step names and literal shipped commands. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] [VERIFIED: test/install_smoke/package_metadata_test.exs]

```elixir
# Source: test/install_smoke/release_docs_parity_test.exs / package_metadata_test.exs
assert release_guide =~ "Verify HexDocs reachability"
assert release_workflow =~ "Verify HexDocs reachability"
assert release_guide =~ ~s(curl --silent --show-error --fail --location --output /dev/null)
assert release_workflow =~ ~s(curl --silent --show-error --fail --location --output /dev/null)
```

### Anti-Patterns to Avoid
- **Do not use `HEAD` or a non-following request.** The live site returns `301` first for both versioned and unversioned docs URLs, so a raw initial-status check will misclassify a healthy docs page as failed. [VERIFIED: curl -I https://hexdocs.pm/rindle/0.1.4] [VERIFIED: curl -I https://hexdocs.pm/rindle] [VERIFIED: curl -sSL -o /dev/null -w 'code=%{http_code}' https://hexdocs.pm/rindle/0.1.4]
- **Do not fold the docs probe into `public_smoke.sh`.** The phase boundary explicitly keeps docs HTTP reachability separate from package install smoke. [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md]
- **Do not add a live network ExUnit test.** The locked decision is to assert wiring via parity tests, not to make the test suite depend on external uptime. [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Public docs HTTP verification | Custom Elixir HTTP client or a new Mix task | Inline `curl` in the workflow step | The workflow already runs shell steps, and `curl --fail --location` exactly matches the need with no repo-runtime dependency change. [CITED: https://curl.se/docs/manpage.html] [VERIFIED: .github/workflows/release.yml] |
| Docs propagation retry policy | New backoff algorithm | Reuse the existing `SECONDS + 300` / `sleep 15` loop shape | The repo already trusts that envelope for Hex package indexing, and D-04 locks alignment to that posture. [VERIFIED: .github/workflows/release.yml] [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md] |
| Workflow drift detection | New bespoke parser or snapshot harness | Extend `release_docs_parity_test.exs` and `package_metadata_test.exs` | Those files already assert step names, workflow contract commands, and `public_verify` topology. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] [VERIFIED: test/install_smoke/package_metadata_test.exs] |

**Key insight:** This phase closes an observability gap, so the cheapest correct implementation is a minimal workflow step plus parity assertions, not new runtime code. [VERIFIED: .planning/v1.3-MILESTONE-AUDIT.md] [VERIFIED: .planning/phases/16-live-publish-execution-and-post-publish-verification/16-VERIFICATION.md]

## Common Pitfalls

### Pitfall 1: Treating the First HTTP Status as Final Truth
**What goes wrong:** A probe without redirect following sees `301` and fails even though the docs page is healthy. [VERIFIED: curl -I https://hexdocs.pm/rindle/0.1.4]
**Why it happens:** HexDocs serves `/index.html` behind redirects for both `https://hexdocs.pm/rindle` and `https://hexdocs.pm/rindle/<version>` in current behavior. [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html] [VERIFIED: curl -I https://hexdocs.pm/rindle/0.1.4] [VERIFIED: curl -I https://hexdocs.pm/rindle]
**How to avoid:** Use `curl --location` and judge the final response after redirects. [CITED: https://curl.se/docs/manpage.html]
**Warning signs:** `curl -I` shows `301` with a `Location:` header to `/index.html`. [VERIFIED: curl -I https://hexdocs.pm/rindle/0.1.4]

### Pitfall 2: Using `curl` Without HTTP Failure Semantics
**What goes wrong:** A 404 or 500 can still return exit code 0 unless `curl` is told to fail on HTTP errors. [CITED: https://curl.se/docs/faq.html] [CITED: https://curl.se/docs/manpage.html]
**Why it happens:** By default, curl treats a completed HTTP transfer as success even if the response status is an application-level error. [CITED: https://curl.se/docs/faq.html]
**How to avoid:** Use `--fail` so 4xx/5xx produce a nonzero exit, which then fails the Actions step. [CITED: https://curl.se/docs/manpage.html] [CITED: https://docs.github.com/en/actions/how-tos/create-and-publish-actions/set-exit-codes]
**Warning signs:** The step prints an HTTP error page but still exits 0 when run without `--fail`. [CITED: https://curl.se/docs/faq.html]

### Pitfall 3: Moving the Probe Into the Wrong Boundary
**What goes wrong:** The docs check gets buried inside `public_smoke.sh` or a new helper, making the release workflow less explicit and parity tests harder to reason about. [VERIFIED: scripts/public_smoke.sh] [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md]
**Why it happens:** It is tempting to reuse an existing script instead of adding one clear workflow step. [VERIFIED: scripts/public_smoke.sh]
**How to avoid:** Keep the docs probe as a first-class `public_verify` step with its own step name. [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md]
**Warning signs:** The workflow diff no longer shows a named docs-reachability step between Hex index wait and public artifact verification. [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md]

## Code Examples

Verified patterns from official sources and current repo artifacts:

### Bounded GET Probe With Redirects
```bash
# Source basis: https://curl.se/docs/manpage.html + .github/workflows/release.yml
set -euo pipefail
DEADLINE=$(( SECONDS + 300 ))
URL="https://hexdocs.pm/rindle/$VERSION"

until curl --silent --show-error --fail --location --output /dev/null "$URL"; do
  if [ "$SECONDS" -ge "$DEADLINE" ]; then
    echo "Release blocked: HexDocs did not serve $URL within 5 minutes."
    exit 1
  fi
  sleep 15
done
```

### Workflow/Runbook Parity Assertion
```elixir
# Source: test/install_smoke/release_docs_parity_test.exs pattern
for snippet <- [
      "Verify HexDocs reachability",
      "curl --silent --show-error --fail --location --output /dev/null"
    ] do
  assert release_guide =~ snippet
  assert release_workflow =~ snippet
end
```

### Workflow Topology Assertion
```elixir
# Source: test/install_smoke/package_metadata_test.exs pattern
assert workflow =~ "public_verify:"
assert workflow =~ "name: Wait for Hex.pm index (post-publish)"
assert workflow =~ "name: Verify HexDocs reachability"
assert workflow =~ "name: Verify public Hex.pm artifact"
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Infer docs availability from `mix hex.publish --yes` and docs build success alone. [VERIFIED: .planning/phases/16-live-publish-execution-and-post-publish-verification/16-VERIFICATION.md] | Explicitly probe the public versioned HexDocs URL in CI after publish. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/v1.3-MILESTONE-AUDIT.md] | Routed to Phase 21 on 2026-05-01 in roadmap/audit/context artifacts. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/v1.3-MILESTONE-AUDIT.md] [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md] | Closes the last VERIFY-02 observability gap without changing publish semantics. [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md] |
| Check raw URL status only. [ASSUMED] | Follow redirects and evaluate final response. [CITED: https://curl.se/docs/manpage.html] [VERIFIED: curl -I https://hexdocs.pm/rindle/0.1.4] | Needed under current live host behavior observed 2026-05-02 UTC. [VERIFIED: curl -I https://hexdocs.pm/rindle/0.1.4] | Prevents false negatives against healthy `/index.html` redirects. [VERIFIED: curl -sSL -o /dev/null -w 'code=%{http_code} final=%{url_effective}' https://hexdocs.pm/rindle/0.1.4] |

**Deprecated/outdated:**
- A docs check that uses `HEAD` or does not follow redirects is outdated for this phase’s target URL because the live endpoint currently redirects before serving content. [VERIFIED: curl -I https://hexdocs.pm/rindle/0.1.4] [VERIFIED: curl -I https://hexdocs.pm/rindle]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | “Check raw URL status only” is the previously assumed/naive approach worth comparing against. [ASSUMED] | State of the Art | Low; it does not affect the recommended implementation, which is verified independently. |

## Open Questions (RESOLVED)

1. **RESOLVED: Use the shorter step name `Verify HexDocs reachability`.** [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md]
   - Reason: parity tests already assert literal step names, so the name should stay stable, concise, and readable in workflow logs. [VERIFIED: test/install_smoke/release_docs_parity_test.exs]
   - Outcome: the workflow, runbook, and parity tests should all mirror `Verify HexDocs reachability` exactly. [VERIFIED: test/install_smoke/release_docs_parity_test.exs]

2. **RESOLVED: In `package_metadata_test.exs`, assert distinctive probe substrings rather than one giant exact `curl` line.** [VERIFIED: test/install_smoke/package_metadata_test.exs]
   - Reason: the file already checks literal workflow snippets, but asserting `curl`, `--fail`, `--location`, the URL shape, ordering, and retry-cadence substrings separately stays robust to harmless flag reordering while still locking the contract. [VERIFIED: test/install_smoke/package_metadata_test.exs] [CITED: https://curl.se/docs/manpage.html]
   - Outcome: the workflow wiring test should assert the new step name, placement between index wait and `public_smoke.sh`, and the bounded retry markers (`DEADLINE=$(( SECONDS + 300 ))`, `sleep 15`, timeout message). [VERIFIED: .github/workflows/release.yml]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `mix` | Local parity tests | ✓ [VERIFIED: command -v mix] | Mix 1.19.5 [VERIFIED: mix --version] | — |
| `elixir` | Local parity tests | ✓ [VERIFIED: command -v elixir] | Elixir 1.19.5 / OTP 28 [VERIFIED: elixir --version] | — |
| `curl` | Probe implementation and local reproduction | ✓ [VERIFIED: command -v curl] | 8.7.1 locally [VERIFIED: curl --version] | None for the planned workflow shape. |
| `rg` | Fast local text assertions during development | ✓ [VERIFIED: command -v rg] | 15.1.0 [VERIFIED: rg --version] | `grep` if needed. [VERIFIED: scripts/assert_release_docs_html.sh] |
| GitHub-hosted runner / remote workflow execution | End-to-end live release proof | Remote-only [VERIFIED: .github/workflows/release.yml] | `ubuntu-latest` not pinned beyond workflow label. [VERIFIED: .github/workflows/release.yml] | Local parity tests can verify wiring, but not live post-publish behavior. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] |

**Missing dependencies with no fallback:**
- None for planning. Live end-to-end proof still requires an actual GitHub Actions run after release, which local tests cannot substitute. [VERIFIED: .github/workflows/release.yml]

**Missing dependencies with fallback:**
- None. [VERIFIED: local environment audit]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit on Elixir/Mix 1.19.5 locally. [VERIFIED: test/test_helper.exs] [VERIFIED: mix --version] |
| Config file | `test/test_helper.exs`. [VERIFIED: test/test_helper.exs] |
| Quick run command | `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs test/install_smoke/package_metadata_test.exs`. [VERIFIED: repo test files] |
| Full suite command | `MIX_ENV=test mix test`. [VERIFIED: ExUnit repo layout] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| VERIFY-02 | `public_verify` contains a redirect-following docs probe step and the runbook documents it. [VERIFIED: .planning/ROADMAP.md] | install-smoke parity | `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs test/install_smoke/package_metadata_test.exs` | ✅ [VERIFIED: test/install_smoke/release_docs_parity_test.exs] [VERIFIED: test/install_smoke/package_metadata_test.exs] |

### Sampling Rate
- **Per task commit:** `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs test/install_smoke/package_metadata_test.exs`. [VERIFIED: repo test targets]
- **Per wave merge:** `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs test/install_smoke/package_metadata_test.exs`. [VERIFIED: phase scope]
- **Phase gate:** Same parity suite green locally, then rely on the next real `Release` workflow execution for live post-publish confirmation. [VERIFIED: .github/workflows/release.yml]

### Wave 0 Gaps
- None — existing test infrastructure already covers workflow/runbook parity for this kind of release-flow change. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] [VERIFIED: test/install_smoke/package_metadata_test.exs]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no [VERIFIED: phase scope] | `HEX_API_KEY` is not used in the docs probe step; the check is intentionally public. [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md] |
| V3 Session Management | no [VERIFIED: phase scope] | No session state is introduced. [VERIFIED: phase scope] |
| V4 Access Control | no [VERIFIED: phase scope] | The probe hits a public HTTPS endpoint only. [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md] |
| V5 Input Validation | yes [VERIFIED: shell-based implementation] | Keep `$VERSION` quoted and URL construction constant-scoped inside the workflow shell step. [VERIFIED: existing workflow quoting style in .github/workflows/release.yml] |
| V6 Cryptography | yes [VERIFIED: HTTPS probe] | Use `https://hexdocs.pm/...` and rely on curl’s normal TLS verification; do not add `-k`. [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md] [CITED: https://curl.se/index.html] |

### Known Threat Patterns for this Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Shell injection via interpolated version string | Tampering | Keep `URL="https://hexdocs.pm/rindle/$VERSION"` and always quote `"$URL"`; do not eval or concatenate unquoted shell fragments. [VERIFIED: existing shell style in .github/workflows/release.yml] |
| False-negative verification from redirects | Denial of service | Use `curl --location` and bounded retries. [CITED: https://curl.se/docs/manpage.html] [VERIFIED: curl -I https://hexdocs.pm/rindle/0.1.4] |
| Silent HTTP failure treated as success | Repudiation | Use `curl --fail` so 4xx/5xx become nonzero and fail the GitHub Actions step. [CITED: https://curl.se/docs/manpage.html] [CITED: https://docs.github.com/en/actions/how-tos/create-and-publish-actions/set-exit-codes] |

## Sources

### Primary (HIGH confidence)
- `.planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md` - locked scope, placement, retry policy, parity-test boundary. [VERIFIED: repo file]
- `.planning/ROADMAP.md` - Phase 21 goal and success criteria. [VERIFIED: repo file]
- `.planning/REQUIREMENTS.md` - VERIFY-02 wording and traceability state. [VERIFIED: repo file]
- `.planning/v1.3-MILESTONE-AUDIT.md` - G4 gap definition and closure requirement. [VERIFIED: repo file]
- `.planning/phases/16-live-publish-execution-and-post-publish-verification/16-VERIFICATION.md` - VERIFY-02 forward reference to Phase 21. [VERIFIED: repo file]
- `.github/workflows/release.yml` - existing `public_verify` topology and polling pattern. [VERIFIED: repo file]
- `guides/release_publish.md` - current runbook content and parity target. [VERIFIED: repo file]
- `test/install_smoke/release_docs_parity_test.exs` - release guide/workflow parity pattern. [VERIFIED: repo file]
- `test/install_smoke/package_metadata_test.exs` - workflow topology/snippet assertions. [VERIFIED: repo file]
- `https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html` - docs publish semantics, versioned docs URL, redirect behavior of unversioned docs URL, revert/docs-only publish semantics. [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html]
- `https://curl.se/docs/manpage.html` - `--fail`, `--location`, `--retry-all-errors` semantics. [CITED: https://curl.se/docs/manpage.html]
- `https://curl.se/docs/faq.html` - default curl treatment of HTTP status codes. [CITED: https://curl.se/docs/faq.html]
- `https://docs.github.com/en/actions/how-tos/create-and-publish-actions/set-exit-codes` - nonzero exit code causes action failure. [CITED: https://docs.github.com/en/actions/how-tos/create-and-publish-actions/set-exit-codes]
- Live host probes run on 2026-05-02 UTC against `https://hexdocs.pm/rindle` and `https://hexdocs.pm/rindle/0.1.4`. [VERIFIED: curl commands in this session]

### Secondary (MEDIUM confidence)
- None. [VERIFIED: source review]

### Tertiary (LOW confidence)
- None beyond the single explicitly logged assumption. [VERIFIED: assumptions table]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all recommendations are derived from current repo artifacts plus official curl/Hex docs, with no new dependency selection required. [VERIFIED: repo files] [CITED: https://curl.se/docs/manpage.html] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html]
- Architecture: HIGH - the exact integration point is locked in context and already exists in the workflow topology. [VERIFIED: .planning/phases/21-verify-02-hexdocs-reachability-probe/21-CONTEXT.md] [VERIFIED: .github/workflows/release.yml]
- Pitfalls: HIGH - redirect and curl failure semantics were confirmed against official docs and live host behavior in this session. [CITED: https://curl.se/docs/manpage.html] [CITED: https://curl.se/docs/faq.html] [VERIFIED: curl -I https://hexdocs.pm/rindle/0.1.4]

**Research date:** 2026-05-01 [VERIFIED: session date]
**Valid until:** 2026-05-08 for host-behavior checks; 2026-05-31 for repo-structure findings. [VERIFIED: live host behavior is time-sensitive] [VERIFIED: repo artifacts are relatively stable]
