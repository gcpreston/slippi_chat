defmodule SlippiChatWeb.ClientChannel do
  use Phoenix.Channel

  alias SlippiChat.ChatSessionRegistry
  alias SlippiChat.ChatSessions.ChatSession

  @impl true
  def join("clients", payload, socket) do
    if authorized?(payload) do
      ChatSessionRegistry.register_client(ChatSessionRegistry, player_code)
      Phoenix.PubSub.subscribe(SlippiChat.PubSub, "chat_sessions:#{player_code}")

      {:ok, socket |> assign(:client_code, payload["client_code"])}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  defp authorized?(payload) do
    Map.has_key?(payload, "client_code") && is_binary(payload["client_code"])
  end

  @impl true
  def terminate(_reason, socket) do
    ChatSessionRegistry.remove_client(ChatSessionRegistry, socket.assigns.client_code)
  end

  @impl true
  def handle_in("game_started", %{"players" => player_codes}, socket)
      when is_list(player_codes) do
    ChatSessionRegistry.game_started(
      ChatSessionRegistry,
      socket.assigns.client_code,
      player_codes
    )

    {:reply, :ok, socket}
  end

  def handle_in("game_ended", _params, socket) do
    ChatSessionRegistry.game_ended(ChatSessionRegistry, socket.assigns.client_code)
    {:reply, :ok, socket}
  end

  @impl true
  def handle_info({[:session, :start], {players, pid}}, socket) do
    {:ok, uuid} = ChatSession.get_uuid(pid)
    Phoenix.PubSub.subscribe(SlippiChat.PubSub, "chat_sessions:#{uuid}")
    push(socket, "session_start", players)

    {:noreply, socket}
  end

  def handle_info({[:session, :end], {players, _pid}}, socket) do
    push(socket, "session_end", players)
    {:noreply, socket}
  end

  def handle_info({[:session, :message], new_message}, socket) do
    push(socket, "session_message", new_message)
    {:noreply, socket}
  end
end
