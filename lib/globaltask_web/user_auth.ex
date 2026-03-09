defmodule GlobaltaskWeb.UserAuth do
  @moduledoc """
  Authentication hooks for the LiveView UI.
  Reads the securely signed HTTP session cookie and transfers it to the
  websocket assigns during the initial HTTP handshake and subsequent WS connections.
  """
  import Phoenix.Component

  def on_mount(:ensure_role, _params, session, socket) do
    role = Map.get(session, "current_role", "client")

    {:cont, assign(socket, :current_role, role)}
  end
end
