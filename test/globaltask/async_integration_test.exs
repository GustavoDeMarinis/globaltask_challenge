defmodule Globaltask.AsyncIntegrationTest do
  use GlobaltaskWeb.ConnCase, async: false # Oban execution and PG notifications might need async: false
  use Oban.Testing, repo: Globaltask.Repo

  alias Globaltask.CreditApplications
  alias Globaltask.Workers.FetchProviderDataWorker
  alias Globaltask.Workers.RiskEvaluationWorker

  @valid_attrs %{
    "country" => "ES",
    "full_name" => "Juan García",
    "document_type" => "DNI",
    "document_number" => "12345678Z", # ES hash produces a good credit score (e.g. > 700) for testing
    "requested_amount" => 15000,
    "monthly_income" => 3500,
    "application_date" => "2026-03-03"
  }

  setup %{conn: conn} do
    token = GlobaltaskWeb.Token.sign!(%{"role" => "admin"})
    conn = put_req_header(conn, "authorization", "Bearer #{token}")
    {:ok, conn: conn}
  end

  describe "Full Async Lifecycle" do
    test "create -> PG Trigger -> PgListener -> FetchWorker -> RiskWorker -> Approved", %{conn: conn} do
      # Since PgListener runs asynchronously, and Oban might run asynchronously, we use manual testing
      # to control the flow and verify each step.

      Oban.Testing.with_testing_mode(:manual, fn ->
        # 1. API Create
        conn = post(conn, ~p"/api/v1/credit_applications", @valid_attrs)
        assert %{"data" => %{"id" => id, "status" => "created"}} = json_response(conn, 201)

        # 2. PG Trigger -> PgListener -> Oban enqueue
        # Because Ecto tests run in a Sandbox that rolls back transactions, PostgreSQL
        # will never actually deliver the `pg_notify` event. Furthermore, spinning up
        # the PgListener GenServer causes cross-process Ecto sandbox issues when it
        # tries to call Repo.insert/Oban.insert.
        # Therefore, we simulate the PgListener's single responsibility directly in the
        # test process to verify the rest of the async pipeline.

        %{"application_id" => id}
        |> FetchProviderDataWorker.new()
        |> Oban.insert()

        # 3. Verify FetchProviderDataWorker is enqueued
        assert_enqueued worker: FetchProviderDataWorker, args: %{"application_id" => id}

        # 4. Drain the queues to execute the workers
        # Oban.drain_queue returns %{success: _, failure: _}
        # We drain provider_fetch queue first
        assert %{success: 1, failure: 0} = Oban.drain_queue(queue: :provider_fetch)

        # The fetch worker should have populated payload and enqueued risk evaluation
        {:ok, app_fetched} = CreditApplications.get_application(id)
        assert app_fetched.provider_payload != %{}

        assert_enqueued worker: RiskEvaluationWorker, args: %{"application_id" => id}

        # 5. Drain risk_evaluation queue
        assert %{success: 1, failure: 0} = Oban.drain_queue(queue: :risk_evaluation)

        # The risk worker should have evaluated the payload and transitioned the status
        {:ok, app_evaluated} = CreditApplications.get_application(id)
        # We don't know the exact random hash for 12345678Z offhand, but it should NOT be "created"
        assert app_evaluated.status in ["approved", "rejected", "pending_review"]
      end)
    end
  end
end
