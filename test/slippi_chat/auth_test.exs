defmodule SlippiChat.AuthTest do
  use SlippiChat.DataCase, async: true

  alias SlippiChat.Auth
  alias SlippiChat.Auth.{ClientToken, TokenGranter}

  describe "generate_user_session_token/1" do
    setup do
      %{client_code: "ABC#123"}
    end

    test "generates a token", %{client_code: client_code} do
      token = Auth.generate_user_session_token(client_code)
      assert user_token = Repo.get_by(ClientToken, token: token)
      assert user_token.context == "session"

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%ClientToken{
          token: user_token.token,
          client_code: client_code,
          context: "session"
        })
      end
    end
  end

  describe "get_client_code_by_session_token/1" do
    setup do
      client_code = "ABC#123"
      token = Auth.generate_user_session_token(client_code)
      %{client_code: client_code, token: token}
    end

    test "returns client code by token", %{client_code: client_code, token: token} do
      assert session_code = Auth.get_client_code_by_session_token(token)
      assert session_code == client_code
    end

    test "does not return client code for invalid token" do
      refute Auth.get_client_code_by_session_token("oops")
    end

    test "does not return client code for expired token", %{token: token} do
      {1, nil} = Repo.update_all(ClientToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Auth.get_client_code_by_session_token(token)
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      client_code = "ABC#123"
      token = Auth.generate_user_session_token(client_code)
      assert Auth.delete_user_session_token(token) == :ok
      refute Auth.get_client_code_by_session_token(token)
    end
  end

  describe "generate_granted_client_token/2" do
    test "generates a client token" do
      granter_code = "ABC#123"
      granter_token = Auth.generate_admin_client_token(granter_code)

      client_code = "DEF#456"
      token = Auth.generate_granted_client_token(client_code, granter_token)
      {:ok, token} = Base.url_decode64(token, padding: false)

      assert client_token = Repo.get_by(ClientToken, token: :crypto.hash(:sha256, token))
      assert client_token.context == "client"
      assert client_token.client_code == client_code

      assert granter = Repo.get_by(TokenGranter, client_token_id: client_token.id)
      assert granter.granter_code == granter_code
    end

    test "does not generate a token with an invalid granter token" do
      assert Auth.generate_granted_client_token("ABC#123", "invalid token") == :error
    end
  end

  describe "generate_admin_client_token/1" do
    test "generates a client token" do
      client_code = "ABC#123"
      token = Auth.generate_admin_client_token(client_code)
      {:ok, token} = Base.url_decode64(token, padding: false)

      assert client_token = Repo.get_by(ClientToken, token: :crypto.hash(:sha256, token))
      assert client_token.context == "client"
      assert client_token.client_code == client_code
    end
  end

  describe "get_client_code_by_signed_token/2" do
    test "returns the client code for a valid token" do
      client_code = "ABC#123"
      token = Auth.generate_admin_client_token(client_code)

      assert Auth.get_client_code_by_signed_token(token, "client") == client_code
    end

    test "returns `nil` for an invalid token" do
      assert Auth.get_client_code_by_signed_token(":)", "client") == nil

      assert Auth.get_client_code_by_signed_token(
               Base.url_encode64(":)", padding: false),
               "client"
             ) == nil
    end
  end
end
