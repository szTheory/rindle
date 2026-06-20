---
created: 2026-06-19T20:29:52.374Z
title: Fix Docker demo startup warnings
area: tooling
files:
  - scripts/demo/up.sh
  - docker/compose.cohort-demo.yml
  - docker/Dockerfile.cohort-demo
  - examples/adoption_demo/lib/adoption_demo/mux_cassette.ex:23
  - examples/adoption_demo/lib/adoption_demo/mux_cassette.ex:45
  - examples/adoption_demo/lib/adoption_demo/mux_cassette.ex:47
  - examples/adoption_demo/lib/adoption_demo/mux_cassette.ex:56
  - examples/adoption_demo/lib/adoption_demo/mux_cassette.ex:65
---

## Problem

Running `./scripts/demo/up.sh` for the Docker Cohort demo boots successfully, applies migrations, and serves Phoenix, but the app container logs development warnings that should be cleaned up or explicitly documented:

- `AdoptionDemo.MuxCassette` calls `Mox.defmock/2`, `Mox.set_mox_global/1`, and `Mox.stub/3`, but the container logs `module Mox is not available or is yet to be defined`.
- Phoenix live-reload cannot start because `file_system` cannot find `inotify-tools`, producing `{:error, :fs_inotify_bootstrap_error}` and `Could not start Phoenix live-reload because we cannot listen to the file system.`

The second warning is optional per Phoenix's own log text, but it degrades Docker DX. The Mox warnings may indicate the demo image/runtime is compiling code that expects a test/dev dependency that is not available in that environment.

## Solution

TBD. Investigate whether the Docker demo should include Mox in the relevant Mix environment, guard `AdoptionDemo.MuxCassette` behind dependency availability, or avoid compiling that module for the demo runtime. Separately decide whether to install `inotify-tools` in `docker/Dockerfile.cohort-demo` for clean live-reload DX or document the warning as accepted noise.
