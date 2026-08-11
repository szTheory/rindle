# Deferred Items

## 116-05

- `mix test test/install_smoke/docs_parity_test.exs test/rindle/migration_test.exs test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_status_test.exs test/rindle/doctor_test.exs test/rindle/runtime_status_task_test.exs --seed 0` currently fails only in `test/install_smoke/docs_parity_test.exs` because README and guide migration copy still teach the pre-Phase-116 package-directory install flow. This is out of scope for 116-05 and is explicitly owned by 116-06.
