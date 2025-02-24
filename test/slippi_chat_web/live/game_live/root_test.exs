defmodule SlippiChatWeb.GameLive.RootTest do
  use SlippiChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Phoenix.ChannelTest
  import SlippiChat.AuthFixtures

  alias SlippiChatWeb.Endpoint
  alias SlippiChat.ChatSessionRegistry
  alias SlippiChat.ChatSessions.ChatSession
  alias SlippiChatWeb.ClientChannel

  defp chat_session_timeout_ms do
    Application.fetch_env!(:slippi_chat, :chat_session_timeout_ms)
  end

  defp chat_session_registry do
    Application.fetch_env!(:slippi_chat, :chat_session_registry)
  end

  defp authenticate(%{conn: conn}) do
    user = user_fixture(%{connect_code: "ABC#123"})
    %{conn: log_in_user(conn, user.connect_code), client_code: user.connect_code}
  end

  describe "Mount" do
    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/chat")

      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/log_in"
    end
  end

  describe "Rendering" do
    setup [:authenticate]

    test "renders empty state when there is no chat session", %{
      conn: conn,
      client_code: client_code
    } do
      {:ok, _lv, html} = live(conn, ~p"/chat")

      assert html =~ client_code
      assert html =~ "No chat session in progress."
    end

    test "renders chat session and its data when one exists", %{
      conn: conn,
      client_code: client_code
    } do
      player_codes = [client_code, "XYZ#987"]
      {:ok, pid} = ChatSessionRegistry.start_chat_session(chat_session_registry(), player_codes)
      {:ok, message} = ChatSession.send_message(pid, "XYZ#987", "hello world!")
      {:ok, _lv, html} = live(conn, ~p"/chat")

      assert html =~ "Players"
      Enum.each(player_codes, fn player_code -> assert html =~ player_code end)
      assert html =~ message.id
      assert html =~ "hello world!"
    end
  end

  describe "Events" do
    setup [:authenticate]

    test "sends messages", %{conn: conn1} do
      player_codes = ["ABC#123", "XYZ#987"]
      {:ok, _pid} = ChatSessionRegistry.start_chat_session(chat_session_registry(), player_codes)

      _user2 = user_fixture(%{connect_code: "XYZ#987"})
      conn2 = Phoenix.ConnTest.build_conn() |> log_in_user("XYZ#987")
      {:ok, lv1, _html1} = live(conn1, ~p"/chat")
      {:ok, lv2, _html2} = live(conn2, ~p"/chat")

      lv1
      |> element("#message-form")
      |> render_submit(%{message: %{content: "test message"}})

      assert render(lv1) =~ "test message"
      assert render(lv2) =~ "test message"
    end

    test "sending message resets room timeout", %{conn: conn} do
      player_codes = ["ABC#123", "XYZ#987"]

      # No refresh

      {:ok, _pid} = ChatSessionRegistry.start_chat_session(chat_session_registry(), player_codes)
      {:ok, lv, html} = live(conn, ~p"/chat")
      assert html =~ "Players"
      Process.sleep(chat_session_timeout_ms())
      refute render(lv) =~ "Players"

      # Refresh

      {:ok, _pid} = ChatSessionRegistry.start_chat_session(chat_session_registry(), player_codes)
      {:ok, lv, html} = live(conn, ~p"/chat")
      assert html =~ "Players"
      Process.sleep(div(chat_session_timeout_ms(), 2))

      lv
      |> element("#message-form")
      |> render_submit(%{message: %{content: "test message"}})

      Process.sleep(div(chat_session_timeout_ms(), 2))
      assert render(lv) =~ "Players"
      Process.sleep(chat_session_timeout_ms())
      refute render(lv) =~ "Players"
    end

    test "displays online status of client for each player code", %{conn: conn1} do
      old_timeout = chat_session_timeout_ms()
      Application.put_env(:slippi_chat, :chat_session_timeout_ms, 1500)
      on_exit(fn -> Application.put_env(:slippi_chat, :chat_session_timeout_ms, old_timeout) end)

      player_codes = ["ABC#123", "XYZ#987"]
      {:ok, _pid} = ChatSessionRegistry.start_chat_session(chat_session_registry(), player_codes)
      Endpoint.subscribe("clients")

      _user2 = user_fixture(%{connect_code: "XYZ#987"})
      conn2 = Phoenix.ConnTest.build_conn() |> log_in_user("XYZ#987")
      {:ok, lv1, html1} = live(conn1, ~p"/chat")
      {:ok, lv2, html2} = live(conn2, ~p"/chat")

      Enum.each([html1, html2], fn html ->
        refute_html(html, "#player-status-abc-123.online", text: "ABC#123")
        refute_html(html, "#player-status-xyz-987.online", text: "XYZ#987")
      end)

      code_abc = "ABC#123"

      {:ok, _reply, socket_abc} =
        UserSocket
        |> socket("user_socket:#{code_abc}", %{client_code: code_abc})
        |> subscribe_and_join(ClientChannel, "clients")

      assert_broadcast "presence_diff", %{joins: %{^code_abc => _}}

      wait_until(fn ->
        Enum.each([render(lv1), render(lv2)], fn html ->
          assert_html(html, "#player-status-abc-123.online", text: "ABC#123")
          refute_html(html, "#player-status-xyz-987.online", text: "XYZ#987")
        end)
      end)

      code_xyz = "XYZ#987"

      {:ok, _reply, _socket_xyz} =
        UserSocket
        |> socket(code_xyz, %{client_code: code_xyz})
        |> subscribe_and_join(ClientChannel, "clients")

      assert_broadcast "presence_diff", %{joins: %{^code_xyz => _}}

      wait_until(fn ->
        Enum.each([render(lv1), render(lv2)], fn html ->
          assert_html(html, "#player-status-abc-123.online", text: "ABC#123")
          assert_html(html, "#player-status-xyz-987.online", text: "XYZ#987")
        end)
      end)

      Process.unlink(socket_abc.channel_pid)
      close(socket_abc)
      assert_broadcast "presence_diff", %{leaves: %{"ABC#123" => _}}

      wait_until(fn ->
        Enum.each([render(lv1), render(lv2)], fn html ->
          refute_html(html, "#player-status-abc-123.online", text: "ABC#123")
          assert_html(html, "#player-status-xyz-987.online", text: "XYZ#987")
        end)
      end)
    end

    test "Disconnect button ends the session", %{conn: conn} do
      {:ok, _pid} =
        ChatSessionRegistry.start_chat_session(chat_session_registry(), ["ABC#123", "XYZ#987"])

      {:ok, lv, _html} = live(conn, ~p"/chat")

      html = render_until(lv, fn html -> assert html =~ "Players" end)
      assert html =~ "XYZ#987"

      lv
      |> element("button", "Disconnect")
      |> render_click()

      html = render_until(lv, fn html -> assert html =~ "No chat session in progress." end)
      refute html =~ "XYZ#987"
    end

    test "reacts to chat session end", %{conn: conn} do
      {:ok, pid} =
        ChatSessionRegistry.start_chat_session(chat_session_registry(), ["ABC#123", "XYZ#987"])

      {:ok, lv, _html} = live(conn, ~p"/chat")

      html = render_until(lv, fn html -> assert html =~ "Players" end)
      assert html =~ "XYZ#987"

      ChatSession.send_message(pid, "ABC#123", "test message")
      wait_until(fn -> assert render(lv) =~ "test message" end)

      ChatSession.end_session(pid)

      html = render_until(lv, fn html -> assert html =~ "No chat session in progress." end)
      refute html =~ "XYZ#987"
      refute html =~ "test message"
    end

    test "reacts to new chat session start", %{conn: conn} do
      {:ok, pid} =
        ChatSessionRegistry.start_chat_session(chat_session_registry(), ["ABC#123", "XYZ#987"])

      {:ok, lv, _html} = live(conn, ~p"/chat")

      html = render_until(lv, fn html -> assert html =~ "Players" end)
      assert html =~ "XYZ#987"

      ChatSession.send_message(pid, "ABC#123", "test message")
      wait_until(fn -> assert render(lv) =~ "test message" end)

      {:ok, _new_pid} =
        ChatSessionRegistry.start_chat_session(chat_session_registry(), ["ABC#123", "DEF#456"])

      wait_until(fn -> assert render(lv) =~ "DEF#456" end)
      html = render_until(lv, fn html -> refute html =~ "test message" end)
      refute html =~ "XYZ#987"
      refute html =~ "test message"
    end
  end
end
