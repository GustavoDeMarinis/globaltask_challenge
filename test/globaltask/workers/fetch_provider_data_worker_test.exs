defmodule Globaltask.Workers.FetchProviderDataWorkerTest do
  use Globaltask.DataCase, async: true
  use Oban.Testing, repo: Globaltask.Repo

  alias Globaltask.Workers.FetchProviderDataWorker
  alias Globaltask.Workers.RiskEvaluationWorker
  alias Globaltask.CreditApplications

  @valid_attrs %{
    "country" => "ES",
    "full_name" => "Juan García",
    "document_type" => "DNI",
    "document_number" => "12345678Z",
    "requested_amount" => 15000,
    "monthly_income" => 3500,
    "application_date" => "2026-03-03"
  }

  defp create_application(overrides \\ %{}) do
    {:ok, app} = CreditApplications.create_application(Map.merge(@valid_attrs, overrides))
    app
  end

  describe "perform/1" do
    test "fetches data, updates payload, and enqueues risk evaluation" do
      app = create_application()

      # Overriding inline mode so the inserted job isn't consumed immediately
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = perform_job(FetchProviderDataWorker, %{"application_id" => app.id})

        {:ok, updated_app} = CreditApplications.get_application(app.id)
        assert updated_app.provider_payload != %{}
        assert is_integer(updated_app.provider_payload["credit_score"])

        assert_enqueued worker: RiskEvaluationWorker, args: %{"application_id" => app.id}
      end)
    end

    test "is idempotent: skips fetch if payload is already present" do
      app = create_application()
      {:ok, app} = CreditApplications.update_provider_payload_and_enqueue_risk(app, %{"credit_score" => 999})

      assert :ok = perform_job(FetchProviderDataWorker, %{"application_id" => app.id})

      {:ok, updated_app} = CreditApplications.get_application(app.id)
      assert updated_app.provider_payload == %{"credit_score" => 999}

      # Should NOT enqueue risk evaluation again from this worker
      # if it skipped fetching (it relies on the first pass to have enqueued it)
      # Wait, my implementation says if it skips it just returns :ok! Let's verify.
      refute_enqueued worker: RiskEvaluationWorker, args: %{"application_id" => app.id}
    end

    test "discards job if application is not found" do
      assert {:discard, :application_not_found} =
               perform_job(FetchProviderDataWorker, %{"application_id" => Ecto.UUID.generate()})
    end
  end
end
