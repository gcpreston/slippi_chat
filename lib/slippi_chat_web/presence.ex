defmodule SlippiChatWeb.Presence do
  use Phoenix.Presence,
    otp_app: :slippi_chat,
    pubsub_server: SlippiChat.PubSub
end
