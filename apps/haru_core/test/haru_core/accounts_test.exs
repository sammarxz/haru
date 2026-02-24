defmodule HaruCore.AccountsTest do
  use HaruCore.DataCase, async: true

  alias HaruCore.Accounts

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
  end
end
