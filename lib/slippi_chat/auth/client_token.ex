defmodule SlippiChat.Auth.ClientToken do
  use Ecto.Schema
  import Ecto.Query

  @hash_algorithm :sha256
  @rand_size 32

  schema "clients_tokens" do
    field :client_code, :string
    field :token, :binary
    field :context, :string
    field :granter_code, :string
    field :granter_token, :binary

    timestamps(updated_at: false)
  end

  @doc """
  Builds a token and its hash to be delivered to the client.

  The non-hashed token is sent to the client while the
  hashed part is stored in the database. The original token cannot be reconstructed,
  which means anyone with read-only access to the database cannot directly use
  the token in the application to gain access.
  """
  def build_hashed_token(client_code, context, granter_code, granter_token) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {Base.url_encode64(token, padding: false),
     %SlippiChat.Auth.ClientToken{
       token: hashed_token,
       context: context,
       client_code: client_code,
       granter_code: granter_code,
       granter_token: granter_token
     }}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the client_code associated with the token, if any.

  The given token is valid if it matches its hashed counterpart in the
  database.
  """
  def verify_hashed_token_query(token, context) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        # days = days_for_context(context)

        query =
          from token in token_and_context_query(decoded_token, context),
            # where: token.inserted_at > ago(^days, "day") and token.sent_to == user.email,
            select: token.client_code

        {:ok, query}

      :error ->
        :error
    end
  end

  @doc """
  Returns the token struct for the given token value and context.
  """
  def token_and_context_query(token, context) do
    hashed_token = :crypto.hash(@hash_algorithm, token)
    from SlippiChat.Auth.ClientToken, where: [token: ^hashed_token, context: ^context]
  end
end
