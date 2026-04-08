defmodule Mccap.Repo.Migrations.FixPartialUniqueIndexExcludeApproved do
  use Ecto.Migration

  @doc """
  Narrows the partial unique index to only block duplicate applications that
  are still in-progress (created or pending_review).

  Previously, approved applications also blocked new ones, which would prevent
  a customer from applying for a second credit after their first was approved.
  """

  def up do
    execute "DROP INDEX credit_applications_document_number_country_active_index"

    execute """
    CREATE UNIQUE INDEX credit_applications_document_number_country_active_index
    ON credit_applications (document_number, country)
    WHERE status IN ('created', 'pending_review')
    """
  end

  def down do
    execute "DROP INDEX credit_applications_document_number_country_active_index"

    execute """
    CREATE UNIQUE INDEX credit_applications_document_number_country_active_index
    ON credit_applications (document_number, country)
    WHERE status != 'rejected'
    """
  end
end
