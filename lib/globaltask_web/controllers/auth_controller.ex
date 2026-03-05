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
end
