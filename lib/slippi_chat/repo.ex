defmodule SlippiChat.Repo do
  use Ecto.Repo,
    otp_app: :slippi_chat,
    adapter: Ecto.Adapters.Postgres
end
