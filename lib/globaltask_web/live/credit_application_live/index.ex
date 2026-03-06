defmodule GlobaltaskWeb.CreditApplicationLive.Index do
  use GlobaltaskWeb, :live_view

  alias Globaltask.CreditApplications

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Globaltask.PubSub, "credit_applications")
    end

    socket =
      socket
      |> assign(:filters, %{country: "", status: ""})
      |> stream(:applications, [])

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    filters = %{
      country: params["country"] || "",
      status: params["status"] || ""
    }

    socket =
      socket
      |> assign(:filters, filters)

    {:noreply, fetch_applications(socket)}
  end

  @impl true
  def handle_event("filter", %{"filters" => filters}, socket) do
    # Push patch to the URL, which triggers handle_params
    {:noreply, push_patch(socket, to: ~p"/?#{filters}")}
  end

  @impl true
  def handle_info({:new_application, app}, socket) do
    if matches_filters?(app, socket.assigns.filters) do
      # Stream insert at position 0, keeping only 50 elements in DOM
      {:noreply, stream_insert(socket, :applications, app, at: 0, limit: 50)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:application_updated, app}, socket) do
    if matches_filters?(app, socket.assigns.filters) do
      # Updates an existing row
      {:noreply, stream_insert(socket, :applications, app)}
    else
      # If it no longer matches current filters, it deletes itself from UI stream
      {:noreply, stream_delete(socket, :applications, app)}
    end
  end

  defp fetch_applications(socket) do
    clean_filters =
      socket.assigns.filters
      |> Enum.reject(fn {_, v} -> v == "" end)
      |> Map.new(fn {k, v} -> {to_string(k), v} end)
      |> Map.put("page_size", 50)

    %{data: applications} = CreditApplications.list_applications(clean_filters)

    stream(socket, :applications, applications, reset: true)
  end

  defp matches_filters?(app, filters) do
    (filters.country == "" or app.country == filters.country) and
    (filters.status == "" or app.status == filters.status)
  end
end
