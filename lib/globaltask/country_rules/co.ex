defmodule Globaltask.CountryRules.CO do
  @moduledoc """
  Country-specific validation rules for Colombia (CO).

  - **Document:** Cédula de Ciudadanía (CC) — 6 to 10 digits.
  - **Business rule:** Pass-through (placeholder). Debt-to-income ratio
    validation is done via the async risk evaluation pipeline.
  - **Risk evaluation:** Debt-to-income ratio (`total_debt` from provider / `monthly_income`):
    - ≤ 0.3 → approve
    - 0.3–0.4 → review
    - > 0.4 → reject
  """

  use Globaltask.CountryRules

  import Ecto.Changeset

  @cc_regex ~r/^\d{6,10}$/

  @impl true
  @spec required_document_type() :: String.t()
  def required_document_type, do: "CC"

  @impl true
  @spec validate_document(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate_document(changeset) do
    case get_field(changeset, :document_number) do
      nil -> changeset
      doc_number ->
        trimmed = String.trim(doc_number)

        if Regex.match?(@cc_regex, trimmed) do
          changeset
        else
          add_error(changeset, :document_number, "invalid CC format (expected 6–10 digits)")
        end
    end
  end

  @impl true
  @spec validate_business_rules(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate_business_rules(changeset) do
    # Business rules that don't depend on provider data.
    # The debt-to-income ratio rule is implemented in evaluate_risk/1.
    changeset
  end

  # -- Risk evaluation --

  @impl true
  @spec evaluate_risk(%Globaltask.CreditApplications.CreditApplication{}) ::
          :approve | :reject | :review | :skip
  def evaluate_risk(%{
        provider_payload: %{"total_debt" => total_debt_str},
        monthly_income: income
      }) do
    # provider_payload comes from JSON so Decimal values are strings
    total_debt = Decimal.new(total_debt_str)
    ratio = Decimal.div(total_debt, income) |> Decimal.to_float()

    cond do
      ratio <= 0.3 -> :approve
      ratio <= 0.4 -> :review
      true -> :reject
    end
  end

  def evaluate_risk(_app), do: :skip
end
