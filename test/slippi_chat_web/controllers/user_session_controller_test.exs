defmodule SlippiChatWeb.UserSessionControllerTest do
  use SlippiChatWeb.ConnCase, async: true

  alias SlippiChat.Auth
  alias SlippiChat.Auth.MagicAuthenticator

  defp magic_authenticator do
    Application.fetch_env!(:slippi_chat, :magic_authenticator)
  end

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

  describe "POST /magic_verify" do
    setup do
      allow = Process.whereis(magic_authenticator())
      Ecto.Adapters.SQL.Sandbox.allow(SlippiChat.Repo, self(), allow)
      %{}
    end

    test "requires authorization", %{conn: conn, client_code: client_code} do
      verification_code =
        MagicAuthenticator.register_verification_code(magic_authenticator(), client_code)

      conn = post(conn, ~p"/magic_verify", %{"verification_code" => verification_code})

      assert json_response(conn, 401) == %{"errors" => %{"detail" => "Unauthorized"}}
      refute_receive {:verified, _data}
    end

    test "does not authorize invalid verification code", %{conn: conn, client_token: client_token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{client_token}")
        |> post(~p"/magic_verify", %{"verification_code" => "12345"})

      assert json_response(conn, 401) == %{"errors" => %{"detail" => "Unauthorized"}}
      refute_receive {:verified, _data}
    end

    test "does not authorize with a different user's client token", %{
      conn: conn,
      client_code: client_code
    } do
      SlippiChatWeb.Endpoint.subscribe("magic_login:#{client_code}")
      diff_client_token = Auth.generate_admin_client_token("XYZ#987")

      verification_code =
        MagicAuthenticator.register_verification_code(magic_authenticator(), client_code)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{diff_client_token}")
        |> post(~p"/magic_verify", %{"verification_code" => verification_code})

      assert json_response(conn, 401) == %{"errors" => %{"detail" => "Unauthorized"}}
      refute_receive {:verified, _data}
    end

    test "sends a login token via pubsub on successful verification", %{
      conn: conn,
      client_code: client_code,
      client_token: client_token
    } do
      SlippiChatWeb.Endpoint.subscribe("magic_login:#{client_code}")

      verification_code =
        MagicAuthenticator.register_verification_code(magic_authenticator(), client_code)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{client_token}")
        |> post(~p"/magic_verify", %{"verification_code" => verification_code})

      assert json_response(conn, 200) == "OK"
      assert_receive {:verified, %{login_token: login_token}}
      assert Auth.get_client_code_by_login_token(login_token) == client_code
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
