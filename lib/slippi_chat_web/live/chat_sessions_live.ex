defmodule SlippiChatWeb.ChatSessionsLive do
  use SlippiChatWeb, :live_view
  alias SlippiChat.ChatSessionManager

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mb-3">
      <h1>Chat sessions:</h1>

      <ul>
        <li :for={game <- @games}><%= inspect(game) %></li>
      </ul>
    </div>
    <.button phx-click="refresh">Refresh</.button>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> fetch_sessions()}
  end

  @impl true
  def handle_event("refresh", _value, socket) do
    {:noreply, socket |> fetch_sessions()}
  end

  defp fetch_sessions(socket) do
    assign(socket, :games, ChatSessionManager.list(ChatSessionManager))
  end
end
