defmodule Mccap.CountryRules.IT do
  @moduledoc """
  Country-specific validation rules for Italy (IT).

  - **Document:** Codice Fiscale — 16 alphanumeric characters matching
    `^[A-Z]{6}\\d{2}[A-Z]\\d{2}[A-Z]\\d{3}[A-Z]$`.
  - **Business rule:** `monthly_income >= 800`. Reject if below.
  - **Risk evaluation:** Based on `financial_stability` from bank provider:
    - "stable" → approve
    - "moderate" → review
    - "at_risk" → reject
  """

  use Mccap.CountryRules

  import Ecto.Changeset

  @codice_fiscale_regex ~r/^[A-Z]{6}\d{2}[A-Z]\d{2}[A-Z]\d{3}[A-Z]$/i
  @min_income Decimal.new("800")

  @impl true
  @spec required_document_type() :: String.t()
  def required_document_type, do: "CodiceFiscale"

  @impl true
  @spec validate_document(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate_document(changeset) do
    case get_field(changeset, :document_number) do
      nil -> changeset
      doc_number ->
        if valid_codice_fiscale?(doc_number) do
          changeset
        else
          add_error(changeset, :document_number, "invalid Codice Fiscale format or check digit")
        end
    end
  end

  # -- Private helpers --

  @spec valid_codice_fiscale?(String.t()) :: boolean()
  defp valid_codice_fiscale?(doc_number) do
    trimmed = String.trim(doc_number) |> String.upcase()

    if Regex.match?(@codice_fiscale_regex, trimmed) do
      chars = String.graphemes(trimmed)

      # The 16th character is the control letter
      {body_chars, [control_char]} = Enum.split(chars, 15)

      # 1-based indexing in Elixir Enum.with_index(1), but Italian law uses odd/even positions:
      # e.g. 1st char (odd index), 2nd char (even index).
      sum =
        body_chars
        |> Enum.with_index(1)
        |> Enum.reduce(0, fn {char, pos}, acc ->
          if rem(pos, 2) != 0 do
            acc + odd_value(char)
          else
            acc + even_value(char)
          end
        end)

      check_digit_value = rem(sum, 26)
      expected_control_char = encode_check_digit(check_digit_value)

      control_char == expected_control_char
    else
      false
    end
  end

  # Even positions convert 0-9 to 0-9, and A-Z to 0-25
  defp even_value(c) do
    if Regex.match?(~r/\d/, c) do
      String.to_integer(c)
    else
      <<code::utf8>> = c
      code - ?A
    end
  end

  # Odd positions use a chaotic mapping table established by Italian law
  defp odd_value(c) do
    case c do
      "0" -> 1; "1" -> 0; "2" -> 5; "3" -> 7; "4" -> 9
      "5" -> 13; "6" -> 15; "7" -> 17; "8" -> 19; "9" -> 21
      "A" -> 1; "B" -> 0; "C" -> 5; "D" -> 7; "E" -> 9
      "F" -> 13; "G" -> 15; "H" -> 17; "I" -> 19; "J" -> 21
      "K" -> 2; "L" -> 4; "M" -> 18; "N" -> 20; "O" -> 11
      "P" -> 3; "Q" -> 6; "R" -> 8; "S" -> 12; "T" -> 14
      "U" -> 16; "V" -> 10; "W" -> 22; "X" -> 25; "Y" -> 24
      "Z" -> 23
    end
  end

  defp encode_check_digit(value) do
    <<value + ?A::utf8>>
  end

  @impl true
  @spec validate_business_rules(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate_business_rules(changeset) do
    case get_field(changeset, :monthly_income) do
      nil ->
        changeset

      income ->
        if Decimal.lt?(income, @min_income) do
          add_error(changeset, :monthly_income,
            "must be at least %{min_income} for Italy",
            min_income: Decimal.to_string(@min_income)
          )
        else
          changeset
        end
    end
  end

  # -- Risk evaluation --

  @impl true
  @spec evaluate_risk(%Mccap.CreditApplications.CreditApplication{}) ::
          :approve | :reject | :review | :skip
  def evaluate_risk(%{provider_payload: %{"financial_stability" => stability}}) do
    case stability do
      "stable" -> :approve
      "moderate" -> :review
      "at_risk" -> :reject
      _ -> :reject
    end
  end

  def evaluate_risk(_app), do: :skip
end
