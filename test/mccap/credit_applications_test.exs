defmodule Mccap.CreditApplicationsTest do
  use Mccap.DataCase, async: true

  alias Mccap.CreditApplications
  alias Mccap.CreditApplications.CreditApplication

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
      assert %{document_type: [_ | _]} = errors_on(changeset)
    end

    test "with invalid country returns {:error, changeset}" do
      attrs = Map.put(@valid_attrs, "country", "XX")
      assert {:error, changeset} = CreditApplications.create_application(attrs)
      assert %{country: [_ | _]} = errors_on(changeset)
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
      create_application(%{"document_number" => "23456789D"})
      create_application(%{"document_number" => "34567890V"})

      result = CreditApplications.list_applications()
      assert result.total == 2
      assert length(result.data) == 2
      assert result.page == 1
      assert result.page_size == 20
    end

    test "with country filter returns only matching records" do
      create_application(%{"country" => "ES", "document_number" => "23456789D"})
      create_application(%{"country" => "BR", "document_number" => "52998224725", "document_type" => "CPF"})

      result = CreditApplications.list_applications(%{"country" => "ES"})
      assert result.total == 1
      assert hd(result.data).country == "ES"
    end

    test "with status filter returns only matching records" do
      app = create_application(%{"document_number" => "23456789D"})
      create_application(%{"document_number" => "34567890V"})
      {:ok, _} = CreditApplications.update_status(app, "pending_review")

      result = CreditApplications.list_applications(%{"status" => "pending_review"})
      assert result.total == 1
      assert hd(result.data).status == "pending_review"
    end

    test "with date_from and date_to returns only matching records" do
      create_application(%{"document_number" => "23456789D"})

      # Filters now operate on application_date (business date), not inserted_at
      result = CreditApplications.list_applications(%{
        "date_from" => "2026-03-03",
        "date_to" => "2026-03-03"
      })

      assert result.total == 1
    end

    test "with page and page_size returns correct slice and total" do
      for i <- 1..5 do
        create_application(%{"document_number" => "#{10000000 + i}#{String.at("TRWAGMYFPDXBNJZSQVHLCKE", rem(10000000 + i, 23))}"})
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

  # -- update_application/2 --

  describe "update_application/2" do
    test "with valid attrs returns {:ok, updated_app}" do
      app = create_application()
      assert {:ok, updated} = CreditApplications.update_application(app, %{"full_name" => "Updated Name", "requested_amount" => 20000})
      assert updated.full_name == "Updated Name"
      assert Decimal.compare(updated.requested_amount, Decimal.new("20000")) == :eq
    end

    test "with invalid requested_amount returns {:error, changeset}" do
      app = create_application()
      assert {:error, changeset} = CreditApplications.update_application(app, %{"requested_amount" => -1})
      assert %{requested_amount: [_]} = errors_on(changeset)
    end

    test "does not change country" do
      app = create_application()
      {:ok, updated} = CreditApplications.update_application(app, %{"country" => "BR"})
      assert updated.country == "ES"
    end

    test "does not change status" do
      app = create_application()
      {:ok, updated} = CreditApplications.update_application(app, %{"status" => "approved"})
      assert updated.status == "created"
    end

    test "returns {:error, :stale} when record was concurrently modified" do
      app = create_application()
      {:ok, _} = CreditApplications.update_application(app, %{"full_name" => "First Update"})
      assert {:error, :stale} = CreditApplications.update_application(app, %{"full_name" => "Second Update"})
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

    test "returns {:error, :stale} when record was concurrently modified" do
      app = create_application()

      # Perform a valid transition to bump lock_version in DB
      {:ok, _updated} = CreditApplications.update_status(app, "pending_review")

      # Now try to update using the stale `app` struct (lock_version: 0)
      assert {:error, :stale} = CreditApplications.update_status(app, "rejected")
    end
  end

  # -- Country Rules Integration --

  describe "create_application/1 country rules integration" do
    test "ES with invalid DNI returns changeset error on :document_number" do
      attrs = %{@valid_attrs | "document_number" => "1234"}

      assert {:error, changeset} = CreditApplications.create_application(attrs)
      assert %{document_number: [msg]} = errors_on(changeset)
      assert msg =~ "invalid DNI"
    end

    test "ES with wrong document_type returns changeset error on :document_type" do
      attrs = %{@valid_attrs | "document_type" => "CPF"}

      assert {:error, changeset} = CreditApplications.create_application(attrs)
      assert %{document_type: [_ | _]} = errors_on(changeset)
    end

    test "ES with amount > 50k sets status to pending_review" do
      attrs = %{@valid_attrs | "requested_amount" => 60_000}

      assert {:ok, app} = CreditApplications.create_application(attrs)
      assert app.status == "pending_review"
    end

    test "PT with amount > 4× income returns changeset error on :requested_amount" do
      attrs = %{
        "country" => "PT",
        "full_name" => "João Silva",
        "document_type" => "NIF",
        "document_number" => "123456789",
        "requested_amount" => 15_000,
        "monthly_income" => 3000,
        "application_date" => "2026-03-04"
      }

      assert {:error, changeset} = CreditApplications.create_application(attrs)
      assert %{requested_amount: [msg]} = errors_on(changeset)
      assert msg =~ "4"
    end

    test "BR with valid CPF and valid income ratio succeeds" do
      attrs = %{
        "country" => "BR",
        "full_name" => "Maria Oliveira",
        "document_type" => "CPF",
        "document_number" => "52998224725",
        "requested_amount" => 10_000,
        "monthly_income" => 5000,
        "application_date" => "2026-03-04"
      }

      assert {:ok, app} = CreditApplications.create_application(attrs)
      assert app.country == "BR"
      assert app.document_type == "CPF"
      assert app.status == "created"
    end
  end

  describe "update_application/2 country rules integration" do
    test "with invalid document_number returns changeset error" do
      app = create_application()

      assert {:error, changeset} =
               CreditApplications.update_application(app, %{"document_number" => "INVALID"})

      assert %{document_number: [_]} = errors_on(changeset)
    end

    test "with valid document_number update succeeds" do
      app = create_application()

      assert {:ok, updated} =
               CreditApplications.update_application(app, %{"document_number" => "23456789D"})

      assert updated.document_number == "23456789D"
    end
  end

  # -- Architect Review Edge Case Tests --

  describe "architect review fixes" do
    test "ES update with amount > 50k does NOT regress status" do
      app = create_application()
      {:ok, approved_app} = CreditApplications.update_status(app, "pending_review")
      {:ok, approved_app} = CreditApplications.update_status(approved_app, "approved")

      # Update requested_amount to > 50k on an already-approved application
      assert {:ok, updated} =
               CreditApplications.update_application(approved_app, %{"requested_amount" => 60_000})

      # Status must NOT regress to pending_review
      assert updated.status == "approved"
    end

    test "document_type change on update is silently ignored (immutable)" do
      app = create_application()

      assert {:ok, updated} =
               CreditApplications.update_application(app, %{"document_type" => "CPF"})

      # document_type should remain DNI (not cast on update)
      assert updated.document_type == "DNI"
    end

    test "monthly_income below 100 is rejected" do
      attrs = %{@valid_attrs | "monthly_income" => 50}
      assert {:error, changeset} = CreditApplications.create_application(attrs)
      assert %{monthly_income: [_ | _]} = errors_on(changeset)
    end

    test "application_date before 2020 is rejected" do
      attrs = %{@valid_attrs | "application_date" => "2019-12-31", "document_number" => "23456789D"}
      assert {:error, changeset} = CreditApplications.create_application(attrs)
      assert %{application_date: [_ | _]} = errors_on(changeset)
    end

    test "application_date far in the future is rejected" do
      future = Date.utc_today() |> Date.add(60) |> Date.to_iso8601()
      attrs = %{@valid_attrs | "application_date" => future, "document_number" => "23456789D"}
      assert {:error, changeset} = CreditApplications.create_application(attrs)
      assert %{application_date: [_ | _]} = errors_on(changeset)
    end

    test "document_number is trimmed and persisted without whitespace" do
      attrs = %{@valid_attrs | "document_number" => "  12345678Z  "}
      assert {:ok, app} = CreditApplications.create_application(attrs)
      assert app.document_number == "12345678Z"
    end

    test "approved application allows new application from same person" do
      app = create_application()
      {:ok, app} = CreditApplications.update_status(app, "pending_review")
      {:ok, _approved} = CreditApplications.update_status(app, "approved")

      # New application with same document should succeed
      assert {:ok, new_app} =
               CreditApplications.create_application(%{@valid_attrs | "requested_amount" => 8000})

      assert new_app.status == "created"
    end

    test "update_status returns {:error, :stale} on concurrent modification" do
      app = create_application()
      # Simulate concurrent modification
      {:ok, _} = CreditApplications.update_status(app, "pending_review")

      # Now try to update using the stale `app` struct (lock_version: 0)
      assert {:error, :stale} = CreditApplications.update_status(app, "rejected")
    end
  end
end
