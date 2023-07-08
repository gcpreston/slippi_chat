defmodule SlippiChat.ChatSessions.ChatSession do
  @moduledoc """
  A chat session between a group of players.
  """
  use GenServer, restart: :transient

  require Logger

  # TODO: More session end conditions
  # - send event on slippi quit out, quit when last player disconnects
  # - send event on client quit out, via Channel terminate/2

  @pubsub_name SlippiChat.PubSub
  @pubsub_topic "chat_sessions"
  @session_timeout_ms 9_000_000 # 15 min
  # @session_timeout_ms 15_000 # 15 sec

  defstruct messages: [], player_codes: nil, timeout_ref: nil

  ## Client API

  def start_link(player_codes) do
    GenServer.start_link(__MODULE__, player_codes, name: {:global, player_codes})
  end

  def topic(player_codes) when is_list(player_codes) do
    suffix =
      Enum.map(player_codes, &String.upcase/1)
      |> Enum.sort()
      |> Enum.join(",")

    "#{@pubsub_topic}:#{suffix}"
  end

  def topic(player_code) when is_binary(player_code) do
    "#{@pubsub_topic}:#{String.upcase(player_code)}"
  end

  def get_current_session_player_codes(server) do
    GenServer.call(server, :get_current_session_player_codes)
  end

  def send_message(server, message) do
    GenServer.call(server, {:message, message})
  end

  def list_messages(server) do
    GenServer.call(server, :list_messages)
  end

  def reset_timeout(server) do
    GenServer.cast(server, :reset_timeout)
  end

  def end_session(server) do
    GenServer.stop(server)
  end

  ## Callbacks

  @impl true
  def init(player_codes) do
    {:ok, %__MODULE__{player_codes: player_codes} |> set_timeout()}
  end

  @impl true
  def handle_call({:message, new_message}, _from, state) do
    {:reply, {:ok, new_message}, %{state | messages: [new_message | state.messages]} |> set_timeout(),
     {:continue, {:notify_subscribers, [:session, :message], new_message}}}
  end

  def handle_call(:get_current_session_player_codes, _from, state) do
    {:reply, state.player_codes, state}
  end

  def handle_call(:list_messages, _from, state) do
    {:reply, state.messages, state}
  end

  @impl true
  def handle_cast(:reset_timeout, state) do
    {:noreply, set_timeout(state)}
  end

  @impl true
  def handle_info(:timeout, state) do
    Logger.info("Session #{inspect(state.player_codes)} timed out")
    {:stop, :normal, state}
  end

  @impl true
  def handle_continue({:notify_subscribers, [:session, _action] = event, result}, state) do
    Phoenix.PubSub.broadcast(
      @pubsub_name,
      topic(state.player_codes),
      {event, result}
    )

    {:noreply, state}
  end

  ## Helpers

  defp set_timeout(%{timeout_ref: ref} = state) do
    if is_reference(ref) do
      Process.cancel_timer(ref)
    end

    %{state | timeout_ref: Process.send_after(self(), :timeout, @session_timeout_ms)}
  end
end
