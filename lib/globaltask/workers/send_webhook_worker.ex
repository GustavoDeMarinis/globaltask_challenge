defmodule Globaltask.Workers.SendWebhookWorker do
  @moduledoc """
  Oban worker to reliably send webhooks to an external system when an application
  reaches a terminal state (approved or rejected).
  """
  use Oban.Worker, queue: :webhooks, max_attempts: 3

  require Logger

  alias Globaltask.CreditApplications

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"application_id" => id, "status" => status}}) do
    case CreditApplications.get_application(id) do
      {:ok, app} ->
        payload = %{
          "application_id" => app.id,
          "status" => status,
          "document_number" => app.document_number,
          "country" => app.country,
          "timestamp" => DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
        }

        url = Application.get_env(:globaltask, :webhook_url) || "https://webhook.site/mock"

        Logger.info("Dispatching webhook for application #{app.id} with status #{status}",
          worker: "SendWebhookWorker",
          application_id: app.id,
          url: url
        )

        case Req.post(url, json: payload, receive_timeout: 5000, connect_options: [timeout: 5000]) do
          {:ok, %Req.Response{status: status_code}} when status_code in 200..299 ->
            Logger.info("Webhook delivered successfully",
              worker: "SendWebhookWorker",
              application_id: app.id,
              status_code: status_code
            )

            :ok

          {:ok, %Req.Response{status: status_code}} ->
            Logger.warning("Webhook delivery failed with HTTP #{status_code}",
              worker: "SendWebhookWorker",
              application_id: app.id,
              status_code: status_code
            )

            # Returning an error tuple forces Oban to retry (up to max_attempts)
            {:error, "HTTP #{status_code}"}

          {:error, reason} ->
            Logger.warning("Webhook delivery failed with exception",
              worker: "SendWebhookWorker",
              application_id: app.id,
              reason: inspect(reason)
            )

            {:error, reason}
        end

      {:error, :not_found} ->
        Logger.error("Application not found for webhook",
          worker: "SendWebhookWorker",
          application_id: id
        )

        {:discard, :not_found}
    end
  end
end
