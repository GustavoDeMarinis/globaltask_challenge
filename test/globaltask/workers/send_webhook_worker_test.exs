defmodule Globaltask.Workers.SendWebhookWorkerTest do
  use Globaltask.DataCase, async: true
  use Oban.Testing, repo: Globaltask.Repo

  alias Globaltask.Workers.SendWebhookWorker
  alias Globaltask.CreditApplications

  @valid_attrs %{
    "country" => "BR",
    "full_name" => "João Silva",
    "document_type" => "CPF",
    "document_number" => "12345678909",
    "requested_amount" => 5000,
    "monthly_income" => 5000,
    "application_date" => "2026-03-05"
  }

  describe "Webhook enqueuing logic" do
    test "enqueues webhook when application transitions to approved" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, app} = CreditApplications.create_application(@valid_attrs)

        # Let's transition to "approved" (if allowed via pending_review).
        {:ok, app} = CreditApplications.update_status(app, "pending_review")
        {:ok, app} = CreditApplications.update_status(app, "approved")

        assert_enqueued worker: SendWebhookWorker, args: %{"application_id" => app.id, "status" => "approved"}
      end)
    end

    test "does not enqueue webhook on non-terminal transitions" do
      {:ok, app} = CreditApplications.create_application(@valid_attrs)
      {:ok, app} = CreditApplications.update_status(app, "pending_review")

      refute_enqueued worker: SendWebhookWorker, args: %{"application_id" => app.id, "status" => "pending_review"}
    end
  end
end
