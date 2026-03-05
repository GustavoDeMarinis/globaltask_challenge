defmodule GlobaltaskWeb.FallbackController do
  @moduledoc """
  Handles error tuples returned by controller actions.

  Used via `action_fallback` — translates `{:error, ...}` return values
  into consistent JSON error responses.
  """

  use GlobaltaskWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: GlobaltaskWeb.ErrorJSON)
    |> render(:error, status: 404, message: "Not found")
  end

  def call(conn, {:error, :stale}) do
    conn
    |> put_status(:conflict)
    |> put_view(json: GlobaltaskWeb.ErrorJSON)
    |> render(:error, status: 409, message: "Resource was modified by another request, please retry")
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: GlobaltaskWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  # Catch-all for unexpected error tuples (e.g. from country hooks).
  # Logs the error and returns a generic 500 to avoid leaking internals.
  def call(conn, {:error, reason}) do
    require Logger
    Logger.error("Unhandled error in FallbackController: #{inspect(reason)}")

    conn
    |> put_status(:internal_server_error)
    |> put_view(json: GlobaltaskWeb.ErrorJSON)
    |> render(:error, status: 500, message: "Internal server error")
  end
end
