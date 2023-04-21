# TODO: If this genserver crashes, we need the ETS table to drop
defmodule SlippiChat.ChatSessionRegistry do
  use GenServer

  @pubsub_name SlippiChat.PubSub
  @pubsub_topic "chat_sessions"

  ## ETS
  # This module creates an ETS table, named the same as the GenServer name.
  #
  # Format:
  # - key: player_code
  # - value: {pid, meta}
  #   * where meta: %{players: player_codes, uuid: uuid}

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
  Looks up the chat session pid for `player_code` stored in `server`.

  Returns `{:ok, pid}` if the bucket exists, `:error` otherwise.
  """
  def lookup(server, player_code) do
    case :ets.lookup(server, player_code) do
      [{^player_code, data}] -> {:ok, data}
      [] -> :error
    end
  end

  @doc """
  Ensures there is a chat session for the given `players` in `server`.
  """
  def start_session(server, players) do
    GenServer.call(server, {:start, players})
  end

  ## Server callbacks

  @impl true
  def init(table) do
    names = :ets.new(table, [:named_table, read_concurrency: true])
    refs  = %{}
    {:ok, {names, refs}}
  end

  @impl true
  def handle_call({:start, players}, _from, {names, refs}) do
    # TODO: This feels frail
    [player1 | _rest] = players

    case lookup(names, player1) do
      {:ok, pid} ->
        {:reply, {:ok, pid}, {names, refs}}
      :error ->
        {:ok, pid} = DynamicSupervisor.start_child(SlippiChat.ChatSessionSupervisor, SlippiChat.ChatSessions.ChatSession) |> dbg()
        ref = Process.monitor(pid)
        refs = Map.put(refs, ref, players)

        Enum.each(players, fn player_code ->
          data = {pid, %{players: players, uuid: nil}}
          :ets.insert(names, {player_code, data})
        end)

        {:reply,
          {:ok, pid},
          {names, refs},
          {:continue, {:notify_subscribers, [:session, :start], {players, pid}}}}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, _reason}, {names, refs}) do
    {players, refs} = Map.pop(refs, ref)

    Enum.each(players, fn player_code ->
      :ets.delete(names, player_code)
    end)

    send(SlippiChat.PlayerRegistry, {[:session, :end], {players, pid}})

    {:noreply, {names, refs}, {:continue, {:notify_subscribers, [:session, :end], {players, pid}}}}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_continue({:notify_subscribers, [:session, _action] = event, {players, _pid} = result}, state) do
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
