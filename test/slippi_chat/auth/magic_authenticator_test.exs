defmodule SlippiChat.Auth.MagicAuthenticatorTest do
  use SlippiChat.DataCase, async: true

  alias SlippiChat.Auth.MagicAuthenticator

  setup %{test: name} do
    client_code = "ABC#123"
    pid = start_supervised!({MagicAuthenticator, name: name})
    Ecto.Adapters.SQL.Sandbox.allow(SlippiChat.Repo, self(), pid)

    %{pid: pid, client_code: client_code}
  end

  describe "register_verification_code/2" do
    test "generates a verification code", %{pid: pid, client_code: client_code} do
      verification_code = MagicAuthenticator.register_verification_code(pid, client_code)
      assert Regex.match?(~r/^\d{6}$/, verification_code)
    end
  end

  describe "verify/3" do
    setup %{pid: pid, client_code: client_code} do
      verification_code = MagicAuthenticator.register_verification_code(pid, client_code)
      %{verification_code: verification_code}
    end

    test "verifies a valid client code + verification code combo", %{
      pid: pid,
      client_code: client_code,
      verification_code: verification_code
    } do
      assert MagicAuthenticator.verify(pid, client_code, verification_code) == true
    end

    test "does not verify a valid verification code with the wrong client code", %{
      pid: pid,
      verification_code: verification_code
    } do
      assert MagicAuthenticator.verify(pid, "XYZ#987", verification_code) == false
    end

    test "does not verify a valid client code with the wrong verification", %{
      pid: pid,
      client_code: client_code,
      verification_code: verification_code
    } do
      assert MagicAuthenticator.verify(pid, client_code, verification_code <> "fake") == false
    end

    test "does not verify a valid client code + verification code combo twice", %{
      pid: pid,
      client_code: client_code,
      verification_code: verification_code
    } do
      assert MagicAuthenticator.verify(pid, client_code, verification_code) == true
      assert MagicAuthenticator.verify(pid, client_code, verification_code) == false
    end
  end
end
