# Retained historical native timing breakdown

Source `bb0341a07ebf58b556aff4bcfa84003673d0151f`, producer40609107572/1. Archive, manifest, sidecar and all24 receipt references were byte-checked before this bounded extraction. This is timing research with zero READY/CI-16 credit; the earlier producer's successful job is not terminal acceptance.

| Gate | Elapsed minutes |
|---|---:|
| async-isolation | 190.77 |
| twin-recovery | 11.64 |
| contributor-bootstrap | 10.21 |
| coverage | 6.81 |
| release-truth | 4.99 |
| dialyzer-fresh | 3.35 |
| docs | 1.47 |
| generated-consumer | 1.36 |
| hygiene | 0.21 |
| contracts | 0.21 |
| dialyzer-restored | 0.17 |
| credo | 0.11 |
| compile | 0.08 |
| doctor | 0.07 |
| format | 0.02 |
| security | 0.02 |
| package | 0.01 |
| inbox-ledger | 0.00 |

Async isolation used **190.77 minutes**, **75.9%** of the whole candidate-collection step and **82.4%** of the sum of local gate intervals. The latter sum is231.51 minutes. It cannot be added to the parent collection duration.

The aggregate implies about7.63 minutes per seed across25 fresh coverage processes, but does not reveal per-seed distribution. No gate, seed, command, timeout or active source was changed. The next safe step is bounded timing/progress, then a separately scoped design decision if isolation-preserving parallel qualification is worthwhile. Cutting coverage/seeds or substituting receipt caches is not inferred from this measurement.

Data and source digests: [retained-native-timings.json](retained-native-timings.json).
