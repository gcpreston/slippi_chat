defmodule SlippiChat.PlayerRegistry do
  use GenServer

  require Logger

  @type player_code :: String.t()

  # A player code is a code representing a unique player, in the format CODE#123
  #
  # A %PlayerRegistry{} is a struct with the following fields:
  # - player_codes: a MapSet of player codes representing clients currently online
  # - player_data: a Map of each client's player code to its Metadata
  #
  # A %Metadata{} is a struct with the following fields:
  # - current_game: a list of the player codes of the client's current game

  defmodule Metadata do
    defstruct current_game: nil

    def set_current_game(metadata, game) do
      %{metadata | current_game: game}
    end
  end

  defstruct player_codes: MapSet.new(), player_data: %{}

  ## API
  # TODO: notify_subscribers

  def start_link(opts \\ [name: __MODULE__]) do
    server_name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, [], name: server_name)
  end

  def debug(server) do
    GenServer.call(server, :debug)
  end

  def register(server, player_code) do
    GenServer.call(server, {:register, player_code})
  end

  def remove(server, player_code) do
    GenServer.call(server, {:remove, player_code})
  end

  @spec game_started(GenServer.name(), player_code(), list(player_code())) :: :ok
  def game_started(server, client_code, player_codes) do
    GenServer.call(server, {:game_started, client_code, player_codes})
  end

  @spec game_ended(GenServer.name(), player_code()) :: :ok
  def game_ended(server, client_code) do
    GenServer.call(server, {:game_ended, client_code})
  end

  ## Callbacks

  @impl true
  def init(initial_codes) do
    {:ok, %__MODULE__{player_codes: MapSet.new(initial_codes)}}
  end

  @impl true
  def handle_call(
        {:register, code},
        _from,
        %{player_codes: player_codes, player_data: data} = state
      ) do
    new_state = %{
      state
      | player_codes: MapSet.put(player_codes, code),
        player_data: Map.put(data, code, %Metadata{})
    }

    Logger.debug("Registered #{code}")

    {:reply, :ok, new_state}
  end

  def handle_call(
        {:remove, code},
        _from,
        %{player_codes: player_codes, player_data: player_data} = state
      ) do
    new_state = %{
      state
      | player_codes: MapSet.delete(player_codes, code),
        player_data: Map.delete(player_data, code)
    }

    Logger.debug("Removed #{code}")

    {:reply, :ok, new_state}
  end

  def handle_call(
        {:game_started, client_code, player_codes},
        _from,
        %{player_data: player_data} = state
      ) do
    new_metadata = Metadata.set_current_game(player_data[client_code], player_codes)
    new_player_data = Map.replace(player_data, client_code, new_metadata)
    new_state = %{state | player_data: new_player_data}
    Logger.debug("Game started for client #{client_code}: #{inspect(player_codes)}")

    {:reply, :ok, new_state}
  end

  def handle_call({:game_ended, client_code}, _from, %{player_data: player_data} = state) do
    new_metadata = Metadata.set_current_game(player_data[client_code], nil)
    new_player_data = Map.replace(player_data, client_code, new_metadata)
    new_state = %{state | player_data: new_player_data}
    Logger.debug("Game ended for client #{client_code}")

    {:reply, :ok, new_state}
  end

  # -----

  # TODO: For development
  def handle_call(:debug, _from, state) do
    {:reply, state, state}
  end

  def handle_call(req, _from, state) do
    IO.inspect(req, label: "got unhandled request")
    IO.inspect(state, label: "State")

    {:reply, :ok, state}
  end
end
