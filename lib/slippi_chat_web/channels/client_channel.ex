defmodule SlippiChatWeb.ClientChannel do
  use Phoenix.Channel

  alias SlippiChat.{ChatSessions, ChatSessionRegistry}
  alias SlippiChat.ChatSessions.ChatSession
  alias SlippiChatWeb.{Endpoint, Presence}

  defp chat_session_registry do
    Application.fetch_env!(:slippi_chat, :chat_session_registry)
  end

  @impl true
  def join("clients", _payload, socket) do
    if authorized?(socket) do
      client_code = socket.assigns.client_code
      Endpoint.subscribe(ChatSessions.player_topic(client_code))
      # TODO: More refined client tracking so not every LV instance receives every join
      Presence.track(socket, client_code, %{})

      socket =
        case ChatSessionRegistry.lookup(chat_session_registry(), client_code) do
          {:ok, pid} ->
            player_codes = ChatSession.get_player_codes(pid)

            socket
            |> assign(:client_code, client_code)
            |> assign(:current_session_pid, pid)
            |> assign(:current_session_player_codes, player_codes)

          :error ->
            socket
            |> assign(:client_code, client_code)
            |> assign(:current_session_pid, nil)
            |> assign(:current_session_player_codes, nil)
        end

      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  defp authorized?(socket) do
    Map.has_key?(socket.assigns, :client_code) && is_binary(socket.assigns.client_code)
  end

  @impl true
  def handle_in("game_started", %{"players" => player_codes}, socket)
      when is_list(player_codes) do
    case ChatSessionRegistry.start_chat_session(chat_session_registry(), player_codes) do
      {:already_started, _pid} ->
        {:reply, :ok, socket}

      {:ok, pid} ->
        topic = ChatSessions.chat_session_topic(player_codes)
        Endpoint.subscribe(topic)

        push(socket, "session_start", player_codes)

        {:reply, :ok,
         socket
         |> assign(:current_session_pid, pid)
         |> assign(:current_session_player_codes, player_codes)}
    end
  end

  def handle_in("game_ended", _params, socket) do
    {:reply, :ok, socket}
  end

  @impl true
  def handle_info({[:session, :end], {player_codes, _pid}}, socket) do
    topic = ChatSessions.chat_session_topic(player_codes)
    Endpoint.unsubscribe(topic)

    push(socket, "session_end", player_codes)

    {:noreply,
     socket
     |> assign(:current_session_pid, nil)
     |> assign(:current_session_player_codes, nil)}
  end

  def handle_info({[:session, :message], message}, socket) do
    push(socket, "session_message", message)
    {:noreply, socket}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end
end
