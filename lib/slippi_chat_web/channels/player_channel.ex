defmodule SlippiChat.PlayerChannel do
  use Phoenix.Channel

  require Logger

  alias SlippiChat.PlayerRegistry

  def join("players:" <> player_code, _payload, socket) do
    PlayerRegistry.register(PlayerRegistry, player_code)
    {:ok, socket |> assign(:player_code, player_code)}
  end

  def terminate(_reason, socket) do
    PlayerRegistry.remove(PlayerRegistry, socket.assigns.player_code)
  end

  def handle_in("game_started", %{"client" => client_code, "players" => player_codes}, socket)
      when is_list(player_codes) do
    PlayerRegistry.game_started(PlayerRegistry, client_code, player_codes)
    {:reply, :ok, socket}
  end

  def handle_in("game_ended", %{"client" => client_code}, socket) do
    PlayerRegistry.game_ended(PlayerRegistry, client_code)
    {:reply, :ok, socket}
  end
end
