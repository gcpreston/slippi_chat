defmodule SlippiChat.Auth.ClientToken do
  use Ecto.Schema
  import Ecto.Query

  @hash_algorithm :sha256
  @rand_size 32

  @session_validity_in_days 60

  schema "clients_tokens" do
    field :client_code, :string
    field :token, :binary
    field :context, :string

    timestamps(updated_at: false)
  end

  @doc """
  Generates a token that will be stored in a signed place,
  such as session or cookie. As they are signed, those
  tokens do not need to be hashed.

  The reason why we store session tokens in the database, even
  though Phoenix already provides a session cookie, is because
  Phoenix' default session cookies are not persisted, they are
  simply signed and potentially encrypted. This means they are
  valid indefinitely, unless you change the signing/encryption
  salt.

  Therefore, storing them allows individual user
  sessions to be expired. The token system can also be extended
  to store additional data, such as the device used for logging in.
  You could then use this information to display all valid sessions
  and devices in the UI and allow users to explicitly expire any
  session they deem invalid.
  """
  def build_session_token(client_code) do
    token = :crypto.strong_rand_bytes(@rand_size)

    {token,
     %SlippiChat.Auth.ClientToken{token: token, context: "session", client_code: client_code}}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the token's client code.

  The token is valid if it matches the value in the database and it has
  not expired (after @session_validity_in_days).
  """
  def verify_session_token_query(token) do
    query =
      from token in token_and_context_query(token, "session"),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        select: token.client_code

    {:ok, query}
  end

  @doc """
  Builds a token and its hash to be delivered to the client.

  The non-hashed token is sent to the client while the
  hashed part is stored in the database. The original token cannot be reconstructed,
  which means anyone with read-only access to the database cannot directly use
  the token in the application to gain access.
  """
  def build_hashed_token(client_code, context) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {Base.url_encode64(token, padding: false),
     %SlippiChat.Auth.ClientToken{
       token: hashed_token,
       context: context,
       client_code: client_code
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
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)
        # days = days_for_context(context)

        query =
          from token in token_and_context_query(hashed_token, context),
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
    from SlippiChat.Auth.ClientToken, where: [token: ^token, context: ^context]
  end
end
