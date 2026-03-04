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
    field :lock_version, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  @create_fields ~w(country full_name document_type document_number requested_amount monthly_income application_date provider_payload)a
  @create_required ~w(country full_name document_type document_number requested_amount monthly_income application_date)a

  @doc """
  Changeset for creating a new credit application.

  Does NOT cast `status` — it always defaults to `"created"`.
  This prevents callers from setting an arbitrary status on creation.

  Country-specific validations (document format, business rules) are applied
  via `Globaltask.CountryRules.validate/1` after basic field checks.
  """
  @spec create_changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def create_changeset(application, attrs) do
    application
    |> cast(attrs, @create_fields)
    |> validate_required(@create_required)
    |> validate_length(:full_name, max: 255)
    |> validate_length(:document_number, max: 50)
    |> validate_number(:requested_amount, greater_than: 0)
    |> validate_number(:monthly_income, greater_than: 0)
    |> validate_inclusion(:country, @valid_countries)
    |> validate_inclusion(:document_type, @valid_document_types)
    |> Globaltask.CountryRules.validate()
    |> unique_constraint([:document_number, :country],
      name: :credit_applications_document_number_country_active_index,
      message: "an active application already exists for this document in this country"
    )
  end

  @update_fields ~w(full_name document_type document_number requested_amount monthly_income application_date provider_payload)a

  @doc """
  Changeset for updating an existing credit application's fields.

  Does NOT cast `status` or `country` — status changes go through
  `update_status_changeset/2`, and country is immutable after creation.
  Uses optimistic locking via `lock_version`.

  Country-specific validations are re-applied on update to ensure
  consistency if document or financial fields change.
  """
  @spec update_changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def update_changeset(application, attrs) do
    application
    |> cast(attrs, @update_fields)
    |> validate_length(:full_name, max: 255)
    |> validate_length(:document_number, max: 50)
    |> validate_number(:requested_amount, greater_than: 0)
    |> validate_number(:monthly_income, greater_than: 0)
    |> validate_inclusion(:document_type, @valid_document_types)
    |> Globaltask.CountryRules.validate()
    |> unique_constraint([:document_number, :country],
      name: :credit_applications_document_number_country_active_index,
      message: "an active application already exists for this document in this country"
    )
    |> optimistic_lock(:lock_version)
  end

  @doc """
  Changeset for updating the status of an existing credit application.

  Only casts `status` and validates that the transition is allowed.
  Uses optimistic locking via `lock_version` to prevent race conditions.
  """
  @spec update_status_changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def update_status_changeset(application, attrs) do
    application
    |> cast(attrs, [:status])
    |> validate_required([:status])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_status_transition()
    |> optimistic_lock(:lock_version)
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

  @spec valid_statuses() :: [String.t()]
  def valid_statuses, do: @valid_statuses

  @spec valid_countries() :: [String.t()]
  def valid_countries, do: @valid_countries

  @spec valid_document_types() :: [String.t()]
  def valid_document_types, do: @valid_document_types

  @spec valid_transitions() :: %{String.t() => [String.t()]}
  def valid_transitions, do: @valid_transitions
end
