defmodule SlippiChatWeb.ClientChannelTest do
  use SlippiChatWeb.ChannelCase

  alias SlippiChat.ChatSessionRegistry
  alias SlippiChat.ChatSessions.{ChatSession, Message}
  alias SlippiChatWeb.{Presence, UserSocket, ClientChannel}

  defp chat_session_timeout_ms do
    Application.fetch_env!(:slippi_chat, :chat_session_timeout_ms)
  end

  setup do
    # TODO: Authorize socket on connection rather than channel join
    client_code = "ABC#123"

    {:ok, _reply, socket} =
      UserSocket
      |> socket()
      |> subscribe_and_join(ClientChannel, "clients", %{"client_code" => client_code})

    %{client_code: client_code, socket: socket}
  end

  describe "join" do
    test "tracks via Presence", %{socket: socket1} do
      assert Presence.list("clients") |> Map.keys() == ["ABC#123"]

      {:ok, _reply, _socket2} =
        UserSocket
        |> socket()
        |> subscribe_and_join(ClientChannel, "clients", %{"client_code" => "DEF#456"})

      assert Presence.list("clients") |> Map.keys() == ["ABC#123", "DEF#456"]

      Process.unlink(socket1.channel_pid)
      :ok = close(socket1)

      assert Presence.list("clients") |> Map.keys() == ["DEF#456"]
    end
  end

  describe "game_started event" do
    test "starts a chat session", %{socket: socket, client_code: client_code} do
      assert ChatSessionRegistry.lookup(ChatSessionRegistry, client_code) == :error

      player_codes = [client_code, "XYZ#999"]
      push(socket, "game_started", %{"players" => player_codes})

      assert_push "session_start", ^player_codes
      assert {:ok, _pid} = ChatSessionRegistry.lookup(ChatSessionRegistry, client_code)
    end
  end

  describe "PubSub messages" do
    test "on session end, pushes to channel", %{socket: socket, client_code: client_code}  do
      player_codes = [client_code, "XYZ#999"]
      push(socket, "game_started", %{"players" => player_codes})

      assert_push "session_start", ^player_codes
      Process.sleep(chat_session_timeout_ms() + 50)
      assert_push "session_end", ^player_codes
    end

    test "on chat session message, pushes to socket", %{socket: socket, client_code: client_code}  do
      player_codes = [client_code, "XYZ#999"]

      push(socket, "game_started", %{"players" => player_codes})
      assert_push "session_start", ^player_codes

      {:ok, pid} = ChatSessionRegistry.lookup(ChatSessionRegistry, client_code)
      ChatSession.send_message(pid, client_code, "test message")
      assert_push "session_message", %Message{content: "test message", sender: ^client_code}
    end
  end
end
