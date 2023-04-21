defmodule SlippiChat.PlayerRegistry do
  @moduledoc """
  A GenServer to keep track of connected clients and their game states.
  """
  use GenServer

  alias SlippiChat.ChatSessionRegistry
  alias SlippiChat.ChatSessions.ChatSession

  require Logger

  @type player_code :: String.t()
  @type game :: list(player_code())

  # A player code is a code representing a unique player, in the format CODE#123
  #
  # A %PlayerRegistry{} is a struct with the following fields:
  # - player_codes: a MapSet of player codes representing clients currently online
  # - player_data: a Map of each client's player code to its PlayerMetadata
  # - sessions: a Map of client player code to their active session,
  #     where at least 2 clients are active
  #
  # A %PlayerMetadata{} is a struct with the following fields:
  # - current_game: the Game currently in progress for a client
  #
  # A Game is an alpha-numerically sorted list of player codes
  # > A Game represents players in a Slippi game
  #

  defmodule PlayerMetadata do
    @type t :: %__MODULE__{current_game: SlippiChat.PlayerRegistry.game()}

    defstruct current_game: nil

    def set_current_game(metadata, game) do
      %{metadata | current_game: game}
    end
  end

  @type t :: %__MODULE__{
    player_codes: MapSet.t(player_code()),
    player_data: %{player_code() => PlayerMetadata.t()},
    sessions: %{player_code() => game() | nil}
  }

  defstruct player_codes: MapSet.new(), player_data: %{}, sessions: %{}

  defp get_player_metadata(%__MODULE__{} = state, player_code) do
    Map.get(state.player_data, player_code)
  end

  ## API
  # TODO: notify_subscribers

  def start_link(opts \\ [name: __MODULE__]) do
    server_name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, [], name: server_name)
  end

  def debug(server) do
    GenServer.call(server, :debug)
  end

  def crash(server) do
    GenServer.call(server, :crash)
  end

  def register(server, player_code) do
    GenServer.call(server, {:register, player_code})
  end

  def remove(server, player_code) do
    GenServer.call(server, {:remove, player_code})
  end

  @spec game_started(GenServer.name(), player_code(), list(player_code())) :: :ok
  def game_started(server, client_code, player_codes) do
    player_codes = Enum.sort(player_codes)
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
  def handle_info({[:session, :end], {players, _pid}}, state) do
    new_sessions = handle_session_end(state.sessions, players)
    {:noreply, %{state | sessions: new_sessions}}
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
        player_data: Map.put(data, code, %PlayerMetadata{})
    }

    Logger.debug("Registered #{code}")

    {:reply, :ok, new_state}
  end

  def handle_call(
        {:remove, code},
        _from,
        %{player_codes: player_codes, player_data: player_data, sessions: sessions} = state
      ) do
    maybe_current_session = sessions[code]
    new_sessions =
      if maybe_current_session do
        remove_session(sessions, maybe_current_session)
      else
        sessions
      end

    new_state = %{
      state
      | player_codes: MapSet.delete(player_codes, code),
        player_data: Map.delete(player_data, code),
        sessions: new_sessions
    }

    Logger.debug("Removed #{code}")

    {:reply, :ok, new_state}
  end

  def handle_call(
        {:game_started, client_code, game},
        _from,
        %{player_data: player_data, sessions: sessions} = state
      ) do
    new_metadata = PlayerMetadata.set_current_game(player_data[client_code], game)
    new_player_data = Map.replace(player_data, client_code, new_metadata)
    Logger.debug("Game started for client #{client_code}: #{inspect(game)}")

    # There is a session if any code in player_codes other than client_code
    # is registered with the same Game

    # TODO: Make helpers
    # TODO: Handle not everyone being on the same page
    should_add_session =
      game
      |> Enum.filter(fn code -> code != client_code end)
      |> Enum.all?(fn code ->
        maybe_metadata = get_player_metadata(state, code)

        if maybe_metadata do
          maybe_metadata.current_game == game
        else
          false
        end
      end)

    should_remove_session =
      game
      |> Enum.filter(fn code -> code != client_code end)
      |> Enum.all?(fn code ->
        maybe_metadata = get_player_metadata(state, code)

        if maybe_metadata do
          maybe_metadata.current_game != game
        else
          true
        end
      end)

    new_sessions =
      cond do
        should_add_session ->
          add_session(sessions, game)

        should_remove_session ->
          remove_session(sessions, game)

        true -> sessions
      end

    new_state = %{state | player_data: new_player_data, sessions: new_sessions}
    {:reply, :ok, new_state}
  end

  def handle_call({:game_ended, client_code}, _from, %{player_data: player_data} = state) do
    new_metadata = PlayerMetadata.set_current_game(player_data[client_code], nil)
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

  def handle_call(:crash, _from, state) do
    # 1 / 0
    {:reply, :ok, state}
  end

  def handle_call(req, _from, state) do
    IO.inspect(req, label: "got unhandled request")
    IO.inspect(state, label: "State")

    {:reply, :ok, state}
  end

  # ====

  defp add_session(sessions, players) do
    ChatSessionRegistry.start_session(ChatSessionRegistry, players) |> dbg()
    additions = Enum.reduce(players, %{}, fn player_code, acc -> Map.put(acc, player_code, players) end)
    Map.merge(sessions, additions)
  end

  defp remove_session(sessions, game) do
    # TODO: This feels frail
    [player1 | _rest] = game

    case ChatSessionRegistry.lookup(ChatSessionRegistry, player1) do
      {:ok, {pid, _meta}} ->
        ChatSession.end_session(pid)
        handle_session_end(sessions, game)

      :error ->
        sessions
    end
  end

  defp handle_session_end(sessions, game) do
    Map.drop(sessions, game)
  end
end
