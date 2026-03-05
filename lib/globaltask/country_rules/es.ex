defmodule Globaltask.CountryRules.ES do
  @moduledoc """
  Country-specific validation rules for Spain (ES).

  - **Document:** DNI — 8 digits followed by a control letter.
    The letter is computed as `digits rem 23` mapped to `TRWAGMYFPDXBNJZSQVHLCKE`.
  - **Business rule:** If `requested_amount > 50_000`, the application is
    flagged for additional review by forcing the status to `"pending_review"`.
    This uses `Ecto.Changeset.force_change/3` — see `Globaltask.CountryRules`
    moduledoc for rationale.
  """

  use Globaltask.CountryRules

  import Ecto.Changeset

  @dni_control_letters "TRWAGMYFPDXBNJZSQVHLCKE"
  @review_threshold Decimal.new("50000")

  @impl true
  @spec required_document_type() :: String.t()
  def required_document_type, do: "DNI"

  @impl true
  @spec validate_document(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate_document(changeset) do
    case get_field(changeset, :document_number) do
      nil ->
        changeset

      doc_number ->
        if valid_dni?(doc_number) do
          changeset
        else
          add_error(changeset, :document_number, "invalid DNI format or control letter")
        end
    end
  end

  @impl true
  @spec validate_business_rules(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate_business_rules(changeset) do
    case get_field(changeset, :requested_amount) do
      nil ->
        changeset

      amount ->
        if Decimal.gt?(amount, @review_threshold) and is_nil(changeset.data.id) do
          # Only force status on CREATE flow. On updates, the state machine
          # governs transitions — we don't regress an approved app.
          force_change(changeset, :status, "pending_review")
        else
          changeset
        end
    end
  end

  # -- Private helpers --

  @spec valid_dni?(String.t()) :: boolean()
  defp valid_dni?(doc_number) do
    trimmed = String.trim(doc_number)

    case Regex.run(~r/^(\d{8})([A-Z])$/i, trimmed) do
      [_full, digits_str, letter] ->
        expected_letter = expected_control_letter(digits_str)
        String.upcase(letter) == expected_letter

      _ ->
        false
    end
  end

  @spec expected_control_letter(String.t()) :: String.t()
  defp expected_control_letter(digits_str) do
    index = digits_str |> String.to_integer() |> rem(23)
    String.at(@dni_control_letters, index)
  end
end
