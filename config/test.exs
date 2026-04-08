import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :mccap, Mccap.Repo,
  username: "mccap",
  password: "mccap",
  hostname: "localhost",
  database: "mccap_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :mccap, MccapWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "6ev7njGdNhWqb2uaq1erQ4zQwVvf2cTF9qQuTjcE/W2wqg5ttRTBqT6RxhfpFpLr",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Run Oban jobs synchronously during tests (no actual workers)
config :mccap, Oban, testing: :inline

# Skip simulated bank provider latency in tests
config :mccap, skip_provider_latency: true

# Don't start PgListener in tests (no real PG NOTIFY needed)
config :mccap, start_pg_listener: false
