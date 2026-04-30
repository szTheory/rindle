# Phase 16: Live Publish Execution and Post-Publish Verification — Research

**Researched:** 2026-04-30
**Domain:** Validation architecture for the three locked work items (CONTEXT.md decisions D-01 through D-25)
**Confidence:** HIGH (locked decisions already research-grounded; this layer only adds the proof strategy)

## Summary

CONTEXT.md locks the *what* and *how* of Phase 16 across 24 decisions and three work items: (b) `workflow_dispatch` recovery idempotency fix, (c) SC-5 revert tabletop rehearsal evidence, (a) runbook deviation capture. This research focuses exclusively on **how to prove each work item lands correctly without breaking the existing release pipeline** — the Validation Architecture dimension that CONTEXT.md does not enumerate.

The phase has zero library-runtime code changes. Validation therefore lives entirely in three layers: (1) shell-script unit tests for the new `scripts/hex_release_exists.sh` (D-09), (2) ExUnit parity tests in `test/install_smoke/release_docs_parity_test.exs` and `package_metadata_test.exs` for runbook + workflow contract drift, (3) a structured tabletop evidence file at `.planning/phases/16-.../16-REVERT-REHEARSAL.md` (D-18). No live publish, no live revert, no destructive Hex commands in CI.

**Primary recommendation:** Add idempotency to the workflow under `MIX_ENV=test` discipline (precedent: `6dd0d54`), prove the new script via a deterministic ExUnit wrapper that mocks both `mix hex.info` exit codes and the HTTP fallback, extend parity-test snippet lists for every new runbook section, and capture the rehearsal as a signed transcript with read-only Hex commands only (D-19).

<phase_requirements>
## Phase Requirements

| ID | Description | Validation Support |
|----|-------------|------------------|
| PUBLISH-03 | Tag push → workflow publishes to Hex.pm with no manual intervention | Workflow contract preserved; idempotency probe (D-09) is a passive gate that does not change the happy-path semantics. Validated via parity tests + dry-run rehearsal. |
| VERIFY-01 | Adopter can `mix deps.get` from Hex.pm | Already satisfied retroactively against 0.1.4 (CONTEXT §Phase Boundary). No new validation needed; existing `public_verify` job continues to enforce. |
| VERIFY-02 | Adopter can browse `hexdocs.pm/rindle` | Already satisfied retroactively against 0.1.4. Existing `assert_release_docs_html.sh` continues to enforce. |
| RELEASE-01 | Step-by-step runbook with no guesswork, deviations encoded | Validated by extended `release_docs_parity_test.exs` assertions covering new TL;DR, Footguns, Appendix A (Deviation Log), Appendix B (Architecture Note), idempotent recovery contract. |
| RELEASE-02 | Maintainer can execute `mix hex.publish --revert VERSION` per runbook | Validated by (i) parity test asserting D-20 command correction, (ii) `16-REVERT-REHEARSAL.md` evidence file with read-only auth proof + canonicalized command transcripts. |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Idempotency probe (D-09) | Shell script (`scripts/hex_release_exists.sh`) | ExUnit (parity + behavior wrapper) | Script owns runtime decision; ExUnit asserts shape and exit-code contract. |
| Workflow gate logic (D-10, D-11, D-14) | GitHub Actions YAML | ExUnit parity (`package_metadata_test.exs`) | Workflow owns gate; parity test ensures step names + `if:` shape are not silently drifted. |
| Version parsing canonicalization (D-15) | GitHub Actions YAML inline shell | ExUnit parity | Workflow inlines `mix run -e 'IO.puts(Mix.Project.config()[:version])'`; parity test asserts the idiom matches `assert_version_match.sh`. |
| Runbook deviation capture (a, D-01..D-08) | Markdown (`guides/release_publish.md`) | ExUnit parity (`release_docs_parity_test.exs`) | Markdown is source of truth; parity test enforces snippet coverage so future edits cannot silently drop content. |
| Revert rehearsal evidence (c, D-18..D-24) | Markdown (`16-REVERT-REHEARSAL.md`) | None (evidence file is unshipped) | Tabletop transcript; not parity-tested because not shipped to hexdocs. Validated by reviewer signoff at phase close. |

## Validation Architecture

> Required by Nyquist Dimension 8. Group by validation type × work item. All commands runnable in < 60s except the full preflight rehearsal.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (existing) + Bash (new for `hex_release_exists.sh`) |
| Config file | `mix.exs` `:test_paths`, `test/test_helper.exs` |
| Quick run | `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs test/install_smoke/package_metadata_test.exs` |
| Full suite | `bash scripts/release_preflight.sh` (runs both above plus install_smoke + docs gates) |
| Phase gate | Full preflight green on the work-item-(b) PR SHA before merge; CI on the merged SHA also green. |

### Validation Matrix (work item × type × test file × assertion shape)

| Work Item | Type | Test File / Artifact | Assertion Shape | Expected Output |
|-----------|------|----------------------|-----------------|-----------------|
| **(b) probe script** | unit | `test/scripts/hex_release_exists_test.exs` (NEW) | `System.cmd("bash", ["scripts/hex_release_exists.sh"], env: [{"RINDLE_PROBE_FAKE_HEX_INFO_EXIT", "0"}, {"VERSION", "0.1.4"}])` returns `{output, 0}` and stdout contains `already_published=true` | Exit 0; `already_published=true\n` |
| **(b) probe script** | unit | same | With fake `mix hex.info` exit 1 + fake HTTP 404, returns `already_published=false` | Exit 0; `already_published=false\n` |
| **(b) probe script** | unit | same | With fake `mix hex.info` unavailable (binary missing) + fake HTTP 200, falls back to HTTP and returns `already_published=true` (D-09 defense-in-depth) | Exit 0; `already_published=true\n` |
| **(b) probe script** | unit | same | With both probes inconclusive (transient errors), exits non-zero with diagnostic | Exit ≠ 0; stderr names both probes |
| **(b) probe script** | unit | same | Honors `RINDLE_PROJECT_ROOT` env per workspace convention | Script `cd`s to that dir before invoking `mix` |
| **(b) workflow gate** | parity | `test/install_smoke/package_metadata_test.exs` | New assertion: `assert workflow =~ "scripts/hex_release_exists.sh"` and `assert workflow =~ ~s(if: steps.idempotency.outputs.already_published != 'true')` (D-10) | Both substrings present in `release.yml` |
| **(b) workflow gate** | parity | same | New assertion: `assert workflow =~ "Idempotent publish summary"` (D-11) | Step name present |
| **(b) workflow gate** | parity | same | New assertion: `assert workflow =~ "release-publish-rindle"` and `refute workflow =~ "release-recovery-{0}"` (D-14 single-token concurrency) | Single global lock confirmed |
| **(b) version parse** | parity | same | New assertion: `assert workflow =~ ~s(Mix.Project.config()[:version])` and `refute workflow =~ "@version[[:space:]]+"` (D-15 sed retired) | Canonical idiom replaces sed |
| **(b) workflow rename** | parity | `test/install_smoke/release_docs_parity_test.exs` | Update `step_names` list: replace `"Live publish to Hex"` with `"Publish to Hex.pm (live)"` and `"Wait for Hex.pm index"` with `"Wait for Hex.pm index (post-publish)"` (D-16). Mirror change in runbook step-name list. | Parity test green against renamed workflow |
| **(b) HEX_API_KEY guard** | parity | `package_metadata_test.exs` | New assertion: `assert workflow =~ "Settings → Environments → release"` (D-17) | New error-message wording present |
| **(b) dry-run rehearsal** | integration | manual + CI on probe-fix PR | Push `feat(release): probe before publish` branch; observe `release.yml` is NOT triggered (no tag) but `ci.yml` runs the package-consumer dry-run lane and stays green | CI green; no live publish attempted |
| **(b) workflow_dispatch rehearsal** | integration | manual `gh workflow run release.yml -f recovery_reason="probe rehearsal" -f recovery_ref=<sha-of-0.1.4>` | Probe step outputs `already_published=true`; `Dry run Hex publish` and `Publish to Hex.pm (live)` steps show as **skipped** (not failed); `public_verify` runs and passes; job conclusion = success | Failed run `25135467509` regression case proven fixed; `$GITHUB_STEP_SUMMARY` shows the skip message (D-11) |
| **(c) read-only auth proof** | tabletop evidence | `16-REVERT-REHEARSAL.md` §1 | Transcript of `mix hex.user whoami` → `sztheory`; `mix hex.owner list rindle` → `jon@coderjon.com\tfull`; `mix hex.info rindle 0.1.4` → `Releases: 0.1.4` | All three commands produce expected outputs; signed with date + SHA of runbook reviewed |
| **(c) command canonicalization** | tabletop evidence | `16-REVERT-REHEARSAL.md` §3 | Documented walkthrough proving `mix hex.publish --revert VERSION` is the canonical form; `mix hex.revert rindle VERSION` is documented as the wrong-command-from-old-runbook | Cite `https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html` `--revert` switch |
| **(c) decision matrix** | tabletop evidence | `16-REVERT-REHEARSAL.md` §2 | Matrix: Revert (within window) | Retire (after window) | docs.publish (docs only) | window-closed fallback. Each cell names the canonical command + when to use it (D-21..D-23) | Matrix complete with 4 rows |
| **(c) advisory template** | tabletop evidence | `16-REVERT-REHEARSAL.md` §4 | Inline copy of D-24 adopter advisory + commit-message convention + GitHub Release title format | Three artifacts present, ready to copy |
| **(c) runbook cross-reference** | parity | `release_docs_parity_test.exs` | New assertion: `assert release_guide =~ "mix hex.publish --revert"` and `refute release_guide =~ "mix hex.revert rindle"` (D-20 fix) | Wrong command removed; canonical command present |
| **(c) runbook cross-reference** | parity | same | New assertion: `assert release_guide =~ "mix hex.retire rindle"` and `assert release_guide =~ "mix hex.docs publish"` (D-22, D-23) | Retire + docs-only paths documented |
| **(c) runbook cross-reference** | parity | same | New assertion: `assert release_guide =~ "renamed"` and `=~ "deprecated"` and `=~ "security"` and `=~ "invalid"` and `=~ "other"` (D-22 valid retire reasons) | All five reasons enumerated |
| **(c) runbook cross-reference** | parity | same | New assertion: `assert release_guide =~ "1-hour window"` and `=~ "24-hour"` (revert window) and `assert release_guide =~ "lockfiles still install"` (D-22 retire caveat) | Window semantics + retire caveat present |
| **(a) TL;DR cheatsheet** | parity | `release_docs_parity_test.exs` | New test: `release_guide` first 30 lines contain `## TL;DR` heading and ≤ 5 bullet/numbered lines (D-02) | TL;DR section present near top, bounded length |
| **(a) Footguns section** | parity | same | New test: `release_guide =~ "## Footguns"` and contains representative substrings: `"version immutability"`, `"last version"`, `"8MB"`, `"64MB"`, `"git deps"`, `"conventional commits"`, `"--warnings-as-errors"` (D-03 inventory) | All footgun categories enumerated |
| **(a) Deviation Log** | parity | same | New test: `release_guide =~ "## Appendix A"` and contains the 5 SHAs `a7efefd`, `d5c21ad`, `65728e5`, `71a0f99`, `6dd0d54` (D-05 newest-first append-only) plus the new (b) commit SHA appended after merge | All 5 historical fix SHAs present |
| **(a) Architecture Note** | parity | same | New test: `release_guide =~ "## Appendix B"` and contains `"current tooling, frozen source"`, `"git worktree"`, `"recovery_ref"`, `"main HEAD"` (D-Architecture pattern) | Pattern documented inline |
| **(a) Voice / structure** | parity | same | Update existing test: assert imperative voice markers present in routine-release section (`"Run "`, `"Confirm "`, `"Push "`); `refute release_guide =~ "you should consider"` style hedge (D-04) | Voice rewrite landed |
| **(a) Step name update** | parity | same | Existing test `step_names` list updated to renamed steps (D-16); both `release.yml` AND `release_publish.md` agree | Parity test stays green after rename |
| **(a) CHANGELOG note** | parity | NEW assertion in `package_metadata_test.exs` | `assert changelog =~ "shakedown"` or `=~ "pipeline iteration"` (D-07 one-line note about 0.1.0–0.1.3) | Note present near top |
| **(a) `--replace` ban** | parity | `release_docs_parity_test.exs` | New assertion: `release_guide =~ "--replace is forbidden in CI"` or equivalent ban statement (D-13) | Ban documented |

### Sampling Rate

- **Per task commit:** `MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs test/install_smoke/package_metadata_test.exs test/scripts/hex_release_exists_test.exs` (≤ 30s)
- **Per wave merge:** `bash scripts/release_preflight.sh` (full preflight including install smoke + docs HTML)
- **Phase gate:** Full preflight green + `gh workflow run release.yml -f recovery_reason="phase 16 idempotency rehearsal" -f recovery_ref=<sha-of-0.1.4>` succeeds with the publish steps **skipped** and `public_verify` green

### Wave 0 Gaps

- [ ] `test/scripts/hex_release_exists_test.exs` — new ExUnit test for the new bash script. Pattern: lift `System.cmd("mix", ...)` from `package_metadata_test.exs:168` to `System.cmd("bash", [script_path], env: [...])`. Inject a test-only PATH-prepended directory containing fake `mix` and `curl` shims that emit configurable exit codes; assert stdout contains `already_published=true|false` + correct exit code per case.
- [ ] `test/scripts/support/fake_hex_bin.sh` — shim factory: writes a tiny shell script to a temp dir that exits with `$RINDLE_PROBE_FAKE_HEX_INFO_EXIT` and prints `$RINDLE_PROBE_FAKE_HEX_INFO_STDOUT`; mirror for `curl`. Lets the unit test cover all four cases (live/missing/fallback-only/inconclusive) without touching the network.
- [ ] No framework install needed — ExUnit is the existing harness.

## User Constraints (from CONTEXT.md)

### Locked Decisions
All 25 decisions D-01 through D-25 are locked in CONTEXT.md. Citations below reference them by ID rather than restating.

### Claude's Discretion (relevant to validation)
- Exact bash style of `scripts/hex_release_exists.sh` (`set -euo pipefail`, error-handling shape) — research recommends matching `scripts/release_preflight.sh` lines 1–18 verbatim for trap/cleanup discipline.
- Whether to add a CI lint asserting all `scripts/*.sh` accept `RINDLE_PROJECT_ROOT` — research recommends YES; cheap parity assertion in `package_metadata_test.exs`: `for script <- Path.wildcard("scripts/*.sh"), do: assert File.read!(script) =~ "RINDLE_PROJECT_ROOT"`.

### Deferred Ideas (OUT OF SCOPE)
- Live revert audit-log evidence (CONTEXT §specifics — locked **off** per D-19).
- Local `hexpm/hexpm` server for full-fidelity rehearsal.
- `hex.docs publish` as a dedicated CI job.

## Per-Work-Item Validation Strategy (D-25 execution order: b → c → a)

### (b) workflow_dispatch idempotency fix

**Goal of validation:** Prove the failure mode of run `25135467509` cannot recur, without publishing or attempting to mutate any live release.

**Layer 1 — script unit tests** (`test/scripts/hex_release_exists_test.exs`):
- Four canonical cases: (i) `mix hex.info` exit 0 → `already_published=true`; (ii) `mix hex.info` exit 1 + curl 404 → `already_published=false`; (iii) `mix hex.info` exec error + curl 200 → `already_published=true` (defense-in-depth, D-09); (iv) both inconclusive → script exits non-zero with diagnostic (avoids silent false-negative that would re-trigger the original bug).
- Use shim factory (Wave 0 Gap above) to drive `mix` and `curl` deterministically. Pattern is the established `System.cmd` wrapper from `package_metadata_test.exs:168`.
- Assert `already_published=` line is the **last** line of stdout — `release.yml` will pipe this to `$GITHUB_OUTPUT`, and a trailing diagnostic would corrupt the action output.

**Layer 2 — workflow parity** (`package_metadata_test.exs`):
- Snippet assertions enumerated in the matrix above. The principle: every D-09..D-17 outcome that lands in YAML gets a snippet assertion. Drift = test failure.
- Specifically validate the gated `if:` shape — `if: steps.idempotency.outputs.already_published != 'true'` (D-10). Skipped steps in a passing job leave job conclusion = success, so `public_verify` (gated on `needs.publish.result == 'success'`) auto-runs. Encode this expectation in a comment in the test.

**Layer 3 — dry-run rehearsal** (manual, before merge):
- On a feature branch (no tag): `bash scripts/release_preflight.sh` must stay green; `ci.yml` must stay green; the workflow file change must not break the package-consumer lane in `ci.yml`.
- Post-merge: invoke `gh workflow run release.yml -f recovery_reason="phase 16 probe rehearsal" -f recovery_ref=<sha-of-0.1.4>`. Expected outcome: the `idempotency` step writes `already_published=true`, the two publish steps show **skipped**, `public_verify` runs and passes, `$GITHUB_STEP_SUMMARY` shows the D-11 skip message. **This is the SC-assertion that the original bug is fixed.** Capture the run URL in the deviation log entry for this phase (D-05).

**Layer 4 — defense-in-depth fallback proof:**
- The unit test alone proves the fallback path; the live rehearsal exercises only the `mix hex.info` path. That asymmetry is acceptable — the fallback is the safety net, not the primary signal, and forcing it live would require simulating `mix` failure in CI which is high-cost-low-value.

### (c) revert rehearsal — `16-REVERT-REHEARSAL.md`

**Goal of validation:** Produce auditable evidence that SC-5 is satisfied (RELEASE-02: maintainer **can** execute revert per documented runbook). D-19 locks this as capability proof, not "has executed."

**Evidence file structure** (per CONTEXT D-18 + research C §5):

```
16-REVERT-REHEARSAL.md
├── §0 Header (date, maintainer, runbook SHA reviewed, signoff line)
├── §1 Identity proof transcript
│     - mix hex.user whoami → sztheory
│     - mix hex.owner list rindle → jon@coderjon.com  full
│     - mix hex.info rindle 0.1.4 → Releases: 0.1.4
├── §2 Decision matrix (revert | retire | docs.publish | window-closed fallback)
├── §3 Command canonicalization proof
│     - mix hex.publish --revert VERSION (canonical, cite hexdocs)
│     - mix hex.revert rindle VERSION (does not exist, source-of-error)
│     - mix hex.retire rindle VERSION REASON --message "..." (peer)
│     - mix hex.docs publish (docs-only)
├── §4 Communication walkthrough
│     - Adopter advisory template (D-24)
│     - Commit-message convention: fix(release): retire <BAD>, ship <FIX>
│     - GitHub Release title format
└── §5 Runbook cross-reference signoff
      - Confirms guides/release_publish.md "Rollback and Revert" section
        contains the canonical commands and the four-row decision matrix
      - Maintainer signature + date
```

**Validation of the evidence file itself:** No automated parity test — the file is unshipped (`.planning/` is in `@prohibited_paths` per `package_metadata_test.exs:19`). Validation = reviewer signoff at phase close + the parity tests on the runbook (which reference the same canonical commands).

**Critical: do NOT invoke `mix hex.publish --revert 0.1.4 --yes`** (D-19). The rehearsal exercises read-only commands only. The destructive command is documented + canonicalized but not executed. CONTEXT §specifics records the stretch toggle.

### (a) runbook deviations

**Goal of validation:** Keep `release_docs_parity_test.exs` and `package_metadata_test.exs` green while adding TL;DR, Footguns, Appendix A, Appendix B, Rollback-rewrite, voice-rewrite, step-name updates, and CHANGELOG note.

**Strategy — extend before edit:**
1. Add new parity assertions FIRST (Wave 0 of work item (a)) — they will fail.
2. Edit the runbook to satisfy them.
3. Run preflight; if green, parity contract holds.

**Per-section validation:**
- **TL;DR (D-02):** Length-bounded assertion (≤5 numbered/bulleted lines after `## TL;DR`). Implementation: `tl_dr_block = release_guide |> String.split("## TL;DR", parts: 2) |> List.last() |> String.split(~r/\n##\s/, parts: 2) |> List.first(); assert length(tl_dr_lines) <= 5`.
- **Footguns (D-03):** 12 substring assertions covering each footgun category. Drift in the inventory = test failure.
- **Appendix A Deviation Log (D-05):** Assert all 5 historical SHAs present + asserted format ("newest first" markers). After (b) merges, append entry for the (b) commit; parity test enforces presence of the new SHA.
- **Appendix B Architecture Note:** Assert `"current tooling, frozen source"` + `"git worktree"` + `"recovery_ref"` substrings present.
- **Voice rewrite (D-04):** Negative assertions against hedge language (`refute release_guide =~ "you should consider"`, `=~ "the maintainer can"` in routine-release section). Positive assertion: imperative-mood markers. Caveat: voice is fuzzy; keep negative assertions tight (5–6 explicit phrases) rather than trying to assert "voice quality."
- **CHANGELOG note (D-07):** New assertion in `package_metadata_test.exs` "unpacked changelog ships with the first-release entry" test — extend with shakedown-iteration note check.
- **Rollback rewrite (D-20..D-24):** Already covered in §(c) above — same parity test, same file.

**Update existing assertions to reflect renames (D-16):**
- `release_docs_parity_test.exs:104..114` `step_names` list: change `"Live publish to Hex"` → `"Publish to Hex.pm (live)"` and `"Wait for Hex.pm index"` → `"Wait for Hex.pm index (post-publish)"`. Both occurrences in `release_publish.md` AND `release.yml` must be updated atomically — that's what the parity test enforces.

**Order of edits inside the (a) wave:**
1. Add new parity assertions (red).
2. Update `release.yml` step names per D-16 (parity tests reference both files; updating just one breaks parity).
3. Edit `release_publish.md` top-to-bottom: TL;DR → existing happy-path (trim verbose prose only, D-01) → Footguns → Rollback rewrite → Appendix A → Appendix B.
4. Run `bash scripts/release_preflight.sh`. Assert green.
5. `mix docs --warnings-as-errors` will catch broken in-doc links — do not skip this gate.

## Common Pitfalls (specific to *validating* this work)

### Pitfall 1: `MIX_ENV=test` vs default `MIX_ENV=dev` drift
**What goes wrong:** Test invocations in CI vs local diverge silently. Precedent: `6dd0d54` had to fix `public_smoke.sh` to use `MIX_ENV=test` after the publish lane defaulted to dev. New `hex_release_exists_test.exs` must pin `MIX_ENV=test` like `package_metadata_test.exs:172` and like `public_smoke.sh:17`.
**Prevention:** Every `System.cmd("mix", ...)` or `System.cmd("bash", ...)` in the new test passes `env: [{"MIX_ENV", "test"}]` explicitly. Don't rely on inherited env.

### Pitfall 2: `mix hex.info` rate limits / network flake in unit tests
**What goes wrong:** A naive unit test that calls `mix hex.info rindle 0.1.4` directly will hit Hex.pm and (a) be slow, (b) fail offline, (c) be at the mercy of Hex.pm rate limits during CI bursts.
**Prevention:** Shim `mix` and `curl` via PATH-prepended fake-binary shims controlled by env vars (Wave 0 Gap). Never let the unit test touch the network. The single live exercise is the `workflow_dispatch` rehearsal post-merge.

### Pitfall 3: HEX_API_KEY / owner-key not set in CI for the new probe
**What goes wrong:** `mix hex.info` does NOT require an API key for read access (verified: `Wait for Hex.pm index` already calls it with `HEX_API_KEY: ""`). Probe will work in CI without any new secret. **But** if a future maintainer adds `mix hex.user whoami` to the probe (it's tempting), it will fail in CI without `HEX_API_KEY`.
**Prevention:** Document inline in `scripts/hex_release_exists.sh` that the script must NOT call any auth-required command. Add a parity assertion: `refute File.read!("scripts/hex_release_exists.sh") =~ "hex.user"` and `refute ... =~ "hex.owner"`.

### Pitfall 4: `$GITHUB_OUTPUT` corruption from extra stdout lines
**What goes wrong:** Bash script that prints diagnostic info before the `already_published=...` line will write multiple lines to `$GITHUB_OUTPUT` if the maintainer (or a future edit) accidentally uses `>> "$GITHUB_OUTPUT"` for the diagnostic. This silently corrupts the gate's `if:` evaluation.
**Prevention:** Unit test asserts the stdout shape: exactly one line matching `^already_published=(true|false)$`. Diagnostics go to stderr (`>&2`). Mirror the pattern from `assert_version_match.sh:25,31,36` (all errors go to stderr).

### Pitfall 5: Concurrency-token change race window (D-14)
**What goes wrong:** Tightening `concurrency.group` from event-conditional to a single global `release-publish-rindle` token closes a race, but only AFTER the change merges. In the brief window between merging the new probe and a release-please bot opening a new PR, an in-flight `workflow_dispatch` could still race a `push` event on the old concurrency value if the old workflow run is still pending.
**Prevention:** Validate by checking `gh run list --workflow=release.yml` shows no in-flight `release.yml` runs at merge time. Document this as a one-time merge precaution in the task description; not a recurring concern.

### Pitfall 6: Parity-test snippet brittleness — too many false positives on prose edits
**What goes wrong:** Asserting on long literal strings (e.g., the full footguns inventory) makes prose editing painful. Every comma change breaks the test.
**Prevention:** Keep snippet assertions to short, semantically distinctive substrings (e.g., `"--warnings-as-errors"`, `"8MB"`, `"version immutability"`). Avoid asserting on full sentences. Existing test pattern at `release_docs_parity_test.exs:36..45` is the model.

### Pitfall 7: Mocked-vs-live tradeoff for the live rehearsal
**What goes wrong:** The post-merge `workflow_dispatch` rehearsal (Layer 3) consumes a real Hex.pm API quota slot per call. Multiple rehearsal attempts in a debugging loop could trip rate limits.
**Prevention:** Get the unit + parity layers green first (deterministic, no network). Treat the live rehearsal as a single confirmation, not iterative debugging. If the live rehearsal fails, debug locally with shims first; do not retry blindly against Hex.pm.

### Pitfall 8: `mix hex.info` exit-code asymmetry
**What goes wrong:** `mix hex.info rindle <version>` exits 0 when the version exists; exits 1 when it doesn't. But it ALSO exits 1 on transient Hex.pm 5xx errors and on network failure. Treating "exit 1" as "not published" is the bug shape that re-creates run `25135467509` if applied to recovery: a transient error during recovery would let the publish step proceed and hit `--replace flag` again.
**Prevention:** This is exactly why D-09 specifies the curl HTTP fallback. The script must distinguish: `mix hex.info` exit 0 → published (return true); `mix hex.info` exit 1 + curl 404 → not published (return false); `mix hex.info` exit 1 + curl 200 → published (return true, fallback wins); `mix hex.info` error + curl error → INCONCLUSIVE (exit non-zero, do not write `already_published`). Unit test case (iv) covers this.

### Pitfall 9: `Mix.Project.config()[:version]` requires `mix.exs` to be loadable in the workflow shell
**What goes wrong:** D-15 replaces `sed` with `mix run --no-start --no-deps-check -e 'IO.puts(Mix.Project.config()[:version])'`. This assumes `mix` is on PATH and `mix.exs` is in cwd. The `Read release version from mix.exs` step in `release.yml` runs after `Set up Elixir for version resolution` but BEFORE `Materialize immutable release source tree` — the working directory is the standard checkout, which is fine. **But** this step does NOT have `--no-deps-check` in the existing `assert_version_match.sh` (line 10), which runs without `--no-deps-check` and would fail on missing deps. Adding `--no-deps-check` to the workflow inline is the right call; do not back-port the flag to `assert_version_match.sh` without checking that its callers (preflight) have already run `mix deps.get`.
**Prevention:** Validate the workflow change with a feature-branch CI run before merging. Confirm the `release_version` output is non-empty in the run's logs.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `mix hex.info <pkg> <version>` exits 0 if released, 1 if not, 1 on transient errors | Pitfall 8 + Validation Matrix | Probe could give false negatives on transient errors and re-trigger the original bug. **Mitigation already in plan:** D-09 mandates the curl HTTP fallback; unit test case (iv) covers inconclusive case. [VERIFIED: `release.yml:414` already relies on this exit-code semantic in `Wait for Hex.pm index`.] |
| A2 | Skipped steps in a GitHub Actions job leave the job conclusion as `success` | Validation Matrix (b) workflow gate | If skipped steps caused job-level failure, `public_verify` would not auto-run after a no-op probe. **[VERIFIED: GitHub Actions semantics — `if: false` steps skip cleanly; this is documented behavior, not assumption.]** |
| A3 | `mix hex.publish --revert VERSION` is the canonical Mix task; `mix hex.revert` does not exist | (c) §3 Command canonicalization | If `mix hex.revert` did exist, D-20 would be wrong. **[VERIFIED in CONTEXT.md D-20: "Verified against `hexpm/hex` source `lib/mix/tasks/hex.publish.ex` `@switches [revert: :string, ...]`".]** |
| A4 | `.planning/` is excluded from the published Hex package | (c) Evidence file | If included, the rehearsal evidence (which contains internal commentary) would ship to hexdocs.pm. **[VERIFIED: `package_metadata_test.exs:19` lists `.planning` in `@prohibited_paths` and `package_metadata_test.exs:75..78` asserts the path is absent from the unpacked tarball.]** |
| A5 | `release_docs_parity_test.exs` test names will accept `MIX_ENV=test` (no DB / no MinIO bootstrap needed) | Sampling Rate | If the parity test pulled in MinIO setup, the quick-run command would be slow. **[VERIFIED: test uses only `File.read!` on text files; no `use ExUnit.Case` setup beyond that. `mix.exs` does not list these install_smoke tests in `:test_paths` for the default suite — they're in `test/install_smoke/` and `release_preflight.sh:36..37` invokes them with explicit paths.]** |
| A6 | A bash script unit test under `test/scripts/` will be picked up by `mix test` automatically | Wave 0 Gaps | If `test_paths` excludes it, the test will silently not run. **[ASSUMED — needs verification at planning time.]** Mitigation: planner should either (i) place the new test under `test/install_smoke/` next to existing precedent, or (ii) verify `mix.exs` `:test_paths` includes the new directory, or (iii) add it explicitly to `release_preflight.sh`. Recommend (i) — co-located with peer release-validation tests. |

## Open Questions

1. **Should the new probe-script unit test live in `test/install_smoke/` or `test/scripts/`?**
   - What we know: `test/install_smoke/` is the established home for release-related ExUnit tests (`release_docs_parity_test.exs`, `package_metadata_test.exs`). `test/scripts/` does not exist yet.
   - What's unclear: Whether the planner wants to introduce a new test directory.
   - Recommendation: Co-locate at `test/install_smoke/hex_release_exists_test.exs`. Avoids `mix.exs` `:test_paths` change and inherits the existing preflight invocation in `release_preflight.sh:36..37`.

2. **Should the workflow_dispatch live rehearsal be required for phase signoff, or evidence-only?**
   - What we know: It is the only end-to-end proof that the original bug is fixed. CONTEXT does not explicitly require it.
   - What's unclear: Whether running it consumes adopter-visible Hex API budget meaningfully.
   - Recommendation: REQUIRED for phase signoff. One run against `recovery_ref=<sha-of-0.1.4>`; capture the run URL in the deviation log (D-05) entry for this phase as the proof artifact.

3. **Does the `Idempotent publish summary` step (D-11) need a parity assertion in `release_publish.md`?**
   - What we know: D-11 says the step writes to `$GITHUB_STEP_SUMMARY`; nothing about the runbook reflecting it.
   - What's unclear: Whether the runbook's "Recovery Workflow Contract" section should mention the skip-on-rerun semantics for maintainer 2am readability.
   - Recommendation: YES — add a one-line note to the Recovery Workflow Contract section: *"If the recovery run targets an already-published version, the publish steps skip and the summary tab shows the no-op message. Public verification still runs."* Add a parity assertion: `assert release_guide =~ "publish steps skip"` or similar.

## Environment Availability

> Validation tooling only — no new external dependencies introduced.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir 1.17 | All ExUnit tests | ✓ (CI + dev) | 1.17 | — |
| `mix` | `mix.exs` version parse (D-15), `mix hex.info` probe | ✓ | bundled with Elixir | — |
| `curl` | HTTP fallback in probe (D-09) | ✓ (ubuntu-latest + macOS dev) | system | — |
| `bash` | All `scripts/*.sh` | ✓ | ≥ 4 (uses `set -euo pipefail`) | — |
| `gh` CLI | Live `workflow_dispatch` rehearsal | ✓ (dev box) | — | Manual GitHub Actions UI dispatch |
| Hex.pm | Live rehearsal (read-only) | ✓ (network) | — | None — rehearsal requires network |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** None.

## Sources

### Primary (HIGH confidence)
- `/Users/jon/projects/rindle/.planning/phases/16-live-publish-execution-and-post-publish-verification/16-CONTEXT.md` — locked decisions D-01..D-25
- `/Users/jon/projects/rindle/test/install_smoke/release_docs_parity_test.exs` — current parity contract
- `/Users/jon/projects/rindle/test/install_smoke/package_metadata_test.exs` — current metadata contract + workflow assertions
- `/Users/jon/projects/rindle/.github/workflows/release.yml` — current workflow shape
- `/Users/jon/projects/rindle/scripts/assert_version_match.sh` — canonical `Mix.Project.config()[:version]` pattern (D-15)
- `/Users/jon/projects/rindle/scripts/release_preflight.sh` — `RINDLE_PROJECT_ROOT` discipline pattern
- `/Users/jon/projects/rindle/scripts/public_smoke.sh` — `MIX_ENV=test` precedent (`6dd0d54`)
- https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html — `--revert` flag canonical syntax (cited per CONTEXT D-20 verification)

### Secondary (MEDIUM confidence)
- GitHub Actions: skipped-step-passes-job semantics — well-documented platform behavior, not project-specific.

### Tertiary (LOW confidence)
- None for this validation layer; the underlying decisions are already research-grounded in CONTEXT.

## Project Constraints (workspace conventions)

- All `scripts/*.sh` accept `RINDLE_PROJECT_ROOT` env via `cd "${RINDLE_PROJECT_ROOT:-$(pwd)}"` — new `hex_release_exists.sh` MUST follow.
- `MIX_ENV=test` is the standard for smoke runs (precedent: `6dd0d54`) — new tests MUST pin it explicitly.
- Never use destructive Hex commands in CI (D-13: `--replace` forbidden in CI; D-19: revert/retire only on maintainer machine).
- Conventional commits required for release-please autopilot — new commits in this phase use `fix(release): ...`, `docs(release): ...`, `test(release): ...` prefixes.
- `.planning/` is `@prohibited_paths` — evidence files do not ship to hexdocs.

## Metadata

**Confidence breakdown:**
- Validation matrix: HIGH — every assertion maps to an existing test file pattern or a CONTEXT-locked decision
- Pitfalls: HIGH — derived from concrete artifacts (run `25135467509` failure, `6dd0d54` precedent, existing test file shape)
- Open questions: MEDIUM — 3 questions flagged for planner judgment

**Research date:** 2026-04-30
**Valid until:** 2026-05-30 (30 days; runbook + workflow are stable surfaces)

## RESEARCH COMPLETE

Validation playbook for Phase 16: idempotency probe proven via shimmed unit tests + parity assertions + one live `workflow_dispatch` rehearsal; rehearsal evidence captured as a structured tabletop transcript with read-only Hex commands only; runbook deviations enforced via extended snippet assertions in `release_docs_parity_test.exs` and `package_metadata_test.exs`. No live publish, no live revert, no destructive Hex commands in CI.
