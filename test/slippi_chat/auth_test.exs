defmodule SlippiChat.AuthTest do
  use SlippiChat.DataCase, async: true

  alias SlippiChat.Auth
  alias SlippiChat.Auth.ClientToken

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
      assert client_token.granter_code == granter_code
      assert client_token.granter_token == granter_token
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

  describe "get_client_code_by_client_token/1" do
    test "returns the client code for a valid token" do
      client_code = "ABC#123"
      token = Auth.generate_admin_client_token(client_code)

      assert Auth.get_client_code_by_client_token(token) == client_code
    end

    test "returns `nil` for an invalid token" do
      assert Auth.get_client_code_by_client_token(":)") == nil
      assert Auth.get_client_code_by_client_token(Base.url_encode64(":)", padding: false)) == nil
    end
  end

  describe "delete_client_token/1" do
    test "deletes a valid token" do
      client_code = "ABC#123"
      token = Auth.generate_admin_client_token(client_code)
      {:ok, decoded_token} = Base.url_decode64(token, padding: false)

      assert %ClientToken{} =
               Repo.get_by(ClientToken, token: :crypto.hash(:sha256, decoded_token))

      assert Auth.delete_client_token(token) == :ok
      assert Repo.get_by(ClientToken, token: :crypto.hash(:sha256, decoded_token)) == nil
    end

    test "returns :error if token is not base64" do
      assert Auth.delete_client_token(":)") == :error
    end

    test "deletes nothing if token is not valid" do
      count_before = Repo.aggregate(ClientToken, :count, :id)
      assert Auth.delete_client_token(Base.url_encode64(":)", padding: false)) == :ok
      count_after = Repo.aggregate(ClientToken, :count, :id)
      assert count_before == count_after
    end
  end
end
