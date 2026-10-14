---
quick_id: 260930-nqd
slug: fix-the-remaining-phase-133-cr-01-json-k
date: 2026-09-30
mode: quick
files_modified:
  - scripts/maintainer/phase_133_local_gates.sh
  - scripts/maintainer/test_phase_133_local_gates.sh
autonomous: true
must_haves:
  truths:
    - A quoted JSON credential key cannot expose its value in the saved local-gates report or the failure excerpt on stderr.
    - Existing credential redaction and the original failing CI exit remain intact.
  artifacts:
    - scripts/maintainer/phase_133_local_gates.sh
    - scripts/maintainer/test_phase_133_local_gates.sh
  key_links:
    - The shared sanitize_output function feeds both capture_diagnostics and print_safe_excerpt.
---

<objective>
Close the remaining Phase 133 CR-01 diagnostic disclosure for quoted JSON credential keys. The local-gates report and failure excerpt must redact values such as the one following `"password":` while retaining useful diagnostic context.
</objective>

<context>
@AGENTS.md
@.planning/STATE.md
@scripts/maintainer/phase_133_local_gates.sh
@scripts/maintainer/test_phase_133_local_gates.sh

The current sanitizer handles unquoted credential assignments and natural-language forms. The quoted key's closing `"` prevents its value pattern from matching. `capture_diagnostics` persists sanitized lines in the report; `print_safe_excerpt` uses the same sanitizer for stderr when a gate fails.
</context>

<tasks>

<task type="auto">
  <name>Redact quoted JSON credential values in both diagnostic destinations</name>
  <files>scripts/maintainer/phase_133_local_gates.sh, scripts/maintainer/test_phase_133_local_gates.sh</files>
  <action>Extend the credential handling inside sanitize_output to recognize a double-quoted JSON key from the existing credential-key set followed by a colon, optional whitespace, and a quoted value. Replace the value with the redaction marker while preserving the key and JSON punctuation; preserve the existing assignment, natural-language, token, path, line-limit, and exit-status behavior. In the fake Mix diagnostic attack, emit an allowlisted error line containing a unique quoted-key canary such as `"password":"json-key-secret-canary"`. Extend the existing successful and failing sanitized-diagnostics assertions to prove that this canary is absent from each saved report and from stderr; assert the redacted key remains visible so the check cannot pass by dropping the line. The failing CI case must retain its original exit code.</action>
  <verify>
    <automated>bash -n scripts/maintainer/phase_133_local_gates.sh scripts/maintainer/test_phase_133_local_gates.sh &amp;&amp; bash scripts/maintainer/test_phase_133_local_gates.sh</automated>
  </verify>
  <done>The quoted-key canary is absent from both the saved report and stderr in the failure case, the redacted diagnostic remains useful, the success case stays sanitized, and the local-gates test script passes.</done>
</task>

</tasks>

<assumption_delta_decision>
Primary noun: credential value in a diagnostic line. Decision: no-change. The Phase 133 detector's “second” and “additional” matches describe other roadmap work; recognizing quoted JSON spelling adds no new identity or source of truth to this quick fix.
</assumption_delta_decision>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Mix output → diagnostic report and stderr | Untrusted command output can contain credential values. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-260930-nqd-01 | Information disclosure | sanitize_output, capture_diagnostics, print_safe_excerpt | high | mitigate | Redact quoted JSON credential values in the shared sanitizer and prove the canary is absent from the saved report and stderr on a failing gate. |
</threat_model>

<verification>
Run `bash -n scripts/maintainer/phase_133_local_gates.sh scripts/maintainer/test_phase_133_local_gates.sh` and `bash scripts/maintainer/test_phase_133_local_gates.sh`.
</verification>

<success_criteria>
The local-gates diagnostic canary cannot disclose through either persisted evidence or surfaced stderr, and the automated fixture passes without changing the gate's failure semantics.
</success_criteria>
