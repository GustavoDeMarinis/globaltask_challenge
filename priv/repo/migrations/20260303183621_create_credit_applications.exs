defmodule Globaltask.Repo.Migrations.CreateCreditApplications do
  use Ecto.Migration

  def up do
    # Create ENUM types
    execute "CREATE TYPE credit_application_status AS ENUM ('created', 'pending_review', 'approved', 'rejected')"
    execute "CREATE TYPE document_type AS ENUM ('DNI', 'CPF', 'CURP', 'NIF', 'CC', 'CodiceFiscale')"
    execute "CREATE TYPE country_code AS ENUM ('ES', 'PT', 'IT', 'MX', 'CO', 'BR')"

    create table(:credit_applications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :country, :country_code, null: false
      add :full_name, :string, null: false
      add :document_type, :document_type, null: false
      add :document_id, :string, null: false
      add :requested_amount, :decimal, precision: 15, scale: 2, null: false
      add :monthly_income, :decimal, precision: 15, scale: 2, null: false
      add :application_date, :date, null: false
      add :status, :credit_application_status, null: false, default: "created"
      add :provider_payload, :map, default: %{}, null: false

      timestamps(type: :utc_datetime)
    end

    # Single-column indexes for common filters
    create index(:credit_applications, [:country])
    create index(:credit_applications, [:status])
    create index(:credit_applications, [:inserted_at])
    create index(:credit_applications, [:document_id])

    # Composite index for the most common paginated list query:
    # SELECT ... WHERE country = ? AND status = ? ORDER BY inserted_at DESC
    execute """
    CREATE INDEX credit_applications_country_status_inserted_at_index
    ON credit_applications (country, status, inserted_at DESC)
    """

    # Partial unique index: prevents duplicate active applications per person per country,
    # but allows re-application after rejection.
    execute """
    CREATE UNIQUE INDEX credit_applications_document_id_country_active_index
    ON credit_applications (document_id, country)
    WHERE status != 'rejected'
    """
  end

  def down do
    drop table(:credit_applications)

    execute "DROP TYPE credit_application_status"
    execute "DROP TYPE document_type"
    execute "DROP TYPE country_code"
  end
end
