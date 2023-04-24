defmodule SlippiChatWeb.ChatLive.Root do
  use SlippiChatWeb, :live_view

  alias SlippiChat.ChatSessionRegistry
  alias SlippiChat.ChatSessions.{ChatSession, Message}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mb-3">
      <ul>
        <li>User: <%= @player_code %></li>
        <li>Chat session: <%= inspect(@players) %></li>
      </ul>

      <%= if @chat_session_pid do %>
        <h3>Chat</h3>
        <div id="chat-log" phx-update="stream">
          <li
            :for={{dom_id, message} <- Enum.reverse(@streams.messages)}
            id={dom_id}
            class="chat-message"
          >
            <%= message.sender %>: <%= message.content %>
          </li>
        </div>
        <.live_component
          module={SlippiChatWeb.ChatLive.Message.Form}
          id={:new}
          sender={@player_code}
          chat_session_pid={@chat_session_pid}
        />
        <div class="mt-3">
          <.button phx-click="disconnect">Disconnect</.button>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def mount(%{"code" => code}, _session, socket) do
    player_code = translate_code(code)

    {pid, players} =
      case ChatSessionRegistry.lookup(ChatSessionRegistry, player_code) do
        :error -> {nil, nil}
        {:ok, %{current_chat_session: nil}} -> {nil, nil}
        {:ok, %{current_chat_session: session_data}} -> {session_data.pid, session_data.players}
      end

    if connected?(socket) do
      # TODO: Module specifically for subscribe functions and notification helpers?
      Phoenix.PubSub.subscribe(SlippiChat.PubSub, "chat_sessions:#{player_code}")

      if pid do
        {:ok, uuid} = ChatSession.get_uuid(pid)
        Phoenix.PubSub.subscribe(SlippiChat.PubSub, "chat_sessions:#{uuid}")
      end
    end

    messages = if pid, do: ChatSession.list_messages(pid), else: []

    {:ok,
     socket
     |> assign(:player_code, player_code)
     |> assign(:chat_session_pid, pid)
     |> assign(:players, players)
     |> stream(:messages, messages)}
  end

  @impl true
  def handle_event("send_message", %{"content" => content}, socket) do
    message = Message.new(content, socket.assigns.player_code)
    ChatSession.send_message(socket.assigns.chat_session_pid, message)
    {:noreply, socket}
  end

  def handle_event("disconnect", _value, socket) do
    # For now, this will just end the session.
    # In the future, I want a way to show not only that the clients are connected,
    # but that the liveviews are connected. Then, "disconnect" would DC the liveview,
    # and the opponent could see that this happened, but still have the chat log.
    ChatSession.end_session(socket.assigns.chat_session_pid)
    {:noreply, socket}
  end

  @impl true
  def handle_info({[:session, :start], {players, pid}}, socket) do
    {:ok, uuid} = ChatSession.get_uuid(pid)
    Phoenix.PubSub.subscribe(SlippiChat.PubSub, "chat_sessions:#{uuid}")

    {:noreply,
     socket
     |> assign(:chat_session_pid, pid)
     |> assign(:players, players)}
  end

  def handle_info({[:session, :end], _result}, socket) do
    {:noreply,
     socket
     |> assign(:chat_session_pid, nil)
     |> assign(:players, nil)}
  end

  def handle_info({[:session, :message], new_message}, socket) do
    {:noreply, socket |> stream_insert(:messages, new_message)}
  end

  defp translate_code(player_code) do
    String.replace(player_code, "-", "#")
    |> String.upcase()
  end
end
