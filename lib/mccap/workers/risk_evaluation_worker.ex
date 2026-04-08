defmodule Mccap.Workers.RiskEvaluationWorker do
  @moduledoc """
  Oban worker that evaluates risk based on bank provider data and
  transitions the application status accordingly.

  ## Pipeline position

      FetchProviderDataWorker → **RiskEvaluationWorker** → status transition

  ## Behaviour

  1. Loads the application by ID
  2. **Guard:** only processes apps in `"created"` status (prevents re-processing)
  3. Calls `CountryRules.evaluate_risk/1` on the country module
  4. Maps the result to a status transition:
     - `:approve` → `"approved"`
     - `:reject` → `"rejected"`
     - `:review` → `"pending_review"`
     - `:skip` → no transition (country has no provider-based rules)
  5. Uses `CreditApplications.update_status/2` (Ecto.Multi + optimistic lock)

  ## Stale handling

  If `update_status/2` returns `{:error, :stale}`, it means another process
  already transitioned the status. This is expected in concurrent environments —
  the worker logs a warning and returns `:ok` (no retry).
  """

  use Oban.Worker, queue: :risk_evaluation, max_attempts: 3

  require Logger

  alias Mccap.CreditApplications
  alias Mccap.CountryRules

  @status_map %{
    approve: "approved",
    reject: "rejected",
    review: "pending_review"
  }

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"application_id" => id}}) do
    with {:ok, app} <- CreditApplications.get_application(id) do
      if app.status != "created" do
        Logger.warning("Application not in 'created' status, skipping risk evaluation",
          application_id: id,
          current_status: app.status,
          worker: "RiskEvaluationWorker"
        )

        :ok
      else
        evaluate_and_transition(app)
      end
    else
      {:error, :not_found} ->
        Logger.error("Application not found, discarding job",
          application_id: id,
          worker: "RiskEvaluationWorker"
        )

        {:discard, :application_not_found}
    end
  end

  defp evaluate_and_transition(app) do
    case CountryRules.resolve(app.country) do
      {:ok, module} ->
        result = module.evaluate_risk(app)
        apply_result(app, result)

      {:error, :unsupported_country} ->
        Logger.warning("Unsupported country for risk evaluation",
          application_id: app.id,
          country: app.country,
          worker: "RiskEvaluationWorker"
        )

        :ok
    end
  end

  defp apply_result(app, :skip) do
    Logger.info("Risk evaluation skipped (no provider-based rules)",
      application_id: app.id,
      country: app.country,
      worker: "RiskEvaluationWorker"
    )

    :ok
  end

  defp apply_result(app, result) when result in [:approve, :reject, :review] do
    new_status = Map.fetch!(@status_map, result)

    case CreditApplications.update_status(app, new_status) do
      {:ok, updated_app} ->
        Logger.info("Risk evaluation completed",
          application_id: app.id,
          country: app.country,
          result: result,
          new_status: updated_app.status,
          worker: "RiskEvaluationWorker"
        )

        :ok

      {:error, :stale} ->
        Logger.warning("Stale entry during status transition, another process won",
          application_id: app.id,
          attempted_status: new_status,
          worker: "RiskEvaluationWorker"
        )

        :ok

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.warning("Status transition rejected by changeset",
          application_id: app.id,
          attempted_status: new_status,
          errors: inspect(changeset.errors),
          worker: "RiskEvaluationWorker"
        )

        :ok
    end
  end
end
