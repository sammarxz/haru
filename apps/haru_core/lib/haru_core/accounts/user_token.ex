defmodule HaruCore.Accounts.UserToken do
  @moduledoc "Ecto schema for user session tokens."
  use Ecto.Schema
  import Ecto.Query

  @rand_size 32
  @session_validity_in_days 60

  schema "user_tokens" do
    field(:token, :binary)
    field(:context, :string)
    field(:sent_to, :string)

    belongs_to(:user, HaruCore.Accounts.User)

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Builds a session token for the given user.
  Returns {token_binary, user_token_struct}.
  """
  @spec build_session_token(HaruCore.Accounts.User.t()) ::
          {binary(), %__MODULE__{}}
  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)

    {token,
     %__MODULE__{
       token: token,
       context: "session",
       user_id: user.id
     }}
  end

  @doc """
  Returns a query to fetch the user for a given session token,
  verifying the token has not expired.
  """
  @spec verify_session_token_query(binary()) :: Ecto.Query.t()
  def verify_session_token_query(token) do
    from(token in token_and_context_query(token, "session"),
      join: user in assoc(token, :user),
      where: token.inserted_at > ago(@session_validity_in_days, "day"),
      select: user
    )
  end

  @doc """
  Returns a query to find a token by its value and context.
  """
  @spec token_and_context_query(binary(), String.t()) :: Ecto.Query.t()
  def token_and_context_query(token, context) do
    from(__MODULE__, where: [token: ^token, context: ^context])
  end

  @doc """
  Returns a query to fetch all tokens for a user in a given context.
  """
  @spec user_and_contexts_query(HaruCore.Accounts.User.t(), list(String.t()) | :all) ::
          Ecto.Query.t()
  def user_and_contexts_query(user, :all) do
    from(t in __MODULE__, where: t.user_id == ^user.id)
  end

  def user_and_contexts_query(user, [_ | _] = contexts) do
    from(t in __MODULE__, where: t.user_id == ^user.id and t.context in ^contexts)
  end
end
