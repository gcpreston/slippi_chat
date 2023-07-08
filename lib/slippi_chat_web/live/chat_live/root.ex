defmodule SlippiChatWeb.ChatLive.Root do
  use SlippiChatWeb, :live_view

  alias SlippiChat.ChatSessionRegistry
  alias SlippiChat.ChatSessions.{ChatSession, Message}
  alias SlippiChatWeb.{Endpoint, Presence}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mb-3">
      <p>User: <%= @player_code %></p>
      <div :if={@chat_session_pid}>
        <p>Chat session players:</p>
        <ul>
          <li :for={player_code <- @player_codes}>
            <%= player_code %> <span :if={Enum.member?(@online_codes, player_code)}>(online)</span>
          </li>
        </ul>
      </div>

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
    socket = assign(socket, :player_code, player_code)

    if connected?(socket) do
      player_topic = ChatSession.topic(player_code)
      Endpoint.subscribe(player_topic)
      Endpoint.subscribe("clients")
    end

    socket =
      with {:ok, pid} when is_pid(pid) <- ChatSessionRegistry.lookup(ChatSessionRegistry, player_code),
          player_codes when is_list(player_codes) <- ChatSession.get_current_session_player_codes(pid)
      do
        messages = ChatSession.list_messages(pid)
        online_codes = online_players(player_codes)

        socket
        |> assign(:chat_session_pid, pid)
        |> assign(:player_codes, player_codes)
        |> assign(:online_codes, online_codes || [])
        |> stream(:messages, messages)
      else
        _ ->
          socket
          |> assign(:chat_session_pid, nil)
          |> assign(:player_codes, nil)
          |> assign(:online_codes, [])
          |> stream(:messages, [])
      end

    {:ok, socket}
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
  def handle_info({[:session, :start], {player_codes, pid}}, socket) do
    topic = ChatSession.topic(player_codes)
    Endpoint.subscribe(topic)

    {:noreply,
     socket
     |> assign(:chat_session_pid, pid)
     |> assign(:player_codes, player_codes)
     |> assign(:online_codes, Presence.list("clients") |> Map.keys())
     |> assign(:session_topic, topic)}
  end

  def handle_info({[:session, :end], _result}, socket) do
    Endpoint.unsubscribe(socket.assigns.session_topic)

    {:noreply,
     socket
     |> assign(:chat_session_pid, nil)
     |> assign(:player_codes, nil)
     |> assign(:online_codes, [])
     |> assign(:session_topic, nil)}
  end

  def handle_info({[:session, :message], new_message}, socket) do
    {:noreply, socket |> stream_insert(:messages, new_message)}
  end

  # TODO: Create connect/disconnect events via handle_metas rather than fetching from presence here
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", topic: "clients", payload: _payload}, socket) do
    if socket.assigns.chat_session_pid do
      {:noreply, socket |> assign(:online_codes, online_players(socket.assigns.player_codes))}
    else
      {:noreply, socket}
    end
  end

  defp online_players(player_codes) do
    Enum.reduce(player_codes, [], fn player_code, acc ->
      case Presence.get_by_key("clients", player_code) do
        [] -> acc
        _ -> [player_code | acc]
      end
    end)
  end

  defp translate_code(player_code) do
    String.replace(player_code, "-", "#")
    |> String.upcase()
  end
end
