import Config

if System.get_env("PHX_SERVER") do
  config :globaltask, GlobaltaskWeb.Endpoint, server: true
end

if config_env() != :test do
  database_url =
    System.fetch_env!("DATABASE_URL")

  config :globaltask, Globaltask.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("DB_POOL_SIZE", "10"))

  secret_key_base =
    System.fetch_env!("SECRET_KEY_BASE")

  config :globaltask, GlobaltaskWeb.Endpoint,
    secret_key_base: secret_key_base,
    server: true,
    http: [
      ip: {0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT", "4000"))
    ]
end
