defmodule Globaltask.CreditApplications.CreditApplication do
  @moduledoc """
  Schema for credit applications across multiple countries.

  Uses PostgreSQL ENUM types for `status`, `document_type`, and `country`
  to enforce valid values at the database level while remaining extensible
  via `ALTER TYPE ... ADD VALUE`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @valid_statuses ~w(created pending_review approved rejected)
  @valid_countries ~w(ES PT IT MX CO BR)
  @valid_document_types ~w(DNI CPF CURP NIF CC CodiceFiscale)

  @valid_transitions %{
    "created" => ~w(pending_review rejected),
    "pending_review" => ~w(approved rejected),
    "approved" => [],
    "rejected" => []
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "credit_applications" do
    field :country, :string
    field :full_name, :string
    field :document_type, :string
    field :document_number, :string
    field :requested_amount, :decimal
    field :monthly_income, :decimal
    field :application_date, :date
    field :status, :string, default: "created"
    field :provider_payload, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  @create_fields ~w(country full_name document_type document_number requested_amount monthly_income application_date provider_payload)a
  @create_required ~w(country full_name document_type document_number requested_amount monthly_income application_date)a

  @doc """
  Changeset for creating a new credit application.

  Does NOT cast `status` — it always defaults to `"created"`.
  This prevents callers from setting an arbitrary status on creation.
  """
  def create_changeset(application, attrs) do
    application
    |> cast(attrs, @create_fields)
    |> validate_required(@create_required)
    |> validate_number(:requested_amount, greater_than: 0)
    |> validate_number(:monthly_income, greater_than: 0)
    |> validate_inclusion(:country, @valid_countries)
    |> validate_inclusion(:document_type, @valid_document_types)
    |> unique_constraint([:document_number, :country],
      name: :credit_applications_document_number_country_active_index,
      message: "an active application already exists for this document in this country"
    )
  end

  @doc """
  Changeset for updating the status of an existing credit application.

  Only casts `status` and validates that the transition is allowed.
  """
  def update_status_changeset(application, attrs) do
    application
    |> cast(attrs, [:status])
    |> validate_required([:status])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_status_transition()
  end

  defp validate_status_transition(changeset) do
    case {changeset.data.status, get_change(changeset, :status)} do
      {_current, nil} ->
        changeset

      {current, new} ->
        allowed = Map.get(@valid_transitions, current, [])

        if new in allowed do
          changeset
        else
          add_error(changeset, :status, "cannot transition from %{from} to %{to}",
            from: current,
            to: new
          )
        end
    end
  end

  def valid_statuses, do: @valid_statuses
  def valid_countries, do: @valid_countries
  def valid_document_types, do: @valid_document_types
  def valid_transitions, do: @valid_transitions
end
