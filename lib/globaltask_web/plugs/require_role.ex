defmodule GlobaltaskWeb.Plugs.RequireRole do
  @moduledoc """
  Plug to guard endpoints based on the `conn.assigns.role`.
  Must be plugged after `GlobaltaskWeb.Plugs.Auth`.
  """
  import Plug.Conn

  def init(roles) when is_list(roles), do: roles
  def init(role), do: [role]

  def call(conn, roles) do
    role = conn.assigns[:role]

    if role in roles do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> Phoenix.Controller.json(%{errors: %{detail: "Forbidden: insufficient permissions"}})
      |> halt()
    end
  end
end
