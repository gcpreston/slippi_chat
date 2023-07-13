defmodule SlippiChat.ChatSessions.Message do
  @moduledoc """
  A chat message.
  """

  @type player_code :: String.t()
  @type t :: %__MODULE__{
          id: String.t(),
          sender: player_code(),
          content: String.t()
        }

  defstruct [:id, :sender, :content]

  def new(sender, content) do
    %__MODULE__{id: Ecto.UUID.generate(), sender: sender, content: content}
  end
end

defimpl Jason.Encoder, for: SlippiChat.ChatSessions.Message do
  def encode(%SlippiChat.ChatSessions.Message{id: id, sender: sender, content: content}, opts) do
    Jason.Encode.map(%{id: id, sender: sender, content: content}, opts)
  end
end
