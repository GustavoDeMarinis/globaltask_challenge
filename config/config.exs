# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :mccap,
  ecto_repos: [Mccap.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configures the endpoint
config :mccap, MccapWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: MccapWeb.ErrorHTML, json: MccapWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Mccap.PubSub,
  live_view: [signing_salt: "Iwzlz1py"]

config :mccap, Oban,
  repo: Mccap.Repo,
  queues: [default: 10, provider_fetch: 10, risk_evaluation: 5, webhooks: 5],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7}, # Retain jobs for 7 days
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)},
    {Oban.Plugins.Cron,
     crontab: [
       {"* * * * *", Mccap.Workers.RecoverStaleApplicationsWorker}
     ]}
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure esbuild
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind
config :tailwind,
  version: "4.1.12",
  default: [
    args: ~w(
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
