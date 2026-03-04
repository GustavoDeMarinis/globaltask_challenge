defmodule Globaltask.CountryRules.MXTest do
  use Globaltask.DataCase, async: true

  alias Globaltask.CountryRules.MX
  alias Globaltask.CreditApplications.CreditApplication

  import Ecto.Changeset

  @fields ~w(country full_name document_type document_number requested_amount monthly_income application_date)a

  defp build_changeset(overrides \\ %{}) do
    defaults = %{
      "country" => "MX",
      "full_name" => "Carlos López",
      "document_type" => "CURP",
      "document_number" => "LOPC900101HDFRRL09",
      "requested_amount" => 10_000,
      "monthly_income" => 5000,
      "application_date" => "2026-03-04"
    }

    %CreditApplication{}
    |> cast(Map.merge(defaults, overrides), @fields)
  end

  test "required_document_type/0 returns \"CURP\"" do
    assert MX.required_document_type() == "CURP"
  end

  # -- validate_document/1 --

  describe "validate_document/1" do
    test "valid CURP passes validation" do
      changeset = build_changeset() |> MX.validate_document()
      refute changeset.errors[:document_number]
    end

    test "valid CURP with female gender marker" do
      changeset = build_changeset(%{"document_number" => "LOPC900101MDFRRL09"}) |> MX.validate_document()
      refute changeset.errors[:document_number]
    end

    test "invalid CURP — wrong length" do
      changeset = build_changeset(%{"document_number" => "LOPC900101HDFRRL0"}) |> MX.validate_document()
      assert %{document_number: [_]} = errors_on(changeset)
    end

    test "invalid CURP — bad gender char (X instead of H/M)" do
      changeset = build_changeset(%{"document_number" => "LOPC900101XDFRRL09"}) |> MX.validate_document()
      assert %{document_number: [_]} = errors_on(changeset)
    end

    test "invalid CURP — whitespace trimmed" do
      changeset = build_changeset(%{"document_number" => "  LOPC900101HDFRRL09  "}) |> MX.validate_document()
      refute changeset.errors[:document_number]
    end

    test "invalid CURP — lowercase accepted" do
      changeset = build_changeset(%{"document_number" => "lopc900101hdfrrl09"}) |> MX.validate_document()
      refute changeset.errors[:document_number]
    end
  end

  # -- validate_business_rules/1 --

  describe "validate_business_rules/1" do
    test "amount within 3× income passes" do
      changeset = build_changeset(%{"requested_amount" => 15_000, "monthly_income" => 5000}) |> MX.validate_business_rules()
      refute changeset.errors[:requested_amount]
    end

    test "amount exceeding 3× income fails" do
      changeset = build_changeset(%{"requested_amount" => 15_001, "monthly_income" => 5000}) |> MX.validate_business_rules()
      assert %{requested_amount: [_]} = errors_on(changeset)
    end

    test "amount exactly at 3× income passes" do
      changeset = build_changeset(%{"requested_amount" => 15_000, "monthly_income" => 5000}) |> MX.validate_business_rules()
      refute changeset.errors[:requested_amount]
    end
  end
end
