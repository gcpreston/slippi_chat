# TODO: If this genserver crashes, we need the ETS table to drop
defmodule SlippiChat.ChatSessionRegistry do
  use GenServer

  alias SlippiChat.ChatSessions.ChatSession

  require Logger

  @pubsub_name SlippiChat.PubSub
  @pubsub_topic "chat_sessions"

  @moduledoc """
  This module creates an ETS table, named the same as the GenServer name.
  The ETS table is a mapping of player code to information about the current
  state of the player.

  Format:

  player_code => %{
    current_game: list(player_code),
    current_chat_session: %{
      pid: pid()
      players: list(player_code),
      uuid: uuid()
    }
  }
  """

  ## Client API

  @doc """
  Starts the registry with the given options.

  `:name` is always required.
  """
  def start_link(opts) do
    server = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, server, opts)
  end

  @doc """
  Looks up the metadata for `player_code` stored in `server`.

  Returns `{:ok, data}` if the bucket exists, `:error` otherwise.
  """
  def lookup(server, player_code) do
    case :ets.lookup(server, player_code) do
      [{^player_code, data}] -> {:ok, data}
      [] -> :error
    end
  end

  @doc """
  Ensure the client code is registered in the server.
  """
  def register_client(server, client_code) do
    GenServer.call(server, {:register_client, client_code})
  end

  @doc """
  Ensure the client code is not registered in the server.
  """
  def remove_client(server, client_code) do
    GenServer.call(server, {:remove_client, client_code})
  end

  @doc """
  Handle a game being started for a client. Starts or stops sessions accordingly.
  """
  def game_started(server, client_code, players) do
    GenServer.call(server, {:game_started, client_code, players})
  end

  @doc """
  Handle a game ending for a client.
  """
  def game_ended(server, client_code) do
    GenServer.call(server, {:game_ended, client_code})
  end

  ## Server callbacks

  @impl true
  def init(table) do
    players_ets = :ets.new(table, [:named_table, read_concurrency: true])
    refs = %{}
    {:ok, {players_ets, refs}}
  end

  @impl true
  def handle_call({:register_client, client_code}, _from, {players_ets, _refs} = state) do
    if lookup(players_ets, client_code) == :error do
      data = %{current_game: nil, current_chat_session: nil}
      :ets.insert(players_ets, {client_code, data})
    end

    {:reply, :ok, state}
  end

  def handle_call({:remove_client, client_code}, _from, {players_ets, _refs} = state) do
    with {:ok, data} <- lookup(players_ets, client_code) do
      :ets.delete(players_ets, client_code)

      with %{current_chat_session: %{pid: pid}} <- data do
        ChatSession.end_session(pid)
      end
    end

    {:reply, :ok, state}
  end

  def handle_call({:game_started, client_code, players}, _from, {players_ets, refs}) do
    Logger.debug("Game started for client #{client_code}: #{inspect(players)}")
    update_client_data(players_ets, client_code, players)
    player_data = get_player_data(players_ets, players)
    stop_old_sessions(player_data, players)

    if should_start_session(player_data, client_code, players) do
      {pid, new_refs} = start_session(players_ets, refs, player_data, players)

      {:reply, {:ok, pid}, {players_ets, new_refs},
       {:continue, {:notify_subscribers, [:session, :start], {players, pid}}}}
    else
      {:reply, :ok, {players_ets, refs}}
    end
  end

  def handle_call({:game_ended, client_code}, _from, {players_ets, _refs} = state) do
    Logger.debug("Game ended for client #{client_code}")

    with {:ok, data} <- lookup(players_ets, client_code) do
      new_data = put_in(data.current_game, nil)
      :ets.insert(players_ets, {client_code, new_data})
    end

    {:reply, :ok, state}
  end

  defp get_player_data(players_ets, players) do
    Enum.reduce(players, %{}, fn player_code, acc ->
      case lookup(players_ets, player_code) do
        {:ok, data} -> Map.put(acc, player_code, data)
        :error -> Map.put(acc, player_code, nil)
      end
    end)
  end

  defp update_client_data(players_ets, client_code, players) do
    {:ok, %{current_chat_session: client_chat_session}} = lookup(players_ets, client_code)
    new_client_data = %{current_game: players, current_chat_session: client_chat_session}
    :ets.insert(players_ets, {client_code, new_client_data})
  end

  defp stop_old_sessions(player_data, players) do
    Enum.each(players, fn player_code ->
      with data when not is_nil(data) <- player_data[player_code],
           %{current_chat_session: %{pid: pid, players: current_session_players}} <- data do
        if Process.alive?(pid) && current_session_players != players do
          ChatSession.end_session(pid)
        end
      end
    end)
  end

  defp should_start_session(player_data, client_code, players) do
    if get_in(player_data, [client_code, :current_chat_session, :players]) != players do
      Enum.all?(players, fn player_code ->
        with data when not is_nil(data) <- player_data[player_code] do
          %{current_game: current_game} = data
          current_game == players
        end
      end)
    else
      false
    end
  end

  defp start_session(players_ets, refs, player_data, players) do
    {:ok, pid} =
      DynamicSupervisor.start_child(
        SlippiChat.ChatSessionSupervisor,
        SlippiChat.ChatSessions.ChatSession
      )

    ref = Process.monitor(pid)
    new_refs = Map.put(refs, ref, players)

    Enum.each(players, fn player_code ->
      if data = player_data[player_code] do
        # TODO: uuid
        data = put_in(data.current_chat_session, %{pid: pid, players: players, uuid: nil})
        :ets.insert(players_ets, {player_code, data})
      end
    end)

    {pid, new_refs}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, _reason}, {players_ets, refs}) do
    {players, refs} = Map.pop(refs, ref)

    Enum.each(players, fn player_code ->
      with {:ok, data} <- lookup(players_ets, player_code) do
        new_data = Map.put(data, :current_chat_session, nil)
        :ets.insert(players_ets, {player_code, new_data})
      end
    end)

    {:noreply, {players_ets, refs},
     {:continue, {:notify_subscribers, [:session, :end], {players, pid}}}}
  end

  @impl true
  def handle_continue(
        {:notify_subscribers, [:session, _action] = event, {players, _pid} = result},
        state
      ) do
    Enum.each(players, fn player_code ->
      Phoenix.PubSub.broadcast(
        @pubsub_name,
        topic(player_code),
        {event, result}
      )
    end)

    {:noreply, state}
  end

  defp topic(player_code) when is_binary(player_code) do
    "#{@pubsub_topic}:#{player_code}"
  end
end
