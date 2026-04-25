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

config :logger, level: :warning

config :oban, Oban, testing: :inline
