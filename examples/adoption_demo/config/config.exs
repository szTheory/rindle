# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :adoption_demo,
  ecto_repos: [AdoptionDemo.Repo],
  generators: [timestamp_type: :utc_datetime]

config :rindle, :repo, AdoptionDemo.Repo

config :adoption_demo, Oban,
  repo: AdoptionDemo.Repo,
  queues: [
    rindle_media: 2,
    rindle_promote: 2,
    rindle_process: 2,
    rindle_purge: 1,
    rindle_maintenance: 1
  ]

config :rindle, :tus_profiles, [AdoptionDemo.VideoProfile]

# Configure the endpoint
config :adoption_demo, AdoptionDemoWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: AdoptionDemoWeb.ErrorHTML, json: AdoptionDemoWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: AdoptionDemo.PubSub,
  live_view: [signing_salt: "oEDzS3sz"]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
