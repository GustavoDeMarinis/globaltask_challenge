defmodule Globaltask.CountryRules.PT do
  @moduledoc """
  Country-specific validation rules for Portugal (PT).

  - **Document:** NIF — 9 digits with a check digit (weighted sum mod 11).
  - **Business rule:** `requested_amount <= 4 × monthly_income`. Reject if exceeded.
  - **Risk evaluation:** Based on `risk_class` from bank provider:
    - "A" → approve
    - "B" → review
    - "C" → reject
  """

  use Globaltask.CountryRules

  import Ecto.Changeset

  @income_multiplier 4

  @impl true
  @spec required_document_type() :: String.t()
  def required_document_type, do: "NIF"

  @impl true
  @spec validate_document(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate_document(changeset) do
    case get_field(changeset, :document_number) do
      nil -> changeset
      doc_number ->
        if valid_nif?(doc_number) do
          changeset
        else
          add_error(changeset, :document_number, "invalid NIF format or check digit")
        end
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

  # -- Private helpers --

  @spec valid_nif?(String.t()) :: boolean()
  defp valid_nif?(doc_number) do
    trimmed = String.trim(doc_number)

    case Regex.run(~r/^(\d{9})$/, trimmed) do
      [_full, digits_str] ->
        digits = digits_str |> String.graphemes() |> Enum.map(&String.to_integer/1)
        check_digit = List.last(digits)
        body = Enum.take(digits, 8)

        weights = [9, 8, 7, 6, 5, 4, 3, 2]
        weighted_sum = body |> Enum.zip(weights) |> Enum.reduce(0, fn {d, w}, acc -> acc + d * w end)

        remainder = rem(weighted_sum, 11)
        expected = if remainder < 2, do: 0, else: 11 - remainder

        check_digit == expected

      _ ->
        false
    end
  end
end
