defmodule SlippiChat.ChatSessions do
  @pubsub_name SlippiChat.PubSub
  @pubsub_topic "chat_sessions"

  def subscribe do
    Phoenix.PubSub.subscribe(@pubsub_name, @pubsub_topic)
  end

  def session_start(game) do
    Phoenix.PubSub.broadcast(
      @pubsub_name,
      @pubsub_topic,
      {__MODULE__, [:session, :start], game}
    )
  end

  def session_end(game) do
    Phoenix.PubSub.broadcast(
      @pubsub_name,
      @pubsub_topic,
      {__MODULE__, [:session, :end], game}
    )
  end
end
