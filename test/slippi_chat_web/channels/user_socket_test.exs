defmodule SlippiChatWeb.UserSocketTest do
  use SlippiChatWeb.ChannelCase, async: false

  alias SlippiChat.Auth
  alias SlippiChatWeb.UserSocket

  setup do
    %{socket: socket(UserSocket)}
  end

  describe "connect" do
    test "requires a session token", %{socket: socket} do
      client_code = "ABC#123"
      client_token = Auth.generate_admin_session_token(client_code)

      assert {:ok, socket} = UserSocket.connect(%{"client_token" => client_token}, socket)
      assert socket.assigns.client_code == client_code
    end

    test "refuses connection with no token specified", %{socket: socket} do
      assert UserSocket.connect(%{}, socket) == :error
    end

    test "refuses connection on invalid session token", %{socket: socket} do
      fake_token = "fake token"
      encoded_fake_token = Base.url_encode64("fake token", padding: false)

      assert UserSocket.connect(%{"client_token" => fake_token}, socket) == :error
      assert UserSocket.connect(%{"client_token" => encoded_fake_token}, socket) == :error
    end
  end
end
