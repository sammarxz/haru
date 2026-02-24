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
        token = Accounts.generate_user_session_token(user)

        conn
        |> put_session(:user_token, token)
        |> put_flash(:info, "Account created successfully!")
        |> redirect(to: "/dashboard")

      {:error, changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Enum.reduce(opts, msg, fn {key, value}, acc ->
              value_str =
                if is_list(value),
                  do: Enum.map_join(value, ", ", &to_string/1),
                  else: to_string(value)

              String.replace(acc, "%{#{key}}", value_str)
            end)
          end)
          |> Enum.map_join(", ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)

        conn
        |> put_flash(:error, errors)
        |> redirect(to: "/register")
    end
  end
end
