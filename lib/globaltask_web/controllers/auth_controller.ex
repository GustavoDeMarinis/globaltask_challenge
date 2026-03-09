defmodule GlobaltaskWeb.AuthController do
  use GlobaltaskWeb, :controller

  @moduledoc """
  Simulated authentication endpoint for the MVP.
  Issues a valid JWT for testing the API security layer.
  """

  def token(conn, %{"role" => role}) when role in ["admin", "client"] do
    token = GlobaltaskWeb.Token.sign!(%{"role" => role})
    json(conn, %{data: %{token: token, role: role}})
  end

  def token(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{errors: %{detail: "Invalid or missing role. Must be 'admin' or 'client'."}})
  end

  @doc """
  Sets an encrypted session cookie to impersonate a role in the LiveView browser UI.
  """
  def impersonate(conn, %{"role" => "admin"}) do
    conn
    |> put_session(:current_role, "admin")
    |> put_flash(:info, "Impersonation active. You are now operating as an Admin.")
    |> redirect(to: ~p"/")
  end

  def impersonate(conn, _params) do
    conn
    |> delete_session(:current_role)
    |> put_flash(:info, "Impersonation cleared. You are back to regular client mode.")
    |> redirect(to: ~p"/")
  end
end
