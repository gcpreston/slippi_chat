defmodule SlippiChat.ChatSessionManager do
  @moduledoc """
  A GenServer to keep track of chat sessions between users.
  """
  use GenServer

  alias SlippiChat.ChatSessions

  require Logger

  # TODO: Share types
  @type player_code :: String.t()
  @type game :: list(player_code())

  @type t :: %__MODULE__{
          sessions: %{player_code() => game()}
        }

  @topic inspect(__MODULE__)

  defstruct sessions: %{}

  @spec start_link(name: GenServer.name()) :: GenServer.on_start()
  def start_link(opts \\ [name: __MODULE__]) do
    server_name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, [], name: server_name)
  end

  @spec session_start(GenServer.name(), game()) :: :ok
  def session_start(server, game) do
    GenServer.call(server, {:session_start, game})
  end

  @spec session_end(GenServer.name(), game()) :: :ok
  def session_end(server, game) do
    GenServer.call(server, {:session_end, game})
  end

  @spec list(GenServer.name()) :: [game()]
  def list(server) do
    GenServer.call(server, :list)
  end

  @spec get(GenServer.name(), player_code()) :: game() | nil
  def get(server, code) do
    GenServer.call(server, {:get, code})
  end

  ## Callbacks

  @impl true
  def init(_) do
    ChatSessions.subscribe()
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call(:list, _from, state) do
    {:reply,
     state.sessions
     |> Map.values()
     |> Enum.uniq(), state}
  end

  def handle_call({:get, code}, _from, state) do
    {:reply, state.sessions[code], state}
  end

  @impl true
  def handle_info({ChatSessions, [:session, :start], game}, state) do
    additions = Enum.reduce(game, %{}, fn player_code, acc -> Map.put(acc, player_code, game) end)
    new_sessions = Map.merge(state.sessions, additions)
    Logger.debug("Session started for game: #{inspect(game)}")

    {:noreply, %{state | sessions: new_sessions}}
  end

  def handle_info({ChatSessions, [:session, :end], game}, state) do
    new_sessions = Map.drop(state.sessions, game)
    Logger.debug("Session removed for game: #{inspect(game)}")

    {:noreply, %{state | sessions: new_sessions}}
  end

  ## Helpers

  defp topic(player_code) when is_binary(player_code) do
    "#{@topic}:#{player_code}"
  end
end
