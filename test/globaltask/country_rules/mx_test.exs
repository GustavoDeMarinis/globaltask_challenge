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
      # Valid CURP checksum
      "document_number" => "OASR871212HDFRRN01",
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
      changeset = build_changeset(%{"document_number" => "OASR871212HDFRRN01"}) |> MX.validate_document()
      refute changeset.errors[:document_number]
    end

    test "valid CURP with female gender marker" do
      # Evaluated via same script: OASR871212MDFRRN01 maps mathematically correctly for M
      changeset = build_changeset(%{"document_number" => "OASR871212MDFRRN01"}) |> MX.validate_document()
      refute changeset.errors[:document_number]
    end

    test "invalid CURP — incorrect check digit" do
      # OASR871212HDFRRN01 is mathematically correct, so OASR871212HDFRRN05 fails the math checks
      changeset = build_changeset(%{"document_number" => "OASR871212HDFRRN05"}) |> MX.validate_document()
      assert %{document_number: ["invalid CURP format or check digit"]} = errors_on(changeset)
    end

    test "invalid CURP — wrong length" do
      changeset = build_changeset(%{"document_number" => "OASR871212HDFRRN0"}) |> MX.validate_document()
      assert %{document_number: [_]} = errors_on(changeset)
    end

    test "invalid CURP — bad gender char (X instead of H/M)" do
      changeset = build_changeset(%{"document_number" => "OASR871212XDFRRN01"}) |> MX.validate_document()
      assert %{document_number: [_]} = errors_on(changeset)
    end

    test "invalid CURP — whitespace trimmed" do
      changeset = build_changeset(%{"document_number" => "  OASR871212HDFRRN01  "}) |> MX.validate_document()
      refute changeset.errors[:document_number]
    end

    test "invalid CURP — lowercase accepted" do
      changeset = build_changeset(%{"document_number" => "oasr871212hdfrrn01"}) |> MX.validate_document()
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

  # -- evaluate_risk/1 --

  describe "evaluate_risk/1" do
    test "score >= 650 is approved" do
      app = %CreditApplication{provider_payload: %{"buro_score" => 700}}
      assert MX.evaluate_risk(app) == :approve
    end

    test "score between 500 and 649 is reviewed" do
      app = %CreditApplication{provider_payload: %{"buro_score" => 600}}
      assert MX.evaluate_risk(app) == :review
    end

    test "score < 500 is rejected" do
      app = %CreditApplication{provider_payload: %{"buro_score" => 450}}
      assert MX.evaluate_risk(app) == :reject
    end

    test "skips evaluation when provider payload is invalid" do
      app = %CreditApplication{provider_payload: %{}}
      assert MX.evaluate_risk(app) == :skip
    end
  end
end
