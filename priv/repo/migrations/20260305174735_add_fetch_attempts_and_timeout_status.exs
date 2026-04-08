defmodule Mccap.Repo.Migrations.AddFetchAttemptsAndTimeoutStatus do
  use Ecto.Migration

  @disable_ddl_transaction true

  def up do
    # Add the new status enum value if the type exists
    # Requires @disable_ddl_transaction true
    execute "ALTER TYPE credit_application_status ADD VALUE IF NOT EXISTS 'provider_timeout';"

    alter table(:credit_applications) do
      add :fetch_attempts, :integer, default: 0, null: false
    end
  end

  def down do
    alter table(:credit_applications) do
      remove :fetch_attempts
    end
    # Note: PostgreSQL does not support dropping a value from an ENUM type easily
  end
end
