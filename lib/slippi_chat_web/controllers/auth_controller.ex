defmodule SlippiChatWeb.AuthController do
  use Phoenix.Controller

  @doc """
  Generate a new token for a client UUID.

  ## Examples

      iex> SlippiChat.AuthController.generate_token(123)
      "xxxxxxx"

  """
  def generate_token(client_uuid) do
    Phoenix.Token.sign(
      ExampleWeb.Endpoint,
      inspect(__MODULE__),
      client_uuid
    )
  end
end
