defmodule HaruWebWeb.Router do
  use HaruWebWeb, :router

  import HaruWebWeb.Plugs.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HaruWebWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :tracking do
    plug :accepts, ["json"]
    plug CORSPlug, origin: ~r/https?:\/\/.*$/, credentials: true, methods: ["POST", "OPTIONS"]
    plug HaruWebWeb.Plugs.TrackingRateLimit
  end

  pipeline :auth_rate_limit do
    plug HaruWebWeb.Plugs.AuthRateLimit
  end

  pipeline :require_auth do
    plug :require_authenticated_user
  end

  pipeline :redirect_if_authed do
    plug :redirect_if_user_is_authenticated
  end

  # Public tracking endpoint
  scope "/api", HaruWebWeb.Api do
    pipe_through :tracking

    post "/collect", CollectController, :create
    options "/collect", CollectController, :options
  end

  # Guest-only GET routes
  scope "/", HaruWebWeb do
    pipe_through [:browser, :redirect_if_authed]

    get "/", PageController, :home
    get "/login", SessionController, :new

    live_session :redirect_if_authenticated,
      on_mount: [{HaruWebWeb.LiveAuth, :redirect_if_authenticated}] do
      live "/register", RegistrationLive, :new
    end
  end

  # Guest-only POST routes — rate limited to block brute force
  scope "/", HaruWebWeb do
    pipe_through [:browser, :redirect_if_authed, :auth_rate_limit]

    post "/login", SessionController, :create
    post "/register", RegistrationController, :create
  end

  # Public shared dashboards — no auth required
  scope "/", HaruWebWeb do
    pipe_through :browser

    live_session :public do
      live "/share/:slug", PublicDashboardLive.Index, :index
    end
  end

  # Authenticated routes
  scope "/", HaruWebWeb do
    pipe_through [:browser, :require_auth]

    delete "/logout", SessionController, :delete

    live_session :require_authenticated_user,
      on_mount: [{HaruWebWeb.LiveAuth, :ensure_authenticated}] do
      live "/dashboard", DashboardLive.Index, :index
      live "/dashboard/:site_id", DashboardLive.Index, :show
      live "/settings", SettingsLive.Index, :index
      live "/sites/:id/settings", SettingsLive.Site, :index
    end

    delete "/sites/:id", SiteController, :delete
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:haru_web, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: HaruWebWeb.Telemetry
    end
  end
end
