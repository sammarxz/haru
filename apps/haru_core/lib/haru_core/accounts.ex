defmodule HaruCore.Accounts do
  @moduledoc """
  Context for managing user accounts and sessions.
  """

  import Ecto.Changeset
  alias HaruCore.Accounts.{User, UserToken}
  alias HaruCore.Repo

  @doc """
  Registers a new user with email and password.
  Returns `{:ok, user}` or `{:error, changeset}`.
  """
  @spec register_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns a user matching the given email and password, or nil.
  """
  @spec get_user_by_email_and_password(String.t(), String.t()) :: User.t() | nil
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)

    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a user by ID.
  """
  @spec get_user!(pos_integer()) :: User.t()
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Generates a session token for the given user, persisting it to the DB.
  Returns the raw token binary (to be stored in the session cookie).
  """
  @spec generate_user_session_token(User.t()) :: binary()
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Returns the user associated with the given session token, if valid.
  """
  @spec get_user_by_session_token(binary()) :: User.t() | nil
  def get_user_by_session_token(token) do
    token
    |> UserToken.verify_session_token_query()
    |> Repo.one()
  end

  @doc """
  Deletes a session token, effectively logging the user out.
  """
  @spec delete_user_session_token(binary()) :: :ok
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.token_and_context_query(token, "session"))
    :ok
  end

  @doc """
  Deletes a user.
  """
  @spec delete_user(User.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Updates the user password after verifying the current password.
  On success, all existing session tokens are deleted — callers must
  re-authenticate (e.g. redirect to /login).
  """
  @spec update_user_password(User.t(), String.t(), map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> validate_password_verification(password)

    case Repo.update(changeset) do
      {:ok, user} ->
        delete_all_user_session_tokens(user)
        {:ok, user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Deletes all session tokens for the given user.
  Used after a password change to invalidate other active sessions.
  """
  @spec delete_all_user_session_tokens(User.t()) :: :ok
  def delete_all_user_session_tokens(user) do
    Repo.delete_all(UserToken.user_and_contexts_query(user, ["session"]))
    :ok
  end

  defp validate_password_verification(changeset, password) do
    if User.valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end

  @doc """
  Returns a changeset for tracking user changes.
  """
  @spec change_user_registration(User.t(), map()) :: Ecto.Changeset.t()
  def change_user_registration(user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end
end
