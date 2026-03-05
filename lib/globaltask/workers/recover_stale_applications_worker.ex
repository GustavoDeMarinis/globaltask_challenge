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

  @impl Oban.Worker
  def perform(_job) do
    # Find stuck applications
    stale_apps = Globaltask.CreditApplications.list_recoverable_applications()

    if Enum.any?(stale_apps) do
      Logger.warning("Found #{length(stale_apps)} stale applications, processing recovery",
        worker: "RecoverStaleApplicationsWorker",
        stale_count: length(stale_apps)
      )

      Enum.each(stale_apps, fn app ->
        if app.fetch_attempts >= 3 do
          Logger.error("Application exceeded max fetch attempts, marking as provider_timeout",
            application_id: app.id,
            worker: "RecoverStaleApplicationsWorker"
          )

          Globaltask.CreditApplications.update_status(app, "provider_timeout")
        else
          Globaltask.CreditApplications.enqueue_fetch_and_increment_attempts(app)
        end
      end)
    else
      Logger.debug("No stale applications found", worker: "RecoverStaleApplicationsWorker")
    end

    :ok
  end
end
