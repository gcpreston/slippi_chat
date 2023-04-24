defmodule SlippiChat.ChatSessionRegistryTest do
  use ExUnit.Case, async: true

  alias SlippiChat.ChatSessionRegistry

  @registry_name TestRegistry

  setup do
    pid = start_supervised!({ChatSessionRegistry, name: @registry_name})
    %{pid: pid}
  end

  describe "register_client/2" do
    test "adds a player code to the registry" do
      :error = ChatSessionRegistry.lookup(@registry_name, "ALIC#3")

      :ok = ChatSessionRegistry.register_client(@registry_name, "ALIC#3")
      {:ok, data} = ChatSessionRegistry.lookup(@registry_name, "ALIC#3")
      assert data == %{current_game: nil, current_chat_session: nil}

      :ok = ChatSessionRegistry.register_client(@registry_name, "ALIC#3")
      {:ok, data} = ChatSessionRegistry.lookup(@registry_name, "ALIC#3")
      assert data == %{current_game: nil, current_chat_session: nil}
    end
  end

  describe "remove_client/2" do
    test "removes a player code from the registry" do
      ChatSessionRegistry.register_client(@registry_name, "ALIC#3")
      {:ok, _data} = ChatSessionRegistry.lookup(@registry_name, "ALIC#3")

      :ok = ChatSessionRegistry.remove_client(@registry_name, "ALIC#3")
      :error = ChatSessionRegistry.lookup(@registry_name, "ALIC#3")

      :ok = ChatSessionRegistry.remove_client(@registry_name, "ALIC#3")
      :error = ChatSessionRegistry.lookup(@registry_name, "ALIC#3")
    end

    test "stops an active session for removed client" do
      ChatSessionRegistry.register_client(@registry_name, "ALIC#3")
      ChatSessionRegistry.register_client(@registry_name, "BOB#1")

      Phoenix.PubSub.subscribe(SlippiChat.PubSub, "chat_sessions:ALIC#3")

      :ok = ChatSessionRegistry.game_started(@registry_name, "ALIC#3", ["ALIC#3", "BOB#1"])
      {:ok, pid} = ChatSessionRegistry.game_started(@registry_name, "BOB#1", ["ALIC#3", "BOB#1"])

      assert_receive {[:session, :start], {["ALIC#3", "BOB#1"], ^pid}}

      ChatSessionRegistry.remove_client(@registry_name, "BOB#1")

      assert_receive {[:session, :end], {["ALIC#3", "BOB#1"], ^pid}}
    end
  end

  describe "game_started/3" do
    test "starts a game in the registry" do
      ChatSessionRegistry.register_client(@registry_name, "ALIC#3")
      {:ok, %{current_game: nil}} = ChatSessionRegistry.lookup(@registry_name, "ALIC#3")

      :ok = ChatSessionRegistry.game_started(@registry_name, "ALIC#3", ["ALIC#3", "BOB#1"])

      {:ok, %{current_game: ["ALIC#3", "BOB#1"], current_chat_session: nil}} =
        ChatSessionRegistry.lookup(@registry_name, "ALIC#3")
    end

    test "only affects current_game for the specified client" do
      ChatSessionRegistry.register_client(@registry_name, "ALIC#3")
      ChatSessionRegistry.register_client(@registry_name, "BOB#1")

      :ok = ChatSessionRegistry.game_started(@registry_name, "ALIC#3", ["ALIC#3", "BOB#1"])

      {:ok, %{current_game: nil, current_chat_session: nil}} =
        ChatSessionRegistry.lookup(@registry_name, "BOB#1")
    end

    test "starts a session when all players are in the same game" do
      ChatSessionRegistry.register_client(@registry_name, "ALIC#3")
      ChatSessionRegistry.register_client(@registry_name, "BOB#1")
      ChatSessionRegistry.register_client(@registry_name, "CAT#2")
      ChatSessionRegistry.register_client(@registry_name, "DAVE#4")

      Phoenix.PubSub.subscribe(SlippiChat.PubSub, "chat_sessions:ALIC#3")

      :ok = ChatSessionRegistry.game_started(@registry_name, "ALIC#3", ["ALIC#3", "BOB#1", "CAT#2", "DAVE#4"])
      :ok = ChatSessionRegistry.game_started(@registry_name, "BOB#1", ["ALIC#3", "BOB#1", "CAT#2", "DAVE#4"])
      :ok = ChatSessionRegistry.game_started(@registry_name, "CAT#2", ["ALIC#3", "BOB#1", "CAT#2", "DAVE#4"])
      {:ok, pid} = ChatSessionRegistry.game_started(@registry_name, "DAVE#4", ["ALIC#3", "BOB#1", "CAT#2", "DAVE#4"])

      assert_receive {[:session, :start], {["ALIC#3", "BOB#1", "CAT#2", "DAVE#4"], ^pid}}

      assert_player_data = fn player_code ->
        {:ok, data} = ChatSessionRegistry.lookup(@registry_name, player_code)
        assert data.current_game == ["ALIC#3", "BOB#1", "CAT#2", "DAVE#4"]
        assert data.current_chat_session.players == ["ALIC#3", "BOB#1", "CAT#2", "DAVE#4"]
      end

      Enum.each(["ALIC#3", "BOB#1", "CAT#2", "DAVE#4"], assert_player_data)
    end

    test "stops old sessions when a new session starts" do
      ChatSessionRegistry.register_client(@registry_name, "ALIC#3")
      ChatSessionRegistry.register_client(@registry_name, "BOB#1")
      ChatSessionRegistry.register_client(@registry_name, "CAT#2")
      ChatSessionRegistry.register_client(@registry_name, "DAVE#4")
      ChatSessionRegistry.register_client(@registry_name, "EVE#5")

      Phoenix.PubSub.subscribe(SlippiChat.PubSub, "chat_sessions:ALIC#3")
      Phoenix.PubSub.subscribe(SlippiChat.PubSub, "chat_sessions:CAT#2")

      # Session between ALIC#3 and BOB#1
      :ok = ChatSessionRegistry.game_started(@registry_name, "ALIC#3", ["ALIC#3", "BOB#1"])
      {:ok, pid1} = ChatSessionRegistry.game_started(@registry_name, "BOB#1", ["ALIC#3", "BOB#1"])

      # Session between CAT#2 and DAVE#4
      :ok = ChatSessionRegistry.game_started(@registry_name, "CAT#2", ["CAT#2", "DAVE#4"])
      {:ok, pid2} = ChatSessionRegistry.game_started(@registry_name, "DAVE#4", ["CAT#2", "DAVE#4"])

      # Game start between EVE#5, ALIC#3, and CAT#2
      :ok = ChatSessionRegistry.game_started(@registry_name, "EVE#5", ["ALIC#3", "CAT#2", "EVE#5"])

      # Old sessions for ALIC#3 and CAT#2 are stopped
      assert_receive {[:session, :end], {["ALIC#3", "BOB#1"], ^pid1}}

      {:ok, %{current_game: ["ALIC#3", "BOB#1"], current_chat_session: nil}} =
        ChatSessionRegistry.lookup(@registry_name, "ALIC#3")

      assert_receive {[:session, :end], {["CAT#2", "DAVE#4"], ^pid2}}

      {:ok, %{current_game: ["CAT#2", "DAVE#4"], current_chat_session: nil}} =
        ChatSessionRegistry.lookup(@registry_name, "CAT#2")

      refute Process.alive?(pid1)
      refute Process.alive?(pid2)
    end
  end

  describe "game_ended/2" do
    test "updates a client's current game in the registry" do
      ChatSessionRegistry.register_client(@registry_name, "ALIC#3")

      :ok = ChatSessionRegistry.game_started(@registry_name, "ALIC#3", ["ALIC#3", "BOB#1"])
      {:ok, %{current_game: ["ALIC#3", "BOB#1"]}} = ChatSessionRegistry.lookup(@registry_name, "ALIC#3")

      :ok = ChatSessionRegistry.game_ended(@registry_name, "ALIC#3")
      {:ok, %{current_game: nil}} = ChatSessionRegistry.lookup(@registry_name, "ALIC#3")
    end

    test "only affects current_game for the specified client" do
      ChatSessionRegistry.register_client(@registry_name, "ALIC#3")
      ChatSessionRegistry.register_client(@registry_name, "BOB#1")

      :ok = ChatSessionRegistry.game_started(@registry_name, "ALIC#3", ["ALIC#3", "BOB#1"])
      {:ok, pid} = ChatSessionRegistry.game_started(@registry_name, "BOB#1", ["ALIC#3", "BOB#1"])
      :ok = ChatSessionRegistry.game_ended(@registry_name, "ALIC#3")

      {:ok, %{current_game: ["ALIC#3", "BOB#1"], current_chat_session: %{pid: ^pid}}} =
        ChatSessionRegistry.lookup(@registry_name, "BOB#1")
    end
  end
end
