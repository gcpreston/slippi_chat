defmodule SlippiChatWeb.Presence do
  use Phoenix.Presence,
    otp_app: :slippi_chat,
    pubsub_server: SlippiChat.PubSub

  def init(_opts) do
    # user-land state
    {:ok, %{}}
  end

  def handle_metas(topic, %{joins: joins, leaves: leaves}, presences, state) do
    # fetch existing presence information for the joined users and broadcast the
    # event to all subscribers
    for {player_code, _presence} <- joins do
      user_data = %{player_code: player_code, metas: Map.fetch!(presences, player_code)}
      msg = {SlippiChat.PresenceClient, {:join, user_data}}
      Phoenix.PubSub.local_broadcast(SlippiChat.PubSub, topic, msg)
    end

    # fetch existing presence information for the left users and broadcast the
    # event to all subscribers
    for {player_code, _presence} <- leaves do
      metas =
        case Map.fetch(presences, player_code) do
          {:ok, presence_metas} -> presence_metas
          :error -> []
        end

      # only broadcast leave if a user has left on all devices
      if metas == [] do
        user_data = %{player_code: player_code, metas: metas}
        msg = {SlippiChat.PresenceClient, {:leave, user_data}}
        Phoenix.PubSub.local_broadcast(SlippiChat.PubSub, topic, msg)
      end
    end

    {:ok, state}
  end
end
