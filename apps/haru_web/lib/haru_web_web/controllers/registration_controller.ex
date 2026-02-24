defmodule HaruWebWeb.RegistrationController do
  use HaruWebWeb, :controller

  alias HaruCore.Accounts

  def new(conn, _params) do
    changeset = Accounts.change_user_registration(%HaruCore.Accounts.User{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"email" => email, "password" => password}) do
    case Accounts.register_user(%{email: email, password: password}) do
      {:ok, user} ->
        handle_registration_success(conn, user)

      {:error, changeset} ->
        handle_registration_error(conn, changeset)
    end
  end

  defp handle_registration_success(conn, user) do
    token = Accounts.generate_user_session_token(user)

    conn
    |> put_session(:user_token, token)
    |> put_flash(:info, "Account created successfully!")
    |> redirect(to: "/dashboard")
  end

  defp handle_registration_error(conn, changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
      |> Enum.map_join(", ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)

    conn
    |> put_flash(:error, errors)
    |> redirect(to: "/register")
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      value_str = if is_list(value), do: Enum.join(value, ", "), else: to_string(value)
      String.replace(acc, "%{#{key}}", value_str)
    end)
  end
end
