defmodule SlippiChatWeb.MagicLoginLiveTest do
  use SlippiChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  alias SlippiChat.Auth

  describe "GET /magic_log_in" do
    setup do
      %{client_code: "ABC#123"}
    end

    test "rejects an invalid magic token", %{conn: conn} do
      {:error, {:redirect, %{to: "/log_in", flash: %{"error" => "Invalid magic token"}}}} =
        live(conn, ~p"/magic_log_in?#{%{t: "fake token"}}")
    end

    test "redirects if already logged in", %{conn: conn, client_code: client_code} do
      conn = conn |> log_in_user(client_code)

      {:error, {:redirect, %{to: "/"}}} =
        live(conn, ~p"/magic_log_in?#{%{t: "doesn't matter"}}")
    end

    test "enters flow with a valid magic token", %{conn: conn, client_code: client_code} do
      magic_token = Auth.generate_magic_token(client_code)
      {:ok, _live, html} = live(conn, ~p"/magic_log_in?#{%{t: magic_token}}")

      assert html =~ "Magic login"
      assert html =~ "Your magic code is"
      assert html =~ ~r/\d{6}/
    end

    test "submits form when event is received", %{conn: conn, client_code: client_code} do
      magic_token = Auth.generate_magic_token(client_code)
      {:ok, live, _html} = live(conn, ~p"/magic_log_in?#{%{t: magic_token}}")

      login_token = Auth.generate_login_token(client_code)
      send(live.pid, {:verified, %{login_token: login_token}})

      assert live |> element("#redirect_form") |> render() =~ login_token

      form = form(live, "#redirect_form", %{"login_token" => login_token})
      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Logged in magically!"
    end

    test "only logs in the LiveView for the code being verified", %{
      conn: conn1,
      client_code: client_code
    } do
      magic_token = Auth.generate_magic_token(client_code)
      conn2 = build_conn()
      {:ok, live1, _html} = live(conn1, ~p"/magic_log_in?#{%{t: magic_token}}")
      {:ok, live2, _html} = live(conn2, ~p"/magic_log_in?#{%{t: magic_token}}")

      login_token = Auth.generate_login_token(client_code)
      send(live1.pid, {:verified, %{login_token: login_token}})

      form1_html = live1 |> element("#redirect_form") |> render()
      form2_html = live2 |> element("#redirect_form") |> render()

      assert form1_html =~ login_token
      assert form1_html =~ "phx-trigger-action"
      refute form2_html =~ login_token
      refute form2_html =~ "phx-trigger-action"
    end
  end
end
