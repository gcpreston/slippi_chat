defmodule SlippiChat.PlayerChannel do
  use Phoenix.Channel

  require Logger

  alias SlippiChat.ChatSessionRegistry

  def join("players:" <> player_code, _payload, socket) do
    ChatSessionRegistry.register_client(ChatSessionRegistry, player_code)
    {:ok, socket |> assign(:client_code, player_code)}
  end

  def terminate(_reason, socket) do
    ChatSessionRegistry.remove_client(ChatSessionRegistry, socket.assigns.client_code)
  end

  def handle_in("game_started", %{"players" => player_codes}, socket)
      when is_list(player_codes) do
    ChatSessionRegistry.game_started(ChatSessionRegistry, socket.assigns.client_code, player_codes)
    {:reply, :ok, socket}
  end

  def handle_in("game_ended", _params, socket) do
    ChatSessionRegistry.game_ended(ChatSessionRegistry, socket.assigns.client_code)
    {:reply, :ok, socket}
  end
end
