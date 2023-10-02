defmodule SlippiChat.Auth.MagicAuthenticator do
  @moduledoc """
  A GenServer for tracking and authenticating LiveView pids
  in the magic login flow.
  """
  use GenServer

  alias SlippiChat.Auth

  defstruct registrations: %{}, used_codes: MapSet.new()

  @verification_code_length 6

  ## API

  @doc """
  Starts MagicAuthenticator with the given options.

  `:name` is always required.
  """
  def start_link(opts) do
    server_name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, nil, name: server_name)
  end

  @doc """
  Generate a verification code for a client code. Registers the calling
  process as the receiver of the login token when the client code +
  returned verification code are verified.
  """
  @spec register_verification_code(GenServer.server(), String.t()) :: String.t()
  def register_verification_code(server, client_code) do
    GenServer.call(server, {:register_verification_code, client_code})
  end

  @doc """
  Verify a combination of client code and verification code.
  """
  @spec verify(GenServer.server(), String.t(), String.t()) :: boolean()
  def verify(server, client_code, verification_code) do
    GenServer.call(server, {:verify, client_code, verification_code})
  end

  ## Callbacks

  @impl true
  def init(_) do
    state = %__MODULE__{}
    {:ok, state}
  end

  @impl true
  def handle_call({:register_verification_code, client_code}, {from_pid, _tag}, state) do
    verification_code = unique_random_code(state.used_codes)
    new_regs = Map.put_new(state.registrations, {client_code, verification_code}, from_pid)
    new_used_codes = MapSet.put(state.used_codes, verification_code)
    {:reply, verification_code, %{state | registrations: new_regs, used_codes: new_used_codes}}
  end

  def handle_call({:verify, client_code, verification_code}, _from, state) do
    case Map.get(state.registrations, {client_code, verification_code}) do
      nil ->
        {:reply, false, state}

      pid when is_pid(pid) ->
        login_token = Auth.generate_login_token(client_code)
        send(pid, {:verified, %{login_token: login_token}})
        new_regs = Map.delete(state.registrations, {client_code, verification_code})
        new_used_codes = MapSet.delete(state.used_codes, verification_code)

        {:reply, true, %{state | registrations: new_regs, used_codes: new_used_codes}}
    end
  end

  defp unique_random_code(used_codes) do
    test_code = random_code()

    if MapSet.member?(used_codes, test_code) do
      unique_random_code(used_codes)
    else
      test_code
    end
  end

  defp random_code do
    symbols = ~c"0123456789"
    symbol_count = Enum.count(symbols)

    for _ <- 1..@verification_code_length, into: "" do
      <<Enum.at(symbols, :rand.uniform(symbol_count) - 1)>>
    end
  end
end
