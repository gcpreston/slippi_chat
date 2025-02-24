defmodule SlippiChatWeb.UserSessionController do
  use SlippiChatWeb, :controller

  alias SlippiChat.Auth
  alias SlippiChatWeb.UserAuth

  def create(conn, %{"login_token" => login_token} = params) do
    params = params |> Map.delete("login_token") |> Map.put("token", login_token)

    create(conn, params, "login", "Logged in magically!")
  end

  def create(conn, %{"client_token" => client_token} = params) do
    params = params |> Map.delete("client_token") |> Map.put("token", client_token)

    create(conn, params, "client", "Welcome back!")
  end

  defp create(conn, %{"token" => token} = params, context, info) do
    if user = Auth.get_user_by_signed_token(token, context) do
      if context == "login" do
        Auth.delete_login_tokens(user.connect_code)
      end

      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user.connect_code, params)
    else
      conn
      |> put_flash(:error, "Invalid token")
      |> redirect(to: ~p"/log_in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
