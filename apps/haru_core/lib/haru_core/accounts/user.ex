defmodule HaruCore.Accounts.User do
  @moduledoc "Ecto schema for a Haru user account."
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field(:email, :string)
    field(:hashed_password, :string, redact: true)
    field(:password, :string, virtual: true, redact: true)
    field(:confirmed_at, :utc_datetime)

    has_many(:sites, HaruCore.Sites.Site)
    has_many(:tokens, HaruCore.Accounts.UserToken)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for registering a new user. Validates email uniqueness,
  password length, and hashes the password.
  """
  @spec registration_changeset(%__MODULE__{}, map(), keyword()) :: Ecto.Changeset.t()
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_email(opts)
    |> validate_password(opts)
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    |> maybe_hash_password(opts)
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, HaruCore.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)

    if hash_password? && changeset.valid? do
      changeset
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(get_change(changeset, :password)))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Changeset for updating an existing user's password.
  Validates the new password and hashes it. Does not touch email.
  """
  @spec password_changeset(%__MODULE__{}, map(), keyword()) :: Ecto.Changeset.t()
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Verifies the password against the stored hash.
  Returns true if the password is correct, false otherwise.
  Always performs a hash comparison to prevent timing attacks.
  """
  @spec valid_password?(%__MODULE__{}, String.t()) :: boolean()
  def valid_password?(%__MODULE__{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end
