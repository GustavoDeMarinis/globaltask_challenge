defmodule GlobaltaskWeb.CreditApplicationLive.Show do
  use GlobaltaskWeb, :live_view

  alias Globaltask.CreditApplications

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Globaltask.PubSub, "credit_application:#{id}")
    end

    case CreditApplications.get_application(id) do
      {:ok, application} ->
        {:ok, assign(socket, :application, application)}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Application not found")
         |> push_navigate(to: "/")}
    end
  end

  @impl true
  def handle_params(_params, _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:application_updated, updated_app}, socket) do
    {:noreply, assign(socket, :application, updated_app)}
  end

  @impl true
  def handle_event("approve", _, socket) do
    case CreditApplications.update_status(socket.assigns.application, "approved") do
      {:ok, updated_app} ->
        {:noreply,
         socket
         |> put_flash(:info, "Application approved successfully")
         |> assign(:application, updated_app)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to approve application")}
    end
  end

  @impl true
  def handle_event("reject", _, socket) do
    case CreditApplications.update_status(socket.assigns.application, "rejected") do
      {:ok, updated_app} ->
        {:noreply,
         socket
         |> put_flash(:info, "Application rejected successfully")
         |> assign(:application, updated_app)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to reject application")}
    end
  end
end
