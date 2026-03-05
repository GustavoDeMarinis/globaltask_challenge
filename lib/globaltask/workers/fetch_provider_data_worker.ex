defmodule Globaltask.Workers.FetchProviderDataWorker do
  @moduledoc """
  Oban worker that fetches bank provider data for a credit application.

  ## Pipeline position

      PG trigger → PgListener → **FetchProviderDataWorker** → RiskEvaluationWorker

  ## Behaviour

  1. Loads the application by ID
  2. **Idempotency guard:** skips if `provider_payload` is already populated
  3. Calls `BankProvider.fetch/1` to get provider data
  4. Writes the payload via `CreditApplications.update_provider_payload/2`
  5. Enqueues `RiskEvaluationWorker` for the next step

  ## Retries

  Max 3 attempts. Failures (e.g. simulated API timeout) are retried
  automatically by Oban with backoff.
  """

  use Oban.Worker, queue: :provider_fetch, max_attempts: 3

  require Logger

  alias Globaltask.CreditApplications
  alias Globaltask.BankProvider

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"application_id" => id}}) do
    with {:ok, app} <- CreditApplications.get_application(id) do
      if app.provider_payload != %{} do
        Logger.warning("Provider data already fetched, skipping",
          application_id: id,
          worker: "FetchProviderDataWorker"
        )

        :ok
      else
        fetch_and_store(app)
      end
    else
      {:error, :not_found} ->
        Logger.error("Application not found, discarding job",
          application_id: id,
          worker: "FetchProviderDataWorker"
        )

        # Discard — retrying won't help if the app doesn't exist
        {:discard, :application_not_found}
    end
  end

  defp fetch_and_store(app) do
    started_at = System.monotonic_time(:millisecond)

    case BankProvider.fetch(app) do
      {:ok, payload} ->
        duration_ms = System.monotonic_time(:millisecond) - started_at

        {:ok, _updated} = CreditApplications.update_provider_payload(app, payload)

        Logger.info("Provider data fetched successfully",
          application_id: app.id,
          country: app.country,
          worker: "FetchProviderDataWorker",
          duration_ms: duration_ms
        )

        # Chain to risk evaluation
        %{"application_id" => app.id}
        |> Globaltask.Workers.RiskEvaluationWorker.new()
        |> Oban.insert()

        :ok

      {:error, reason} ->
        Logger.error("Provider fetch failed",
          application_id: app.id,
          country: app.country,
          worker: "FetchProviderDataWorker",
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end
end
