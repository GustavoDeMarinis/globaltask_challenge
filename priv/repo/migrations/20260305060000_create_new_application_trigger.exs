defmodule Mccap.Repo.Migrations.CreateNewApplicationTrigger do
  use Ecto.Migration

  def up do
    # PG function that sends a notification with the new application's ID.
    # This is the "native database capability" required by §3.7.
    execute """
    CREATE OR REPLACE FUNCTION notify_new_application()
    RETURNS TRIGGER AS $$
    BEGIN
      PERFORM pg_notify('new_credit_application', NEW.id::text);
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    # Fire after every INSERT on credit_applications.
    execute """
    CREATE TRIGGER credit_application_after_insert
    AFTER INSERT ON credit_applications
    FOR EACH ROW EXECUTE FUNCTION notify_new_application();
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS credit_application_after_insert ON credit_applications;"
    execute "DROP FUNCTION IF EXISTS notify_new_application();"
  end
end
