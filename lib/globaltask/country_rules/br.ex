defmodule Globaltask.CountryRules.BR do
  @moduledoc """
  Country-specific validation rules for Brazil (BR).

  - **Document:** CPF — 11 digits with two modular arithmetic check digits.
    Rejects all-same-digit CPFs (e.g. `11111111111`) which pass the algorithm
    but are invalid in practice.
  - **Business rule:** `requested_amount <= 5 × monthly_income` (capacity).
    Credit score validation deferred to Issue #4 with bank provider data.
  """

  use Globaltask.CountryRules

  import Ecto.Changeset

  @income_multiplier 5

  @impl true
  @spec required_document_type() :: String.t()
  def required_document_type, do: "CPF"

  @impl true
  @spec validate_document(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate_document(changeset) do
    case get_field(changeset, :document_number) do
      nil -> changeset
      doc_number ->
        if valid_cpf?(doc_number) do
          changeset
        else
          add_error(changeset, :document_number, "invalid CPF format or check digits")
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

  @spec valid_cpf?(String.t()) :: boolean()
  defp valid_cpf?(doc_number) do
    trimmed = String.trim(doc_number)

    case Regex.run(~r/^(\d{11})$/, trimmed) do
      [_full, digits_str] ->
        digits = digits_str |> String.graphemes() |> Enum.map(&String.to_integer/1)

        not all_same?(digits) and
          check_digit_valid?(digits, 9) and
          check_digit_valid?(digits, 10)

      _ ->
        false
    end
  end

  @spec all_same?(list()) :: boolean()
  defp all_same?([first | rest]), do: Enum.all?(rest, &(&1 == first))

  @spec check_digit_valid?([integer()], integer()) :: boolean()
  defp check_digit_valid?(digits, position) do
    weights = for i <- (position + 1)..2//-1, do: i
    body = Enum.take(digits, position)

    sum = body |> Enum.zip(weights) |> Enum.reduce(0, fn {d, w}, acc -> acc + d * w end)
    remainder = rem(sum * 10, 11)
    expected = if remainder == 10, do: 0, else: remainder

    Enum.at(digits, position) == expected
  end
end
