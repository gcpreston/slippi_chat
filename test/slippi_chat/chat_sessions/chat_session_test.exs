defmodule SlippiChat.ChatSessionTest do
  use SlippiChat.DataCase, async: false

  alias SlippiChat.Repo
  alias SlippiChat.ChatSessions
  alias SlippiChat.ChatSessions.ChatSession
  alias SlippiChat.ChatSessions.Report

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

      {:ok, msg1} = ChatSession.send_message(pid, "ALIC#3", "message1")
      {:ok, msg2} = ChatSession.send_message(pid, "BOB#1", "message2")
      {:ok, msg3} = ChatSession.send_message(pid, "ALIC#3", "message3")
      {:ok, msg4} = ChatSession.send_message(pid, "TEST#123", "message4")
      {:ok, msg5} = ChatSession.send_message(pid, "TEST#123", "message5")

      assert ChatSession.list_messages(pid) == [msg5, msg4, msg3, msg2, msg1]
    end
  end

  describe "send_message/2" do
    test "sends a message to the session", %{pid: pid, player_codes: player_codes} do
      topic = ChatSessions.chat_session_topic(player_codes)
      Phoenix.PubSub.subscribe(SlippiChat.PubSub, topic)

      assert ChatSession.list_messages(pid) == []

      {:ok, message} = ChatSession.send_message(pid, "ALIC#3", "test message")

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

  describe "report/3" do
    test "creates a report", %{pid: pid} do
      ChatSession.send_message(pid, "ALIC#3", "ur mean")
      ChatSession.send_message(pid, "BOB#1", "no your mean")
      {:ok, report} = ChatSession.report(pid, "BOB#1", "ALIC#3")

      assert report.reportee == "ALIC#3"
      assert report.reporter == "BOB#1"
      assert length(report.chat_log) == 2
      assert %{sender: "ALIC#3", content: "ur mean"} = Enum.at(report.chat_log, 0)
      assert %{sender: "BOB#1", content: "no your mean"} = Enum.at(report.chat_log, 1)
      assert Repo.get(Report, report.id)
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
