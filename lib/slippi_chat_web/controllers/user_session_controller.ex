defmodule SlippiChatWeb.UserSessionController do
  use SlippiChatWeb, :controller

  alias SlippiChat.Auth
  alias SlippiChat.Auth.MagicAuthenticator
  alias SlippiChatWeb.UserAuth

  defp magic_authenticator do
    Application.fetch_env!(:slippi_chat, :magic_authenticator)
  end

  def create(conn, %{"login_token" => login_token} = params) do
    params = params |> Map.delete("login_token") |> Map.put("token", login_token)

    create(conn, params, "login", "Logged in magically!")
  end

  def create(conn, %{"client_token" => client_token} = params) do
    params = params |> Map.delete("client_token") |> Map.put("token", client_token)

    create(conn, params, "client", "Welcome back!")
  end

  defp create(conn, %{"token" => token} = params, context, info) do
    if client_code = Auth.get_client_code_by_signed_token(token, context) do
      if context == "login" do
        Auth.delete_login_tokens(client_code)
      end

      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(client_code, params)
    else
      conn
      |> put_flash(:error, "Invalid token")
      |> redirect(to: ~p"/log_in")
    end
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

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
