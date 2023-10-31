defmodule SlippiChat.ChatSessions.Report do
  use Ecto.Schema

  @type t :: %__MODULE__{
          reporter: String.t(),
          reportee: String.t(),
          chat_log: list()
        }

  schema "reports" do
    field :reporter, :string
    field :reportee, :string
    field :chat_log, {:array, :map}

    timestamps(updated_at: false)
  end
end
