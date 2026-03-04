defmodule Globaltask.CountryRules.COTest do
  use Globaltask.DataCase, async: true

  alias Globaltask.CountryRules.CO
  alias Globaltask.CreditApplications.CreditApplication

  defp build_changeset(overrides \\ %{}) do
    defaults = %{
      "country" => "CO",
      "full_name" => "Andrés Martínez",
      "document_type" => "CC",
      "document_number" => "1234567890",
      "requested_amount" => 10_000,
      "monthly_income" => 3000,
      "application_date" => "2026-03-04"
    }

    %CreditApplication{}
    |> CreditApplication.create_changeset(Map.merge(defaults, overrides))
  end

  test "required_document_type/0 returns \"CC\"" do
    assert CO.required_document_type() == "CC"
  end

  # -- validate_document/1 --

  describe "validate_document/1" do
    test "valid CC — 10 digits passes" do
      changeset = build_changeset() |> CO.validate_document()
      refute changeset.errors[:document_number]
    end

    test "valid CC — 6 digits passes" do
      changeset = build_changeset(%{"document_number" => "123456"}) |> CO.validate_document()
      refute changeset.errors[:document_number]
    end

    test "valid CC — 8 digits passes" do
      changeset = build_changeset(%{"document_number" => "12345678"}) |> CO.validate_document()
      refute changeset.errors[:document_number]
    end

    test "invalid CC — too short (5 digits)" do
      changeset = build_changeset(%{"document_number" => "12345"}) |> CO.validate_document()
      assert %{document_number: [_]} = errors_on(changeset)
    end

    test "invalid CC — too long (11 digits)" do
      changeset = build_changeset(%{"document_number" => "12345678901"}) |> CO.validate_document()
      assert %{document_number: [_]} = errors_on(changeset)
    end

    test "invalid CC — non-digits" do
      changeset = build_changeset(%{"document_number" => "1234ABCD"}) |> CO.validate_document()
      assert %{document_number: [_]} = errors_on(changeset)
    end

    test "valid CC — whitespace trimmed" do
      changeset = build_changeset(%{"document_number" => "  1234567890  "}) |> CO.validate_document()
      refute changeset.errors[:document_number]
    end
  end

  # -- validate_business_rules/1 --

  describe "validate_business_rules/1" do
    test "placeholder rule always passes" do
      changeset = build_changeset(%{"requested_amount" => 999_999}) |> CO.validate_business_rules()
      refute changeset.errors[:requested_amount]
    end
  end
end
