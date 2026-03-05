defmodule GlobaltaskWeb.API.V1.CreditApplicationController do
  @moduledoc """
  REST controller for credit applications.

  All error handling is delegated to `FallbackController`.
  """

  use GlobaltaskWeb, :controller

  alias Globaltask.CreditApplications

  action_fallback GlobaltaskWeb.FallbackController

  def create(conn, params) do
    with {:ok, app} <- CreditApplications.create_application(params) do
      conn
      |> put_status(:created)
      |> render(:show, credit_application: app, role: conn.assigns[:role])
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, app} <- CreditApplications.get_application(id) do
      render(conn, :show, credit_application: app, role: conn.assigns[:role])
    end
  end

  def index(conn, params) do
    result = CreditApplications.list_applications(params)
    render(conn, :index, result: result, role: conn.assigns[:role])
  end

  def update(conn, %{"id" => id} = params) do
    attrs = Map.drop(params, ["id"])

    with {:ok, app} <- CreditApplications.get_application(id),
         {:ok, updated_app} <- CreditApplications.update_application(app, attrs) do
      render(conn, :show, credit_application: updated_app, role: conn.assigns[:role])
    end
  end

  def update_status(conn, %{"id" => id, "status" => status}) do
    with {:ok, app} <- CreditApplications.get_application(id),
         {:ok, updated_app} <- CreditApplications.update_status(app, status) do
      render(conn, :show, credit_application: updated_app, role: conn.assigns[:role])
    end
  end

  def update_status(conn, %{"id" => _id}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: GlobaltaskWeb.ErrorJSON)
    |> render(:error, status: 422, message: "Missing required field: status")
  end
end
