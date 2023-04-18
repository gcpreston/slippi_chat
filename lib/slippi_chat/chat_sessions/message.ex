defmodule SlippiChat.ChatSessions.Message do
  @moduledoc """
  A chat message.
  """

  @type player_code :: String.t()
  @type t :: %__MODULE__{
    uuid: String.t(),
    content: String.t(),
    player_code: player_code()
  }

  defstruct [:uuid, :content, :player_code]

  def new(content, player_code) do
    %__MODULE__{uuid: Ecto.UUID.generate(), content: content, player_code: player_code}
  end
end
