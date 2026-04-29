# Phase 15 Release Candidate Checklist

Status: BLOCKED pending exact-SHA remote CI proof and maintainer signoff

As of 2026-04-29, local HEAD `566f6f4a7f0ff4ac73befa62d050ef55036769c4` had no recorded GitHub Actions CI proof for the exact release-candidate SHA. Before Phase 16 pushes a live tag, replace that missing-proof state with the exact commit that will actually be tagged and the matching CI run URL.

Local preflight is diagnostic preparation, not authoritative release proof.

## Release Candidate

- Exact release-candidate SHA:
- GitHub Actions run URL for that exact SHA:
- CI completed at:
- Go / no-go decision:

## Required Remote Proof

- [ ] GitHub Actions CI is green on the exact release-candidate SHA
- [ ] The passing run includes the `Package Consumer + Release Preflight` lane
- [ ] The recorded run URL points to the same SHA listed above

## Required Local Diagnostics

- [ ] `bash scripts/release_preflight.sh` passed on the exact release-candidate SHA
- [ ] Tarball contents reviewed from the unpacked artifact
- [ ] `hex_metadata.config` reviewed from the unpacked artifact
- [ ] `CHANGELOG.md` confirmed with `0.1.0` entry in the packaged artifact

## Maintainer-Only Hex Checks

- [ ] `mix hex.user whoami` reviewed
- [ ] `mix hex.owner list rindle` reviewed
- [ ] Manual `rindle` package-name availability confirmation completed

### Command Output Notes

```text
mix hex.user whoami:

mix hex.owner list rindle:

package-name availability check:
```

## Review Notes

- Tarball / metadata review:
- CI observations:
- Signoff notes:
