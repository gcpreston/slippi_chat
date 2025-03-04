defmodule SlippiChatWeb.Router do
  use SlippiChatWeb, :router

  import SlippiChatWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {SlippiChatWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_current_user
  end

  scope "/", SlippiChatWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/", SlippiChatWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{SlippiChatWeb.UserAuth, :ensure_authenticated}] do
      live "/chat", ChatLive.Root, :index
    end

    live_session :require_granter_user,
      on_mount: [
        {SlippiChatWeb.UserAuth, :ensure_authenticated},
        {SlippiChatWeb.UserAuth, :ensure_granter_status}
      ] do
      live "/create_token", CreateTokenLive, :new
    end
  end

  ## Authentication routes

  scope "/", SlippiChatWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{SlippiChatWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/log_in", UserLoginLive, :new
      live "/magic_log_in", MagicLoginLive, :new
    end

    post "/log_in", UserSessionController, :create
  end

  scope "/", SlippiChatWeb do
    pipe_through [:browser]

    delete "/log_out", UserSessionController, :delete
  end

  scope "/", SlippiChatWeb do
    pipe_through [:api, :require_authenticated_user]

    post "/magic_generate", MagicLoginController, :generate
    post "/magic_verify", MagicLoginController, :verify
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:slippi_chat, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SlippiChatWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
