import Config

config :rindle,
  ecto_repos: [Rindle.Repo]

config :rindle, Rindle.Repo,
  migration_primary_key: [type: :binary_id],
  migration_timestamps: [type: :utc_datetime_usec]

config :rindle, :repo, Rindle.Repo
config :rindle, :queue, :rindle
config :rindle, :signed_url_ttl_seconds, 900
config :rindle, :upload_session_ttl_seconds, 86_400

import_config "#{config_env()}.exs"
