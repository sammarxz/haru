defmodule HaruCore.AccountsTest do
  use HaruCore.DataCase, async: true

  alias HaruCore.Accounts
  alias HaruCore.Accounts.User

  describe "register_user/1" do
    test "creates a user with valid attrs" do
      attrs = %{email: "test@example.com", password: "correct_password123"}

      assert {:ok, user} = Accounts.register_user(attrs)
      assert user.email == "test@example.com"
      assert user.hashed_password != "correct_password123"
      assert is_nil(user.password)
    end

    test "returns error changeset with invalid email" do
      assert {:error, changeset} =
               Accounts.register_user(%{email: "invalid", password: "correct_password123"})

      assert %{email: [_]} = errors_on(changeset)
    end

    test "returns error changeset with short password" do
      assert {:error, changeset} =
               Accounts.register_user(%{email: "test@example.com", password: "short"})

      assert %{password: [_]} = errors_on(changeset)
    end

    test "returns error changeset with duplicate email" do
      attrs = %{email: "dup@example.com", password: "correct_password123"}
      {:ok, _user} = Accounts.register_user(attrs)
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert %{email: [_]} = errors_on(changeset)
    end
  end

  describe "get_user_by_email_and_password/2" do
    setup do
      {:ok, user} =
        Accounts.register_user(%{email: "auth@example.com", password: "correct_password123"})

      %{user: user}
    end

    test "returns user with correct credentials", %{user: user} do
      found = Accounts.get_user_by_email_and_password("auth@example.com", "correct_password123")
      assert found.id == user.id
    end

    test "returns nil with wrong password" do
      assert nil ==
               Accounts.get_user_by_email_and_password("auth@example.com", "wrong_password123")
    end

    test "returns nil with unknown email" do
      assert nil ==
               Accounts.get_user_by_email_and_password(
                 "nobody@example.com",
                 "correct_password123"
               )
    end
  end

  describe "session token" do
    setup do
      {:ok, user} =
        Accounts.register_user(%{email: "token@example.com", password: "correct_password123"})

      %{user: user}
    end

    test "generates and retrieves user by session token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert is_binary(token)
      assert found = Accounts.get_user_by_session_token(token)
      assert found.id == user.id
    end

    test "delete_user_session_token invalidates the token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert :ok = Accounts.delete_user_session_token(token)
      assert nil == Accounts.get_user_by_session_token(token)
    end

    test "delete_all_user_session_tokens invalidates all tokens for user", %{user: user} do
      token1 = Accounts.generate_user_session_token(user)
      token2 = Accounts.generate_user_session_token(user)
      assert :ok = Accounts.delete_all_user_session_tokens(user)
      assert nil == Accounts.get_user_by_session_token(token1)
      assert nil == Accounts.get_user_by_session_token(token2)
    end
  end

  describe "user management" do
    setup do
      {:ok, user} =
        Accounts.register_user(%{email: "mgmt@example.com", password: "correct_password123"})

      %{user: user}
    end

    test "get_user!/1 returns user", %{user: user} do
      assert Accounts.get_user!(user.id).id == user.id
    end

    test "delete_user/1 deletes user", %{user: user} do
      assert {:ok, _} = Accounts.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
    end

    test "update_user_password/3 updates password and invalidates tokens", %{user: user} do
      token = Accounts.generate_user_session_token(user)

      assert {:ok, updated_user} =
               Accounts.update_user_password(user, "correct_password123", %{
                 password: "new_password123456"
               })

      assert User.valid_password?(updated_user, "new_password123456")
      assert nil == Accounts.get_user_by_session_token(token)
    end

    test "update_user_password/3 fails with invalid current password", %{user: user} do
      assert {:error, changeset} =
               Accounts.update_user_password(user, "wrong", %{
                 password: "new_password123456"
               })

      assert "is not valid" in errors_on(changeset).current_password
    end
  end
end
