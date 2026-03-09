defmodule GlobaltaskWeb.Router do
  use GlobaltaskWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GlobaltaskWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug GlobaltaskWeb.Plugs.Auth
  end

  pipeline :admin_only do
    plug GlobaltaskWeb.Plugs.RequireRole, ["admin"]
  end

  pipeline :client_or_admin do
    plug GlobaltaskWeb.Plugs.RequireRole, ["admin", "client"]
  end

  scope "/", GlobaltaskWeb do
    pipe_through :browser

    live_session :default, on_mount: {GlobaltaskWeb.UserAuth, :ensure_role} do
      live "/", CreditApplicationLive.Index, :index
      live "/applications/new", CreditApplicationLive.New, :new
      live "/applications/:id", CreditApplicationLive.Show, :show
    end
  end

  scope "/auth", GlobaltaskWeb do
    pipe_through :browser
    get "/impersonate", AuthController, :impersonate
  end

  scope "/api/v1/auth", GlobaltaskWeb do
    pipe_through :api

    post "/token", AuthController, :token
  end

  scope "/api/v1/credit_applications", GlobaltaskWeb.API.V1 do
    pipe_through [:api, :api_auth, :client_or_admin]

    post "/", CreditApplicationController, :create
    get "/:id", CreditApplicationController, :show
    put "/:id", CreditApplicationController, :update
    patch "/:id", CreditApplicationController, :update
  end

  scope "/api/v1/credit_applications", GlobaltaskWeb.API.V1 do
    pipe_through [:api, :api_auth, :admin_only]

    get "/", CreditApplicationController, :index
    patch "/:id/status", CreditApplicationController, :update_status
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:globaltask, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: GlobaltaskWeb.Telemetry
    end
  end
end
