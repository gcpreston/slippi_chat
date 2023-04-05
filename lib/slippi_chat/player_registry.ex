defmodule SlippiChat.PlayerRegistry do
  alias SlippiChat.PlayerRegistry
  use GenServer

  defstruct player_codes: MapSet.new()

  ## API
  # TODO: notify_subscribers

  def start_link(opts \\ [name: __MODULE__]) do
    server_name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, [], name: server_name)
  end

  def add(player_code), do: add(__MODULE__, player_code)
  def add(server, player_code) do
    GenServer.call(server, {:add, player_code})
  end

  def remove(player_code), do: remove(__MODULE__, player_code)
  def remove(server, player_code) do
    GenServer.call(server, {:remove, player_code})
  end

  def list(), do: list(__MODULE__)
  def list(server) do
    GenServer.call(server, :list)
  end

  ## Callbacks

  @impl true
  def init(initial_codes) do
    {:ok, %__MODULE__{player_codes: MapSet.new(initial_codes)}}
  end

  @impl true
  def handle_call({:add, code}, _from, %{player_codes: player_codes} = state) do
    {:reply, :ok, %{state | player_codes: MapSet.put(player_codes, code)}}
  end

  def handle_call({:remove, code}, _from, %{player_codes: player_codes} = state) do
    {:reply, :ok, %{state | player_codes: MapSet.delete(player_codes, code)}}
  end

  def handle_call(:list, _from, state) do
    {:reply, state.player_codes, state}
  end
end
