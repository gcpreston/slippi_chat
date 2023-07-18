defmodule SlippiChat.Injections do
  def set_chat_session_registry(registry_name) do
    {:ok, chat_session_supervisor} = DynamicSupervisor.start_link(strategy: :one_for_one)
    ExUnit.Callbacks.start_supervised!({SlippiChat.ChatSessionRegistry, name: registry_name, supervisor: chat_session_supervisor})
    Application.put_env(:slippi_chat, :chat_session_registry, registry_name)
  end
end
