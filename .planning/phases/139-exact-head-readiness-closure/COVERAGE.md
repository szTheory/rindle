# API Coverage — GitHub Actions, repository, security, and Hex audit read-only surfaces

> Full coverage for the Phase 139 read-only readiness need. This matrix concerns consumed endpoint families, not GitHub's unrelated full product API. Each OPT-OUT is explicit.

| capability | decision | reason |
|---|---|---|
| GitHub refs main resolution | INTEGRATE | |
| GitHub workflow runs and run details | INTEGRATE | |
| GitHub jobs for exact run attempt with pagination | INTEGRATE | |
| GitHub commit checks and legacy statuses for PR heads | INTEGRATE | |
| GitHub issues with PR distinction and pagination | INTEGRATE | |
| GitHub pull requests and exact heads | INTEGRATE | |
| GitHub repository advisories | INTEGRATE | |
| GitHub Dependabot alerts | INTEGRATE | |
| GitHub classic branch protection | INTEGRATE | |
| GitHub active repository and organization rulesets | INTEGRATE | |
| GitHub artifact upload/download and metadata | INTEGRATE | |
| GitHub completed run/attempt digest-sidecar metadata | INTEGRATE | Producer digest sidecar is authenticated to the selected completed run/attempt; durable host consumes it before byte comparison. |
| Hex audit findings and database identity | INTEGRATE | |
| GitHub issue, PR, advisory, ruleset mutation | OPT-OUT | Readiness is read-only; D-25 forbids remote mutation authority. |
| GitHub maintainer readiness-retention workflow dispatch | INTEGRATE | |
| GitHub Nightly workflow dispatch as scheduled evidence | OPT-OUT | A diagnostic dispatch cannot satisfy scheduled Nightly closure; D-12. |
| Hex publish or dependency mutation | OPT-OUT | Release Please owns release intent; D-25 forbids publish authority. |
