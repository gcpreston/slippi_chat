defmodule SlippiChatWeb.CreateTokenLiveTest do
  use SlippiChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import SlippiChat.AuthFixtures

  alias SlippiChat.Auth
  alias SlippiChat.Auth.User

  describe "GET /create_token" do
    test "is not accessible to those without granter status", %{conn: conn} do
      non_admin = user_fixture(%{is_admin: false})

      result =
        log_in_user(conn, non_admin.connect_code)
        |> live(~p"/create_token")

      assert {:error, {:redirect, %{to: "/", flash: flash}}} = result
      assert %{"error" => "You must have token granter status to access this page."} = flash
    end

    test "generates an admin token", %{conn: conn} do
      user = user_fixture(%{is_admin: true})
      new_user_connect_code = unique_connect_code()

      {:ok, lv, _html} =
        log_in_user(conn, user.connect_code)
        |> live(~p"/create_token")

      html =
        lv
        |> element("#grant-form")
        |> render_submit(%{grantee: new_user_connect_code})

      assert html =~ "New token created, copy it now, you won&#39;t be able to again:"
      new_token = Floki.parse_fragment!(html) |> Floki.find("#new-token") |> Floki.text()

      assert %User{connect_code: ^new_user_connect_code} =
               Auth.get_user_by_client_token(new_token)
    end

    test "does not generate new token for existing user", %{conn: conn} do
      user = user_fixture(%{is_admin: true})
      other_user = user_fixture(%{is_admin: false})

      {:ok, lv, _html} =
        log_in_user(conn, user.connect_code)
        |> live(~p"/create_token")

      html =
        lv
        |> element("#grant-form")
        |> render_submit(%{grantee: other_user.connect_code})

      assert html =~ "Failed to create token, does this user already exist?"
      assert Floki.parse_fragment!(html) |> Floki.find("#new-token") == []
    end
  end
end
