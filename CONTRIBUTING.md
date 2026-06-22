# Contributing to Rindle

Thanks for contributing. Rindle is an Elixir/Phoenix/Ecto-native media lifecycle
library; contributions follow the same production-aware, maintainer-to-maintainer
posture as the rest of the project.

This document focuses on **what CI runs on your PR versus after merge**, so you know
which signal is fast-feedback and which is release-readiness breadth. The deeper local
developer workflow — a single `mix ci` equivalent and faithful local reproduction of the
CI Linux/Chromium gates — is being added in a follow-up (Phase 107, HARD-03); this file
will gain those local commands then.

## CI: what runs on your PR vs after merge

> **Copy-pasteable trust/speed label** — paste this paragraph into your PR description so
> the trust/speed tradeoff is explicit on the PR itself (see "PR-side handoff" below).

On every PR we run the representative gate — compile (warnings-as-errors) + full test
suite on both supported Elixir/OTP cells, optional-dependency compile, integration
(storage + MinIO), contract + docs-parity proofs, the canonical adopter lifecycle, the
storage-free adoption-demo unit suite, the token→CSS drift gate, and one representative
`image` package-consumer install-smoke — targeting **≤7 minutes**. We verify the
following **after merge** (`push:main`) or **nightly**, not on your PR: the full
five-profile package-consumer matrix + release preflight + `hex.publish --dry-run`, the
Playwright browser E2E, the Docker-compose cold-start smoke, the broad OTP×Elixir
compatibility matrix, the owned Dialyzer lane, and the real-API GCS/Mux soak lanes. Why:
these are expensive (the 5-profile matrix is the ~9-min long pole), browser/Docker-flaky
(false reds erode trust more than they catch bugs), or depend on live third-party
services (a provider outage must never block your merge). A regression in a moved lane is
caught on `main` within one merge — it blocks the *next* merge, not your PR — and the
full release-verification gate always runs, provably, before any Hex publish.

### Why this split (the trust/speed tradeoff)

We adopt a **representative gate on PR, breadth after merge/nightly** model (the Tokio
model), rather than running the full matrix on every PR. The goal is fast, trustworthy PR
feedback without dropping any real quality signal:

- **Expensive lanes** — the full five-profile `package-consumer` matrix + release
  preflight + `hex.publish --dry-run` is the long pole (~9 min). Running it on every PR is
  what made PR CI ~15 min. It runs on `push:main` instead.
- **Browser/Docker-flaky lanes** — the Playwright browser E2E and the Docker-compose
  cold-start smoke have a higher false-red rate; a false red erodes trust more than it
  catches bugs. Their PR-side proxy is the storage-free, browser-free `adoption-demo`
  unit suite, which stays on every PR.
- **Live third-party lanes** — the real-API GCS and Mux soak lanes depend on external
  services; a provider outage must never block your merge. They run nightly (GCS) or are
  label-gated (Mux).

**The signal is not lost — only re-homed by trigger.** A regression in any lane moved off
PR is caught on `main` within **one merge**: it blocks the *next* merge, not the innocent
author who pushed an unrelated change. And the full release-verification gate (the
five-profile matrix + release preflight + `hex.publish --dry-run`) always runs, provably,
on `push:main` before any Hex publish — so release readiness is never weakened.

The full keep / optimize / move-to-nightly / label-gated / off-critical-path
classification behind every lane placement is recorded in
[`.planning/phases/106-trigger-split-matrix-lane-refinement/106-LANE-CLASSIFICATION.md`](.planning/phases/106-trigger-split-matrix-lane-refinement/106-LANE-CLASSIFICATION.md),
and the maintainer lane-severity table is in [`RUNNING.md`](RUNNING.md) §"Maintainer: CI
lane severity".

### On your PR (representative gate, ≤7 min target)

- **compile (warnings-as-errors)** + **full test suite via `mix coveralls`** on both
  supported Elixir/OTP cells (1.15/26 and 1.17/27)
- **optional-dependency compile** (`mix compile --no-optional-deps --warnings-as-errors`)
- **integration** (lifecycle + storage with MinIO)
- **contract** (AV hygiene gate + contract tests) and **proof** (docs-parity, adoption
  proof drift gate, batch-owner-erasure mix proof)
- **adopter** (canonical adopter lifecycle)
- **adoption-demo unit suite** (storage-free, browser-free admin-console mount + brand +
  lifecycle render)
- **token→CSS drift gate** (`brandbook-tokens`)
- **one representative `image` package-consumer install-smoke**

### After merge (`push:main`) / nightly (not on your PR)

- the full **five-profile `package-consumer` matrix** (video/image/tus/mux/gcs) +
  **release preflight** + **`hex.publish --dry-run`** (`push:main`; this is the
  release-readiness gate, proven by the push:main run conclusion before any publish)
- the **Playwright browser E2E** (`push:main`)
- the **Docker-compose cold-start smoke** (`push:main`)
- the broad **OTP×Elixir compatibility matrix** (nightly)
- the owned **Dialyzer** lane (nightly, gating there)
- the real-API **GCS soak** lane (nightly) and the **Mux soak** lane (label-gated on
  `streaming`-labeled PRs)

### PR-side handoff (do not skip)

LANE-04 requires the trust/speed label to appear **both** in this file **and in the PR**.
The copy-pasteable block above is the canonical text. The `/gsd-ship`-time step **MUST
paste that trust/speed paragraph into the PR body** so the PR-side half of the requirement
is not lost. (No automation is added here — this is a ship-time handoff reminder.)

## Scope note

Rindle keeps `lib/` and public behavior unchanged in CI/infrastructure work. Documentation
and CI-topology changes (like this file) are docs/workflow-only and must not alter the
public API surface.
