defmodule SlippiChatWeb.MagicLoginController do
  use SlippiChatWeb, :controller

  alias SlippiChat.Auth
  alias SlippiChat.Auth.MagicAuthenticator

  defp magic_authenticator do
    Application.fetch_env!(:slippi_chat, :magic_authenticator)
  end

  def generate(conn, _params) do
    client_code = conn.assigns[:current_user_code]
    magic_token = Auth.generate_magic_token(client_code)

    render(conn, :show, magic_token: magic_token)
  end

  def verify(conn, %{"verification_code" => verification_code}) do
    client_code = conn.assigns[:current_user_code]

    if MagicAuthenticator.verify(magic_authenticator(), client_code, verification_code) do
      conn
      |> put_status(:ok)
      |> render(:"200")
    else
      conn
      |> put_status(:unauthorized)
      |> put_view(SlippiChatWeb.ErrorJSON)
      |> render(:"401")
    end
  end
end
