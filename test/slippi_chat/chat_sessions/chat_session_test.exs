defmodule SlippiChat.ChatSessionTest do
  use ExUnit.Case, async: true

  alias SlippiChat.ChatSessions
  alias SlippiChat.ChatSessions.{ChatSession, Message}

  defp chat_session_timeout_ms do
    Application.fetch_env!(:slippi_chat, :chat_session_timeout_ms)
  end

  setup do
    player_codes = ["ALIC#3", "BOB#1"]
    pid = start_supervised!({ChatSession, player_codes})

    %{pid: pid, player_codes: player_codes}
  end

  describe "get_player_codes/1" do
    test "gets player codes of the chat session", %{pid: pid, player_codes: player_codes} do
      assert ChatSession.get_player_codes(pid) == player_codes
    end
  end

  describe "list_messages/1" do
    test "lists all messages of the chat session", %{pid: pid} do
      assert ChatSession.list_messages(pid) == []

      msg1 = Message.new("message1", "ALIC#3")
      msg2 = Message.new("message2", "BOB#1")
      msg3 = Message.new("message3", "ALIC#3")
      msg4 = Message.new("message4", "TEST#123")
      msg5 = Message.new("message5", "TEST#123")

      ChatSession.send_message(pid, msg1)
      ChatSession.send_message(pid, msg2)
      ChatSession.send_message(pid, msg3)
      ChatSession.send_message(pid, msg4)
      ChatSession.send_message(pid, msg5)

      assert ChatSession.list_messages(pid) == [msg5, msg4, msg3, msg2, msg1]
    end
  end

  describe "send_message/2" do
    test "sends a message to the session", %{pid: pid, player_codes: player_codes} do
      topic = ChatSessions.chat_session_topic(player_codes)
      Phoenix.PubSub.subscribe(SlippiChat.PubSub, topic)

      assert ChatSession.list_messages(pid) == []

      message = Message.new("test message", "ALIC#3")
      ChatSession.send_message(pid, message)

      assert ChatSession.list_messages(pid) == [message]

      assert_receive {[:session, :message], ^message}
    end
  end

  describe "reset_timeout/1" do
    test "chat session terminates after inactivity timeout", %{pid: pid} do
      assert Process.alive?(pid)

      Process.sleep(chat_session_timeout_ms() + 10)

      refute Process.alive?(pid)
    end

    test "resets chat session inactivity timeout", %{pid: pid} do
      assert Process.alive?(pid)

      Process.sleep(div(chat_session_timeout_ms(), 2))
      ChatSession.reset_timeout(pid)
      Process.sleep(div(chat_session_timeout_ms(), 2))

      assert Process.alive?(pid)

      Process.sleep(div(chat_session_timeout_ms(), 2))

      refute Process.alive?(pid)
    end
  end

  describe "end_session/1" do
    test "stops the chat session process", %{pid: pid} do
      assert Process.alive?(pid)
      ChatSession.end_session(pid)
      refute Process.alive?(pid)
    end
  end
end
