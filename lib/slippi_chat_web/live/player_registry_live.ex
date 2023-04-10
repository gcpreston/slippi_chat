defmodule SlippiChatWeb.PlayerRegistryLive do
  use SlippiChatWeb, :live_view
  alias SlippiChat.PlayerRegistry

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mb-3">
      PlayerRegistry state: <%= inspect(@player_registry_state) %>
    </div>
    <.button phx-click="refresh">Refresh</.button>
    <.button phx-click="crash-registry">Crash Registry</.button>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> fetch_player_registry_state()}
  end

  @impl true
  def handle_event("refresh", _value, socket) do
    {:noreply, socket |> fetch_player_registry_state()}
  end

  def handle_event("crash-registry", _value, socket) do
    # PlayerRegistry.crash(PlayerRegistry)
    1 / 0
    {:noreply, socket}
  end

  defp fetch_player_registry_state(socket) do
    assign(socket, :player_registry_state, PlayerRegistry.debug(PlayerRegistry))
  end
end
