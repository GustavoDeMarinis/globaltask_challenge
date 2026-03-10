defmodule Globaltask.Repo.Migrations.AddCronRecoveryPartialIndex do
  use Ecto.Migration

  @disable_ddl_transaction true

  def up do
    # Using raw SQL for the partial JSONB equality condition
    execute """
    CREATE INDEX IF NOT EXISTS credit_applications_stale_recovery_idx
    ON credit_applications (inserted_at)
    WHERE status = 'created' AND provider_payload = '{}'::jsonb;
    """
  end

  def down do
    execute "DROP INDEX IF NOT EXISTS credit_applications_stale_recovery_idx;"
  end
end
