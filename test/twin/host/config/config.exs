import Config
config :twin, ecto_repos: [Twin.Repo]

config :rindle,
  repo: Twin.Repo,
  profiles: [Twin.Profile, Twin.AVProfile, Twin.ProviderProfile],
  tmp_dir: "/retained/tmp"

config :twin, Oban,
  repo: Twin.Repo,
  queues: [
    rindle_media: 2,
    rindle_promote: 2,
    rindle_process: 2,
    rindle_purge: 1,
    rindle_maintenance: 1,
    rindle_provider: 2
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

# Docker provides the disposable host boundary; its cgroup filesystem is read-only.
config :rindle, Rindle.AV.Subprocess, use_cgroups: false

config :rindle, Rindle.Streaming.Provider.Mux,
  token_id: "twin-local-token",
  token_secret: "twin-local-secret",
  base_url: "http://localhost:4100",
  webhook_secrets: ["twin-local-webhook-secret"]
