defmodule SlippiChat.ChatSessions.ChatSession do
  @moduledoc """
  A chat session between a group of players.
  """
  use GenServer, restart: :transient

  require Logger

  alias SlippiChat.ChatSessions
  alias SlippiChat.ChatSessions.Message

  # TODO: More session end conditions
  # - send event on slippi quit out, quit when last player disconnects
  # - send event on client quit out, via Channel terminate/2

  defstruct messages: [], player_codes: nil, timeout_ref: nil

  ## Client API

  def start_link(player_codes) do
    player_codes = standardize(player_codes)
    GenServer.start_link(__MODULE__, player_codes, name: {:global, {__MODULE__, player_codes}})
  end

  def get_player_codes(server) do
    GenServer.call(server, :get_player_codes)
  end

  def send_message(server, sender, content) do
    GenServer.call(server, {:send_message, sender, content})
  end

  @doc """
  Returns messages of the chat session in ascending order.
  """
  def list_messages(server) do
    GenServer.call(server, :list_messages)
  end

  def reset_timeout(server) do
    GenServer.cast(server, :reset_timeout)
  end

  def end_session(server) do
    GenServer.stop(server)
  end

  def report(server, reporter, reportee) do
    GenServer.call(server, {:report, reporter, reportee})
  end

  ## Callbacks

  @impl true
  def init(player_codes) do
    {:ok, %__MODULE__{player_codes: player_codes} |> set_timeout()}
  end

  @impl true
  def handle_call({:send_message, sender, content}, _from, state) do
    new_message = Message.new(sender, content)

    {:reply, {:ok, new_message},
     %{state | messages: [new_message | state.messages]} |> set_timeout(),
     {:continue, {:notify_subscribers, [:session, :message], new_message}}}
  end

  def handle_call(:get_player_codes, _from, state) do
    {:reply, state.player_codes, state}
  end

  def handle_call(:list_messages, _from, state) do
    {:reply, state.messages, state}
  end

  def handle_call({:report, reporter, reportee}, _from, state) do
    report = ChatSessions.create_report!(reporter, reportee, Enum.reverse(state.messages))
    {:reply, {:ok, report}, state}
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
      SlippiChat.PubSub,
      ChatSessions.chat_session_topic(state.player_codes),
      {event, result}
    )

    {:noreply, state}
  end

  ## Helpers

  defp standardize(player_codes) when is_list(player_codes) do
    Enum.map(player_codes, &standardize/1)
    |> Enum.sort()
  end

  defp standardize(player_code) when is_binary(player_code) do
    String.upcase(player_code)
  end

  defp set_timeout(%{timeout_ref: ref} = state) do
    if is_reference(ref) do
      Process.cancel_timer(ref)
    end

    %{state | timeout_ref: Process.send_after(self(), :timeout, timeout_ms())}
  end

  defp timeout_ms do
    Application.fetch_env!(:slippi_chat, :chat_session_timeout_ms)
  end
end
