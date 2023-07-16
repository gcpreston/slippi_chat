defmodule SlippiChat.ChatSessions.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    children = [
      {SlippiChat.ChatSessionRegistry, name: SlippiChat.ChatSessionRegistry},
      {DynamicSupervisor, name: SlippiChat.ChatSessionSupervisor, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
