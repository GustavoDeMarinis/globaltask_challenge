defmodule Globaltask.Workers.RecoverStaleApplicationsWorker do
  @moduledoc """
  Cron worker to recover credit applications that missed the PG trigger.

  If the `PgListener` is down when a new application is created, the
  `pg_notify` event is lost. This worker acts as a safety net, finding
  applications stuck in `"created"` state without a `provider_payload`
  that are older than 2 minutes, and manually enqueuing them.

  Runs every minute via Oban Cron.
  """

  use Oban.Worker, queue: :default

  require Logger

  alias Globaltask.Repo
  alias Globaltask.CreditApplications.CreditApplication
  import Ecto.Query

  @impl Oban.Worker
  def perform(_job) do
    two_minutes_ago = DateTime.utc_now() |> DateTime.add(-2, :minute)

    # Find stuck applications
    query =
      from a in CreditApplication,
        where: a.status == "created" and a.provider_payload == ^%{},
        where: a.inserted_at < ^two_minutes_ago,
        select: a.id

    stale_ids = Repo.all(query)

    if Enum.any?(stale_ids) do
      Logger.warning("Found #{length(stale_ids)} stale applications, enqueuing recovery jobs",
        worker: "RecoverStaleApplicationsWorker",
        stale_count: length(stale_ids)
      )

      # Enqueue fetch jobs using Oban.insert_all for efficiency
      jobs =
        Enum.map(stale_ids, fn id ->
          %{"application_id" => id}
          |> Globaltask.Workers.FetchProviderDataWorker.new()
        end)

      Oban.insert_all(jobs)
    else
      Logger.debug("No stale applications found", worker: "RecoverStaleApplicationsWorker")
    end

    :ok
  end
end
