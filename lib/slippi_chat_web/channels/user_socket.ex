defmodule SlippiChatWeb.UserSocket do
  use Phoenix.Socket

  require Logger
  alias SlippiChat.Auth

  ## Channels
  channel "clients", SlippiChatWeb.ClientChannel

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  @impl true
  def connect(params, socket) do
    with token when not is_nil(token) <- params["client_token"],
         client_code when not is_nil(client_code) <-
           Auth.get_client_code_by_client_token(token) do
      Logger.info("Socket connected for #{client_code}")
      {:ok, assign(socket, :client_code, client_code)}
    else
      _ -> :error
    end
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     SlippiChatWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.client_code}"
end
