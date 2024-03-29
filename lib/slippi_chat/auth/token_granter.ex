defmodule SlippiChat.Auth.TokenGranter do
  use Ecto.Schema

  schema "token_granters" do
    field :granter_code, :string
    belongs_to :client_token, SlippiChat.Auth.ClientToken

    timestamps(updated_at: false)
  end
end
