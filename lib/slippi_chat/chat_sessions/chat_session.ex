defmodule SlippiChat.ChatSessions.ChatSession do
  @moduledoc """
  A chat session between a group of players.
  """
  use GenServer

  @pubsub_name SlippiChat.PubSub
  @pubsub_topic "chat_sessions"

  # TODO: uuid doesn't need to be here? It can be all handled by the registry
  defstruct uuid: nil, messages: [], players: nil

  ## Client API

  def start_link(players) do
    GenServer.start_link(__MODULE__, players)
  end

  # TODO: I don't like this
  def get_uuid(server) do
    GenServer.call(server, :get_uuid)
  end

  def send_message(server, message) do
    GenServer.call(server, {:message, message})
  end

  def end_session(server) do
    GenServer.stop(server)
  end

  ## Callbacks

  @impl true
  def init(players) do
    {:ok, %__MODULE__{uuid: Ecto.UUID.generate(), players: players}}
  end

  @impl true
  def handle_call(:get_uuid, _from, state) do
    {:reply, {:ok, state.uuid}, state}
  end

  def handle_call({:message, new_message}, _from, state) do
    {:reply,
      {:ok, new_message},
      %{state | messages: [new_message | state.messages]},
      {:continue, {:notify_subscribers, [:session, :message], new_message}}}
  end

  @impl true
  def handle_continue({:notify_subscribers, [:session, _action] = event, result}, state) do
    Phoenix.PubSub.broadcast(
      @pubsub_name,
      topic(state.uuid),
      {event, result}
    )
  end

  defp topic(uuid) when is_binary(uuid) do
    "#{@pubsub_topic}:#{uuid}"
  end
end
