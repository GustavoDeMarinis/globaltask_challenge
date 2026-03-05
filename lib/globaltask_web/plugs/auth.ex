defmodule GlobaltaskWeb.Plugs.Auth do
  @moduledoc """
  Plug to verify Bearer JWT tokens in incoming requests.
  """
  import Plug.Conn
  alias GlobaltaskWeb.Token

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- Token.verify!(token) do
      assign(conn, :role, claims["role"])
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{errors: %{detail: "Unauthorized"}})
        |> halt()
    end
  end
end
