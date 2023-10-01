defmodule SlippiChat.Auth do
  @moduledoc """
  The Auth context.

  Based on mix phx.gen.auth.
  """

  import Ecto.Query, warn: false
  alias SlippiChat.Repo

  alias SlippiChat.Auth.{ClientToken, TokenGranter}

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(client_code) do
    {token, user_token} = ClientToken.build_session_token(client_code)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the connect code for the given signed token.
  """
  def get_client_code_by_session_token(token) do
    {:ok, query} = ClientToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(ClientToken.token_and_context_query(token, "session"))
    :ok
  end

  @doc """
  Generates a client token.

  Returns `:error` if the granter token is not valid.
  """
  def generate_granted_client_token(client_code, granter_token) do
    with {:ok, query} <- ClientToken.verify_hashed_token_query(granter_token, "client"),
         granter_code when not is_nil(granter_code) <- Repo.one(query) do
      build_and_insert_client_token(client_code, granter_code)
    else
      _ -> :error
    end
  end

  @doc """
  Generates a client token without a granter.
  """
  def generate_admin_client_token(client_code) do
    build_and_insert_client_token(client_code, nil)
  end

  defp build_and_insert_client_token(client_code, granter_code) do
    {token, client_token} = ClientToken.build_hashed_token(client_code, "client")

    Repo.transaction(fn ->
      client_token = Repo.insert!(client_token)

      if granter_code do
        Repo.insert!(%TokenGranter{granter_code: granter_code, client_token_id: client_token.id})
      end
    end)

    token
  end

  @doc """
  Gets the client_code for the given client token.

  Returns `nil` if the token doesn't exist or isn't valid.
  """
  def get_client_code_by_client_token(client_code) do
    get_client_code_by_signed_token(client_code, "client")
  end

  @doc """
  Generates a token for logging in a user.
  """
  def generate_login_token(client_code) do
    build_and_insert_signed_token(client_code, "login")
  end

  @doc """
  Gets the client_code for the given login token.

  Returns `nil` if the token doesn't exist or isn't valid.
  """
  def get_client_code_by_login_token(client_code) do
    get_client_code_by_signed_token(client_code, "login")
  end

  @doc """
  Removes all login tokens for a client_code from the database.
  """
  def delete_login_tokens(client_code) do
    query =
      from t in ClientToken,
        where: t.context == "login",
        where: t.client_code == ^client_code

    Repo.delete_all(query)
  end
  @doc """
  Gets the client_code for the given signed token.

  Returns `nil` if the token doesn't exist or isn't valid.
  """
  def get_client_code_by_signed_token(token, context) do
    with {:ok, query} <- ClientToken.verify_hashed_token_query(token, context) do
      Repo.one(query)
    else
      _ -> nil
    end
  end
end
