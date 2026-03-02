defmodule Globaltask.Repo do
  use Ecto.Repo,
    otp_app: :globaltask,
    adapter: Ecto.Adapters.Postgres
end
