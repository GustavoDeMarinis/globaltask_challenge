defmodule Globaltask.Repo.Migrations.AddLockVersionToCreditApplications do
  use Ecto.Migration

  def change do
    alter table(:credit_applications) do
      add :lock_version, :integer, default: 0, null: false
    end
  end
end
