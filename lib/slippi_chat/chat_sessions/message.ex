defmodule SlippiChat.ChatSessions.Message do
  @moduledoc """
  A chat message.
  """

  @type player_code :: String.t()
  @type t :: %__MODULE__{
          id: String.t(),
          sender: player_code(),
          content: String.t(),
          timestamp: DateTime.t()
        }

  defstruct [:id, :sender, :content, :timestamp]

  def new(sender, content) do
    %__MODULE__{
      id: Ecto.UUID.generate(),
      sender: sender,
      content: content,
      timestamp: DateTime.utc_now()
    }
  end
end

defimpl Jason.Encoder, for: SlippiChat.ChatSessions.Message do
  def encode(
        %SlippiChat.ChatSessions.Message{
          id: id,
          sender: sender,
          content: content,
          timestamp: timestamp
        },
        opts
      ) do
    Jason.Encode.map(%{id: id, sender: sender, content: content, timestamp: timestamp}, opts)
  end
end
