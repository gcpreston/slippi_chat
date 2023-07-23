defmodule SlippiChatWeb.GameLive.RootTest do
  use SlippiChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Phoenix.ChannelTest

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

  describe "Show" do
    ## Rendering

    test "renders empty state when there is no chat session", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/chat/abc-123")

      assert html =~ "ABC#123"
      assert html =~ "No chat session in progress."
    end

    test "renders chat session and its data when one exists", %{conn: conn} do
      player_codes = ["ABC#123", "XYZ#987"]
      {:ok, pid} = ChatSessionRegistry.start_chat_session(chat_session_registry(), player_codes)
      {:ok, message} = ChatSession.send_message(pid, "XYZ#987", "hello world!")
      {:ok, _lv, html} = live(conn, ~p"/chat/abc-123")

      assert html =~ "Chat session players:"
      Enum.each(player_codes, fn player_code -> assert html =~ player_code end)
      assert html =~ message.id
      assert html =~ "hello world!"
    end

    ## Events

    test "sends messages", %{conn: conn1} do
      player_codes = ["ABC#123", "XYZ#987"]
      ChatSessionRegistry.start_chat_session(chat_session_registry(), player_codes)

      conn2 = Phoenix.ConnTest.build_conn()
      {:ok, lv1, _html1} = live(conn1, ~p"/chat/abc-123")
      {:ok, lv2, _html2} = live(conn2, ~p"/chat/xyz-987")

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
      {:ok, lv, html} = live(conn, ~p"/chat/abc-123")
      assert html =~ "Chat session players:"
      Process.sleep(chat_session_timeout_ms())
      refute render(lv) =~ "Chat session players:"

      # Refresh

      {:ok, _pid} = ChatSessionRegistry.start_chat_session(chat_session_registry(), player_codes)
      {:ok, lv, html} = live(conn, ~p"/chat/abc-123")
      assert html =~ "Chat session players:"
      Process.sleep(div(chat_session_timeout_ms(), 2))

      lv
      |> element("#message-form")
      |> render_submit(%{message: %{content: "test message"}})

      Process.sleep(div(chat_session_timeout_ms(), 2))
      assert render(lv) =~ "Chat session players:"
      Process.sleep(chat_session_timeout_ms())
      refute render(lv) =~ "Chat session players:"
    end

    test "displays online status of client for each player code", %{conn: conn1} do
      player_codes = ["ABC#123", "XYZ#987"]
      ChatSessionRegistry.start_chat_session(chat_session_registry(), player_codes)
      Endpoint.subscribe("clients")

      conn2 = Phoenix.ConnTest.build_conn()
      {:ok, lv1, html1} = live(conn1, ~p"/chat/abc-123")
      {:ok, lv2, html2} = live(conn2, ~p"/chat/xyz-987")

      Enum.each([html1, html2], fn html ->
        refute html =~ "ABC#123 (online)"
        refute html =~ "XYZ#987 (online)"
      end)

      code_abc = "ABC#123"

      {:ok, _reply, socket_abc} =
        UserSocket
        |> socket("user_socket:#{code_abc}", %{client_code: code_abc})
        |> subscribe_and_join(ClientChannel, "clients")

      assert_broadcast "presence_diff", %{joins: %{^code_abc => _}}

      wait_until(fn ->
        Enum.each([render(lv1), render(lv2)], fn html ->
          assert html =~ "ABC#123 (online)"
          refute html =~ "XYZ#987 (online)"
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
          assert html =~ "ABC#123 (online)"
          assert html =~ "XYZ#987 (online)"
        end)
      end)

      Process.unlink(socket_abc.channel_pid)
      close(socket_abc)
      assert_broadcast "presence_diff", %{leaves: %{"ABC#123" => _}}

      wait_until(fn ->
        Enum.each([render(lv1), render(lv2)], fn html ->
          refute html =~ "ABC#123 (online)"
          assert html =~ "XYZ#987 (online)"
        end)
      end)
    end

    test "reacts to chat session end", %{conn: conn} do
      {:ok, pid} =
        ChatSessionRegistry.start_chat_session(chat_session_registry(), ["ABC#123", "XYZ#987"])

      {:ok, lv, html} = live(conn, ~p"/chat/abc-123")

      assert html =~ "Chat session players:"
      assert html =~ "XYZ#987"

      ChatSession.send_message(pid, "ABC#123", "test message")
      wait_until(fn -> assert render(lv) =~ "test message" end)

      ChatSession.end_session(pid)

      wait_until(fn -> assert render(lv) =~ "No chat session in progress." end)
      html = render(lv)
      refute html =~ "XYZ#987"
      refute html =~ "test message"
    end

    test "reacts to new chat session start", %{conn: conn} do
      {:ok, pid} =
        ChatSessionRegistry.start_chat_session(chat_session_registry(), ["ABC#123", "XYZ#987"])

      {:ok, lv, html} = live(conn, ~p"/chat/abc-123")

      assert html =~ "Chat session players:"
      assert html =~ "XYZ#987"

      ChatSession.send_message(pid, "ABC#123", "test message")
      wait_until(fn -> assert render(lv) =~ "test message" end)

      {:ok, _new_pid} =
        ChatSessionRegistry.start_chat_session(chat_session_registry(), ["ABC#123", "DEF#456"])

      wait_until(fn -> assert render(lv) =~ "DEF#456" end)
      wait_until(fn -> refute render(lv) =~ "test message" end)
      html = render(lv)
      refute html =~ "XYZ#987"
      refute html =~ "test message"
    end
  end
end
