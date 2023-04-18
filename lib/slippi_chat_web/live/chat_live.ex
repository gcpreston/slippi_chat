defmodule SlippiChatWeb.ChatLive do
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
          <li id={dom_id} :for={{dom_id, message} <- @streams.messages} class="chat-message">
            <%= message.player_code %>: <%= message.content %>
          </li>
        </div>
        <span>
          <input type="text" id="chat-input" />
          <button phx-click="send_message" phx-value-content="hello world!">Send</button>
        </span>
      <% end %>
    </div>
    """
  end

  @impl true
  def mount(%{"code" => code}, _session, socket) do
    player_code = translate_code(code)

    {pid, players} =
      case ChatSessionRegistry.lookup(ChatSessionRegistry, player_code) do
        {:ok, {pid, %{players: players}}} -> {pid, players}
        :error -> {nil, nil}
      end
      |> dbg()

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
    IO.inspect(new_message, label: "LV got message")
    {:noreply, socket |> stream_insert(:messages, new_message) |> IO.inspect()}
  end

  defp translate_code(player_code) do
    String.replace(player_code, "-", "#")
    |> String.upcase()
  end
end
