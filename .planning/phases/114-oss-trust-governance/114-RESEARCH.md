# Phase 114: OSS Trust & Governance - Research

**Researched:** 2026-06-30
**Domain:** OSS governance files (SECURITY.md, CODE_OF_CONDUCT.md, GitHub issue/PR templates) + Hex package metadata (`package.links`, `maintainers`)
**Confidence:** HIGH

## Summary

Phase 114 is a low-risk, docs/config-only phase: no `lib/` change, no behavior change. It adds the
conventional OSS-trust governance files and two Hex metadata keys. All five requirements
(TRUST-01/02/03, META-01/02) are well-understood, standard conventions — the research effort is spent
(a) grounding `SECURITY.md`'s "what to report" section in Rindle's **actual** verified threat surface so
it is concrete and credible, and (b) pinning exact copy-pasteable syntax so the planner can write
zero-ambiguity tasks.

The single load-bearing pitfall: **`test/install_smoke/package_metadata_test.exs` (line 71-72) asserts
the EXACT `links` map equals `{<<"GitHub">>,<<"...">>}` and nothing else** [VERIFIED: read test file].
META-01 (adding "Changelog" + "Docs") WILL red-CI on the merge-blocking Quality lane unless that
assertion is updated in the SAME phase. This is the repo's documented meta-test-coupling footgun.

**Primary recommendation:** Place all four governance files at **repo root** (`SECURITY.md`,
`CODE_OF_CONDUCT.md`) and `.github/` (issue forms + `PULL_REQUEST_TEMPLATE.md`). Do NOT add them to
mix.exs `files:` — keep them repo-only (out of the Hex tarball), consistent with `.github` already being
in the meta-test's `@prohibited_paths`. Use GitHub **issue forms** (`.yml`) for new templates (the
existing `release-train-drift.md` legacy markdown template stays untouched — GitHub supports both formats
in the same directory). Update `package_metadata_test.exs` in lockstep with the `package.links` change.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Vulnerability disclosure policy (TRUST-01) | Repo metadata (GitHub) | — | SECURITY.md is a GitHub-surfaced repo file; auto-detected at root/.github/docs |
| Code of conduct (TRUST-02) | Repo metadata (GitHub) | — | GitHub-surfaced community health file |
| Issue/PR templates (TRUST-03) | Repo metadata (`.github/`) | — | GitHub-rendered new-issue/new-PR forms |
| Hex package links + maintainers (META-01/02) | Build config (`mix.exs`) | Hex.pm / HexDocs | `package/0` map; surfaced on hex.pm package page |

## User Constraints (from locked decisions — no CONTEXT.md present)

### Locked Decisions
- **TRUST-01 disclosure channel: GitHub Private Vulnerability Reporting** (Security > Advisories > "Report
  a vulnerability"). No email exposed. SECURITY.md points reporters to that button. Repo-settings
  enablement (Settings > Code security > Private vulnerability reporting) is an operational follow-up.
- **META-02 maintainers value: `szTheory`** (from @source_url + git owner).
- **CODE_OF_CONDUCT.md: Contributor Covenant** (standard default).

### Claude's Discretion
- Issue templates: markdown vs forms (RECOMMENDATION below: forms).
- Exact SECURITY.md section copy and supported-versions wording.
- CoC enforcement-contact line value (RECOMMENDATION below).
- Whether governance files ship in the Hex tarball (RECOMMENDATION below: no).

### Deferred Ideas (OUT OF SCOPE)
- VERSION-01/02, README-01/02 (Phase 115); MIGRATE-01/02 (Phase 116); all v1.23 ISO23 schema work.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TRUST-01 | `SECURITY.md` with disclosure policy for a lib handling untrusted uploads, MIME sniffing, signed delivery, webhook HMAC | Verified threat surface (modules listed below); GitHub PVR flow; pre-1.0 supported-versions policy |
| TRUST-02 | `CODE_OF_CONDUCT.md` | Contributor Covenant 2.1 exact source + enforcement-contact recommendation |
| TRUST-03 | `.github/ISSUE_TEMPLATE/` + `PULL_REQUEST_TEMPLATE.md` | Issue-forms vs markdown decision; `config.yml`; existing `release-train-drift.md` preservation |
| META-01 | `package.links` "Changelog" + "Docs" alongside "GitHub" | Exact map syntax + canonical URLs + the meta-test that must be updated in lockstep |
| META-02 | `package` declares `maintainers` | Exact `maintainers: ["szTheory"]` key syntax |
</phase_requirements>

## Standard Stack

No new dependencies. All deliverables are static files + two `mix.exs` keys. **Package Legitimacy Audit
and Environment Availability sections are intentionally omitted — this phase installs zero packages and
has no external runtime dependency** (governance/config files only).

## TRUST-01: SECURITY.md — Verified Threat Surface

GitHub auto-detects `SECURITY.md` at **root**, `.github/`, or `docs/` [CITED:
docs.github.com/en/code-security/getting-started/adding-a-security-policy-to-your-repository]. When
present, GitHub shows a "Security policy" link on the Security tab and links it from the new-issue page.
**Recommendation: place at repo root** (most discoverable; consistent with `CONTRIBUTING.md` already at
root).

**"What to report" section must name Rindle's real security-relevant surfaces.** Verified by grepping
`lib/` [VERIFIED: grep + read of source]:

| Surface | Module(s) | What SECURITY.md should acknowledge |
|---------|-----------|-------------------------------------|
| Untrusted upload validation | `lib/rindle/security/upload_validation.ex`, `lib/rindle/security/filename.ex`, `lib/rindle/security/storage_key.ex` | Path/filename/storage-key sanitization; metadata validation before promotion |
| Content-type / MIME sniffing | `lib/rindle/security/mime.ex` (magic-byte detection via `ex_marcel`, 8 KB probe; `extension_matches_mime?`) | MIME-confusion / content-type spoofing on uploads |
| Malware scanning hook | `lib/rindle/scanner.ex` (behaviour: scan-before-promotion) | Adopter-provided scanner contract; scanning happens before promotion |
| Signed/time-limited delivery | `lib/rindle/delivery.ex` (private-by-default, `signed_url_ttl_seconds: 900`), `lib/rindle/storage/gcs/signer.ex` (V4 signed URLs) | Signed-URL TTL, accidental public exposure (the "most common media mistake" per `guides/secure_delivery.md`) |
| Webhook HMAC verification | `lib/rindle/delivery/webhook_plug.ex`, `lib/rindle/streaming/provider/mux.ex` (`Mux.Webhooks.verify_header`, `webhook_tolerance_seconds: 300` replay window), `lib/rindle/delivery/webhook_body_reader.ex` (verified raw body) | Signature mismatch, replay-window bypass, secret handling |
| Subprocess / arg handling | `lib/rindle/security/argv.ex`, `muontrap` | Command-arg injection into media tooling (ffmpeg/libvips) |

Cross-reference the existing `guides/secure_delivery.md` ("private-by-default", signed time-limited URLs)
so the policy aligns with shipped docs [VERIFIED: read guide].

**Supported-versions policy (pre-1.0 / 0.x).** Recommendation [CITED: SemVer 0.x convention + GitHub
SECURITY.md norms]: a minimal table stating that **only the latest 0.x release line receives security
fixes** — no backports to older 0.x minors pre-1.0. Example:

| Version | Supported |
|---------|-----------|
| latest 0.x | ✅ |
| older 0.x | ❌ (upgrade to latest) |

**Standard section layout** (GitHub convention) [CITED: github SECURITY.md examples]:
1. `## Supported Versions` (the table above)
2. `## Reporting a Vulnerability` — direct reporters to **Security > Advisories > "Report a
   vulnerability"** (GitHub Private Vulnerability Reporting); state no public issues / no email.
3. Response expectations — acknowledgment + triage timeframe (pre-1.0 best-effort; keep modest, e.g.
   "acknowledge within a few business days").
4. Optional: "What to report" pointing at the surfaces above.

**Operational follow-up (not a code change — note as a checklist item):** Private Vulnerability Reporting
must be enabled in repo **Settings > Code security > Private vulnerability reporting** for the "Report a
vulnerability" button to appear. The SECURITY.md is inert until this toggle is on. The planner should add
a `checkpoint:human-verify` or a documented manual step for this.

## TRUST-02: CODE_OF_CONDUCT.md — Contributor Covenant 2.1

Current version is **2.1** [VERIFIED: contributor-covenant.org]. Source markdown:
`https://www.contributor-covenant.org/version/2/1/code_of_conduct/code_of_conduct.md` [CITED].

The template has exactly one placeholder to fill — the Enforcement section line [VERIFIED: fetched
source]:

> "Instances of abusive, harassing, or otherwise unacceptable behavior may be reported to the community
> leaders responsible for enforcement at **[INSERT CONTACT METHOD]**."

**Enforcement-contact recommendation.** The CoC contact is a **community-conduct** channel, distinctly NOT
the security channel (TRUST-01 owns security via PVR). Since `szTheory` uses a `noreply` git email
[locked context], do not invent an email. Recommend a **GitHub-based contact**, e.g. *"by opening a
private report via the repository's Security advisories, or by contacting the maintainer
([@szTheory](https://github.com/szTheory)) directly on GitHub."* Keep it GitHub-routed to avoid exposing a
personal address. Preserve the standard attribution/footer (links to contributor-covenant.org homepage +
FAQ) verbatim. GitHub auto-detects `CODE_OF_CONDUCT.md` at root/.github/docs — **place at repo root**.

## TRUST-03: Issue Templates + PULL_REQUEST_TEMPLATE.md

**Current state** [VERIFIED: ls]: `.github/ISSUE_TEMPLATE/` exists with ONE file —
`release-train-drift.md` (legacy markdown template, maintainer-facing release-automation issue). **Do NOT
clobber or convert it.** No `config.yml`, no `PULL_REQUEST_TEMPLATE.md` exist yet.

**Decision: use GitHub issue FORMS (`.yml`)** for the new newcomer-facing templates (bug report, feature
proposal). Rationale: forms enforce structured input (required fields, dropdowns), render better for
newcomers than free-text markdown, and are GitHub's current-recommended format. **Forms and legacy
markdown templates coexist in the same `ISSUE_TEMPLATE/` directory** — adding `.yml` forms does not
disturb the existing `.md` template [CITED: GitHub issue-template docs].

**Recommended `.github/` layout:**
```
.github/
├── ISSUE_TEMPLATE/
│   ├── release-train-drift.md     # EXISTING — leave untouched
│   ├── bug_report.yml             # NEW — issue form
│   ├── feature_request.yml        # NEW — issue form
│   └── config.yml                 # NEW — blank_issues_enabled + contact_links
└── PULL_REQUEST_TEMPLATE.md       # NEW — single PR template at .github/ root
```

**Issue form front-matter (`.yml`) — pinned skeleton** [CITED: GitHub issue-forms syntax]:
```yaml
name: Bug report
description: Report a defect in Rindle
labels: ["type:bug"]
body:
  - type: markdown
    attributes:
      value: "Before filing, see [CONTRIBUTING.md](../CONTRIBUTING.md) for how CI gates your report."
  - type: textarea
    id: what-happened
    attributes:
      label: What happened?
      description: Steps to reproduce, expected vs actual.
    validations:
      required: true
  - type: input
    id: version
    attributes:
      label: Rindle version
    validations:
      required: true
  - type: input
    id: elixir-otp
    attributes:
      label: Elixir / OTP version
```
Top-level keys for forms: `name`, `description`, `title` (optional default), `labels`, `assignees`
(optional), `body` (list of fields). Each `body` field has a `type` (`markdown`/`input`/`textarea`/
`dropdown`/`checkboxes`), `id`, `attributes`, and optional `validations`.

**`config.yml`** [CITED: GitHub docs]:
```yaml
blank_issues_enabled: false
contact_links:
  - name: Report a security vulnerability
    url: https://github.com/szTheory/rindle/security/advisories/new
    about: Please report vulnerabilities privately, not as a public issue.
```
Setting `blank_issues_enabled: false` forces the form picker; the `contact_links` security entry routes
security reports away from public issues to the advisory flow — reinforcing TRUST-01.

**`PULL_REQUEST_TEMPLATE.md`** — single template at `.github/PULL_REQUEST_TEMPLATE.md` (plain markdown,
GitHub auto-applies to the PR body). Should include: summary, linked issue, checklist (`mix ci` green,
docs updated, no `lib/` behavior change if docs-only), and a pointer to `CONTRIBUTING.md`. Note the repo's
existing CONTRIBUTING handoff convention — the trust/speed paragraph paste is a `/gsd-ship`-time step, not
something the PR template must duplicate; a short reference is enough.

All new templates should reference the CI-only `CONTRIBUTING.md` as the complement (CONTRIBUTING = CI
behavior; templates = the newcomer on-ramp).

## META-01: package.links Changelog + Docs

**Current `mix.exs` `package/0`** [VERIFIED: read, lines 279-288]:
```elixir
defp package do
  [
    licenses: ["MIT"],
    links: %{
      "GitHub" => @source_url
    },
    files:
      ~w(lib priv/repo/migrations priv/static/rindle_admin mix.exs README.md RUNNING.md CHANGELOG.md LICENSE guides)
  ]
end
```

**Pinned change** (add Changelog + Docs; add `maintainers` for META-02 in the same edit):
```elixir
defp package do
  [
    licenses: ["MIT"],
    maintainers: ["szTheory"],
    links: %{
      "GitHub" => @source_url,
      "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
      "Docs" => "https://hexdocs.pm/rindle"
    },
    files:
      ~w(lib priv/repo/migrations priv/static/rindle_admin mix.exs README.md RUNNING.md CHANGELOG.md LICENSE guides)
  ]
end
```

**Canonical URLs** [CITED: hex.pm/docs/publish; HexDocs conventions]:
- **Changelog → `https://github.com/szTheory/rindle/blob/main/CHANGELOG.md`** (GitHub blob URL on the
  default `main` branch). Hex.pm has special handling for a link literally named **"Changelog"** —
  hexdocs/hex.pm surface it prominently [CITED]. `CHANGELOG.md` already ships in the tarball, so an
  in-tarball changelog is also rendered on HexDocs; the package-page link points at the GitHub blob, which
  is the conventional target. (Alternative: `https://hexdocs.pm/rindle/changelog.html` — but the GitHub
  blob URL is the more common convention and matches the existing GitHub-rooted link.)
- **Docs → `https://hexdocs.pm/rindle`** (no version suffix → always redirects to latest) [VERIFIED:
  hexdocs redirect behavior; matches existing README badge `https://hexdocs.pm/rindle`].

**Hex special-surfacing:** hex.pm specially recognizes/links the **"GitHub"** and **"Changelog"** link
names [CITED: hex.pm publish docs]. "Docs" is conventional but not special-cased — still rendered as a
named link. Naming them exactly "Changelog" and "Docs" matches the requirement wording and HexDocs
convention.

## META-02: maintainers

**Pinned syntax** — a top-level key in the `package/0` keyword list (shown in the META-01 block above):
```elixir
maintainers: ["szTheory"],
```
`maintainers` is a list of strings [CITED: hex.pm/docs/publish]. Value `["szTheory"]` per locked decision.
Surfaced in the "Maintainers" section of the hex.pm package page.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Code of conduct text | A custom CoC | Contributor Covenant 2.1 verbatim | Industry-standard, GitHub-recognized, legally reviewed |
| Vulnerability intake | An email mailbox / custom form | GitHub Private Vulnerability Reporting | Locked decision; no email exposure; GitHub-native triage |
| Issue intake structure | Free-text markdown only | GitHub issue forms (`.yml`) | Structured, validated, better newcomer UX |

## Common Pitfalls

### Pitfall 1: package_metadata_test.exs hard-asserts the exact links map (LOAD-BEARING)
**What goes wrong:** `test/install_smoke/package_metadata_test.exs:71-72` asserts the unpacked Hex
metadata `links` equals exactly `[{<<"GitHub">>,<<"https://github.com/szTheory/rindle">>}]` [VERIFIED:
read test]. Adding "Changelog" + "Docs" changes the serialized `links` tuple list → this assertion fails →
red CI on the merge-blocking Quality lane.
**Why it happens:** This repo couples meta-tests to exact mix.exs package contents (documented history:
OBS-02 meta-test content drift, install_smoke path coupling).
**How to avoid:** In the SAME phase/PR that edits `package.links`, update line 71-72's assertion to match
the new three-entry map (order-independent: assert each `{<<"GitHub">>,...}`, `{<<"Changelog">>,...}`,
`{<<"Docs">>,...}` tuple is present rather than equality on the whole list). The planner MUST pair the
mix.exs edit with the test edit in one task or one wave.
**Warning signs:** `mix ci` → `package_metadata_test` failure on the `links` assertion.

### Pitfall 2: Governance files accidentally added to the Hex tarball
**What goes wrong:** Adding `SECURITY.md`/`CODE_OF_CONDUCT.md`/`.github` to mix.exs `files:` ships them in
the package and would trip the meta-test's `@prohibited_paths` (which already lists `.github`) [VERIFIED:
read test line 34].
**How to avoid:** Do NOT touch `files:`. Governance files are repo-only (GitHub-facing), not adopter-facing
package contents. Default `mix hex.build` only includes the explicit `files:` list, so untouched =
correctly excluded.

### Pitfall 3: SECURITY.md inert without the repo-settings toggle
**What goes wrong:** The "Report a vulnerability" button does not appear unless Private Vulnerability
Reporting is enabled in repo Settings. A committed SECURITY.md alone does not enable it.
**How to avoid:** Track the Settings toggle as an explicit operational checklist item /
`checkpoint:human-verify`. It is not a code change and cannot be verified by tests.

### Pitfall 4: Clobbering the existing release-train-drift.md template
**What goes wrong:** Overwriting or "consolidating" `.github/ISSUE_TEMPLATE/release-train-drift.md`
(maintainer-facing release-automation template) removes the stuck-release on-ramp.
**How to avoid:** Add NEW files alongside it; never edit or move it. Forms (`.yml`) and the legacy `.md`
coexist.

## Runtime State Inventory

This is a greenfield-file phase (adding new governance files + two mix.exs keys), not a rename/refactor.
The only "state" considerations:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None | — |
| Live service config | GitHub repo setting: Private Vulnerability Reporting must be enabled (Settings > Code security) — lives in GitHub UI, not git | Manual toggle (operational follow-up; checkpoint) |
| OS-registered state | None | — |
| Secrets/env vars | None (no email/secret introduced; CoC contact is GitHub-routed) | — |
| Build artifacts | `mix.exs` `package.links` change re-serializes `hex_metadata.config` at next `hex.build` — drives Pitfall 1 test update | Update package_metadata_test in lockstep |

## Validation Architecture

Nyquist validation is **enabled** (`workflow.nyquist_validation` absent in `.planning/config.json` →
treat as enabled). This phase warrants **light, high-value validation** given the repo's install_smoke
meta-test history.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.15+); merge-blocking via `mix ci` → `CI Summary` gate |
| Config file | `test/test_helper.exs` (default-tag suite) |
| Quick run command | `mix test test/install_smoke/package_metadata_test.exs` |
| Full suite command | `mix ci` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| META-01 | `links` map includes GitHub + Changelog + Docs | meta-test (existing, MUST UPDATE) | `mix test test/install_smoke/package_metadata_test.exs` | ✅ exists — assertion must change (Pitfall 1) |
| META-02 | `maintainers` present in package metadata | meta-test (add assertion) | `mix test test/install_smoke/package_metadata_test.exs` | ✅ extend same test (`metadata =~ ~s({<<"maintainers">>,[<<"szTheory">>]}.)`) |
| TRUST-01 | `SECURITY.md` exists at repo root | governance-presence test | new assertion (see Wave 0) | ❌ Wave 0 |
| TRUST-02 | `CODE_OF_CONDUCT.md` exists at repo root | governance-presence test | new assertion | ❌ Wave 0 |
| TRUST-03 | issue forms + `PULL_REQUEST_TEMPLATE.md` exist; `release-train-drift.md` preserved | governance-presence test | new assertion | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test test/install_smoke/package_metadata_test.exs`
- **Per wave merge:** `mix ci`
- **Phase gate:** full `mix ci` green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] Update `test/install_smoke/package_metadata_test.exs` `links` assertion (line 71-72) to the
      three-entry map — covers META-01. **This is a modification, not a new file.**
- [ ] Add a `maintainers` assertion to `package_metadata_test.exs` — covers META-02.
- [ ] Add a small governance-presence test (e.g. `test/install_smoke/governance_files_test.exs`)
      asserting `File.exists?` for `SECURITY.md`, `CODE_OF_CONDUCT.md`,
      `.github/PULL_REQUEST_TEMPLATE.md`, `.github/ISSUE_TEMPLATE/config.yml`, the new bug/feature forms,
      AND that `release-train-drift.md` still exists — covers TRUST-01/02/03 and locks against Pitfall 4.
      Keep these as repo-relative `File.exists?` checks (cheap; runs in the default-tag suite).

*Note: governance-presence tests assert repo files exist; they do NOT assert the files are in the Hex
tarball (they are intentionally repo-only — Pitfall 2). Do not add `.github`/`SECURITY.md` to the
`@required_paths` tarball list.*

## Security Domain

`security_enforcement` is absent in config → treat as enabled. However, this phase **writes no
security-relevant code** — it documents the existing threat surface. The ASVS-relevant content is already
implemented in `lib/rindle/security/*` and the webhook/delivery modules (mapped in the TRUST-01 table).
SECURITY.md's job is to accurately describe that surface, not add controls.

| ASVS Category | Applies to this phase | Note |
|---------------|----------------------|------|
| V1 Documentation / SDLC | yes | SECURITY.md = the disclosure process artifact (ASVS V1.x governance) |
| V5 Input Validation | documented, not changed | Existing `upload_validation.ex` / `mime.ex` — described, not modified |
| V6 Cryptography | documented, not changed | Existing webhook HMAC (`verify_header`, 300s tolerance) + signed URLs — described |

No hand-rolled crypto, no new validation. The phase's only security action is enabling GitHub PVR (a repo
setting) and accurately documenting the surface.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | hex.pm specially surfaces a link named exactly "Changelog" (beyond "GitHub") | META-01 | LOW — even if not special-cased, it still renders as a named link; requirement only asks for the entry to exist |
| A2 | Changelog link target should be the GitHub blob URL (vs `hexdocs.pm/rindle/changelog.html`) | META-01 | LOW — both are valid; GitHub blob matches the existing GitHub-rooted convention. Confirm with maintainer if a HexDocs-internal target is preferred |
| A3 | Default branch is `main` (for the Changelog blob URL) | META-01 | LOW — repo uses `main` (git status confirms `main`), so `/blob/main/CHANGELOG.md` is correct |

## Open Questions

1. **Changelog link target: GitHub blob vs HexDocs changelog page?**
   - What we know: both render; "Changelog" name is the convention hex.pm surfaces.
   - What's unclear: maintainer preference.
   - Recommendation: GitHub blob URL (`/blob/main/CHANGELOG.md`) — matches existing GitHub-rooted link;
     trivially swappable. Not a blocker.

2. **CoC enforcement contact exact wording.**
   - What we know: must be GitHub-routed (szTheory uses noreply email); not the security channel.
   - Recommendation: route to GitHub (Security advisories for private, or @szTheory profile). Planner can
     pick final wording; low risk.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Markdown issue templates (`.md`) | GitHub issue **forms** (`.yml`) | GitHub forms GA ~2021 | Structured/validated intake; coexists with legacy `.md` in same dir |
| `security@` email in SECURITY.md | GitHub Private Vulnerability Reporting | GitHub PVR GA 2023 | No email exposure; native private advisory triage (the locked TRUST-01 choice) |
| Contributor Covenant 2.0 | Contributor Covenant **2.1** | 2021 | 2.1 is current; use it |

## Sources

### Primary (HIGH confidence)
- `mix.exs` (read) — current `package/0`, `docs/0`, `@source_url`, `@version 0.3.1`
- `test/install_smoke/package_metadata_test.exs` (read) — exact `links` assertion (Pitfall 1), `@required_paths`, `@prohibited_paths`
- `lib/rindle/security/*`, `lib/rindle/delivery/webhook_plug.ex`, `lib/rindle/streaming/provider/mux.ex`, `lib/rindle/storage/gcs/signer.ex`, `lib/rindle/scanner.ex` (grep + read) — verified threat surface
- `.github/ISSUE_TEMPLATE/release-train-drift.md` (read) — existing template to preserve
- `CONTRIBUTING.md`, `guides/secure_delivery.md` (read) — cross-reference targets
- contributor-covenant.org/version/2/1/code_of_conduct/code_of_conduct.md (fetched) — exact enforcement-line placeholder + version 2.1

### Secondary (MEDIUM confidence)
- docs.github.com — SECURITY.md auto-detection locations (root/.github/docs)
- hex.pm/docs/publish — `package.links` / `maintainers` conventions; "Changelog"/"GitHub" special handling

### Tertiary (LOW confidence)
- WebSearch on Hex link special-rendering (incomplete on which exact names are special-cased — A1)

## Metadata

**Confidence breakdown:**
- Governance file conventions (SECURITY/CoC/templates): HIGH — standard, GitHub-documented, verified existing files
- Threat surface for SECURITY.md: HIGH — grepped and read actual modules
- mix.exs package syntax + meta-test pitfall: HIGH — read the exact file + the coupling test
- Changelog link target choice: MEDIUM — convention clear, maintainer preference open (A2)

**Research date:** 2026-06-30
**Valid until:** ~2026-07-30 (stable domain; GitHub/Hex conventions change slowly)
