defmodule Globaltask.CreditApplicationsTest do
  use Globaltask.DataCase, async: true

  alias Globaltask.CreditApplications
  alias Globaltask.CreditApplications.CreditApplication

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

  # -- create_application/1 --

  describe "create_application/1" do
    test "with valid attrs returns {:ok, app} with status 'created'" do
      assert {:ok, %CreditApplication{} = app} = CreditApplications.create_application(@valid_attrs)
      assert app.status == "created"
      assert app.country == "ES"
      assert app.full_name == "Juan García"
      assert app.document_type == "DNI"
      assert app.document_number == "12345678Z"
      assert app.application_date == ~D[2026-03-03]
      assert Decimal.compare(app.requested_amount, Decimal.new("15000")) == :eq
    end

    test "with missing required field returns {:error, changeset}" do
      assert {:error, changeset} = CreditApplications.create_application(%{"country" => "ES"})
      assert %{full_name: ["can't be blank"]} = errors_on(changeset)
    end

    test "with requested_amount <= 0 returns {:error, changeset}" do
      attrs = Map.put(@valid_attrs, "requested_amount", -100)
      assert {:error, changeset} = CreditApplications.create_application(attrs)
      assert %{requested_amount: [_]} = errors_on(changeset)
    end

    test "with invalid document_type returns {:error, changeset}" do
      attrs = Map.put(@valid_attrs, "document_type", "PASSPORT")
      assert {:error, changeset} = CreditApplications.create_application(attrs)
      assert %{document_type: [_]} = errors_on(changeset)
    end

    test "with invalid country returns {:error, changeset}" do
      attrs = Map.put(@valid_attrs, "country", "XX")
      assert {:error, changeset} = CreditApplications.create_application(attrs)
      assert %{country: [_]} = errors_on(changeset)
    end

    test "ignores caller-supplied status (always defaults to 'created')" do
      attrs = Map.put(@valid_attrs, "status", "approved")
      assert {:ok, app} = CreditApplications.create_application(attrs)
      assert app.status == "created"
    end

    test "with duplicate active document_number + country returns {:error, changeset}" do
      create_application()

      assert {:error, changeset} =
               CreditApplications.create_application(%{@valid_attrs | "full_name" => "Another Person"})

      assert %{document_number: [_]} = errors_on(changeset)
    end

    test "with duplicate document_number + country where prior is rejected succeeds" do
      app = create_application()
      {:ok, _} = CreditApplications.update_status(app, "rejected")

      assert {:ok, new_app} =
               CreditApplications.create_application(%{@valid_attrs | "requested_amount" => 8000})

      assert new_app.status == "created"
      assert new_app.id != app.id
    end
  end

  # -- get_application/1 --

  describe "get_application/1" do
    test "with valid id returns {:ok, app}" do
      app = create_application()
      assert {:ok, found} = CreditApplications.get_application(app.id)
      assert found.id == app.id
    end

    test "with unknown id returns {:error, :not_found}" do
      assert {:error, :not_found} = CreditApplications.get_application(Ecto.UUID.generate())
    end

    test "with invalid UUID format returns {:error, :not_found}" do
      assert {:error, :not_found} = CreditApplications.get_application("not-a-uuid")
    end
  end

  # -- list_applications/1 --

  describe "list_applications/1" do
    test "with no filters returns all records with pagination metadata" do
      create_application(%{"document_number" => "AAA111"})
      create_application(%{"document_number" => "BBB222"})

      result = CreditApplications.list_applications()
      assert result.total == 2
      assert length(result.data) == 2
      assert result.page == 1
      assert result.page_size == 20
    end

    test "with country filter returns only matching records" do
      create_application(%{"country" => "ES", "document_number" => "ES001"})
      create_application(%{"country" => "BR", "document_number" => "BR001", "document_type" => "CPF"})

      result = CreditApplications.list_applications(%{"country" => "ES"})
      assert result.total == 1
      assert hd(result.data).country == "ES"
    end

    test "with status filter returns only matching records" do
      app = create_application(%{"document_number" => "ST001"})
      create_application(%{"document_number" => "ST002"})
      {:ok, _} = CreditApplications.update_status(app, "pending_review")

      result = CreditApplications.list_applications(%{"status" => "pending_review"})
      assert result.total == 1
      assert hd(result.data).status == "pending_review"
    end

    test "with date_from and date_to returns only matching records" do
      create_application(%{"document_number" => "DT001"})

      result = CreditApplications.list_applications(%{
        "date_from" => Date.to_iso8601(Date.utc_today()),
        "date_to" => Date.to_iso8601(Date.utc_today())
      })

      assert result.total == 1
    end

    test "with page and page_size returns correct slice and total" do
      for i <- 1..5 do
        create_application(%{"document_number" => "PG#{String.pad_leading("#{i}", 3, "0")}"})
      end

      result = CreditApplications.list_applications(%{"page" => 2, "page_size" => 2})
      assert result.total == 5
      assert result.page == 2
      assert result.page_size == 2
      assert length(result.data) == 2
    end

    test "with page_size over 100 is capped at 100" do
      result = CreditApplications.list_applications(%{"page_size" => 500})
      assert result.page_size == 100
    end
  end

  # -- update_status/2 --

  describe "update_status/2" do
    test "with valid transition (created -> pending_review) returns {:ok, updated_app}" do
      app = create_application()
      assert {:ok, updated} = CreditApplications.update_status(app, "pending_review")
      assert updated.status == "pending_review"
    end

    test "with invalid transition (approved -> created) returns {:error, changeset}" do
      app = create_application()
      {:ok, app} = CreditApplications.update_status(app, "pending_review")
      {:ok, app} = CreditApplications.update_status(app, "approved")

      assert {:error, changeset} = CreditApplications.update_status(app, "created")
      assert %{status: [_]} = errors_on(changeset)
    end

    test "with invalid status value returns {:error, changeset}" do
      app = create_application()
      assert {:error, changeset} = CreditApplications.update_status(app, "nonexistent")
      assert %{status: [_ | _]} = errors_on(changeset)
    end
  end
end
