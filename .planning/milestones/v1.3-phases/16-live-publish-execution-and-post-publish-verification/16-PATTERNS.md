# Phase 16: Live Publish Execution and Post-Publish Verification — Pattern Map

**Mapped:** 2026-04-30
**Files analyzed:** 8 (1 NEW shell, 1 NEW test, 1 NEW evidence, 5 MODIFIED)
**Analogs found:** 7 / 8 (1 NEW shim helper has no direct analog — pattern documented)

## File Classification

| New / Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------------|------|-----------|----------------|---------------|
| `scripts/hex_release_exists.sh` (NEW) | shell script (idempotency probe) | env-in → stdout `already_published=...` + `$GITHUB_OUTPUT` write; stderr diagnostics; exit-code semantics | `scripts/release_preflight.sh` (RINDLE_PROJECT_ROOT + trap) + `scripts/assert_version_match.sh` (stderr + exit semantics + `Mix.Project.config()` idiom) | exact (composite) |
| `test/install_smoke/hex_release_exists_test.exs` (NEW) | ExUnit unit test wrapping shell script | inject env → `System.cmd("bash", …)` → assert stdout/exit | `test/install_smoke/package_metadata_test.exs` (specifically `build_package!/0` `System.cmd` shape at lines 156–178; `setup_all` File.read! shape at 21–40) | exact |
| `test/install_smoke/support/fake_hex_bin.sh` (NEW) | Bash shim factory writing PATH-prepended fake `mix`/`curl` binaries driven by env vars | called from ExUnit test; emits temp shim dir path | **No direct analog** — pattern documented inline (see "No Analog Found" §) | none |
| `.planning/phases/16-…/16-REVERT-REHEARSAL.md` (NEW) | Markdown evidence file (signed transcript) | unshipped tabletop record; review-only validation | `.planning/phases/15-…/15-RELEASE-CANDIDATE-CHECKLIST.md` (signed-evidence template; status header + sectioned proof + command transcript blocks) | exact |
| `.github/workflows/release.yml` (MODIFIED) | GitHub Actions workflow YAML | tag push or `workflow_dispatch` → publish lane → public verify | itself (preserve overall topology; modify `concurrency`, version-parse step, publish job step list, names) | self |
| `guides/release_publish.md` (MODIFIED) | Markdown maintainer runbook | reader-facing prose; parity-tested against `release.yml` substrings | itself (current 195-line runbook; pattern parity tests already enforce shape) | self |
| `CHANGELOG.md` (MODIFIED) | Markdown changelog (release-please managed below the new note) | append-only history (immutable past entries) | itself (existing release-please table at top) | self |
| `test/install_smoke/release_docs_parity_test.exs` (MODIFIED) | ExUnit parity test (markdown ↔ workflow snippet assertions) | extend existing `for snippet <- […] do assert release_guide =~ snippet end` patterns | itself (lines 36–45 personal-first owner snippets; lines 51–60 diagnostic-vs-authoritative snippets; lines 105–114 `step_names` list; lines 129–135 `commands` list) | self |
| `test/install_smoke/package_metadata_test.exs` (MODIFIED) | ExUnit parity test (workflow YAML substrings + tarball shape) | extend existing `assert workflow =~ …` block + `setup_all` File.read! reads | itself (lines 126–145 `release workflow automates public verification` block; line 167–172 `System.cmd("mix", …)` model) | self |

## Pattern Assignments

### `scripts/hex_release_exists.sh` (NEW shell script, env-in / stdout-out)

**Composite analog:** `scripts/release_preflight.sh` (lines 1–25) for `RINDLE_PROJECT_ROOT` + trap discipline; `scripts/assert_version_match.sh` (lines 1–14, 24–36) for stderr discipline and exit-code semantics.

**Header pattern — `set -euo pipefail` + `RINDLE_PROJECT_ROOT`** (`scripts/release_preflight.sh` lines 1–25):
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR="${RINDLE_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PACKAGE_ROOT="${RINDLE_INSTALL_SMOKE_PACKAGE_ROOT:-}"
WORK_DIR=""
KEEP_ARTIFACT="${RINDLE_RELEASE_PREFLIGHT_KEEP_ARTIFACT:-}"

cleanup() {
  if [ -n "$WORK_DIR" ] && [ -z "$KEEP_ARTIFACT" ]; then
    rm -rf "$WORK_DIR"
  elif [ -n "$WORK_DIR" ]; then
    echo "Keeping unpacked artifact at $PACKAGE_ROOT"
  fi
}

trap cleanup EXIT
…
cd "$ROOT_DIR"
```

**Lighter header pattern (no temp dir / no trap needed)** — `scripts/assert_version_match.sh` lines 1–7:
```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${RINDLE_PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Change to root dir so mix can find mix.exs
cd "$ROOT_DIR"
```
The probe script does NOT need temp dirs or cleanup traps; copy this lighter header verbatim. It already aligns with the workspace `RINDLE_PROJECT_ROOT` convention enumerated in CONTEXT §code_context.

**Stderr discipline + `::error::` annotation** — `scripts/assert_version_match.sh` lines 24–36:
```bash
if [ "$MIX_VERSION" != "$TAG_VERSION" ]; then
  echo "::error::Release ref version ($TAG_VERSION) does not match mix.exs version ($MIX_VERSION). Aborting publish." >&2
  exit 1
fi

if [ -z "$EXPECTED_VERSION" ] && [ -z "$RELEASE_REF" ]; then
  echo "::error::Set RINDLE_EXPECTED_VERSION or RINDLE_RELEASE_TAG (or run in GitHub Actions with GITHUB_REF_NAME)." >&2
  exit 1
fi
…
echo "Version matches: $MIX_VERSION"
```
**Adapt** — the probe script must NEVER pollute stdout with diagnostics. Stdout is reserved for the single trailing line `already_published=true|false` (which the workflow pipes to `$GITHUB_OUTPUT`, per RESEARCH Pitfall 4). Diagnostics go to `>&2` exactly as above. Use `::error::` annotation for the inconclusive-both-probes case (RESEARCH Pitfall 8: Probe must distinguish `mix hex.info` exit 1 from network failure — fall back to curl, and if both fail, exit non-zero with diagnostic — never silently emit `already_published=false`).

**Mix invocation already used downstream** — `.github/workflows/release.yml` lines 408–422 (`Wait for Hex.pm index` step):
```bash
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
**Reuse verbatim** — `mix hex.info rindle <version>` exit-code semantic (0 = exists, 1 = missing OR transient). The probe script invokes the same command but interprets it differently: exit 0 → published; exit 1 → fall through to curl HTTP fallback (RESEARCH Pitfall 8 + D-09 defense-in-depth).

**HTTP fallback (curl) — no in-repo analog**, so reuse the existing curl shape from `release.yml` lines 282–289 (MinIO health probe):
```bash
for _ in $(seq 1 30); do
  if curl -fsS http://localhost:9000/minio/health/ready >/dev/null; then
    exit 0
  fi
  sleep 2
done
exit 1
```
**Adapt** — single-shot, not loop. Probe URL is `https://hex.pm/api/packages/rindle/<VERSION>` (or `/releases/<VERSION>`); HTTP 200 → `already_published=true`; HTTP 404 → `already_published=false`; non-200/non-404 (transient) → inconclusive → exit non-zero.

**`$GITHUB_OUTPUT` write convention** — `release.yml` lines 75–85 (recovery-validation):
```bash
if [[ "$recovery_ref" =~ ^[0-9a-f]{40}$ ]]; then
  git cat-file -e "${recovery_ref}^{commit}"
  echo "checkout_ref=$recovery_ref" >> "$GITHUB_OUTPUT"
  echo "release_tag=" >> "$GITHUB_OUTPUT"
elif git show-ref --verify --quiet "refs/tags/$recovery_ref"; then
  echo "checkout_ref=$recovery_ref" >> "$GITHUB_OUTPUT"
…
```
**Adapt** — the probe writes a single line: `echo "already_published=true" >> "$GITHUB_OUTPUT"` (or `false`). The script must also echo it to stdout for the unit test to capture (per Validation Matrix row 1). Mirror this by appending `>> "$GITHUB_OUTPUT"` only when the env var `GITHUB_OUTPUT` is set; print to stdout unconditionally so the unit test can assert it.

**Forbidden patterns (negative parity assertion per RESEARCH Pitfall 3):** the probe MUST NOT call `mix hex.user` or `mix hex.owner` (auth-required, would break in CI). Document inline as a comment.

---

### `test/install_smoke/hex_release_exists_test.exs` (NEW ExUnit unit test)

**Analog:** `test/install_smoke/package_metadata_test.exs`

**`setup_all` File.read! pattern** — `package_metadata_test.exs` lines 21–40:
```elixir
setup_all do
  package_root = build_package!()
  metadata_path = Path.join(package_root, "hex_metadata.config")

  on_exit(fn ->
    File.rm_rf(Path.dirname(package_root))
  end)

  {:ok,
   %{
     package_root: package_root,
     metadata: File.read!(metadata_path),
     script: File.read!(@preflight_script),
     …
     release_workflow: File.read!(@release_workflow),
     …
   }}
end
```
**Adapt** — for the probe test, `setup_all` should resolve and `File.exists?` the new `scripts/hex_release_exists.sh` path; per-test setup builds a temp shim dir using the new `support/fake_hex_bin.sh` factory.

**`System.cmd` wrapper around bash with env injection** — `package_metadata_test.exs` lines 167–172 (the canonical `System.cmd` model RESEARCH Wave 0 Gaps line 93 cites):
```elixir
{output, 0} =
  System.cmd("mix", ["hex.build", "--unpack", "--output", package_root],
    cd: @repo_root,
    env: [{"MIX_ENV", "dev"}],
    stderr_to_stdout: true
  )

assert output =~ "Building rindle"
assert output =~ "Saved to"
```
**Adapt — lift the shape from `mix` to `bash`:**
```elixir
{output, exit_code} =
  System.cmd("bash", [@probe_script],
    cd: @repo_root,
    env: [
      {"MIX_ENV", "test"},                  # RESEARCH Pitfall 1 — pin explicitly
      {"PATH", shim_dir <> ":" <> System.get_env("PATH")},
      {"RINDLE_PROJECT_ROOT", @repo_root},
      {"VERSION", "0.1.4"},
      {"RINDLE_PROBE_FAKE_HEX_INFO_EXIT", "0"},
      {"RINDLE_PROBE_FAKE_CURL_HTTP_STATUS", "200"}
    ],
    stderr_to_stdout: false  # keep stdout clean for shape assertion (Pitfall 4)
  )

assert exit_code == 0
assert output =~ ~r/^already_published=true\n?\z/  # last-line shape
```

**`@module_attr` script paths convention** — `package_metadata_test.exs` lines 4–10:
```elixir
@repo_root Path.expand("../..", __DIR__)
@preflight_script Path.join(@repo_root, "scripts/release_preflight.sh")
@install_smoke_script Path.join(@repo_root, "scripts/install_smoke.sh")
@public_smoke_script Path.join(@repo_root, "scripts/public_smoke.sh")
```
**Adapt verbatim** — add `@probe_script Path.join(@repo_root, "scripts/hex_release_exists.sh")` and `@shim_factory Path.join(@repo_root, "test/install_smoke/support/fake_hex_bin.sh")`.

**Four canonical test cases** (RESEARCH Validation Matrix rows 55–59 + Pitfall 8):
1. `mix hex.info` exit 0 → `already_published=true`, exit 0
2. `mix hex.info` exit 1 + curl 404 → `already_published=false`, exit 0
3. `mix hex.info` exit 1 + curl 200 → `already_published=true`, exit 0 (defense-in-depth — D-09)
4. `mix hex.info` exit 1 + curl error → exit ≠ 0, stderr names both probes (inconclusive)

Plus one path-discipline case (RESEARCH Validation Matrix row 59): set `RINDLE_PROJECT_ROOT` to a known dir; assert script `cd`s there.

---

### `test/install_smoke/support/fake_hex_bin.sh` (NEW shim factory) — NO DIRECT ANALOG

This is a **new pattern**. Document inline as part of planner action: write a tiny bash factory that takes a temp dir argument and writes two files there:

```bash
# pseudocode for planner — no analog file exists
# Usage: bash test/install_smoke/support/fake_hex_bin.sh <shim_dir>
# Writes <shim_dir>/mix and <shim_dir>/curl that honor:
#   RINDLE_PROBE_FAKE_HEX_INFO_EXIT     -> mix hex.info <args> exits with this
#   RINDLE_PROBE_FAKE_HEX_INFO_STDOUT   -> mix hex.info <args> prints this
#   RINDLE_PROBE_FAKE_CURL_HTTP_STATUS  -> curl emits HTTP-like body and exits per status
#   RINDLE_PROBE_FAKE_CURL_EXIT         -> curl exit code (for transient-error case)
```

**Closest reference for "PATH-prepended shim" pattern:** none in this repo. Generic shape:
```bash
#!/usr/bin/env bash
set -euo pipefail
shim_dir="${1:?shim dir required}"
mkdir -p "$shim_dir"

cat > "$shim_dir/mix" <<'EOF'
#!/usr/bin/env bash
# Only intercept "hex.info <pkg> <version>". Pass everything else through.
if [ "${1:-}" = "hex.info" ]; then
  printf '%s' "${RINDLE_PROBE_FAKE_HEX_INFO_STDOUT:-}"
  exit "${RINDLE_PROBE_FAKE_HEX_INFO_EXIT:-0}"
fi
exec /usr/bin/env -i PATH="$RINDLE_REAL_PATH" mix "$@"
EOF
chmod +x "$shim_dir/mix"

cat > "$shim_dir/curl" <<'EOF'
#!/usr/bin/env bash
status="${RINDLE_PROBE_FAKE_CURL_HTTP_STATUS:-200}"
exit_code="${RINDLE_PROBE_FAKE_CURL_EXIT:-0}"
# Emulate curl's -w '%{http_code}' contract used in the probe
case "$*" in
  *"-w"*"%{http_code}"*) printf '%s' "$status" ;;
  *) ;;
esac
exit "$exit_code"
EOF
chmod +x "$shim_dir/curl"
```

**Planner adapts** based on the actual `curl` invocation flags chosen for `hex_release_exists.sh` (D-09 leaves bash style at agent discretion). The shim contract should match whatever the probe actually invokes.

**Decision per RESEARCH Open Question 1:** put both the test file and the shim factory under `test/install_smoke/` so `mix.exs` `:test_paths` does not need to change and `release_preflight.sh` lines 36–37 do not need a new entry. Confirmed: `mix.exs` does not customize `:test_paths`, so default `test/**/*_test.exs` discovery applies.

---

### `.planning/phases/16-…/16-REVERT-REHEARSAL.md` (NEW evidence file)

**Analog:** `.planning/phases/15-ci-integrity-and-publish-preflight/15-RELEASE-CANDIDATE-CHECKLIST.md`

**Status-line header convention** (lines 1–9):
```markdown
# Phase 15 Release Candidate Checklist

Status: CLOSED — retroactive: v0.1.0–v0.1.4 shipped during Phase 15 execution; package name claimed; checklist serves as the historical record of the first-publish boundary.

This phase was authored on 2026-04-29 assuming v0.1.0 was the upcoming first publish. During execution the release-please pipeline auto-bumped through 0.1.0, 0.1.1, 0.1.2, 0.1.3, and 0.1.4; `mix hex.info rindle` shows `Releases: 0.1.4` live on Hex.pm. …

Local preflight is diagnostic preparation, not authoritative release proof.
Authoritative signoff requires a green GitHub Actions run on the exact release-candidate SHA.
…
```

**Signed-fact section pattern** (lines 11–17):
```markdown
## Release Candidate

- Exact release-candidate SHA: `6dd0d54081c89b68c630d9642a40453d310008c6`
- GitHub Actions run URL for that exact SHA: https://github.com/szTheory/rindle/actions/runs/25135464796
- CI completed at: 2026-04-29T21:49:44Z
- Go / no-go decision: GO — retroactive: 0.1.4 already published from this pipeline lineage; …
```

**Checkbox proof block + transcript block pattern** (lines 19–54):
```markdown
## Required Remote Proof

- [x] GitHub Actions CI is green on the exact release-candidate SHA
- [x] The passing run includes the `Package Consumer + Release Preflight` lane
- [x] The recorded run URL points to the same SHA listed above

…

### Command Output Notes

```text
mix hex.user whoami:
sztheory

mix hex.owner list rindle:
Email             Level
jon@coderjon.com  full

package-name availability check:
N/A — name claimed by 0.1.4 publish on 2026-04-29.
mix hex.info rindle returns:
  Config: {:rindle, "~> 0.1.4"}
  Releases: 0.1.4
  Licenses: MIT
  Links: GitHub: https://github.com/szTheory/rindle
```
```

**Reuse verbatim** — header style ("Status: …"), checkbox-list section shape, fenced transcript block. **Adapt** to the rehearsal's structure per RESEARCH §"(c) revert rehearsal" + CONTEXT D-18:
- §0 Header (date, maintainer, runbook SHA reviewed, signoff line)
- §1 Identity proof transcript (`mix hex.user whoami` / `hex.owner list rindle` / `hex.info rindle 0.1.4`)
- §2 Decision matrix (revert | retire | docs.publish | window-closed fallback)
- §3 Command canonicalization proof (`mix hex.publish --revert VERSION` canonical; `mix hex.revert rindle VERSION` documented as wrong-source-of-error)
- §4 Communication walkthrough (D-24 adopter advisory + commit message convention + GH Release title)
- §5 Runbook cross-reference signoff

**Critical constraint per D-19 (research-locked):** §1 contains read-only command transcripts ONLY. No live `mix hex.publish --revert 0.1.4 --yes` execution. Document the destructive command's expected output in §3 as canonicalization evidence, not as live transcript.

---

### `.github/workflows/release.yml` (MODIFIED — workflow YAML)

**Analog:** itself. Show existing patterns at the modification sites.

**Existing concurrency block** (lines 17–19) — D-14 mandates simplification:
```yaml
concurrency:
  group: ${{ github.event_name == 'workflow_dispatch' && format('release-recovery-{0}', inputs.recovery_ref) || 'release-main' }}
  cancel-in-progress: false
```
**Mandate (D-14):** collapse to a single global token: `group: release-publish-rindle`; keep `cancel-in-progress: false`. Parity test (RESEARCH Validation Matrix row 62): `assert workflow =~ "release-publish-rindle"` and `refute workflow =~ "release-recovery-{0}"`.

**Existing version-parse step** (lines 140–152) — D-15 mandates replacement:
```yaml
- name: Read release version from mix.exs
  id: version
  shell: bash
  run: |
    set -euo pipefail
    VERSION=$(
      sed -nE \
        -e 's/^[[:space:]]*@version[[:space:]]+"([^"]+)"/\1/p' \
        -e 's/^[[:space:]]+version:[[:space:]]+"([^"]+)",?/\1/p' \
        mix.exs | head -n1
    )
    test -n "$VERSION"
    echo "release_version=$VERSION" >> "$GITHUB_OUTPUT"
```
**Canonical replacement pattern from `scripts/assert_version_match.sh` lines 9–14:**
```bash
MIX_VERSION=$(
  mix run --no-start -e 'IO.puts(Mix.Project.config()[:version])' \
    | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?' \
    | tail -n1 \
    | tr -d '\r'
)
```
**Mandate (D-15) + RESEARCH Pitfall 9:** add `--no-deps-check` for the workflow shell context (which runs before deps install in the publish job's worktree). Final shape per CONTEXT D-15 wording:
```yaml
run: |
  set -euo pipefail
  VERSION=$(mix run --no-start --no-deps-check -e 'IO.puts(Mix.Project.config()[:version])' | tail -n1 | tr -d '\r')
  test -n "$VERSION"
  echo "release_version=$VERSION" >> "$GITHUB_OUTPUT"
```
Parity test (RESEARCH Validation Matrix row 63): `assert workflow =~ ~s(Mix.Project.config()[:version])` and `refute workflow =~ "@version[[:space:]]+"`.

**Existing publish-job step shape** (lines 314–329) — D-09/D-10/D-11/D-16/D-17 mandate insertions and renames:
```yaml
- name: Dry run Hex publish
  env:
    HEX_API_KEY: ${{ secrets.HEX_API_KEY }}
  working-directory: ${{ steps.release_source.outputs.project_root }}
  run: mix hex.publish --dry-run --yes

- name: Live publish to Hex
  env:
    HEX_API_KEY: ${{ secrets.HEX_API_KEY }}
  working-directory: ${{ steps.release_source.outputs.project_root }}
  run: |
    if [ -z "$HEX_API_KEY" ] || [ "$HEX_API_KEY" = "dryrun-placeholder" ]; then
      echo "::error::HEX_API_KEY is missing or invalid. Cannot publish. Ensure the 'release' environment secret is configured."
      exit 1
    fi
    mix hex.publish --yes
```
**Suggested edit shape per D-09/D-10/D-11/D-16/D-17:**
1. **Insert** new step `id: idempotency` between `Verify version alignment` and `Dry run Hex publish`:
   ```yaml
   - name: Probe Hex.pm for existing release
     id: idempotency
     env:
       RINDLE_PROJECT_ROOT: ${{ steps.release_source.outputs.project_root }}
       VERSION: ${{ needs.gate-ci-green.outputs.release_version }}
     run: bash scripts/hex_release_exists.sh
   ```
2. **Add `if:` guard** to both `Dry run Hex publish` and the renamed `Publish to Hex.pm (live)` step (D-10):
   ```yaml
   if: steps.idempotency.outputs.already_published != 'true'
   ```
3. **Rename steps (D-16)**: `Live publish to Hex` → `Publish to Hex.pm (live)`; `Wait for Hex.pm index` → `Wait for Hex.pm index (post-publish)`. Add `id: live_publish` to the renamed live step.
4. **Improve HEX_API_KEY guard message (D-17)**:
   ```bash
   echo "::error::HEX_API_KEY missing/invalid. Configure repo Settings → Environments → release → secret HEX_API_KEY. See guides/release_publish.md 'One-Time Publish Prerequisites.'"
   ```
5. **Append new final step `Idempotent publish summary` (D-11)** writing one line to `$GITHUB_STEP_SUMMARY` based on `steps.idempotency.outputs.already_published` value.
6. **Add 6-line top-of-file YAML comment block (D-16)** describing the four-job topology (release-please/recovery-validation → gate-ci-green → publish → public_verify).

**Parity assertions added** (RESEARCH Validation Matrix rows 60–65): `scripts/hex_release_exists.sh`, `if: steps.idempotency.outputs.already_published != 'true'`, `Idempotent publish summary`, `release-publish-rindle`, `Mix.Project.config()[:version]`, `Settings → Environments → release`.

---

### `guides/release_publish.md` (MODIFIED — runbook)

**Analog:** itself. Existing 195-line file already exhibits the parity contract that must be preserved.

**Existing First Public Release section** (lines 9–19) — voice will be rewritten per D-04:
```markdown
## First Public Release (0.1.0)

Use this sequence on `main`:

1. Complete the one-time publish prerequisites in this guide.
2. Confirm the root `CHANGELOG.md` has a `0.1.0` entry matching the release scope.
3. Merge the Release Please PR that updates `mix.exs` from `@version "0.1.0-dev"` to `0.1.0` and tags `v0.1.0`.
…
```

**Existing Routine Releases step list** (lines 26–35) — must update for D-16 renames:
```markdown
2. Monitor GitHub Actions until the `Release` workflow completes these
   step names in order:
   - `Release Please`
   - `Wait for CI to finish green on release SHA`
   - `Run release preflight`
   - `Verify version alignment`
   - `Dry run Hex publish`
   - `Live publish to Hex`              ← rename to: Publish to Hex.pm (live)
   - `Wait for Hex.pm index`            ← rename to: Wait for Hex.pm index (post-publish)
   - `Verify public Hex.pm artifact`
```
This list is mirrored by `release_docs_parity_test.exs` lines 105–114 — both files MUST be updated atomically (RESEARCH "Order of edits" §a step 2).

**Existing Recovery Workflow Contract section** (lines 154–163) — must add idempotent-skip semantics per RESEARCH Open Question 3:
```markdown
## Recovery Workflow Contract

The `workflow_dispatch` path in `.github/workflows/release.yml` is recovery-only.
It requires:

- `recovery_reason`
- `recovery_ref` set to an exact existing tag or a 40-character commit SHA

Recovery reruns the same exact-SHA green CI gate, preflight, dry-run publish,
live publish, and public verification as the normal Release Please path.
```
**Append** a one-line note: *"If the recovery run targets an already-published version, the publish steps skip and the summary tab shows the no-op message. Public verification still runs."* — recommended by RESEARCH Open Question 3 with parity assertion `assert release_guide =~ "publish steps skip"`.

**Existing Rollback and Revert section** (lines 179–195) — D-20/D-21/D-22/D-23/D-24 mandate full rewrite:
```markdown
## Rollback and Revert

Package rollback and revert procedures are manual maintainer actions; they
are not automated in CI. …

If a published release is broken, you can revert it using the native Hex tooling:

```bash
mix hex.revert rindle VERSION
```                                       ← WRONG COMMAND. Replace with:
                                            mix hex.publish --revert VERSION

**Important Constraints:**
- You have a **1-hour window** to revert a release.
- For the *first* release (`0.1.0`), this window is extended to **24 hours**.
- Once a version is reverted, you **can** reuse that version number for a future publish.
```
**Suggested edit shape per D-21:** drop-in replace with structure from RESEARCH C §6 — 90-second skim table at top, then four sub-sections: Revert (within window), Retire (after window — preferred for runtime breakage), Window-closed fallback, Rehearsal evidence pointer + Adopter advisory template pointer. New parity assertions per RESEARCH Validation Matrix rows 72–75: `mix hex.publish --revert`, `mix hex.retire rindle`, `mix hex.docs publish`, valid retire reasons (`renamed | deprecated | security | invalid | other`), `1-hour window`, `24-hour`, `lockfiles still install`.

**New sections to add (D-01..D-05, D-13):**
1. **TL;DR cheatsheet** (D-02): ≤5 numbered/bulleted lines under `## TL;DR`, before "First Public Release."
2. **Footguns & Gotchas** (D-03): just before appendices, with substring assertions per RESEARCH Validation Matrix row 77 (`version immutability`, `last version`, `8MB`, `64MB`, `git deps`, `conventional commits`, `--warnings-as-errors`, etc.).
3. **Appendix A: Deviation Log** (D-05): newest-first append-only table with all 5 historical SHAs (`a7efefd`, `d5c21ad`, `65728e5`, `71a0f99`, `6dd0d54`).
4. **Appendix B: Architecture Note** (research A §6): `current tooling, frozen source` / `git worktree` / `recovery_ref` / `main HEAD` substrings present.
5. **`--replace is forbidden in CI` ban statement** (D-13): explicit prose somewhere in the runbook; parity assertion `assert release_guide =~ "--replace is forbidden in CI"`.

**Voice rewrite (D-04):** second-person imperative ("Run X. Then Y.") modeled on Phoenix's `RELEASE.md`. Negative parity assertions: `refute release_guide =~ "you should consider"`, etc.

---

### `CHANGELOG.md` (MODIFIED)

**Analog:** itself. Existing top-of-file (lines 1–9):
```markdown
# Changelog

## [0.1.4](https://github.com/szTheory/rindle/compare/rindle-v0.1.3...rindle-v0.1.4) (2026-04-29)


### Bug Fixes

* **test:** supervise ex_marcel table wrapper ([876afd7](…))
```

**Mandate (D-07):** add a one-line note at the top, BEFORE the first `## [0.1.4]` heading. Suggested shape:
```markdown
# Changelog

> Note: `0.1.0`–`0.1.3` were release-pipeline shakedown iterations; treat `0.1.4` as the first recommended pin.

## [0.1.4](…
```
Do not rewrite shipped entries — Hex history is immutable. New parity assertion in `package_metadata_test.exs` (RESEARCH Validation Matrix row 82): `assert changelog =~ "shakedown"` (or `=~ "pipeline iteration"`). Note: the existing test on line 70 (`assert changelog =~ "## 0.1.0"`) and line 71 (`assert changelog =~ "First public Hex.pm release of Rindle."`) MUST still pass — both substrings remain in the file (lines 33 and 138).

---

### `test/install_smoke/release_docs_parity_test.exs` (MODIFIED)

**Analog:** itself. Existing snippet-list pattern at lines 36–45 (model for new assertions):
```elixir
test "release guide keeps one-time publish prerequisites and personal-first owner follow-up", %{
  release_guide: release_guide
} do
  for snippet <- [
        "mix hex.user whoami",
        "HEX_API_KEY",
        "initial owner",
        "package-name availability",
        "mix hex.owner list rindle",
        "mix hex.owner add rindle USERNAME"
      ] do
    assert release_guide =~ snippet
  end
end
```

**Existing `step_names` list** (lines 105–114) — must be updated atomically with `release.yml` per D-16:
```elixir
step_names = [
  "Release Please",
  "Wait for CI to finish green on release SHA",
  "Run release preflight",
  "Verify version alignment",
  "Dry run Hex publish",
  "Live publish to Hex",                    ← change to: "Publish to Hex.pm (live)"
  "Wait for Hex.pm index",                  ← change to: "Wait for Hex.pm index (post-publish)"
  "Verify public Hex.pm artifact"
]
```

**Suggested edits per Validation Matrix:**
1. Update `step_names` list per D-16 (above).
2. Add new test block for TL;DR section per D-02 (with length-bound assertion using `String.split` on `## TL;DR`).
3. Add new test block for Footguns inventory per D-03 (12 substring assertions).
4. Add new test block for Appendix A Deviation Log per D-05 (5 historical SHAs).
5. Add new test block for Appendix B Architecture Note (4 substrings).
6. Extend the existing "Rollback and Revert" / new test for D-20..D-24: `mix hex.publish --revert`, `mix hex.retire rindle`, `mix hex.docs publish`, the 5 retire reasons, window phrases, lockfile caveat. Negative assertion: `refute release_guide =~ "mix hex.revert rindle"`.
7. Add `--replace is forbidden in CI` ban assertion (D-13).
8. Add Recovery Workflow Contract idempotency note assertion per RESEARCH OQ 3.
9. Add voice-rewrite negative assertions: `refute release_guide =~ "you should consider"` etc. per D-04.

**Pattern principle (RESEARCH Pitfall 6):** keep snippet assertions to short, semantically distinctive substrings. Match the existing model on lines 36–45 — each item is 2–6 words. Avoid full sentences except where the existing pattern (lines 51–60) already does so for distinctive policy claims.

---

### `test/install_smoke/package_metadata_test.exs` (MODIFIED)

**Analog:** itself. Existing workflow-substrings test at lines 126–145 (model for new workflow assertions):
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
  assert workflow =~ ~s(workflow_id: 'ci.yml')
  assert workflow =~ ~s(mix hex.publish --dry-run --yes)
  assert workflow =~ ~s(mix hex.publish --yes)
  assert workflow =~ "public_verify:"
  assert workflow =~ "needs: [gate-ci-green, publish]"
  assert workflow =~ ~s(name: Wait for Hex.pm index)        ← rename to: Wait for Hex.pm index (post-publish)
  assert workflow =~ ~s(name: Verify public Hex.pm artifact)
  assert workflow =~ ~s(HEX_API_KEY: "")
  assert workflow =~ ~s(mix hex.info rindle "$VERSION")
  assert workflow =~ ~s(bash scripts/public_smoke.sh "$VERSION")
end
```

**Suggested edits per RESEARCH Validation Matrix rows 60–65, 82:**
1. **Update existing assertion** at line 140 to reflect D-16 step rename: `name: Wait for Hex.pm index` → `name: Wait for Hex.pm index (post-publish)`.
2. **Add new assertions** for D-09/D-10/D-11/D-14/D-15/D-17:
   ```elixir
   assert workflow =~ "scripts/hex_release_exists.sh"
   assert workflow =~ ~s(if: steps.idempotency.outputs.already_published != 'true')
   assert workflow =~ "Idempotent publish summary"
   assert workflow =~ "release-publish-rindle"
   refute workflow =~ "release-recovery-{0}"
   assert workflow =~ ~s(Mix.Project.config()[:version])
   refute workflow =~ "@version[[:space:]]+"   # use the literal sed pattern this retired
   assert workflow =~ "Settings → Environments → release"
   assert workflow =~ "Publish to Hex.pm (live)"
   ```
3. **Add new test block / extend existing changelog test** per D-07: `assert changelog =~ "shakedown"` (or `"pipeline iteration"`). Note: existing tests at lines 63–72 already pass — extend rather than rewrite.
4. **Optional CI lint assertion (Claude's Discretion in CONTEXT D-25):** `for script <- Path.wildcard("scripts/*.sh"), do: assert File.read!(script) =~ "RINDLE_PROJECT_ROOT"`. Recommended by RESEARCH §"Claude's Discretion (relevant to validation)".

**`System.cmd("mix", …)` model for the new probe test** — `package_metadata_test.exs` lines 167–172 (already covered above in the `hex_release_exists_test.exs` section).

## Shared Patterns

### `RINDLE_PROJECT_ROOT` env contract
**Source:** `scripts/release_preflight.sh` line 5; `scripts/assert_version_match.sh` line 4; `scripts/public_smoke.sh` line 5
**Apply to:** `scripts/hex_release_exists.sh` (new)
```bash
ROOT_DIR="${RINDLE_PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT_DIR"
```
Every workspace shell script honors this. The new probe script MUST follow.

### `set -euo pipefail` + GitHub Actions error annotation
**Source:** `scripts/assert_version_match.sh` lines 2, 25, 31, 36
**Apply to:** All new shell scripts; all inline `run: |` blocks in `release.yml`
```bash
set -euo pipefail
…
echo "::error::<message>" >&2
exit 1
```
Stderr discipline is load-bearing for `$GITHUB_OUTPUT` cleanliness (RESEARCH Pitfall 4).

### `MIX_ENV=test` pinning in System.cmd
**Source:** `package_metadata_test.exs` line 170; `scripts/public_smoke.sh` line 17
**Apply to:** All new ExUnit `System.cmd` invocations (probe test)
```elixir
env: [{"MIX_ENV", "test"}, …]
```
Precedent: `6dd0d54` had to fix `public_smoke.sh` to use `MIX_ENV=test` after the publish lane defaulted to dev. New test must NOT rely on inherited env (RESEARCH Pitfall 1).

### Snippet-list parity assertion idiom
**Source:** `release_docs_parity_test.exs` lines 36–45 (the canonical short-substring model); workflow-substrings model `package_metadata_test.exs` lines 126–145
**Apply to:** Every new D-XX outcome that needs a parity assertion in either test file
```elixir
for snippet <- [
      "<short distinctive substring>",
      "<another>"
    ] do
  assert release_guide =~ snippet
end
```
Keep snippets short (2–6 words) to avoid prose-edit brittleness (RESEARCH Pitfall 6).

### `mix hex.info <pkg> <version>` exit-code semantic (no auth required)
**Source:** `.github/workflows/release.yml` lines 408–422 (`Wait for Hex.pm index` step running `until mix hex.info rindle "$VERSION" >/dev/null 2>&1`); RESEARCH Pitfall 3 confirms `HEX_API_KEY: ""` already works for read access
**Apply to:** `scripts/hex_release_exists.sh` primary probe; reuse semantic but layer curl HTTP fallback for transient-error disambiguation per D-09 + RESEARCH Pitfall 8.

### Conventional-commits commit message
**Source:** Recent git log (`fix(release): …` × 5: `a7efefd`, `d5c21ad`, `65728e5`, `71a0f99`, `6dd0d54`); CHANGELOG.md generated by release-please
**Apply to:** Every commit produced in this phase
- Workflow / probe-script changes → `fix(release): …`
- Runbook changes → `docs(release): …`
- Test extensions → `test(release): …`
- Rehearsal evidence file commit → `docs(state): …` (matches `24bfa6f` precedent)

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `test/install_smoke/support/fake_hex_bin.sh` | shim factory (writes fake `mix`/`curl` to a temp dir) | called by ExUnit test setup; emits PATH-prepended bin dir | No PATH-shim factory exists in this repo. Pattern documented inline above. Closest precedent for "write a small bash file from another bash file" is none in `scripts/`; closest for "test fixture helper" is `test/install_smoke/support/generated_app_helper.ex` but that's an Elixir module, not a bash shim. Planner adapts the documented shape. |

## Metadata

**Analog search scope:**
- `scripts/*.sh` (5 files)
- `.github/workflows/{release,ci}.yml`
- `test/install_smoke/*.{exs,ex}` (4 test files + 1 helper)
- `.planning/phases/15-…/15-RELEASE-CANDIDATE-CHECKLIST.md`
- `guides/release_publish.md`
- `CHANGELOG.md`
- `mix.exs` (verified `:test_paths` defaults — no change needed for new test placement)

**Files scanned:** 14
**Pattern extraction date:** 2026-04-30
