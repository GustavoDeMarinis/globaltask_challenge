defmodule Globaltask.CountryRules.IT do
  @moduledoc """
  Country-specific validation rules for Italy (IT).

  - **Document:** Codice Fiscale — 16 alphanumeric characters matching
    `^[A-Z]{6}\\d{2}[A-Z]\\d{2}[A-Z]\\d{3}[A-Z]$`.
  - **Business rule:** `monthly_income >= 800`. Reject if below.
  """

  use Globaltask.CountryRules

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
        trimmed = String.trim(doc_number)

        if Regex.match?(@codice_fiscale_regex, trimmed) do
          changeset
        else
          add_error(changeset, :document_number, "invalid Codice Fiscale format")
        end
    end
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
end
