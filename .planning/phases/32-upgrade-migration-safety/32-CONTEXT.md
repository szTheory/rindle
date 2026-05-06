# Phase 32: Upgrade & Migration Safety - Context

**Gathered:** 2026-05-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Existing adopters must be able to move from pre-v1.4 image-first installs into
the current AV-aware lifecycle shape using additive migrations, explicit
verification steps, explicit repair verbs, and guide parity.

In scope:
- prove a public-path upgrade from a pre-v1.4 adopter shape into current
  Rindle using the same migration/runtime setup docs teach
- prove legacy image-only data remains valid after the upgrade
- prove one canonical interrupted or partial AV-work scenario can be recovered
  through existing explicit repair surfaces
- publish upgrade guidance that teaches existing-adopter upgrade separately from
  greenfield onboarding without hiding it

Out of scope:
- auto-remediation inside diagnostics
- a second generic control plane or dashboard
- broad rollout/deployment orchestration beyond the Rindle-owned migration,
  diagnostics, and repair surfaces
- full frozen fixture apps unless the generated-app harness cannot model a
  necessary state

</domain>

<decisions>
## Implementation Decisions

### Upgrade Proof Lane

- **D-01:** The canonical proof lane for Phase 32 is the existing generated
  Phoenix package-consumer harness, extended to start from a simulated
  pre-v1.4 adopter shape.
- **D-02:** Phase 32 must keep public-path honesty: the proof lane uses the
  same adopter-facing migration path and runtime setup the docs teach,
  including explicit `Application.app_dir(:rindle, "priv/repo/migrations")`
  migration handoff, adopter-owned Repo wiring, and public Mix/task/facade
  surfaces.
- **D-03:** Do not introduce a full pinned fixture adopter app as the primary
  proof surface. A separate fixture is allowed only if the generated-app lane
  later proves unable to model a required partial-state scenario.
- **D-04:** Keep the existing backward-compat semantic guardrails in place.
  Schema success alone is insufficient; image-only upgrade safety must continue
  to honor digest-stability and legacy data-validity expectations.

### Canonical Recovery Scenario

- **D-05:** The canonical Phase 32 recovery proof is a single narrative with
  two linked steps:
  1. pre-v1.4 legacy image-only data upgrades forward without breakage
  2. newly introduced AV work is interrupted, then recovered through explicit
     repair verbs
- **D-06:** The interrupted-work proof should use deterministic seeded
  failure/cancelled/drift state, not timing-heavy “stuck worker” simulation.
  CI should validate the operator workflow, not race the scheduler.
- **D-07:** For one-asset interrupted AV work, the sharp repair surface is
  asset-scoped `Rindle.requeue_variants/2`. Do not teach broad
  `mix rindle.regenerate_variants` as the default recovery for a single failed
  asset.
- **D-08:** `mix rindle.regenerate_variants` remains the broad maintenance lane
  for `stale` or `missing` derivative drift after profile/preset/storage
  drift. Phase 32 may reference that distinction, but should not collapse the
  single-asset repair story into broad regeneration.
- **D-09:** `mix rindle.doctor` and `mix rindle.runtime_status` remain the
  read-only verification and diagnosis surfaces. They point operators toward
  repair; they do not perform repair.

### Upgrade Runbook Shape

- **D-10:** Ship one dedicated canonical upgrade runbook for existing adopters,
  optimized for the pre-v1.4 -> current upgrade path rather than a thin
  overview page.
- **D-11:** The upgrade runbook should be explicit, linear, and checkpointed:
  dependencies/config/runtime expectations, explicit migrations, `mix
  rindle.doctor`, optional `mix rindle.runtime_status` when state looks wrong,
  then the appropriate repair verb.
- **D-12:** The runbook should be copy-pasteable and parity-testable. It should
  read like an operator-maintainer guide, not like release notes or a generic
  troubleshooting essay.
- **D-13:** The runbook should link out to `operations.md` and
  `troubleshooting.md` for deep error or verb details instead of re-authoring
  those documents inline.

### Greenfield vs Upgrade Docs Split

- **D-14:** Keep greenfield onboarding clean. `README.md` remains the narrow
  quickstart and `guides/getting_started.md` remains the canonical first-run
  path for fresh adopters.
- **D-15:** Use a hybrid docs split:
  - greenfield docs stay focused on first install and first run
  - a dedicated upgrade guide handles the existing-adopter upgrade path
  - release-facing docs summarize what changed and deep-link to the upgrade
    guide instead of duplicating the full procedure
- **D-16:** Prefer a stable upgrade guide entry such as `guides/upgrading.md`
  with a version-scoped section for the pre-v1.4 -> v1.4+ path, rather than
  scattering upgrade steps across `README.md`, `getting_started.md`, and
  release docs.
- **D-17:** Add prominent upgrade cross-links from the README quickstart, the
  top of `guides/getting_started.md`, and release/changelog surfaces so the
  upgrade path is discoverable without polluting the greenfield happy path.

### Ecosystem and UX Posture

- **D-18:** Favor the idiomatic Elixir/Ecto/Phoenix library posture:
  explicit migrations, explicit verification commands, explicit repair verbs,
  additive schema evolution, and no hidden state mutation behind diagnostics.
- **D-19:** Follow the least-surprise examples from successful ecosystems:
  separate install vs upgrade docs, prove the host-app public path, keep
  migration steps explicit, and use repair/cleanup verbs that match the actual
  scope of mutation.
- **D-20:** Avoid the recurring ecosystem footguns:
  - burying upgrade steps inside changelogs only
  - maintaining a stale frozen fixture app that becomes a second truth source
  - timing-based interrupted-job simulations in CI
  - implying diagnostics will auto-fix state
  - teaching broad regeneration when asset-scoped repair is the safer verb

### Decision-Making Preference

- **D-21:** Strengthen the standing project preference for downstream GSD work:
  researchers, planners, and executors should decide by default and present one
  coherent recommendation set rather than asking the user to arbitrate normal
  implementation choices.
- **D-22:** Escalate only for genuinely high-blast-radius decisions such as:
  semver-significant public API reshapes, destructive or irreversible
  operations, security/compliance boundary changes, or similarly consequential
  architectural commitments.

### the agent's Discretion

- Exact helper/test organization used to synthesize the pre-v1.4 generated-app
  state, so long as the public-path proof remains the canonical lane
- Exact seeded failure shape for the interrupted AV scenario, so long as it is
  deterministic and teaches the correct repair verb
- Exact checkpoint names and section ordering in the upgrade guide, provided
  the sequence remains explicit and parity-testable
- Exact release-doc and README callout wording, provided greenfield vs upgrade
  boundaries stay clear

</decisions>

<specifics>
## Specific Ideas

- The upgrade story should feel like: “follow the same public docs contract you
  already trust, then prove recovery with the explicit verbs Rindle already
  shipped,” not “learn a maintainer-only hidden path.”
- The best cohesive shape is:
  generated app as the public upgrade proof, deterministic seeded interrupted
  AV work as the recovery scenario, dedicated upgrade runbook as the canonical
  doc, and clean cross-links from onboarding and release docs.
- The docs split should preserve the current successful posture:
  `README.md` = narrow quickstart,
  `guides/getting_started.md` = canonical greenfield deep guide,
  `guides/upgrading.md` = existing-adopter upgrade procedure,
  `guides/release_publish.md` = maintainer/release specifics only.
- Recovery language should keep the current verb clarity:
  `doctor` validates setup and drift,
  `runtime_status` reports degraded or stuck work,
  repair verbs perform change.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and milestone constraints
- `.planning/ROADMAP.md` — Phase 32 goal, requirements, and success criteria
- `.planning/REQUIREMENTS.md` — `UPGRADE-01`, `UPGRADE-02`, `UPGRADE-03`
- `.planning/PROJECT.md` — current milestone posture, adopter-first runtime
  ownership, and security/operations constraints
- `.planning/STATE.md` — current project status and strengthened autonomy
  preference

### Prior phase decisions this phase must honor
- `.planning/phases/24-domain-model-dsl-extension/24-CONTEXT.md` — additive
  AV migration posture, digest-stability importance, and legacy image-only
  compatibility constraints
- `.planning/phases/28-onboarding-docs-ci-proof/28-CONTEXT.md` — docs parity,
  public onboarding posture, and `mix rindle.doctor` as a first-class proof
  gate
- `.planning/phases/29-adopter-proof-matrix/29-CONTEXT.md` — generated-app
  package-consumer proof philosophy and docs parity expectations
- `.planning/phases/30-lifecycle-repair-operations/30-CONTEXT.md` — explicit
  repair verb boundaries and asset-scoped vs broad maintenance split
- `.planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md` —
  doctor/runtime-status split, read-only diagnostics posture, and recommendation
  semantics

### Current public docs and adopter-path artifacts
- `README.md` — current quickstart, explicit migration snippet, and public-path
  adopter contract
- `guides/getting_started.md` — canonical greenfield deep guide and current
  package-consumer proof framing
- `guides/operations.md` — explicit repair verb semantics and task boundaries
- `guides/troubleshooting.md` — current diagnostics split and recovery maps
- `guides/release_publish.md` — maintainer-only release runbook that should
  link to, not absorb, upgrade procedure

### Current code and test seams
- `test/install_smoke/support/generated_app_helper.ex` — generated-app harness
  and explicit migration-runner seam to extend for upgrade proof
- `test/install_smoke/generated_app_smoke_test.exs` — current package-consumer
  proof structure
- `test/install_smoke/docs_parity_test.exs` — docs parity posture to extend for
  upgrade guidance
- `test/rindle/backward_compat/v13_digest_snapshot_test.exs` — image-default
  digest stability guardrail
- `lib/rindle/ops/lifecycle_repair.ex` — asset-scoped repair verbs and report
  semantics
- `lib/rindle/ops/runtime_checks.ex` — read-only doctor checks and migration
  drift posture
- `lib/rindle/ops/runtime_status.ex` — read-only status/report surface and
  recommendation mapping
- `lib/mix/tasks/rindle.doctor.ex` — public diagnostics entrypoint
- `lib/mix/tasks/rindle.runtime_status.ex` — public runtime status entrypoint
- `lib/mix/tasks/rindle.regenerate_variants.ex` — broad regeneration boundary

### Ecosystem references that informed these decisions
- `https://hexdocs.pm/ecto_sql/Ecto.Migrator.html` — programmatic migration
  posture and real-repo expectations
- `https://hexdocs.pm/ecto_sql/Ecto.Migration.html` — migration locking and
  explicit migration semantics
- `https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html` — canonical Ecto
  migrate task behavior
- `https://hexdocs.pm/oban/v2-0.html` — example of explicit versioned upgrade
  guidance in the Elixir ecosystem
- `https://hexdocs.pm/oban/2.11.1/v2-11.html` — upgrade guide with required
  migration framing
- `https://guides.rubyonrails.org/active_storage_overview.html` — explicit
  attachment setup, cleanup, and migration-related guidance
- `https://guides.rubyonrails.org/upgrading_ruby_on_rails.html` — install vs
  upgrade doc separation pattern
- `https://docs.djangoproject.com/en/dev/topics/migrations/` — explicit
  migration semantics and caveats around faked history
- `https://shrinerb.com/docs/upgrading-to-3` — dedicated upgrade-guide posture
  for a media library

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/install_smoke/support/generated_app_helper.ex` already generates and
  patches a Phoenix adopter app, writes host migrations, runs explicit Rindle
  migrations, and proves the package-consumer path.
- `test/install_smoke/generated_app_smoke_test.exs` already proves the current
  public install path and can be extended to prove upgrade sequencing.
- `test/install_smoke/docs_parity_test.exs` already enforces docs language and
  is the natural place to anchor upgrade-guide parity checks.
- `lib/rindle/ops/lifecycle_repair.ex` provides the existing mutating repair
  surfaces Phase 32 should teach instead of inventing new ones.
- `lib/rindle/ops/runtime_checks.ex` and `lib/rindle/ops/runtime_status.ex`
  already encode the diagnostic split that the upgrade runbook should respect.

### Established Patterns
- Public-path honesty is already a strong repo pattern: generated-app proof,
  explicit adopter-owned migration paths, and docs parity gates are favored
  over repo-private shortcuts.
- Rindle already separates read-only diagnosis from mutation:
  `doctor` and `runtime_status` report;
  repair verbs change state.
- Broad maintenance and asset-scoped repair are intentionally separate. Phase 32
  must preserve that vocabulary and not blur the verbs.
- The docs topology is already intentionally split by audience and task. Phase
  32 should extend that pattern, not flatten it.

### Integration Points
- Generated-app helper and smoke tests are the integration point for upgrade
  proof and package-consumer CI.
- Guides plus docs parity tests are the integration point for greenfield vs
  upgrade documentation.
- Runtime diagnostics and repair modules are the integration point for the
  canonical interrupted-AV recovery scenario.

</code_context>

<deferred>
## Deferred Ideas

- Full pinned adopter fixture app as a second proof lane — defer unless the
  generated-app harness later proves unable to model a required upgrade state
- Broader deployment/rollout orchestration guidance beyond Rindle-owned
  migrations, diagnostics, and repair — separate concern from this phase
- Dashboard/admin UI for upgrade or runtime remediation — outside current
  milestone scope

</deferred>

---

*Phase: 32-upgrade-migration-safety*
*Context gathered: 2026-05-06*
