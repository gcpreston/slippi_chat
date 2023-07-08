defmodule SlippiChat.ChatSessionRegistryTest do
  use ExUnit.Case, async: false

  alias SlippiChat.{ChatSessions, ChatSessionRegistry}
  alias SlippiChat.ChatSessions.ChatSession

  @registry_name __MODULE__

  setup do
    pid = start_supervised!({ChatSessionRegistry, name: @registry_name})
    %{pid: pid}
  end

  describe "start_chat_session/2" do
    test "starts a chat session between the given players and broadcasts to player topics", %{pid: registry_pid} do
      Phoenix.PubSub.subscribe(SlippiChat.PubSub, ChatSessions.player_topic("ALIC#3"))
      Phoenix.PubSub.subscribe(SlippiChat.PubSub, ChatSessions.player_topic("BOB#1"))
      Phoenix.PubSub.subscribe(SlippiChat.PubSub, ChatSessions.player_topic("CARL#4"))

      player_codes = ["ALIC#3", "BOB#1"]
      {:ok, session_pid} = ChatSessionRegistry.start_chat_session(registry_pid, player_codes)

      assert ChatSession.get_player_codes(session_pid) == player_codes
      assert_receive {[:session, :start], {^player_codes, pid}}
      assert_receive {[:session, :start], {^player_codes, pid}}
    end

    test "doesn't start multiple sessions with the same players", %{pid: registry_pid} do
      assert {:ok, _pid} = ChatSessionRegistry.start_chat_session(registry_pid, ["ALIC#2", "ALIC#3", "BOB#1"])
      assert {:already_started, _pid} = ChatSessionRegistry.start_chat_session(registry_pid, ["BOB#1", "ALIC#2", "ALIC#3"])
    end

    test "ends existing sessions with participating players", %{pid: registry_pid} do
      {:ok, session1_pid} = ChatSessionRegistry.start_chat_session(registry_pid, ["ALIC#3", "BOB#1"])
      {:ok, session2_pid} = ChatSessionRegistry.start_chat_session(registry_pid, ["CARL#4", "DAVE#7"])
      {:ok, session3_pid} = ChatSessionRegistry.start_chat_session(registry_pid, ["X#1", "Y#2"])
      Process.monitor(session1_pid)
      Process.monitor(session2_pid)
      Process.monitor(session3_pid)

      assert Process.alive?(session1_pid)
      assert Process.alive?(session2_pid)

      {:ok, session4_pid} = ChatSessionRegistry.start_chat_session(registry_pid, ["ALIC#3", "DAVE#7"])

      assert Process.alive?(session4_pid)
      assert_receive {:DOWN, _ref, :process, ^session1_pid, :normal}
      assert_receive {:DOWN, _ref, :process, ^session2_pid, :normal}
      refute_receive {:DOWN, _ref, :process, ^session3_pid, :normal}
    end
  end

  describe "lookup/2" do
    test "finds session pid for a player code", %{pid: registry_pid} do
      {:ok, session_pid} = ChatSessionRegistry.start_chat_session(registry_pid, ["ALIC#3", "BOB#1"])

      assert ChatSessionRegistry.lookup(@registry_name, "ALIC#3") == {:ok, session_pid}
      assert ChatSessionRegistry.lookup(@registry_name, "BOB#1") == {:ok, session_pid}
      assert ChatSessionRegistry.lookup(@registry_name, "CARL#4") == :error
    end
  end
end
