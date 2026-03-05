defmodule Globaltask.CountryRules.MX do
  @moduledoc """
  Country-specific validation rules for Mexico (MX).

  - **Document:** CURP — 18 characters matching
    `^[A-Z]{4}\\d{6}[HM][A-Z]{5}[A-Z0-9]\\d$`.
  - **Business rule:** `requested_amount <= 3 × monthly_income`. Reject if exceeded.
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
        trimmed = String.trim(doc_number)

        if Regex.match?(@curp_regex, trimmed) do
          changeset
        else
          add_error(changeset, :document_number, "invalid CURP format")
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
end
