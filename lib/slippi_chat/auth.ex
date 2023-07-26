defmodule SlippiChat.Auth do
  @moduledoc """
  The Auth context.

  Based on mix phx.gen.auth.
  """

  import Ecto.Query, warn: false
  alias SlippiChat.Repo

  alias SlippiChat.Auth.ClientToken

  ## Session

  @doc """
  Generates a session token.

  Returns `:error` if the granter token is not valid.
  """
  def generate_granted_session_token(client_code, granter_token) do
    with {:ok, query} <- ClientToken.verify_hashed_token_query(granter_token, "session"),
         granter_code when not is_nil(granter_code) <- Repo.one(query) do
      build_and_insert_token(client_code, granter_code, granter_token)
    else
      _ -> :error
    end
  end

  @doc """
  Generates a session token without a granter.
  """
  def generate_admin_session_token(client_code) do
    build_and_insert_token(client_code, nil, nil)
  end

  defp build_and_insert_token(client_code, granter_code, granter_token) do
    {token, client_token} =
      ClientToken.build_hashed_token(client_code, "session", granter_code, granter_token)

    Repo.insert!(client_token)
    token
  end

  @doc """
  Gets the client_code for the given signed token.

  Returns `nil` if the token doesn't exist or isn't valid.
  """
  def get_client_code_by_session_token(token) do
    with {:ok, query} <- ClientToken.verify_hashed_token_query(token, "session") do
      Repo.one(query)
    else
      _ -> nil
    end
  end

  @doc """
  Deletes a session token.
  """
  def delete_session_token(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        Repo.delete_all(ClientToken.token_and_context_query(decoded_token, "session"))
        :ok

      :error ->
        :error
    end
  end
end
