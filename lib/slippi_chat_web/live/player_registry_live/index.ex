defmodule SlippiChatWeb.PlayerRegistryLive.Index do
  use SlippiChatWeb, :live_view
  alias SlippiChat.PlayerRegistry

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      PlayerRegistry state: <%= inspect(@player_registry_state) %>
    </div>
    <button phx-click="refresh">Refresh</button>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:player_registry_state, nil)}
  end

  @impl true
  def handle_event("refresh", _value, socket) do
    state = PlayerRegistry.debug(PlayerRegistry)
    {:noreply, assign(socket, :player_registry_state, state)}
  end
end
