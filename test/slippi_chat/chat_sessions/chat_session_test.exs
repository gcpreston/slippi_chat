defmodule SlippiChat.ChatSessionTest do
  use ExUnit.Case, async: true

  alias SlippiChat.ChatSessionRegistry
  alias SlippiChat.ChatSessions.{ChatSession, Message}

  @registry_name __MODULE__

  setup do
    start_supervised!({ChatSessionRegistry, name: @registry_name})

    :ok = ChatSessionRegistry.register_client(@registry_name, "ALIC#3")
    :ok = ChatSessionRegistry.register_client(@registry_name, "BOB#1")

    :ok = ChatSessionRegistry.game_started(@registry_name, "ALIC#3", ["ALIC#3", "BOB#1"])
    {:ok, session_pid} = ChatSessionRegistry.game_started(@registry_name, "BOB#1", ["ALIC#3", "BOB#1"])

    %{pid: session_pid}
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
    test "sends a message to the session", %{pid: pid} do
      {:ok, uuid} = ChatSession.get_uuid(pid)
      Phoenix.PubSub.subscribe(SlippiChat.PubSub, "chat_sessions:#{uuid}")

      assert ChatSession.list_messages(pid) == []

      message = Message.new("test message", "ALIC#3")
      ChatSession.send_message(pid, message)

      assert ChatSession.list_messages(pid) == [message]

      assert_receive {[:session, :message], ^message}
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
