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
  database: "rindle_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :logger, :console, format: "[$level] $message\n"
