# Readiness evidence storage and access

Readiness evidence is a saved proof of what passed for one exact source commit
during one recorded interval: test receipts, CI and scheduled Nightly identities,
security inventory coverage, package identity, checksums and the terminal verdict.
It does not grant readiness to later commits or authorize a release. The commands
and acceptance rules are in [Running](running.html#maintainer-exact-head-readiness-evidence).

## Recommended storage

Use a restricted persistent folder outside all repository checkouts. On macOS:

```bash
mkdir -p "$HOME/Library/Application Support/Rindle/readiness"
chmod 700 "$HOME/Library/Application Support/Rindle/readiness"
```

Each attempt needs distinct, previously nonexistent subject and acceptance children.
Keep successful evidence through the lifetime of the readiness claim. Keep failed
attempts while diagnosing them; do not overwrite a failure to make it appear successful.
Include the evidence folder in an encrypted backup and periodically restore and verify
the recorded hashes. Folder creation alone does not establish backup or disk encryption. The maintainer
selected `~/Dropbox/Rindle/readiness` for the secondary redacted evidence copy. Keep
credentials and raw restricted diagnostics local; verify copied bytes and confirm
Dropbox synchronization separately. No terminal bundle has yet been copied.

| Choice | Benefit | Limitation | Decision |
| --- | --- | --- | --- |
| GitHub Actions artifacts | Run-bound transfer with artifact IDs and digests | Expire; deleted runs also lose their artifacts | Keep the existing 30-day transfer window |
| Persistent local files plus encrypted backup | No service, SDK or new dependency; survives checkout cleanup | Maintainer must protect and back up the host | Default for this project |
| Private object storage | Shared access and centralized retention | Credentials, cost and another operational system | Add only when multiple maintainers or policy require it |
| Git, temporary folders, build caches or a run URL alone | Convenient | Confidentiality, cleanup or retention problems; a URL does not preserve bytes | Not an evidence archive |

The controller verifies the producer run/attempt, separate digest sidecar, archive
and manifest, then retains the bytes and locator with restricted permissions. Hashes
detect byte changes; they do not replace authenticated provenance or backups. Raw
private API responses and command logs belong under `restricted/`. Public receipts
must remain redacted. A green upload or a restored file alone does not satisfy acceptance.

GitHub distinguishes artifacts from caches and supports explicit artifact retention;
public-repository retention is capped. See [workflow artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts)
and [repository retention settings](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository).

## Recommended credential setup

For this bounded maintainer run, use a short-lived fine-grained personal access token
restricted to `szTheory/rindle`, with these repository permissions set to **read**:
Actions, Administration (protection/rulesets), Checks, Commit statuses, Contents,
Dependabot alerts, Issues, Pull requests, and Repository security advisories.
Metadata read access is implicit. The account must already have full repository
advisory visibility; a token cannot grant rights its owner lacks. Provision the value
directly as the `READINESS_READ_TOKEN` repository Actions secret, never in chat or Git.
Use the shortest practical expiry and revoke it after the acceptance window.

The producer only reads remote state. Its token needs no merge, publish, secret-write
or alert-dismissal permission. The durable maintainer controller separately needs
authorized Actions workflow dispatch plus artifact/source reads; keep that local
authentication separate. For recurring unattended runs, prefer a repository-scoped
GitHub App with short-lived installation tokens when its permissions satisfy every
collector endpoint; do not add App infrastructure for a single run without need.

GitHub recommends minimum permissions and expiration, and fine-grained tokens over
classic tokens. Its repository advisory and Dependabot listing endpoints both support
read permissions. See [credential security](https://docs.github.com/en/rest/authentication/keeping-your-api-credentials-secure),
[repository advisory listing](https://docs.github.com/en/rest/security-advisories/repository-advisories#list-repository-security-advisories),
and [Dependabot alert listing](https://docs.github.com/en/rest/dependabot/alerts#list-dependabot-alerts-for-a-repository).

## Current live prerequisites

The authenticated Dependabot alerts GET on 2026-10-22 initially returned
`Dependabot alerts are disabled for this repository` (403). After user authorization,
dependency alerts and the graph were enabled; the setting read returned 204 and
the alerts GET succeeded. Automatic security-update PRs remain disabled. A fresh
complete inventory must still be collected and actual findings dispositioned;
existing exceptions must be checked against those findings. The user provisioned the
Rindle-only expiring producer token on 2026-10-22; the secret metadata confirms its
presence, while actual workflow reads must still prove its access.
Security-setting changes and credential provisioning are separate authorized
maintainer operations under RUNNING.md.

The scheduled Nightly must pass for the accepted main SHA. Its current schedule is
07:27 UTC daily; dispatching it manually does not supply scheduled-event evidence,
and GitHub may delay scheduled execution. PR merge, storage setup and fixture tests
leave READY requirements open until terminal live acceptance passes.
