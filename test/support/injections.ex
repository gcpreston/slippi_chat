defmodule SlippiChat.Injections do
  def set_chat_session_registry(registry_name) do
    old_registry = Application.fetch_env!(:slippi_chat, :chat_session_registry)

    {:ok, chat_session_supervisor} = DynamicSupervisor.start_link(strategy: :one_for_one)

    ExUnit.Callbacks.start_supervised!(
      {SlippiChat.ChatSessionRegistry, name: registry_name, supervisor: chat_session_supervisor}
    )

    Application.put_env(:slippi_chat, :chat_session_registry, registry_name)

    ExUnit.Callbacks.on_exit(fn ->
      Application.put_env(:slippi_chat, :chat_session_registry, old_registry)
    end)
  end

  def set_magic_authenticator(name) do
    old_authenticator = Application.fetch_env!(:slippi_chat, :magic_authenticator)
    ExUnit.Callbacks.start_supervised!({SlippiChat.Auth.MagicAuthenticator, name: name})
    Application.put_env(:slippi_chat, :magic_authenticator, name)

    ExUnit.Callbacks.on_exit(fn ->
      Application.put_env(:slippi_chat, :magic_authenticator, old_authenticator)
    end)
  end
end
