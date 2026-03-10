defmodule Globaltask.CountryRules.ES do
  @moduledoc """
  Country-specific validation rules for Spain (ES).

  - **Document:** DNI — 8 digits followed by a control letter.
    The letter is computed as `digits rem 23` mapped to `TRWAGMYFPDXBNJZSQVHLCKE`.
  - **Business rule:** If `requested_amount > 50_000`, the application is
    flagged for additional review by forcing the status to `"pending_review"`.
    This uses `Ecto.Changeset.force_change/3` — see `Globaltask.CountryRules`
    moduledoc for rationale.
  - **Risk evaluation:** Based on `credit_score` from bank provider:
    - ≥ 700 → approve
    - 600–699 → review
    - < 600 → reject
  """

  use Globaltask.CountryRules

  import Ecto.Changeset

  @review_threshold Decimal.new("50000")

  @approve_threshold 700
  @review_min 600

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

  # -- Risk evaluation --

  @impl true
  @spec evaluate_risk(%Globaltask.CreditApplications.CreditApplication{}) ::
          :approve | :reject | :review | :skip
  def evaluate_risk(%{provider_payload: %{"credit_score" => score}}) do
    cond do
      score >= @approve_threshold -> :approve
      score >= @review_min -> :review
      true -> :reject
    end
  end

  def evaluate_risk(_app), do: :skip

  # -- Private helpers --

  @spec valid_dni?(String.t()) :: boolean()
  defp valid_dni?(doc_number) do
    trimmed = String.trim(doc_number)

    if Regex.match?(~r/^[0-9]{8}[A-HJ-NP-TV-Z]$/i, trimmed) do
      # Calculate the DNI control letter
      number_part = String.slice(trimmed, 0..7) |> String.to_integer()
      letter_part = String.slice(trimmed, 8..8) |> String.upcase()

      control_letters = "TRWAGMYFPDXBNJZSQVHLCKE"
      expected_letter = String.at(control_letters, rem(number_part, 23))

      letter_part == expected_letter
    else
      false
    end
  end
end
