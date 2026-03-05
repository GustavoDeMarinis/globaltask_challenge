defmodule Globaltask.Repo.Migrations.AddApplicationDateIndex do
  use Ecto.Migration

  def change do
    # Create the new composite index including application_date
    create index(:credit_applications, [:country, :status, "application_date DESC"])

    # Drop the old one that used inserted_at instead
    drop_if_exists index(:credit_applications, [:country, :status, "inserted_at DESC"])
  end
end
