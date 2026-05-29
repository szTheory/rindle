import Config

repo_config = [
  username: System.get_env("PGUSER") || "postgres",
  password: System.get_env("PGPASSWORD") || "postgres",
  hostname: System.get_env("PGHOST") || "localhost",
  port: String.to_integer(System.get_env("PGPORT") || "5432"),
  database:
    System.get_env("ADOPTION_DEMO_TEST_DB") ||
      "adoption_demo_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool_size: 10,
  migration_primary_key: [type: :binary_id],
  migration_timestamps: [type: :utc_datetime_usec]
]

repo_config =
  if System.get_env("PHX_SERVER") do
    repo_config
  else
    Keyword.put(repo_config, :pool, Ecto.Adapters.SQL.Sandbox)
  end

config :adoption_demo, AdoptionDemo.Repo, repo_config

config :adoption_demo, AdoptionDemoWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || "4102")],
  secret_key_base: "Mmf7hFfGirEDvk4HVoW/lNZwf0Z31ehMYO2dvw3oH3VF95eMLRwJpAzknsKu22Qu",
  check_origin: false,
  server: false

config :adoption_demo, Oban, testing: :inline

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :phoenix,
  sort_verified_routes_query_params: true
