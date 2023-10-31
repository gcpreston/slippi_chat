defmodule SlippiChat.ChatSessionsTest do
  use SlippiChat.DataCase, async: true

  alias SlippiChat.Repo
  alias SlippiChat.ChatSessions
  alias SlippiChat.ChatSessions.{Message, Report}

  describe "player_topic/1" do
    test "returns the pubsub topic for a specific player" do
      assert ChatSessions.player_topic("TEST#1") == "chat_sessions:TEST#1"
      assert ChatSessions.player_topic("lower#5") == "chat_sessions:LOWER#5"
    end
  end

  describe "chat_session_topic/1" do
    test "returns the pubsub topic for a list of players" do
      assert ChatSessions.chat_session_topic(["DAN#432", "BILL#747"]) ==
               "chat_sessions:BILL#747,DAN#432"

      assert ChatSessions.chat_session_topic(["X#732", "bob#421", "x#123"]) ==
               "chat_sessions:BOB#421,X#123,X#732"
    end
  end

  describe "create_report!/3" do
    test "creates a report" do
      report =
        ChatSessions.create_report!("ABC#123", "DEF#456", [
          Message.new("ABC#123", "hi"),
          Message.new("DEF#456", "bum")
        ])

      assert report.reporter == "ABC#123"
      assert report.reportee == "DEF#456"
      assert length(report.chat_log) == 2
      assert %{sender: "ABC#123", content: "hi"} = Enum.at(report.chat_log, 0)
      assert %{sender: "DEF#456", content: "bum"} = Enum.at(report.chat_log, 1)
      assert Repo.get(Report, report.id)
    end
  end
end
