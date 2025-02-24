defmodule SlippiChatWeb.ChatLive.Root do
  use SlippiChatWeb, :live_view

  alias SlippiChat.{ChatSessions, ChatSessionRegistry}
  alias SlippiChat.ChatSessions.ChatSession
  alias SlippiChatWeb.{Endpoint, Presence}

  import SlippiChatWeb.ChatLive.Components

  defp chat_session_registry do
    Application.fetch_env!(:slippi_chat, :chat_session_registry)
  end

  defmodule ChatSessionData do
    @moduledoc """
    Chat session state that the LiveView cares about.
    """
    defstruct [:pid, :player_codes, :topic]

    @type t :: %__MODULE__{
            pid: pid(),
            player_codes: [String.t()],
            topic: String.t()
          }

    def new(pid, player_codes, topic) do
      %__MODULE__{pid: pid, player_codes: player_codes, topic: topic}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= unless @chat_session_data do %>
      <div class="italic text-center">No chat session in progress.</div>
    <% else %>
      <div class="flex flex-col sm:flex-row h-full">
        <div class="sm:w-60 border p-2">
          <.header>Players</.header>
          <ul>
            <li :for={player_code <- @chat_session_data.player_codes}>
              <.player_status
                player_code={player_code}
                online={MapSet.member?(@online_codes, player_code)}
              />
            </li>
          </ul>

          <.header class="mt-8">Actions</.header>
          <div class="mt-2 flex flex-row gap-4">
            <.button phx-click="disconnect">Disconnect</.button>
            <div>
              <.button phx-click="report" disabled={@reported} class="disabled:opacity-75">
                Report
              </.button>
              <.icon :if={@reported} name="hero-check" class="w-4 h-4 font-bold" />
            </div>
          </div>
        </div>

        <div class="flex-1 h-full flex flex-col border border-l-0">
          <.header class="p-2">Chat</.header>
          <div class="flex-1 flex flex-col-reverse overflow-auto">
            <ul id="chat-log" phx-update="stream" class="divide-y">
              <li :for={{dom_id, message} <- @streams.messages} id={dom_id} class="chat-message px-1">
                <span class="font-semibold"><%= message.sender %>:</span> <%= message.content %>
              </li>
            </ul>
          </div>
          <div class="flex flex-row">
            <.live_component
              module={SlippiChatWeb.ChatLive.Message.Form}
              id={:new}
              sender={@current_player_code}
              chat_session_pid={@chat_session_data.pid}
            />
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    code = socket.assigns.current_user.connect_code
    player_code = SlippiChatWeb.Utils.game_player_code(code)

    socket =
      socket
      |> assign(:current_player_code, player_code)

    if connected?(socket) do
      player_topic = ChatSessions.player_topic(player_code)
      Endpoint.subscribe(player_topic)
      Endpoint.subscribe("clients")
    end

    socket =
      with {:ok, pid} when is_pid(pid) <-
             ChatSessionRegistry.lookup(chat_session_registry(), player_code),
           player_codes when is_list(player_codes) <- ChatSession.get_player_codes(pid) do
        chat_session_topic = ChatSessions.chat_session_topic(player_codes)
        chat_session_data = ChatSessionData.new(pid, player_codes, chat_session_topic)
        messages = Enum.reverse(ChatSession.list_messages(pid))
        online_codes = MapSet.new(online_players(player_codes))

        if connected?(socket) do
          Endpoint.subscribe(chat_session_topic)
        end

        socket
        |> assign(:chat_session_data, chat_session_data)
        |> assign(:online_codes, online_codes)
        |> assign(:reported, false)
        |> stream(:messages, messages)
      else
        _ ->
          socket
          |> assign(:chat_session_data, nil)
          |> assign(:online_codes, MapSet.new())
          |> assign(:reported, false)
          |> stream(:messages, [])
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("send_message", %{"content" => content}, socket) do
    ChatSession.send_message(
      socket.assigns.chat_session_data.pid,
      socket.assigns.player_code,
      content
    )

    {:noreply, socket}
  end

  def handle_event("disconnect", _value, socket) do
    # For now, this will just end the session.
    # In the future, I want a way to show not only that the clients are connected,
    # but that the liveviews are connected. Then, "disconnect" would DC the liveview,
    # and the opponent could see that this happened, but still have the chat log.
    ChatSession.end_session(socket.assigns.chat_session_data.pid)
    {:noreply, socket}
  end

  def handle_event("report", _value, socket) do
    %{pid: chat_session_pid, player_codes: player_codes} = socket.assigns.chat_session_data

    if length(player_codes) == 2 do
      reporter = socket.assigns.current_player_code
      opponent = Enum.find(player_codes, fn code -> code != reporter end)
      ChatSession.report(chat_session_pid, reporter, opponent)

      {:noreply, assign(socket, :reported, true)}
    end
  end

  @impl true
  def handle_info({[:session, :start], {player_codes, pid}}, socket) do
    if socket.assigns.chat_session_data != nil do
      Endpoint.unsubscribe(socket.assigns.chat_session_data.topic)
    end

    topic = ChatSessions.chat_session_topic(player_codes)
    Endpoint.subscribe(topic)

    messages = Enum.reverse(ChatSession.list_messages(pid))
    chat_session_data = ChatSessionData.new(pid, player_codes, topic)

    {:noreply,
     socket
     |> assign(:chat_session_data, chat_session_data)
     |> assign(:online_codes, online_players(player_codes))
     |> stream(:messages, messages, reset: true)}
  end

  def handle_info({[:session, :end], {_player_codes, pid}}, socket) do
    if socket.assigns.chat_session_data.pid == pid do
      Endpoint.unsubscribe(socket.assigns.chat_session_data.topic)

      {:noreply,
       socket
       |> assign(:chat_session_data, nil)
       |> assign(:online_codes, MapSet.new())
       |> stream(:messages, [], reset: true)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({[:session, :message], new_message}, socket) do
    {:noreply, socket |> stream_insert(:messages, new_message)}
  end

  def handle_info({SlippiChat.PresenceClient, {:join, %{player_code: player_code}}}, socket) do
    if player_code == socket.assigns.current_player_code ||
         (socket.assigns.chat_session_data &&
            Enum.member?(socket.assigns.chat_session_data.player_codes, player_code)) do
      {:noreply, socket |> update(:online_codes, fn codes -> MapSet.put(codes, player_code) end)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({SlippiChat.PresenceClient, {:leave, %{player_code: player_code}}}, socket) do
    {:noreply, socket |> update(:online_codes, fn codes -> MapSet.delete(codes, player_code) end)}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    {:noreply, socket}
  end

  defp online_players(player_codes) do
    Enum.reduce(player_codes, MapSet.new(), fn player_code, acc ->
      if player_code_is_online?(player_code) do
        MapSet.put(acc, player_code)
      else
        acc
      end
    end)
  end

  defp player_code_is_online?(player_code) do
    Presence.get_by_key("clients", player_code) != []
  end
end
