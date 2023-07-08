defmodule SlippiChatWeb.GameLive.RootTest do
  use SlippiChatWeb.ConnCase, async: false
  # TODO: Inject ChatSessionRegistry name to LV, use one named
  #        after the test file, and async true

  import Phoenix.LiveViewTest
  import Phoenix.ChannelTest

  alias SlippiChatWeb.Endpoint
  alias SlippiChat.ChatSessionRegistry
  alias SlippiChat.ChatSessions.ChatSession
  alias SlippiChatWeb.ClientChannel

  defp chat_session_timeout_ms do
    Application.fetch_env!(:slippi_chat, :chat_session_timeout_ms)
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
      {:ok, pid} = ChatSessionRegistry.start_chat_session(ChatSessionRegistry, player_codes)
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
      ChatSessionRegistry.start_chat_session(ChatSessionRegistry, player_codes)

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

      {:ok, _pid} = ChatSessionRegistry.start_chat_session(ChatSessionRegistry, player_codes)
      {:ok, lv, html} = live(conn, ~p"/chat/abc-123")
      assert html =~ "Chat session players:"
      Process.sleep(chat_session_timeout_ms())
      refute render(lv) =~ "Chat session players:"

      # Refresh

      {:ok, _pid} = ChatSessionRegistry.start_chat_session(ChatSessionRegistry, player_codes)
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
      ChatSessionRegistry.start_chat_session(ChatSessionRegistry, player_codes)
      Endpoint.subscribe("clients")

      conn2 = Phoenix.ConnTest.build_conn()
      {:ok, lv1, html1} = live(conn1, ~p"/chat/abc-123")
      {:ok, lv2, html2} = live(conn2, ~p"/chat/xyz-987")

      Enum.each([html1, html2], fn html ->
        refute html =~ "ABC#123 (online)"
        refute html =~ "XYZ#987 (online)"
      end)

      {:ok, _reply, socket_abc} =
        UserSocket
        |> socket()
        |> subscribe_and_join(ClientChannel, "clients", %{"client_code" => "ABC#123"})

      assert_broadcast "presence_diff", %{joins: %{"ABC#123" => _}}

      Enum.each([render(lv1), render(lv2)], fn html ->
        assert html =~ "ABC#123 (online)"
        refute html =~ "XYZ#987 (online)"
      end)

      {:ok, _reply, _socket_xyz} =
        UserSocket
        |> socket()
        |> subscribe_and_join(ClientChannel, "clients", %{"client_code" => "XYZ#987"})

      assert_broadcast "presence_diff", %{joins: %{"XYZ#987" => _}}

      Enum.each([render(lv1), render(lv2)], fn html ->
        assert html =~ "ABC#123 (online)"
        assert html =~ "XYZ#987 (online)"
      end)

      Process.unlink(socket_abc.channel_pid)
      close(socket_abc)
      assert_broadcast "presence_diff", %{leaves: %{"ABC#123" => _}}

      Enum.each([render(lv1), render(lv2)], fn html ->
        refute html =~ "ABC#123 (online)"
        assert html =~ "XYZ#987 (online)"
      end)
    end
  end
end
