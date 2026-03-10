import Config

# Enable server when PHX_SERVER is set (works in any env)
if System.get_env("PHX_SERVER") do
  config :globaltask, GlobaltaskWeb.Endpoint, server: true
end

# Production runtime configuration
# Dev and test use compile-time config from dev.exs / test.exs respectively.
# Only prod reads DATABASE_URL, SECRET_KEY_BASE, etc. from the environment.
if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  config :globaltask, Globaltask.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("DB_POOL_SIZE", "10"))

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST", "localhost")
  port = String.to_integer(System.get_env("PORT", "4000"))

  config :globaltask, GlobaltaskWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base
end
