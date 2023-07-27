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
      Repo.insert!(%TokenGranter{granter_code: granter_code, client_token_id: client_token.id})
    end)

    token
  end

  @doc """
  Gets the client_code for the given signed token.

  Returns `nil` if the token doesn't exist or isn't valid.
  """
  def get_client_code_by_client_token(token) do
    with {:ok, query} <- ClientToken.verify_hashed_token_query(token, "client") do
      Repo.one(query)
    else
      _ -> nil
    end
  end

  @doc """
  Deletes a client token.
  """
  def delete_client_token(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        Repo.delete_all(ClientToken.token_and_context_query(decoded_token, "client"))
        :ok

      :error ->
        :error
    end
  end
end
