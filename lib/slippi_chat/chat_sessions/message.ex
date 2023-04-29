defmodule SlippiChat.ChatSessions.Message do
  @moduledoc """
  A chat message.
  """

  @type player_code :: String.t()
  @type t :: %__MODULE__{
          id: String.t(),
          content: String.t(),
          sender: player_code()
        }

  defstruct [:id, :content, :sender]

  def new(content, sender) do
    %__MODULE__{id: Ecto.UUID.generate(), content: content, sender: sender}
  end
end

defimpl Jason.Encoder, for: SlippiChat.ChatSessions.Message do
  def encode(%SlippiChat.ChatSessions.Message{id: id, content: content, sender: sender}, opts) do
    Jason.Encode.map(%{id: id, content: content, sender: sender}, opts)
  end
end
