defmodule Globaltask.PgListener do
  @moduledoc """
  GenServer that listens for PostgreSQL `NOTIFY` events on the
  `new_credit_application` channel and enqueues Oban jobs to fetch
  bank provider data.

  This bridges the database trigger (§3.7) with the Oban async pipeline:

      INSERT → PG trigger → pg_notify → PgListener → Oban job

  ## Reconnection

  Uses `Postgrex.Notifications`, which automatically handles reconnection.
  If the listener is down during an INSERT, the recovery cron job
  (`RecoverStaleApplicationsWorker`) catches any missed applications.
  """

  use GenServer

  require Logger

  @channel "new_credit_application"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    repo_config = Globaltask.Repo.config()

    {:ok, pid} =
      Postgrex.Notifications.start_link(
        hostname: repo_config[:hostname],
        username: repo_config[:username],
        password: repo_config[:password],
        database: repo_config[:database],
        port: repo_config[:port] || 5432
      )

    {:ok, _ref} = Postgrex.Notifications.listen(pid, @channel)

    Logger.info("PgListener started, listening on channel: #{@channel}")

    {:ok, %{notifications_pid: pid}}
  end

  @impl true
  def handle_info({:notification, _pid, _ref, @channel, application_id}, state) do
    Logger.info("PgListener received notification",
      application_id: application_id,
      channel: @channel
    )

    %{"application_id" => application_id}
    |> Globaltask.Workers.FetchProviderDataWorker.new()
    |> Oban.insert()

    {:noreply, state}
  end

  # Handle Postgrex disconnection and reconnection messages gracefully
  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    Logger.warning("PgListener Postgrex connection lost: #{inspect(reason)}")
    {:stop, :connection_lost, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
