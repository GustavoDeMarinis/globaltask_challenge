defmodule Globaltask.CreditApplications.AuditLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "credit_application_audit_logs" do
    field :old_status, :string
    field :new_status, :string
    field :actor, :string

    belongs_to :credit_application, Globaltask.CreditApplications.CreditApplication

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [:old_status, :new_status, :actor, :credit_application_id])
    |> validate_required([:new_status, :actor, :credit_application_id])
    # old_status can be nil if it's the very first state (e.g. creation)
  end
end
