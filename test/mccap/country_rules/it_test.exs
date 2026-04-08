defmodule Mccap.CountryRules.ITTest do
  use Mccap.DataCase, async: true

  alias Mccap.CountryRules.IT
  alias Mccap.CreditApplications.CreditApplication

  import Ecto.Changeset

  @fields ~w(country full_name document_type document_number requested_amount monthly_income application_date)a

  defp build_changeset(overrides \\ %{}) do
    defaults = %{
      "country" => "IT",
      "full_name" => "Marco Rossi",
      "document_type" => "CodiceFiscale",
      "document_number" => "RSSMRC90A01H501Y",
      "requested_amount" => 10_000,
      "monthly_income" => 2000,
      "application_date" => "2026-03-04"
    }

    %CreditApplication{}
    |> cast(Map.merge(defaults, overrides), @fields)
  end

  test "required_document_type/0 returns \"CodiceFiscale\"" do
    assert IT.required_document_type() == "CodiceFiscale"
  end

  # -- validate_document/1 --

  describe "validate_document/1" do
    test "valid Codice Fiscale passes validation" do
      changeset = build_changeset() |> IT.validate_document()
      refute changeset.errors[:document_number]
    end

    test "valid Codice Fiscale — lowercase accepted" do
      changeset = build_changeset(%{"document_number" => "rssmrc90a01h501y"}) |> IT.validate_document()
      refute changeset.errors[:document_number]
    end

    test "invalid Codice Fiscale — incorrect check digit" do
      # RSSMRC90A01H501Y is valid, meaning RSSMRC90A01H501B fails the math check
      changeset = build_changeset(%{"document_number" => "RSSMRC90A01H501B"}) |> IT.validate_document()
      assert %{document_number: ["invalid Codice Fiscale format or check digit"]} = errors_on(changeset)
    end

    test "invalid Codice Fiscale — wrong length" do
      changeset = build_changeset(%{"document_number" => "RSSMRC90A01H501"}) |> IT.validate_document()
      assert %{document_number: [_]} = errors_on(changeset)
    end

    test "invalid Codice Fiscale — bad structure (digits where letters expected)" do
      changeset = build_changeset(%{"document_number" => "123MRC90A01H501Y"}) |> IT.validate_document()
      assert %{document_number: [_]} = errors_on(changeset)
    end

    test "invalid Codice Fiscale — too long" do
      changeset = build_changeset(%{"document_number" => "RSSMRC90A01H501YB"}) |> IT.validate_document()
      assert %{document_number: [_]} = errors_on(changeset)
    end

    test "invalid Codice Fiscale — whitespace trimmed" do
      changeset = build_changeset(%{"document_number" => "  RSSMRC90A01H501Y  "}) |> IT.validate_document()
      refute changeset.errors[:document_number]
    end
  end

  # -- validate_business_rules/1 --

  describe "validate_business_rules/1" do
    test "income at threshold passes" do
      changeset = build_changeset(%{"monthly_income" => 800}) |> IT.validate_business_rules()
      refute changeset.errors[:monthly_income]
    end

    test "income above threshold passes" do
      changeset = build_changeset(%{"monthly_income" => 1500}) |> IT.validate_business_rules()
      refute changeset.errors[:monthly_income]
    end

    test "income below threshold fails" do
      changeset = build_changeset(%{"monthly_income" => 799}) |> IT.validate_business_rules()
      assert %{monthly_income: [_]} = errors_on(changeset)
    end
  end

  # -- evaluate_risk/1 --

  describe "evaluate_risk/1" do
    test "stable is approved" do
      app = %CreditApplication{provider_payload: %{"financial_stability" => "stable"}}
      assert IT.evaluate_risk(app) == :approve
    end

    test "moderate is reviewed" do
      app = %CreditApplication{provider_payload: %{"financial_stability" => "moderate"}}
      assert IT.evaluate_risk(app) == :review
    end

    test "at_risk is rejected" do
      app = %CreditApplication{provider_payload: %{"financial_stability" => "at_risk"}}
      assert IT.evaluate_risk(app) == :reject
    end

    test "unknown stability is rejected" do
      app = %CreditApplication{provider_payload: %{"financial_stability" => "unknown"}}
      assert IT.evaluate_risk(app) == :reject
    end

    test "skips evaluation when provider payload is missing financial_stability" do
      app = %CreditApplication{provider_payload: %{}}
      assert IT.evaluate_risk(app) == :skip
    end
  end
end
