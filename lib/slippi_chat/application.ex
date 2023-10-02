defmodule SlippiChat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      SlippiChatWeb.Telemetry,
      # Start the Ecto repository
      SlippiChat.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: SlippiChat.PubSub},
      # Start Presence
      SlippiChatWeb.Presence,
      # Start Finch
      {Finch, name: SlippiChat.Finch},
      # Start the Endpoint (http/https)
      SlippiChatWeb.Endpoint,
      # Start a worker by calling: SlippiChat.Worker.start_link(arg)
      # {SlippiChat.Worker, arg}
      {SlippiChat.ChatSessions.Supervisor, name: SlippiChat.ChatSessions.Supervisor},
      {SlippiChat.Auth.MagicAuthenticator, name: SlippiChat.Auth.MagicAuthenticator}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SlippiChat.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SlippiChatWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
