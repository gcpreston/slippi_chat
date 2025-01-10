defmodule SlippiChat.SlippiAuthBridge.AuthOrchestrator do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, )
  end
end
