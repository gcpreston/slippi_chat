defmodule SlippiChatWeb.MagicLoginControllerTest do
  use SlippiChatWeb.ConnCase, async: false
  import SlippiChat.AuthFixtures

  alias SlippiChat.Auth
  alias SlippiChat.Auth.MagicAuthenticator

  defp magic_authenticator do
    Application.fetch_env!(:slippi_chat, :magic_authenticator)
  end

  setup do
    user = user_fixture()
    client_token = Auth.generate_admin_client_token(user.connect_code)

    allow = Process.whereis(magic_authenticator())
    Ecto.Adapters.SQL.Sandbox.allow(SlippiChat.Repo, self(), allow)

    %{user: user, client_token: client_token}
  end

  describe "POST /magic_generate" do
    test "requires authorization", %{conn: conn} do
      conn = post(conn, ~p"/magic_generate")

      assert json_response(conn, 401) == %{"errors" => %{"detail" => "Unauthorized"}}
    end

    test "generates a magic token", %{
      conn: conn,
      client_token: client_token,
      user: user
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{client_token}")
        |> post(~p"/magic_generate")

      response = json_response(conn, 200)

      assert %{"data" => %{"magic_token" => magic_token}} = response
      assert Auth.get_user_by_magic_token(magic_token) == user
    end
  end

  describe "POST /magic_verify" do
    test "requires authorization", %{conn: conn, user: user} do
      verification_code =
        MagicAuthenticator.register_verification_code(magic_authenticator(), user.connect_code)

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
      user: user
    } do
      SlippiChatWeb.Endpoint.subscribe("magic_login:#{user.connect_code}")
      diff_user = user_fixture()
      diff_client_token = Auth.generate_admin_client_token(diff_user.connect_code)

      verification_code =
        MagicAuthenticator.register_verification_code(magic_authenticator(), user.connect_code)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{diff_client_token}")
        |> post(~p"/magic_verify", %{"verification_code" => verification_code})

      assert json_response(conn, 401) == %{"errors" => %{"detail" => "Unauthorized"}}
      refute_receive {:verified, _data}
    end

    test "sends a login token via pubsub on successful verification", %{
      conn: conn,
      user: user,
      client_token: client_token
    } do
      SlippiChatWeb.Endpoint.subscribe("magic_login:#{user.connect_code}")

      verification_code =
        MagicAuthenticator.register_verification_code(magic_authenticator(), user.connect_code)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{client_token}")
        |> post(~p"/magic_verify", %{"verification_code" => verification_code})

      assert json_response(conn, 200) == "OK"
      assert_receive {:verified, %{login_token: login_token}}
      assert Auth.get_user_by_login_token(login_token) == user
    end
  end
end
