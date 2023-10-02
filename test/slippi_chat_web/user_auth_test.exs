defmodule SlippiChatWeb.UserAuthTest do
  use SlippiChatWeb.ConnCase, async: true

  alias Phoenix.LiveView
  alias SlippiChat.Auth
  alias SlippiChatWeb.UserAuth

  @remember_me_cookie "_slippi_chat_web_user_remember_me"

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, SlippiChatWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{client_code: "ABC#123", conn: conn}
  end

  describe "log_in_user/3" do
    test "stores the user token in the session", %{conn: conn, client_code: client_code} do
      conn = UserAuth.log_in_user(conn, client_code)
      assert token = get_session(conn, :user_token)
      assert get_session(conn, :live_socket_id) == "users_sessions:#{Base.url_encode64(token)}"
      assert redirected_to(conn) == ~p"/"
      assert Auth.get_client_code_by_session_token(token)
    end

    test "clears everything previously stored in the session", %{
      conn: conn,
      client_code: client_code
    } do
      conn = conn |> put_session(:to_be_removed, "value") |> UserAuth.log_in_user(client_code)
      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, client_code: client_code} do
      conn = conn |> put_session(:user_return_to, "/hello") |> UserAuth.log_in_user(client_code)
      assert redirected_to(conn) == "/hello"
    end

    test "writes a cookie if remember_me is configured", %{conn: conn, client_code: client_code} do
      conn =
        conn |> fetch_cookies() |> UserAuth.log_in_user(client_code, %{"remember_me" => "true"})

      assert get_session(conn, :user_token) == conn.cookies[@remember_me_cookie]

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :user_token)
      assert max_age == 5_184_000
    end
  end

  describe "logout_user/1" do
    test "erases session and cookies", %{conn: conn, client_code: client_code} do
      user_token = Auth.generate_user_session_token(client_code)

      conn =
        conn
        |> put_session(:user_token, user_token)
        |> put_req_cookie(@remember_me_cookie, user_token)
        |> fetch_cookies()
        |> UserAuth.log_out_user()

      refute get_session(conn, :user_token)
      refute conn.cookies[@remember_me_cookie]
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
      refute Auth.get_client_code_by_session_token(user_token)
    end

    test "broadcasts to the given live_socket_id", %{conn: conn} do
      live_socket_id = "users_sessions:abcdef-token"
      SlippiChatWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> UserAuth.log_out_user()

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^live_socket_id}
    end

    test "works even if user is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> UserAuth.log_out_user()
      refute get_session(conn, :user_token)
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "fetch_current_user_code/2" do
    setup %{conn: conn} do
      %{conn: Phoenix.Controller.put_format(conn, "html")}
    end

    test "authenticates user from session", %{conn: conn, client_code: client_code} do
      user_token = Auth.generate_user_session_token(client_code)
      conn = conn |> put_session(:user_token, user_token) |> UserAuth.fetch_current_user_code([])
      assert conn.assigns.current_user_code == client_code
    end

    test "authenticates user from bearer token", %{conn: conn, client_code: client_code} do
      client_token = Auth.generate_admin_client_token(client_code)

      conn =
        conn
        |> Phoenix.Controller.put_format("json")
        |> put_req_header("authorization", "Bearer #{client_token}")
        |> UserAuth.fetch_current_user_code(conn)

      assert conn.assigns.current_user_code == client_code
    end

    test "authenticates user from cookies", %{conn: conn, client_code: client_code} do
      logged_in_conn =
        conn |> fetch_cookies() |> UserAuth.log_in_user(client_code, %{"remember_me" => "true"})

      user_token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      conn =
        conn
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> UserAuth.fetch_current_user_code([])

      assert conn.assigns.current_user_code == client_code
      assert get_session(conn, :user_token) == user_token

      assert get_session(conn, :live_socket_id) ==
               "users_sessions:#{Base.url_encode64(user_token)}"
    end

    test "does not authenticate if data is missing", %{conn: conn, client_code: client_code} do
      _ = Auth.generate_user_session_token(client_code)
      conn = UserAuth.fetch_current_user_code(conn, [])
      refute get_session(conn, :user_token)
      refute conn.assigns.current_user_code
    end
  end

  describe "on_mount: mount_current_user" do
    test "assigns current_user based on a valid user_token", %{
      conn: conn,
      client_code: client_code
    } do
      user_token = Auth.generate_user_session_token(client_code)
      session = conn |> put_session(:user_token, user_token) |> get_session()

      {:cont, updated_socket} =
        UserAuth.on_mount(:mount_current_user, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_user_code == client_code
    end

    test "assigns nil to current_user assign if there isn't a valid user_token", %{conn: conn} do
      user_token = "invalid_token"
      session = conn |> put_session(:user_token, user_token) |> get_session()

      {:cont, updated_socket} =
        UserAuth.on_mount(:mount_current_user, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_user_code == nil
    end

    test "assigns nil to current_user assign if there isn't a user_token", %{conn: conn} do
      session = conn |> get_session()

      {:cont, updated_socket} =
        UserAuth.on_mount(:mount_current_user, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_user_code == nil
    end
  end

  describe "on_mount: ensure_authenticated" do
    test "authenticates current_user based on a valid user_token", %{
      conn: conn,
      client_code: client_code
    } do
      user_token = Auth.generate_user_session_token(client_code)
      session = conn |> put_session(:user_token, user_token) |> get_session()

      {:cont, updated_socket} =
        UserAuth.on_mount(:ensure_authenticated, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_user_code == client_code
    end

    test "redirects to login page if there isn't a valid user_token", %{conn: conn} do
      user_token = "invalid_token"
      session = conn |> put_session(:user_token, user_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: SlippiChatWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = UserAuth.on_mount(:ensure_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_user_code == nil
    end

    test "redirects to login page if there isn't a user_token", %{conn: conn} do
      session = conn |> get_session()

      socket = %LiveView.Socket{
        endpoint: SlippiChatWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = UserAuth.on_mount(:ensure_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_user_code == nil
    end
  end

  describe "on_mount: :redirect_if_user_is_authenticated" do
    test "redirects if there is an authenticated  user ", %{conn: conn, client_code: client_code} do
      user_token = Auth.generate_user_session_token(client_code)
      session = conn |> put_session(:user_token, user_token) |> get_session()

      assert {:halt, _updated_socket} =
               UserAuth.on_mount(
                 :redirect_if_user_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end

    test "doesn't redirect if there is no authenticated user", %{conn: conn} do
      session = conn |> get_session()

      assert {:cont, _updated_socket} =
               UserAuth.on_mount(
                 :redirect_if_user_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end
  end

  describe "redirect_if_user_is_authenticated/2" do
    test "redirects if user is authenticated", %{conn: conn, client_code: client_code} do
      conn =
        conn
        |> assign(:current_user_code, client_code)
        |> UserAuth.redirect_if_user_is_authenticated([])

      assert conn.halted
      assert redirected_to(conn) == ~p"/"
    end

    test "does not redirect if user is not authenticated", %{conn: conn} do
      conn = UserAuth.redirect_if_user_is_authenticated(conn, [])
      refute conn.halted
      refute conn.status
    end
  end

  describe "require_authenticated_user/2" do
    setup %{conn: conn} do
      %{conn: Phoenix.Controller.put_format(conn, "html")}
    end

    test "redirects if user is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> UserAuth.require_authenticated_user([])
      assert conn.halted

      assert redirected_to(conn) == ~p"/log_in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "returns 401 for JSON requests if user is not authenticated", %{conn: conn} do
      conn =
        conn
        |> Phoenix.Controller.put_format("json")
        |> UserAuth.require_authenticated_user([])

      assert conn.halted
      assert json_response(conn, 401) == %{"errors" => %{"detail" => "Unauthorized"}}
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | path_info: ["foo"], query_string: ""}
        |> fetch_flash()
        |> UserAuth.require_authenticated_user([])

      assert halted_conn.halted
      assert get_session(halted_conn, :user_return_to) == "/foo"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar=baz"}
        |> fetch_flash()
        |> UserAuth.require_authenticated_user([])

      assert halted_conn.halted
      assert get_session(halted_conn, :user_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar", method: "POST"}
        |> fetch_flash()
        |> UserAuth.require_authenticated_user([])

      assert halted_conn.halted
      refute get_session(halted_conn, :user_return_to)
    end

    test "does not redirect if user is authenticated", %{conn: conn, client_code: client_code} do
      conn =
        conn |> assign(:current_user_code, client_code) |> UserAuth.require_authenticated_user([])

      refute conn.halted
      refute conn.status
    end
  end
end
