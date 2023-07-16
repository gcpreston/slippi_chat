defmodule SlippiChat.ChatSessionRegistry do
  @moduledoc """
  This module creates an ETS table, named the same as the GenServer name.

  Format: player code => chat session PID
  """

  use GenServer

  alias SlippiChat.ChatSessions
  alias SlippiChat.ChatSessions.ChatSession

  require Logger

  ## Client API

  @doc """
  Starts the registry with the given options.

  `:name` is always required.
  """
  def start_link(opts) do
    server_name = Keyword.fetch!(opts, :name)
    supervisor = Keyword.get(opts, :supervisor, SlippiChat.ChatSessionSupervisor)
    GenServer.start_link(__MODULE__, {server_name, supervisor}, name: server_name)
  end

  @doc """
  Looks up the chat session for `player_code` stored in `server`.

  Returns `{:ok, pid}` if the entry exists, `:error` otherwise.
  """
  def lookup(server, player_code) do
    case :ets.lookup(server, player_code) do
      [{^player_code, pid}] -> {:ok, pid}
      [] -> :error
    end
  end

  @doc """
  Lists all active chat sessions by player codes and pid.
  """
  @spec list_chat_sessions() :: [{[String.t()], pid()}]
  def list_chat_sessions do
    :global.registered_names()
    |> Enum.filter(fn name -> match?({ChatSession, player_codes} when is_list(player_codes), name) end)
    |> Enum.map(fn {ChatSession, player_codes} = name -> {player_codes, :global.whereis_name(name)} end)
  end

  def start_chat_session(server, player_codes) do
    GenServer.call(server, {:start_chat_session, player_codes})
  end

  ## Callbacks

  @impl true
  def init({table_name, supervisor}) do
    players_ets = :ets.new(table_name, [:named_table, read_concurrency: true])
    refs = %{}
    {:ok, {supervisor, players_ets, refs}}
  end

  @impl true
  def handle_call({:start_chat_session, player_codes}, _from, {supervisor, players_ets, refs} = state) do
    case DynamicSupervisor.start_child(supervisor, {ChatSession, player_codes}) do
      {:error, {:already_started, pid}} ->
        {:reply, {:already_started, pid}, state}

      {:ok, pid} ->
        ref = Process.monitor(pid)
        new_refs = Map.put(refs, ref, player_codes)

        end_existing_sessions(players_ets, player_codes)

        Enum.each(player_codes, fn player_code ->
          :ets.insert(players_ets, {player_code, pid})
        end)

        Logger.info("Chat session started for players #{inspect(player_codes)}")

        {:reply, {:ok, pid}, {supervisor, players_ets, new_refs},
         {:continue, {:notify_subscribers, [:session, :start], {player_codes, pid}}}}
    end
  end

  defp end_existing_sessions(players_ets, player_codes) when is_list(player_codes) do
    Enum.each(player_codes, &(end_existing_session(players_ets, &1)))
  end

  defp end_existing_session(players_ets, player_code) when is_binary(player_code) do
    with {:ok, pid} <- lookup(players_ets, player_code) do
      if Process.alive?(pid), do: ChatSession.end_session(pid)
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, down_pid, reason}, {supervisor, players_ets, refs}) do
    {player_codes, refs} = Map.pop(refs, ref)
    Logger.info("Registry got DOWN, player codes: #{inspect(player_codes)}, reason: #{inspect(reason)}")

    Enum.each(player_codes, fn player_code ->
      with {:ok, result_pid} <- lookup(players_ets, player_code) do
        if result_pid == down_pid do
          :ets.delete(players_ets, player_code)
        end
      end
    end)

    {:noreply, {supervisor, players_ets, refs},
     {:continue, {:notify_subscribers, [:session, :end], {player_codes, down_pid}}}}
  end

  @impl true
  def handle_continue(
        {:notify_subscribers, [:session, _action] = event, {player_codes, _pid} = result},
        state
      ) do
    Enum.each(player_codes, fn player_code ->
      Phoenix.PubSub.broadcast(
        SlippiChat.PubSub,
        ChatSessions.player_topic(player_code),
        {event, result}
      )
    end)

    {:noreply, state}
  end
end
