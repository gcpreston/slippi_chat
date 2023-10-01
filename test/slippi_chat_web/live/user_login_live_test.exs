defmodule SlippiChatWeb.UserLoginLiveTest do
  use SlippiChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  alias SlippiChat.Auth

  describe "Log in page" do
    test "renders log in page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/log_in")

      assert html =~ "Log in"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user("ABC#123")
        |> live(~p"/log_in")
        |> follow_redirect(conn, "/")

      assert {:ok, _conn} = result
    end
  end

  describe "user login" do
    test "redirects if user login with valid credentials", %{conn: conn} do
      token = Auth.generate_admin_client_token("ABC#123")

      {:ok, lv, _html} = live(conn, ~p"/log_in")

      form =
        form(lv, "#login_form", client_token: token, remember_me: true)

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/"
    end

    test "redirects to login page with a flash error if there are no valid credentials", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/log_in")

      form = form(lv, "#login_form", client_token: "fake token", remember_me: true)
      conn = submit_form(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid token"
      assert redirected_to(conn) == "/log_in"
    end
  end
end
