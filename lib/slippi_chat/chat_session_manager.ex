defmodule SlippiChat.ChatSessionManager do
  @moduledoc """
  A GenServer to keep track of chat sessions between users.
  """
  use GenServer

  # TODO: Share types
  @type player_code :: String.t()
  @type game :: list(player_code())

  @type t :: %__MODULE__{
          sessions: %{player_code() => game()}
        }

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

  ## Callbacks

  @impl true
  def init(_) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call({:session_start, game}, _from, state) do
    additions = Enum.reduce(game, %{}, fn player_code, acc -> Map.put(acc, player_code, game) end)
    new_sessions = Map.merge(state.sessions, additions)

    {:reply, :ok, %{state | sessions: new_sessions}}
  end

  def handle_call({:session_end, game}, _from, state) do
    new_sessions = Map.drop(state.sessions, game)

    {:reply, :ok, %{state | sessions: new_sessions}}
  end

  def handle_call(:list, _from, state) do
    {:reply,
     state.sessions
     |> Map.values()
     |> Enum.uniq(), state}
  end
end
