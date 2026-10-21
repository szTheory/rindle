import Config
config :twin, ecto_repos: [Twin.Repo]
config :rindle, repo: Twin.Repo, profiles: [Twin.Profile], tmp_dir: "/retained/tmp"

config :twin, Oban,
  repo: Twin.Repo,
  queues: [
    rindle_media: 2,
    rindle_promote: 2,
    rindle_process: 2,
    rindle_purge: 1,
    rindle_maintenance: 1
  ]

config :twin, Twin.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  http: [ip: {0, 0, 0, 0}, port: 4100],
  secret_key_base: String.duplicate("twin-disposable-local-only-", 4),
  server: true,
  check_origin: false

config :phoenix, :json_library, Jason
config :ex_aws, http_client: ExAws.Request.Req
# No request logger, body logger, SQL parameter logger or raw telemetry exporter.
config :logger, level: :emergency
