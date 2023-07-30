defmodule SlippiChatWeb.UserSessionController do
  use SlippiChatWeb, :controller

  alias SlippiChat.Auth
  alias SlippiChatWeb.UserAuth

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"client_token" => client_token}, info) do
    if client_code = Auth.get_client_code_by_client_token(client_token) do
      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(client_code)
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
