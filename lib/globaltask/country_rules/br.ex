defmodule Globaltask.CountryRules.BR do
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
    Regex.match?(~r/^\d{11}$/, trimmed)
  end

  # -- Risk evaluation --

  @impl true
  @spec evaluate_risk(%Globaltask.CreditApplications.CreditApplication{}) ::
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
