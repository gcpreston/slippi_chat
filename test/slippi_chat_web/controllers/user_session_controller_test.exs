defmodule SlippiChatWeb.UserSessionControllerTest do
  use SlippiChatWeb.ConnCase, async: true

  alias SlippiChat.Auth

  setup do
    client_code = "ABC#123"
    token = Auth.generate_admin_client_token(client_code)

    %{client_code: client_code, token: token}
  end

  describe "POST /log_in" do
    test "logs the user in", %{conn: conn, client_code: client_code, token: token} do
      conn =
        post(conn, ~p"/log_in", %{"client_token" => token})

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/chat")
      response = html_response(conn, 200)
      assert response =~ client_code
      assert response =~ ~p"/log_out"
    end

    test "logs the user in with remember me", %{conn: conn, token: token} do
      conn =
        post(conn, ~p"/log_in", %{
          "client_token" => token,
          "remember_me" => "true"
        })

      assert conn.resp_cookies["_slippi_chat_web_user_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the user in with return to", %{conn: conn, token: token} do
      conn =
        conn
        |> init_test_session(user_return_to: "/foo/bar")
        |> post(~p"/log_in", %{"client_token" => token})

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "login following registration", %{conn: conn, token: token} do
      conn =
        conn
        |> post(~p"/log_in", %{
          "_action" => "registered",
          "client_token" => token
        })

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Account created successfully"
    end

    test "redirects to login page with invalid credentials", %{conn: conn} do
      conn = post(conn, ~p"/log_in", %{"client_token" => "fake token"})

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
