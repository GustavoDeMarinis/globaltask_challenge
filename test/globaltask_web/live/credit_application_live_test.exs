defmodule GlobaltaskWeb.CreditApplicationLiveTest do
  use GlobaltaskWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Globaltask.CreditApplications

  @valid_es_attrs %{
    "country" => "ES",
    "full_name" => "Juan Perez",
    "document_type" => "DNI",
    "document_number" => "12345678Z",
    "requested_amount" => "1000.00",
    "monthly_income" => "5000.00",
    "application_date" => "2023-01-01"
  }

  @valid_pt_attrs %{
    "country" => "PT",
    "full_name" => "Maria Silva",
    "document_type" => "NIF",
    "document_number" => "123456789",
    "requested_amount" => "1000.00",
    "monthly_income" => "5000.00",
    "application_date" => "2023-01-01"
  }

  describe "Index (Dashboard)" do
    test "lists all applications and updates via PubSub explicitly", %{conn: conn} do
      {:ok, _app1} = CreditApplications.create_application(%{@valid_es_attrs | "full_name" => "Row 1"})

      {:ok, view, html} = live(conn, ~p"/")

      # First, verify the initial load includes our DB fixture
      assert html =~ "Row 1"

      # Then, explicitly simulate another client creating an application
      {:ok, _app2} = CreditApplications.create_application(%{@valid_pt_attrs | "full_name" => "Realtime Row 2"})

      # Since we are the test process and the LiveView runs in another process,
      # we can simply send the PubSub message to the topic it subscribed to.
      # But since the actual create_application pipeline already broadcasts it, we just need to wait
      # for the DOM to update. The fixture helper calls create_application under the hood,
      # which triggers the broadcast!

      # The LiveView Test framework intercepts DOM updates:
      render(view) # flush changes
      assert render(view) =~ "Realtime Row 2"

      # Test filtering
      {:ok, filtered_view, _html} = live(conn, ~p"/?country=ES")

      assert render(filtered_view) =~ "Row 1"
      refute render(filtered_view) =~ "Realtime Row 2"
    end
  end

  describe "New (Form)" do
    test "renders form, validates in real-time, and creates application successfully", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/applications/new")

      assert html =~ "New Credit Application"

      # Test validation errors showing interactively (phx-change)
      # Simulates the user typing invalid data which triggers the debounced validate event
      invalid_attrs = %{@valid_es_attrs | "document_number" => "INVALID"}

      assert view
             |> form("#new-application-form", credit_application: invalid_attrs)
             |> render_change() =~ "invalid"

      # Test successful form submission
      {:error, {:live_redirect, %{to: "/"}}} =
        view
        |> form("#new-application-form", credit_application: @valid_es_attrs)
        |> render_submit()

      # Confirm it really hits the context
      %{data: apps} = CreditApplications.list_applications(%{})
      assert Enum.any?(apps, fn app -> app.document_number == "12345678Z" end)
    end
  end
end
