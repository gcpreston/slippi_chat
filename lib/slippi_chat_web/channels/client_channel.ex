defmodule SlippiChat.ClientChannel do
  use Phoenix.Channel

  alias SlippiChat.ChatSessionRegistry
  alias SlippiChat.ChatSessions.ChatSession
  alias SlippiChatWeb.{Endpoint, Presence}

  @impl true
  def join("clients", payload, socket) do
    if authorized?(payload) do
      client_code = payload["client_code"]
      # TODO: More refined client tracking so not every LV instance receives every join
      Presence.track(self(), "clients", client_code, %{})

      socket =
        case ChatSessionRegistry.lookup(ChatSessionRegistry, client_code) do
          {:ok, pid} ->
            player_codes = ChatSession.get_current_session_player_codes(pid)

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

  defp authorized?(payload) do
    Map.has_key?(payload, "client_code") && is_binary(payload["client_code"])
  end

  @impl true
  def handle_in("game_started", %{"players" => player_codes}, socket)
      when is_list(player_codes) do
    case ChatSessionRegistry.start_chat_session(ChatSessionRegistry, player_codes) do
      {:already_started, pid} ->
        ChatSession.reset_timeout(pid)
        {:reply, :ok, socket}

      {:ok, pid} ->
        topic = ChatSession.topic(player_codes)
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
  def handle_info({[:session, :end], _result}, socket) do
    push(socket, "session_end", %{})
    {:noreply,
     socket
     |> assign(:current_session_pid, nil)
     |> assign(:current_session_player_codes, nil)}
  end

  def handle_info({[:session, :message], new_message}, socket) do
    push(socket, "session_message", new_message)
    {:noreply, socket}
  end
end
