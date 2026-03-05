defmodule Globaltask.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        Globaltask.Repo,
        {Oban, Application.fetch_env!(:globaltask, Oban)},
        GlobaltaskWeb.Telemetry,
        {DNSCluster, query: Application.get_env(:globaltask, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Globaltask.PubSub},
        # PG NOTIFY listener — enqueues Oban jobs when new applications are created.
        # Skipped in test env (tests use Oban inline mode, no real PG notifications).
        if(Application.get_env(:globaltask, :start_pg_listener, true),
          do: Globaltask.PgListener
        ),
        # Start to serve requests, typically the last entry
        GlobaltaskWeb.Endpoint
      ]
      |> Enum.reject(&is_nil/1)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Globaltask.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GlobaltaskWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
