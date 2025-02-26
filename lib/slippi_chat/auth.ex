defmodule SlippiChat.Auth do
  @moduledoc """
  The Auth context.

  Based on mix phx.gen.auth.
  """

  import Ecto.Query, warn: false
  alias SlippiChat.Repo

  alias SlippiChat.Auth.{ClientToken, TokenGranter, User}

  @doc """
  Determines if a user has the priviledge to grant new client tokens.
  """
  def has_granter_status?(%User{is_admin: is_admin}), do: is_admin

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
  Gets the user for the given signed token.
  """
  def get_user_by_session_token(token) do
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
         granter when not is_nil(granter) <- Repo.one(query) do
      build_and_insert_client_token(client_code, granter.connect_code)
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
  Gets the user for the given client token.

  Returns `nil` if the token doesn't exist or isn't valid.
  """
  def get_user_by_client_token(client_token) do
    get_user_by_signed_token(client_token, "client")
  end

  @doc """
  Generates a token to be used in the magic login flow.
  """
  def generate_magic_token(client_code) do
    build_and_insert_signed_token(client_code, "magic")
  end

  @doc """
  Gets the user for the given magic token.

  Returns `nil` if the token doesn't exist or isn't valid.
  """
  def get_user_by_magic_token(magic_token) do
    get_user_by_signed_token(magic_token, "magic")
  end

  @doc """
  Generates a token for logging in a user.
  """
  def generate_login_token(client_code) do
    build_and_insert_signed_token(client_code, "login")
  end

  @doc """
  Gets the user for the given login token.

  Returns `nil` if the token doesn't exist or isn't valid.
  """
  def get_user_by_login_token(login_token) do
    get_user_by_signed_token(login_token, "login")
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

  defp build_and_insert_signed_token(client_code, context) do
    {token, client_token} = ClientToken.build_hashed_token(client_code, context)
    Repo.insert!(client_token)
    token
  end

  @doc """
  Gets the user for the given signed token.

  Returns `nil` if the token doesn't exist or isn't valid.
  """
  def get_user_by_signed_token(token, context) do
    with {:ok, query} <- ClientToken.verify_hashed_token_query(token, context) do
      Repo.one(query)
    else
      _ -> nil
    end
  end

  @doc """
  Registers a user.

  ## Examples

    iex> register_user(%{field: value})
    {:ok, %User{}, "some_client_token"}

    iex> register_user(%{field: bad_value})
    {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    with {:ok, user} <- %User{} |> User.registration_changeset(attrs) |> Repo.insert() do
      token = generate_admin_client_token(user.connect_code)
      {:ok, user, token}
    end
  end
end
