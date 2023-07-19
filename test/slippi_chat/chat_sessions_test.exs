defmodule SlippiChat.ChatSessionsTest do
  use ExUnit.Case, async: true

  alias SlippiChat.ChatSessions

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
end
