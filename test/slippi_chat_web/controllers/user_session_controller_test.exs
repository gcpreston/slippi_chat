defmodule SlippiChatWeb.UserSessionControllerTest do
  use SlippiChatWeb.ConnCase, async: true

  alias SlippiChat.Auth

  setup do
    client_code = "ABC#123"
    client_token = Auth.generate_admin_client_token(client_code)

    %{client_code: client_code, client_token: client_token}
  end

  describe "POST /log_in" do
    test "logs the user in via client token", %{
      conn: conn,
      client_code: client_code,
      client_token: client_token
    } do
      conn =
        post(conn, ~p"/log_in", %{"client_token" => client_token})

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"

      conn = get(conn, ~p"/chat")
      response = html_response(conn, 200)
      assert response =~ client_code
      assert response =~ ~p"/log_out"
    end

    test "logs the user in via login token", %{conn: conn, client_code: client_code} do
      login_token = Auth.generate_login_token(client_code)
      conn = post(conn, ~p"/log_in", %{"login_token" => login_token})

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"

      conn = get(conn, ~p"/chat")
      response = html_response(conn, 200)
      assert response =~ client_code
      assert response =~ ~p"/log_out"
    end

    test "logs the user in with remember me", %{conn: conn, client_token: client_token} do
      conn =
        post(conn, ~p"/log_in", %{
          "client_token" => client_token,
          "remember_me" => "true"
        })

      assert conn.resp_cookies["_slippi_chat_web_user_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the user in with return to", %{conn: conn, client_token: client_token} do
      conn =
        conn
        |> init_test_session(user_return_to: "/foo/bar")
        |> post(~p"/log_in", %{"client_token" => client_token})

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "redirects to login page with invalid credentials", %{conn: conn} do
      conn = post(conn, ~p"/log_in", %{"client_token" => "fake client_token"})

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid token"
      assert redirected_to(conn) == ~p"/log_in"
    end
  end

  describe "DELETE /log_out" do
    test "logs the user out", %{conn: conn, client_code: client_code} do
      conn = conn |> log_in_user(client_code) |> delete(~p"/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end
