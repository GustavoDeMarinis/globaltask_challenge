defmodule Globaltask.CountryRules.BRTest do
  use Globaltask.DataCase, async: true

  alias Globaltask.CountryRules.BR
  alias Globaltask.CreditApplications.CreditApplication

  import Ecto.Changeset

  @fields ~w(country full_name document_type document_number requested_amount monthly_income application_date)a

  defp build_changeset(overrides \\ %{}) do
    defaults = %{
      "country" => "BR",
      "full_name" => "Maria Oliveira",
      "document_type" => "CPF",
      "document_number" => "52998224725",
      "requested_amount" => 10_000,
      "monthly_income" => 3000,
      "application_date" => "2026-03-04"
    }

    %CreditApplication{}
    |> cast(Map.merge(defaults, overrides), @fields)
  end

  test "required_document_type/0 returns \"CPF\"" do
    assert BR.required_document_type() == "CPF"
  end

  # -- validate_document/1 --

  describe "validate_document/1" do
    test "valid CPF passes validation" do
      # 52998224725 is a known valid CPF
      changeset = build_changeset() |> BR.validate_document()
      refute changeset.errors[:document_number]
    end

    test "another valid CPF passes" do
      # 11144477735 is a known valid CPF
      changeset = build_changeset(%{"document_number" => "11144477735"}) |> BR.validate_document()
      refute changeset.errors[:document_number]
    end

    test "valid CPF passes with punctuation" do
      # Our logic strips formatting
      changeset = build_changeset(%{"document_number" => "111.444.777-35"}) |> BR.validate_document()
      refute changeset.errors[:document_number]
    end

    test "invalid CPF — incorrect check digits but structurally valid" do
      # 11144477735 is valid, so 11144477734 fails the math check
      changeset = build_changeset(%{"document_number" => "11144477734"}) |> BR.validate_document()
      assert %{document_number: ["invalid CPF format or check digits"]} = errors_on(changeset)
    end

    test "invalid CPF — all identical digits rejected" do
      changeset = build_changeset(%{"document_number" => "11111111111"}) |> BR.validate_document()
      assert %{document_number: ["invalid CPF format or check digits"]} = errors_on(changeset)
    end

    test "invalid CPF — wrong length (too short)" do
      changeset = build_changeset(%{"document_number" => "5299822472"}) |> BR.validate_document()
      assert %{document_number: [_]} = errors_on(changeset)
    end

    test "invalid CPF — wrong length (too long)" do
      changeset = build_changeset(%{"document_number" => "529982247250"}) |> BR.validate_document()
      assert %{document_number: [_]} = errors_on(changeset)
    end



    test "valid CPF — whitespace trimmed" do
      changeset = build_changeset(%{"document_number" => "  52998224725  "}) |> BR.validate_document()
      refute changeset.errors[:document_number]
    end

    test "invalid CPF — contains non-digits" do
      changeset = build_changeset(%{"document_number" => "5299822472A"}) |> BR.validate_document()
      assert %{document_number: [_]} = errors_on(changeset)
    end
  end

  # -- validate_business_rules/1 --

  describe "validate_business_rules/1" do
    test "amount within 5× income passes" do
      changeset = build_changeset(%{"requested_amount" => 15_000, "monthly_income" => 3000}) |> BR.validate_business_rules()
      refute changeset.errors[:requested_amount]
    end

    test "amount exactly at 5× income passes" do
      changeset = build_changeset(%{"requested_amount" => 15_000, "monthly_income" => 3000}) |> BR.validate_business_rules()
      refute changeset.errors[:requested_amount]
    end

    test "amount exceeding 5× income fails" do
      changeset = build_changeset(%{"requested_amount" => 15_001, "monthly_income" => 3000}) |> BR.validate_business_rules()
      assert %{requested_amount: [_]} = errors_on(changeset)
    end
  end
end
