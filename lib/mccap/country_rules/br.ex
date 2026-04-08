defmodule Mccap.CountryRules.BR do
  @moduledoc """
  Country-specific validation rules for Brazil (BR).

  - **Document:** CPF — 11 digits with two modular arithmetic check digits.
    Rejects all-same-digit CPFs (e.g. `11111111111`) which pass the algorithm
    but are invalid in practice.
  - **Business rule:** `requested_amount <= 5 × monthly_income` (capacity).
  - **Risk evaluation:** Based on `serasa_score` from bank provider:
    - ≥ 600 → approve
    - 400–599 → review
    - < 400 → reject
  """

  use Mccap.CountryRules

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
    # Remove formatting (., -) and trim whitespace
    clean_cpf = String.replace(doc_number, ~r/[^\d]/, "")

    cond do
      # Must be exactly 11 digits
      String.length(clean_cpf) != 11 ->
        false

      # Reject known invalid sequences that pass the mathematical check (e.g. 11111111111)
      all_same_digits?(clean_cpf) ->
        false

      true ->
        digits =
          clean_cpf
          |> String.graphemes()
          |> Enum.map(&String.to_integer/1)

        [d1, d2, d3, d4, d5, d6, d7, d8, d9, check1, check2] = digits

        # Calculate first check digit (weights 10 down to 2)
        sum1 =
          d1 * 10 + d2 * 9 + d3 * 8 + d4 * 7 + d5 * 6 + d6 * 5 + d7 * 4 + d8 * 3 + d9 * 2

        rem1 = rem(sum1 * 10, 11)
        expected_check1 = if rem1 == 10, do: 0, else: rem1

        # Calculate second check digit (weights 11 down to 2)
        sum2 =
          d1 * 11 + d2 * 10 + d3 * 9 + d4 * 8 + d5 * 7 + d6 * 6 + d7 * 5 + d8 * 4 + d9 * 3 +
            expected_check1 * 2

        rem2 = rem(sum2 * 10, 11)
        expected_check2 = if rem2 == 10, do: 0, else: rem2

        check1 == expected_check1 and check2 == expected_check2
    end
  end

  defp all_same_digits?(cpf) do
    first_char = String.at(cpf, 0)
    String.duplicate(first_char, 11) == cpf
  end

  # -- Risk evaluation --

  @impl true
  @spec evaluate_risk(%Mccap.CreditApplications.CreditApplication{}) ::
          :approve | :reject | :review | :skip
  def evaluate_risk(%{provider_payload: %{"serasa_score" => score}}) do
    cond do
      score >= 600 -> :approve
      score >= 400 -> :review
      true -> :reject
    end
  end

  def evaluate_risk(_app), do: :skip
end
