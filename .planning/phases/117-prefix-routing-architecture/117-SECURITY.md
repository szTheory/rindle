---
phase: 117
slug: prefix-routing-architecture
status: verified
# threats_open counts OPEN threats at or above the configured high severity threshold.
threats_open: 0
asvs_level: 1
created: 2026-08-08
---

# Phase 117 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Library macro to adopter schema module | Consumer code can mutate module attributes or invoke raw Ecto macros after using `Rindle.Schema`; the macro must remain an internal-only boundary. | Compile-time schema metadata |
| Rindle-owned schema source to Ecto metadata generation | The six owned schema sources must use the wrapper that reasserts the compiled authority. | Ecto schema and struct prefix metadata |
| Rindle schema metadata to shared host Repo | Rindle metadata must qualify only Rindle-owned tables without changing Repo-wide or Oban routing. | Database routing metadata |
| Compile/release configuration to runtime deployment | The selected `rindle` or `public` prefix is embedded at compilation and cannot be safely switched at runtime. | Build configuration |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-117-03-01 | Tampering | `Rindle.Schema.__using__/1` consumer | medium | mitigate | `__after_compile__/2` compares final Ecto metadata with `Rindle.Schema.prefix/0`; regression coverage preserves the dynamic override rejection. | closed |
| T-117-03-02 | Information Disclosure | Prefix-divergent Rindle schema | medium | mitigate | Final metadata mismatch is rejected before the schema can route reads to a decoy prefix; default and public builds are covered. | closed |
| T-117-03-03 | Denial of Service | Host-owned Oban routing | low | accept | No Repo-wide prefix or Oban configuration was changed; focused routing evidence keeps Oban independent. | closed |
| T-117-04-01 | Tampering | Consumer module attributes | high | mitigate | `Rindle.Schema.schema/2` reassigns the compiled prefix immediately before `Ecto.Schema.schema/2` creates metadata. | closed |
| T-117-04-02 | Information Disclosure | Prefix-divergent schema reads | high | mitigate | Contract tests assert schema and new-struct metadata equality; integration tests retain selected-versus-decoy facade and worker proofs. | closed |
| T-117-04-03 | Elevation of Privilege | Raw Ecto declaration in an owned domain schema | medium | mitigate | The normal import excludes raw `schema/2`; six-source AST tests reject direct Ecto imports, calls, and prefix attributes. | closed |
| T-117-04-04 | Denial of Service | Host-owned Oban tables | low | accept | No Repo-wide prefix, Oban configuration, or migration behavior was introduced. | closed |
| T-117-04-05 | Tampering | Runtime-only release configuration | medium | mitigate | `Application.compile_env/3` supplies the authority and the supported build postures are verified without runtime retargeting. | closed |
| T-117-05-01 | Tampering | Arbitrary `Rindle.Schema` consumer | high | mitigate | `__using__/1` validates `__CALLER__.module` against the exact six owned modules before emitting mutable attributes or callbacks. | closed |
| T-117-05-02 | Elevation of Privilege | Rindle-owned schema source | medium | mitigate | Six-source AST contract preserves wrapper-only declarations and rejects direct Ecto paths and direct prefix attributes. | closed |
| T-117-05-03 | Information Disclosure | Prefix-divergent Rindle reads | high | mitigate | Schema/new-struct equality checks and selected-versus-decoy facade and worker integration tests remain in place. | closed |
| T-117-05-04 | Denial of Service | Host-owned Oban or Repo routing | low | accept | Phase implementation does not change Repo-wide, Oban, or migration routing; independent routing assertions remain covered. | closed |
| T-117-05-05 | Tampering | Runtime-only prefix configuration | medium | mitigate | Prefix authority remains `Application.compile_env/3` based, with separate default/public build checks and no runtime retargeting semantics. | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above `workflow.security_block_on` count toward `threats_open`.*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-117-01 | T-117-03-03 | The phase deliberately leaves host-owned Oban routing unchanged; no new execution path or Repo-wide prefix is introduced. | Phase plan | 2026-08-08 |
| AR-117-02 | T-117-04-04 | Oban tables remain outside Rindle's schema-prefix boundary; no configuration or migration change expands their exposure. | Phase plan | 2026-08-08 |
| AR-117-03 | T-117-05-04 | Shared Repo and Oban routing remain host-owned and independently tested; the phase changes only Rindle-owned schema metadata. | Phase plan | 2026-08-08 |

---

## Security Audit 2026-08-08

| Metric | Count |
|--------|-------|
| Threats found | 13 |
| Closed | 13 |
| Open | 0 |

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-08 | 13 | 13 | 0 | Codex / gsd-secure-phase |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-08
