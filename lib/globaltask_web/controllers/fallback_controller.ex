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

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: GlobaltaskWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end
end
