defmodule GlobaltaskWeb.PageController do
  use GlobaltaskWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
