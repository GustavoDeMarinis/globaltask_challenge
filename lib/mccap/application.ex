defmodule Mccap.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        Mccap.Repo,
        {Oban, Application.fetch_env!(:mccap, Oban)},
        MccapWeb.Telemetry,
        {DNSCluster, query: Application.get_env(:mccap, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Mccap.PubSub},
        {Cachex, name: :mccap_cache, limit: 10_000},
        # PG NOTIFY listener — enqueues Oban jobs when new applications are created.
        # Skipped in test env (tests use Oban inline mode, no real PG notifications).
        if(Application.get_env(:mccap, :start_pg_listener, true),
          do: Mccap.PgListener
        ),
        # Start to serve requests, typically the last entry
        MccapWeb.Endpoint
      ]
      |> Enum.reject(&is_nil/1)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Mccap.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MccapWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
