defmodule Mccap.CountryRules.ESTest do
  use Mccap.DataCase, async: true

  alias Mccap.CountryRules.ES
  alias Mccap.CreditApplications.CreditApplication

  import Ecto.Changeset

  @fields ~w(country full_name document_type document_number requested_amount monthly_income application_date)a

  defp build_changeset(overrides \\ %{}) do
    defaults = %{
      "country" => "ES",
      "full_name" => "Juan García",
      "document_type" => "DNI",
      "document_number" => "12345678Z",
      "requested_amount" => 15_000,
      "monthly_income" => 3500,
      "application_date" => "2026-03-04"
    }

    %CreditApplication{}
    |> cast(Map.merge(defaults, overrides), @fields)
  end

  # -- required_document_type/0 --

  test "required_document_type/0 returns \"DNI\"" do
    assert ES.required_document_type() == "DNI"
  end

  # -- validate_document/1 --

  describe "validate_document/1" do
    test "valid DNI passes validation" do
      # 12345678Z: 12345678 rem 23 = 14 → Z (index 14 in TRWAGMYFPDXBNJZSQVHLCKE)
      changeset = build_changeset() |> ES.validate_document()
      refute changeset.errors[:document_number]
    end

    test "valid DNI with different control letter" do
      # 00000000T: 0 rem 23 = 0 → T
      changeset = build_changeset(%{"document_number" => "00000000T"}) |> ES.validate_document()
      refute changeset.errors[:document_number]
    end
    test "invalid DNI — incorrect control letter" do
      # 12345678Z is valid, meaning 12345678A is structurally valid but mathematically invalid
      changeset = build_changeset(%{"document_number" => "12345678A"}) |> ES.validate_document()
      assert %{document_number: ["invalid DNI format or control letter"]} = errors_on(changeset)
    end
    test "invalid DNI — wrong length (too short)" do
      changeset = build_changeset(%{"document_number" => "1234567Z"}) |> ES.validate_document()
      assert %{document_number: [_]} = errors_on(changeset)
    end

    test "invalid DNI — wrong length (too long)" do
      changeset = build_changeset(%{"document_number" => "123456789Z"}) |> ES.validate_document()
      assert %{document_number: [_]} = errors_on(changeset)
    end

    test "invalid DNI — non-digit characters in number part" do
      changeset = build_changeset(%{"document_number" => "1234ABCDZ"}) |> ES.validate_document()
      assert %{document_number: [_]} = errors_on(changeset)
    end

    test "valid DNI — lowercase letter is accepted (case-insensitive)" do
      # 12345678z should be accepted as valid since we upcase
      changeset = build_changeset(%{"document_number" => "12345678z"}) |> ES.validate_document()
      refute changeset.errors[:document_number]
    end

    test "invalid DNI — whitespace around is handled" do
      # Trimmed "  12345678Z  " should be valid
      changeset = build_changeset(%{"document_number" => "  12345678Z  "}) |> ES.validate_document()
      refute changeset.errors[:document_number]
    end


  end

  # -- validate_business_rules/1 --

  describe "validate_business_rules/1" do
    test "amount below threshold keeps status as 'created'" do
      changeset = build_changeset(%{"requested_amount" => 49_999}) |> ES.validate_business_rules()
      refute get_change(changeset, :status)
    end

    test "amount equal to threshold keeps status as 'created'" do
      changeset = build_changeset(%{"requested_amount" => 50_000}) |> ES.validate_business_rules()
      refute get_change(changeset, :status)
    end

    test "amount above threshold forces status to 'pending_review'" do
      changeset = build_changeset(%{"requested_amount" => 50_001}) |> ES.validate_business_rules()
      assert get_change(changeset, :status) == "pending_review"
    end

    test "amount well above threshold forces status to 'pending_review'" do
      changeset = build_changeset(%{"requested_amount" => 100_000}) |> ES.validate_business_rules()
      assert get_change(changeset, :status) == "pending_review"
    end
  end
end
