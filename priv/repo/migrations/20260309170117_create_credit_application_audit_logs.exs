defmodule Mccap.Repo.Migrations.CreateCreditApplicationAuditLogs do
  use Ecto.Migration

  def change do
    create table(:credit_application_audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :old_status, :string
      add :new_status, :string, null: false
      add :actor, :string, null: false
      add :credit_application_id, references(:credit_applications, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(updated_at: false)
    end

    create index(:credit_application_audit_logs, [:credit_application_id])
    create index(:credit_application_audit_logs, [:inserted_at])
  end
end
