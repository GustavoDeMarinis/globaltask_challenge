defmodule GlobaltaskWeb.CreditApplicationLive.New do
  use GlobaltaskWeb, :live_view

  alias Globaltask.CreditApplications.CreditApplication

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :application, %CreditApplication{})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      New Credit Application
      <:subtitle>Enter the applicant's details below. Validation happens in real-time.</:subtitle>
    </.header>

    <div class="mt-6 max-w-2xl bg-base-100 border border-base-200 rounded-lg p-6 shadow-sm">
      <.live_component
        module={GlobaltaskWeb.CreditApplicationLive.FormComponent}
        id="new-application-form"
        application={@application}
        action={:new}
        navigate={~p"/"}
      />
    </div>
    """
  end
end
