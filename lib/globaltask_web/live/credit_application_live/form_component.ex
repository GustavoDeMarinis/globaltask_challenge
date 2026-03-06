defmodule GlobaltaskWeb.CreditApplicationLive.FormComponent do
  use GlobaltaskWeb, :live_component

  alias Globaltask.CreditApplications

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form
        for={@form}
        id={@id}
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="space-y-4">
          <.input field={@form[:full_name]} type="text" label="Full Name" phx-debounce="300" />

          <div class="grid grid-cols-2 gap-4">
            <.input
              field={@form[:country]}
              type="select"
              label="Country"
              options={~w(ES PT IT MX CO BR)}
              prompt="Select Country"
            />
            <.input
              field={@form[:document_type]}
              type="select"
              label="Document Type"
              options={~w(DNI NIF CodiceFiscale CURP CC CPF PASSPORT)}
              prompt="Select Type"
            />
          </div>

          <.input
            field={@form[:document_number]}
            type="text"
            label="Document Number"
            phx-debounce="300"
          />

          <div class="grid grid-cols-2 gap-4">
            <.input
              field={@form[:requested_amount]}
              type="number"
              step="0.01"
              label="Requested Amount"
              phx-debounce="300"
            />
            <.input
              field={@form[:monthly_income]}
              type="number"
              step="0.01"
              label="Monthly Income"
              phx-debounce="300"
            />
          </div>

          <.input field={@form[:application_date]} type="date" label="Application Date" />
        </div>

        <div class="mt-6 flex justify-end gap-3">
          <.link navigate={@navigate} class="btn btn-ghost">Cancel</.link>
          <.button phx-disable-with="Saving...">Create Application</.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{application: application} = assigns, socket) do
    # Create an empty changeset mapped to default attrs
    changeset = CreditApplications.CreditApplication.create_changeset(application, %{})

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"credit_application" => application_params}, socket) do
    changeset =
      socket.assigns.application
      |> CreditApplications.CreditApplication.create_changeset(application_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"credit_application" => application_params}, socket) do
    case CreditApplications.create_application(application_params) do
      {:ok, _application} ->
        # The creation function automatically pushes the PubSub event
        {:noreply,
         socket
         |> put_flash(:info, "Application created successfully in the background!")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end
end
