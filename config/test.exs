import Config

db_user = System.get_env("PGUSER") || System.get_env("USER") || "postgres"
db_password = System.get_env("PGPASSWORD")
db_host = System.get_env("PGHOST") || "localhost"
db_port = String.to_integer(System.get_env("PGPORT") || "5432")

config :rindle, Rindle.Repo,
  username: db_user,
  password: db_password,
  hostname: db_host,
  port: db_port,
  database: "rindle_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Adopter Repo for CI-08 lane (Plan 05-04).
#
# This Repo is intentionally NOT registered in `:ecto_repos` (and is not started
# by the application supervisor) — it exists only to prove the adopter-repo-first
# pattern works architecturally. The adopter lifecycle test starts it explicitly
# via `start_supervised/1`, and shares the same test database as `Rindle.Repo`
# via Ecto SQL Sandbox (Assumption A3 in 05-RESEARCH.md). Phase 06 uses it to
# prove the configured runtime repo boundary instead of falling back to
# `Rindle.Repo`.
config :rindle, Rindle.Adopter.CanonicalApp.Repo,
  username: db_user,
  password: db_password,
  hostname: db_host,
  port: db_port,
  database: "rindle_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 2

config :logger, level: :warning

config :oban, Oban, testing: :inline
