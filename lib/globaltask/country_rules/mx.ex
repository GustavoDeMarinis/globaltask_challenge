defmodule Globaltask.CountryRules.MX do
  @moduledoc """
  Country-specific validation rules for Mexico (MX).

  - **Document:** CURP — 18 characters matching
    `^[A-Z]{4}\\d{6}[HM][A-Z]{5}[A-Z0-9]\\d$`.
  - **Business rule:** `requested_amount <= 3 × monthly_income`. Reject if exceeded.
  - **Risk evaluation:** Based on `buro_score` from bank provider:
    - ≥ 650 → approve
    - 500–649 → review
    - < 500 → reject
  """

  use Globaltask.CountryRules

  import Ecto.Changeset

  @curp_regex ~r/^[A-Z]{4}\d{6}[HM][A-Z]{5}[A-Z0-9]\d$/i
  @income_multiplier 3

  @impl true
  @spec required_document_type() :: String.t()
  def required_document_type, do: "CURP"

  @impl true
  @spec validate_document(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate_document(changeset) do
    case get_field(changeset, :document_number) do
      nil -> changeset
      doc_number ->
        if valid_curp?(doc_number) do
          changeset
        else
          add_error(changeset, :document_number, "invalid CURP format or check digit")
        end
    end
  end

  # -- Private helpers --

  @spec valid_curp?(String.t()) :: boolean()
  defp valid_curp?(doc_number) do
    trimmed = String.trim(doc_number) |> String.upcase()

    if Regex.match?(@curp_regex, trimmed) do
      chars = String.graphemes(trimmed)
      {body_chars, [control_char]} = Enum.split(chars, 17)

      sum =
        body_chars
        |> Enum.with_index(0)
        |> Enum.reduce(0, fn {char, index}, acc ->
          weight = 18 - index
          acc + curp_value(char) * weight
        end)

      remainder = rem(sum, 10)

      expected_control_digit =
        if remainder == 0 do
          0
        else
          10 - remainder
        end
        |> Integer.to_string()

      control_char == expected_control_digit
    else
      false
    end
  end

  # Base-36 value assignment for CURP calculation
  # '0'-'9' -> 0-9
  # 'A'-'Z' -> 10-35
  # Note: The letter 'Ñ' (rare in ID check logic) is given value 33 in MX law,
  # but standard regex `A-Z` covers standard A-Z 26 letter english alphabet chars.
  defp curp_value(c) do
    if Regex.match?(~r/\d/, c) do
      String.to_integer(c)
    else
      <<code::utf8>> = c
      code - ?A + 10
    end
  end

  @impl true
  @spec validate_business_rules(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate_business_rules(changeset) do
    amount = get_field(changeset, :requested_amount)
    income = get_field(changeset, :monthly_income)

    cond do
      is_nil(amount) or is_nil(income) ->
        changeset

      Decimal.gt?(amount, Decimal.mult(income, @income_multiplier)) ->
        add_error(changeset, :requested_amount,
          "cannot exceed %{multiplier}× monthly income",
          multiplier: @income_multiplier
        )

      true ->
        changeset
    end
  end

  # -- Risk evaluation --

  @impl true
  @spec evaluate_risk(%Globaltask.CreditApplications.CreditApplication{}) ::
          :approve | :reject | :review | :skip
  def evaluate_risk(%{provider_payload: %{"buro_score" => score}}) do
    cond do
      score >= 650 -> :approve
      score >= 500 -> :review
      true -> :reject
    end
  end

  def evaluate_risk(_app), do: :skip
end
