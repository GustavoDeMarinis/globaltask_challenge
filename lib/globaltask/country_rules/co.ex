defmodule Globaltask.CountryRules.CO do
  @moduledoc """
  Country-specific validation rules for Colombia (CO).

  - **Document:** Cédula de Ciudadanía (CC) — 6 to 10 digits.
  - **Business rule:** Pass-through (placeholder). Debt-to-income ratio
    validation will be added in Issue #4 when bank provider data is available.
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
    # Placeholder — debt-to-income ratio requires provider data (Issue #4)
    changeset
  end
end
