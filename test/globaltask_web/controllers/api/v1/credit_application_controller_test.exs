defmodule GlobaltaskWeb.API.V1.CreditApplicationControllerTest do
  use GlobaltaskWeb.ConnCase, async: true

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

  # -- POST /api/v1/credit_applications --

  describe "POST /api/v1/credit_applications" do
    test "with valid body returns 201 with JSON data", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/credit_applications", @valid_attrs)

      assert %{"data" => data} = json_response(conn, 201)
      assert data["country"] == "ES"
      assert data["full_name"] == "Juan García"
      assert data["status"] == "created"
      assert data["id"]
    end

    test "with invalid body returns 422 with error details", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/credit_applications", %{})

      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["country"]
      assert errors["full_name"]
    end

    test "with caller-supplied status is ignored", %{conn: conn} do
      attrs = Map.put(@valid_attrs, "status", "approved")
      conn = post(conn, ~p"/api/v1/credit_applications", attrs)

      assert %{"data" => data} = json_response(conn, 201)
      assert data["status"] == "created"
    end

    test "with duplicate active document_number + country returns 422", %{conn: conn} do
      create_application()
      conn = post(conn, ~p"/api/v1/credit_applications", @valid_attrs)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["document_number"]
    end
  end

  # -- GET /api/v1/credit_applications/:id --

  describe "GET /api/v1/credit_applications/:id" do
    test "for existing record returns 200 with data", %{conn: conn} do
      app = create_application()
      conn = get(conn, ~p"/api/v1/credit_applications/#{app.id}")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == app.id
      assert data["country"] == "ES"
    end

    test "for unknown id returns 404", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/credit_applications/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end

    test "for malformed UUID returns 404", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/credit_applications/not-a-uuid")
      assert json_response(conn, 404)
    end
  end

  # -- GET /api/v1/credit_applications --

  describe "GET /api/v1/credit_applications" do
    test "with no filters returns list with meta", %{conn: conn} do
      create_application(%{"document_number" => "23456789D"})
      create_application(%{"document_number" => "34567890V"})

      conn = get(conn, ~p"/api/v1/credit_applications")

      assert %{"data" => data, "meta" => meta} = json_response(conn, 200)
      assert length(data) == 2
      assert meta["total"] == 2
      assert meta["page"] == 1
    end

    test "with country filter returns filtered list", %{conn: conn} do
      create_application(%{"country" => "ES", "document_number" => "23456789D"})
      create_application(%{"country" => "BR", "document_number" => "52998224725", "document_type" => "CPF"})

      conn = get(conn, ~p"/api/v1/credit_applications?country=ES")

      assert %{"data" => data, "meta" => meta} = json_response(conn, 200)
      assert length(data) == 1
      assert meta["total"] == 1
    end

    test "with page and page_size returns correct page", %{conn: conn} do
      for i <- 1..5 do
        create_application(%{"document_number" => "#{10000000 + i}#{String.at("TRWAGMYFPDXBNJZSQVHLCKE", rem(10000000 + i, 23))}"})
      end

      conn = get(conn, ~p"/api/v1/credit_applications?page=2&page_size=2")

      assert %{"data" => data, "meta" => meta} = json_response(conn, 200)
      assert length(data) == 2
      assert meta["page"] == 2
      assert meta["total"] == 5
    end
  end

  # -- PATCH /api/v1/credit_applications/:id/status --

  describe "PATCH /api/v1/credit_applications/:id/status" do
    test "with valid transition returns 200", %{conn: conn} do
      app = create_application()
      conn = patch(conn, ~p"/api/v1/credit_applications/#{app.id}/status", %{"status" => "pending_review"})

      assert %{"data" => data} = json_response(conn, 200)
      assert data["status"] == "pending_review"
    end

    test "with invalid transition returns 422", %{conn: conn} do
      app = create_application()
      conn = patch(conn, ~p"/api/v1/credit_applications/#{app.id}/status", %{"status" => "approved"})

      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "for malformed UUID returns 404", %{conn: conn} do
      conn = patch(conn, ~p"/api/v1/credit_applications/not-a-uuid/status", %{"status" => "pending_review"})
      assert json_response(conn, 404)
    end

    test "response body never contains provider_payload", %{conn: conn} do
      app = create_application()

      conn_show = get(conn, ~p"/api/v1/credit_applications/#{app.id}")
      assert %{"data" => data} = json_response(conn_show, 200)
      refute Map.has_key?(data, "provider_payload")

      conn_index = get(conn, ~p"/api/v1/credit_applications")
      assert %{"data" => [item | _]} = json_response(conn_index, 200)
      refute Map.has_key?(item, "provider_payload")
    end

    test "increments lock_version on status update", %{conn: conn} do
      app = create_application()

      conn = patch(conn, ~p"/api/v1/credit_applications/#{app.id}/status", %{"status" => "pending_review"})
      assert %{"data" => _} = json_response(conn, 200)

      {:ok, updated} = CreditApplications.get_application(app.id)
      assert updated.lock_version == app.lock_version + 1
    end
  end

  # -- PUT /api/v1/credit_applications/:id --

  describe "PUT /api/v1/credit_applications/:id" do
    test "with valid attrs returns 200 with updated data", %{conn: conn} do
      app = create_application()
      conn = put(conn, ~p"/api/v1/credit_applications/#{app.id}", %{"full_name" => "Updated Name", "requested_amount" => 25000})
      assert %{"data" => data} = json_response(conn, 200)
      assert data["full_name"] == "Updated Name"
      assert data["requested_amount"] == "25000"
    end

    test "with invalid field returns 422", %{conn: conn} do
      app = create_application()
      conn = put(conn, ~p"/api/v1/credit_applications/#{app.id}", %{"requested_amount" => -5})
      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "does not change country", %{conn: conn} do
      app = create_application()
      conn = put(conn, ~p"/api/v1/credit_applications/#{app.id}", %{"country" => "BR"})
      assert %{"data" => data} = json_response(conn, 200)
      assert data["country"] == "ES"
    end

    test "for unknown id returns 404", %{conn: conn} do
      conn = put(conn, ~p"/api/v1/credit_applications/#{Ecto.UUID.generate()}", %{"full_name" => "Test"})
      assert json_response(conn, 404)
    end
  end

  # -- Country Rules Integration (HTTP level) --

  describe "POST /api/v1/credit_applications country rules" do
    test "ES with invalid DNI returns 422 with document_number error", %{conn: conn} do
      attrs = %{@valid_attrs | "document_number" => "00000000X"}
      conn = post(conn, ~p"/api/v1/credit_applications", attrs)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["document_number"]
    end

    test "ES with amount > 50k creates with pending_review status", %{conn: conn} do
      attrs = %{@valid_attrs | "requested_amount" => 60_000}
      conn = post(conn, ~p"/api/v1/credit_applications", attrs)

      assert %{"data" => data} = json_response(conn, 201)
      assert data["status"] == "pending_review"
    end

    test "BR with valid CPF and valid ratio returns 201", %{conn: conn} do
      attrs = %{
        "country" => "BR",
        "full_name" => "Maria Oliveira",
        "document_type" => "CPF",
        "document_number" => "52998224725",
        "requested_amount" => 10_000,
        "monthly_income" => 5000,
        "application_date" => "2026-03-04"
      }

      conn = post(conn, ~p"/api/v1/credit_applications", attrs)

      assert %{"data" => data} = json_response(conn, 201)
      assert data["country"] == "BR"
      assert data["status"] == "created"
    end

    test "PT with amount > 4× income returns 422", %{conn: conn} do
      attrs = %{
        "country" => "PT",
        "full_name" => "João Silva",
        "document_type" => "NIF",
        "document_number" => "123456789",
        "requested_amount" => 15_000,
        "monthly_income" => 3000,
        "application_date" => "2026-03-04"
      }

      conn = post(conn, ~p"/api/v1/credit_applications", attrs)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["requested_amount"]
    end
  end

  describe "PUT /api/v1/credit_applications/:id country rules" do
    test "with invalid document_number returns 422", %{conn: conn} do
      app = create_application()
      conn = put(conn, ~p"/api/v1/credit_applications/#{app.id}", %{"document_number" => "INVALID"})

      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["document_number"]
    end
  end
end
