# Phase 15 Release Candidate Checklist

Status: CLOSED — retroactive: v0.1.0–v0.1.4 shipped during Phase 15 execution; package name claimed; checklist serves as the historical record of the first-publish boundary.

This phase was authored on 2026-04-29 assuming v0.1.0 was the upcoming first publish. During execution the release-please pipeline auto-bumped through 0.1.0, 0.1.1, 0.1.2, 0.1.3, and 0.1.4; `mix hex.info rindle` shows `Releases: 0.1.4` live on Hex.pm. The maintainer-only Hex checks below were completed against the post-publish state, and the green CI run on the current HEAD is recorded as the authoritative remote proof of the release-pipeline contract Phase 15 was created to enforce.

Local preflight is diagnostic preparation, not authoritative release proof.
Authoritative signoff requires a green GitHub Actions run on the exact release-candidate SHA.
Maintainer-only Hex identity, owner, and package-name availability checks stay outside `scripts/release_preflight.sh` and outside secret-gated automation.

## Release Candidate

- Exact release-candidate SHA: `6dd0d54081c89b68c630d9642a40453d310008c6`
- GitHub Actions run URL for that exact SHA: https://github.com/szTheory/rindle/actions/runs/25135464796
- CI completed at: 2026-04-29T21:49:44Z
- Go / no-go decision: GO — retroactive: 0.1.4 already published from this pipeline lineage; checklist closes the v0.1.0 first-publish gate after the fact.

## Required Remote Proof

- [x] GitHub Actions CI is green on the exact release-candidate SHA
- [x] The passing run includes the `Package Consumer + Release Preflight` lane
- [x] The recorded run URL points to the same SHA listed above

## Required Local Diagnostics

- [x] `bash scripts/release_preflight.sh` passed on the exact release-candidate SHA
- [x] Tarball contents reviewed from the unpacked artifact
- [x] `hex_metadata.config` reviewed from the unpacked artifact
- [x] `CHANGELOG.md` confirmed with `0.1.0` entry in the packaged artifact

## Maintainer-Only Hex Checks

- [x] `mix hex.user whoami` reviewed
- [x] `mix hex.owner list rindle` reviewed
- [x] Manual `rindle` package-name availability confirmation completed (N/A post-publish — name owned)

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

## Review Notes

- Tarball / metadata review: enforced on every CI run by `test/install_smoke/package_metadata_test.exs` (package name, version, MIT license, GitHub links, required shipped files including `CHANGELOG.md` with `0.1.0` entry, prohibited repo paths excluded). Latest pass on SHA `6dd0d54` via run `25135464796`.
- CI observations: the `CI` workflow on HEAD is green. Separately, the most recent `Release` workflow `workflow_dispatch` run (`25135467509`, 2026-04-29T21:43Z) failed after `Publish to Hex` set its release_version output — likely on `public_verify`. That failure is in the manual-recovery path of `release.yml` and is tracked as a follow-up; it does not gate Phase 15 closure because the `CI` lane this checkpoint requires is green and 0.1.4 is published.
- Signoff notes: Phase 15 hardening landed (Wave 1: preflight artifact path + shipped CHANGELOG contract; Wave 2 Task 1: runbook boundary + parity test + checklist template). The trust-boundary tests in `test/install_smoke/release_docs_parity_test.exs` continue to enforce the manual-check contract for any future first-publish-style work.
