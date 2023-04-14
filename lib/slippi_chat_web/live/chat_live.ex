defmodule SlippiChatWeb.ChatLive do
  use SlippiChatWeb, :live_view
  alias SlippiChat.{ChatSessions, ChatSessionManager}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mb-3">
      <ul>
        <li>User: <%= @player_code %></li>
        <li>Chat session: <%= inspect(@chat_session) %></li>
      </ul>
    </div>
    """
  end

  @impl true
  def mount(%{"code" => code}, _session, socket) do
    player_code = translate_code(code)
    chat_session = ChatSessionManager.get(ChatSessionManager, player_code)

    if connected?(socket) do
      ChatSessions.subscribe()
    end

    {:ok,
      socket
      |> assign(:player_code, player_code)
      |> assign(:chat_session, chat_session)
      |> stream(:messages, [])}
  end

  @impl true
  def handle_info({ChatSessions, [:session, :start], _game}, socket) do
    chat_session = ChatSessionManager.get(ChatSessionManager, socket.assigns.player_code)
    {:noreply, socket |> assign(:chat_session, chat_session)}
  end

  def handle_info({ChatSessions, [:session, :end], _game}, socket) do
    chat_session = ChatSessionManager.get(ChatSessionManager, socket.assigns.player_code)
    {:noreply, socket |> assign(:chat_session, chat_session)}
  end

  defp translate_code(player_code) do
    String.replace(player_code, "-", "#")
    |> String.upcase()
  end
end
