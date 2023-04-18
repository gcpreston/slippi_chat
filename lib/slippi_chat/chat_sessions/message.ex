defmodule SlippiChat.ChatSessions.Message do
  @moduledoc """
  A chat message.
  """

  @type player_code :: String.t()
  @type t :: %__MODULE__{
    id: String.t(),
    content: String.t(),
    player_code: player_code()
  }

  defstruct [:id, :content, :player_code]

  def new(content, player_code) do
    %__MODULE__{id: Ecto.UUID.generate(), content: content, player_code: player_code}
  end
end
