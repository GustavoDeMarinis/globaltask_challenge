defmodule Mccap.Repo do
  use Ecto.Repo,
    otp_app: :mccap,
    adapter: Ecto.Adapters.Postgres
end
