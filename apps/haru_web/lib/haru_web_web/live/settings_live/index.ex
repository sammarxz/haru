defmodule HaruWebWeb.SettingsLive.Index do
  use HaruWebWeb, :live_view

  alias HaruCore.Accounts
  alias HaruCore.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:page_title, "Settings")
     |> assign(:show_delete_modal, false)
     |> assign(:password_strength, 0)
     |> assign_password_changeset(user)}
  end

  @impl true
  def handle_event("validate_password", %{"user" => params}, socket) do
    changeset =
      socket.assigns.current_user
      |> Accounts.change_user_registration(params)
      |> Map.put(:action, :validate)

    strength = params |> Map.get("password", "") |> calc_password_strength()

    {:noreply,
     socket
     |> assign(:password_changeset, to_form(changeset))
     |> assign(:password_strength, strength)}
  end

  @impl true
  def handle_event("update_password", %{"user" => params}, socket) do
    %{"current_password" => current_password} = params

    case Accounts.update_user_password(socket.assigns.current_user, current_password, params) do
      {:ok, _user} ->
        # All session tokens were invalidated — redirect to login to re-authenticate.
        {:noreply,
         socket
         |> put_flash(:info, "Password updated. Please sign in again.")
         |> push_navigate(to: "/login")}

      {:error, changeset} ->
        {:noreply, assign(socket, :password_changeset, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("toggle_delete_modal", _params, socket) do
    {:noreply, assign(socket, :show_delete_modal, !socket.assigns.show_delete_modal)}
  end

  @impl true
  def handle_event("delete_account", _params, socket) do
    case Accounts.delete_user(socket.assigns.current_user) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Your account has been deleted.")
         |> push_navigate(to: "/")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not delete account. Please try again.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-surface-card">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
      <.app_nav current_user={@current_user}></.app_nav>

      <main class="max-w-3xl mx-auto px-4 py-12">
        <header class="mb-12">
          <h1 class="text-3xl font-bold text-text-primary tracking-tight">Account Settings</h1>
          <p class="text-sm text-text-secondary mt-2">
            Manage your profile and security preferences.
          </p>
        </header>

        <div class="space-y-6">
          <.section_card>
            <h3 class="text-base font-bold text-text-primary">Profile</h3>
            <p class="text-sm text-text-secondary mb-5">
              Your account information.
            </p>
            <.input
              name="email"
              label="Email address"
              value={@current_user && @current_user.email}
              readonly
              disabled
            />
            <:footer>
              <span class="text-xs text-text-muted">
                Email cannot be changed at this time.
              </span>
            </:footer>
          </.section_card>

          <.section_card>
            <h3 class="text-base font-bold text-text-primary">Security</h3>
            <p class="text-sm text-text-secondary mb-5">
              Update your password to keep your account secure.
            </p>
            <.form
              for={@password_changeset}
              id="password-form"
              phx-change="validate_password"
              phx-submit="update_password"
            >
              <div class="space-y-4">
                <.password_input
                  field={@password_changeset[:current_password]}
                  label="Current password"
                  required
                />
                <.password_input
                  field={@password_changeset[:password]}
                  label="New password"
                  required
                />
                <.password_strength strength={@password_strength} />
                <.password_input
                  field={@password_changeset[:password_confirmation]}
                  label="Confirm new password"
                  required
                />
              </div>
            </.form>
            <:footer>
              <div class="flex items-center justify-between">
                <span class="text-xs text-text-muted">Minimum 12 characters.</span>
                <.button
                  form="password-form"
                  type="submit"
                  variant="primary"
                  size="sm"
                  phx-disable-with="Updating..."
                >
                  Update password
                </.button>
              </div>
            </:footer>
          </.section_card>

          <div class="h-[1px] bg-neutral-200 w-full" />

          <.section_card variant="danger">
            <h3 class="text-base font-bold text-red-900">Delete account</h3>
            <p class="text-sm text-red-800">
              Once you delete your account, there is no going back. All your sites and analytics data will be permanently removed.
            </p>
            <:footer>
              <div class="flex items-center justify-between">
                <span class="text-xs text-red-800">Proceed with caution</span>
                <.button type="button" phx-click="toggle_delete_modal" variant="danger" size="sm">
                  Delete account
                </.button>
              </div>
            </:footer>
          </.section_card>
        </div>
      </main>

      <.modal show={@show_delete_modal} class="text-center">
        <div class="size-16 bg-status-error/10 text-status-error rounded-full flex items-center justify-center mx-auto mb-6">
          <.icon name="hero-exclamation-triangle" class="size-8" />
        </div>
        <h3 class="text-xl font-bold text-text-primary mb-2">Delete Account?</h3>
        <p class="text-sm text-text-secondary mb-8 leading-relaxed">
          You are about to permanently delete your account.
          All sites and analytics data will be wiped out from the platform.
        </p>
        <div class="flex flex-col gap-3">
          <.button type="button" phx-click="delete_account" variant="danger" class="w-full">
            Yes, delete my account
          </.button>
          <.button type="button" phx-click="toggle_delete_modal" variant="secondary" class="w-full">
            Cancel
          </.button>
        </div>
      </.modal>
    </div>
    """
  end

  defp assign_password_changeset(socket, user) do
    changeset =
      if user do
        Accounts.change_user_registration(user)
      else
        Accounts.change_user_registration(%User{})
      end

    assign(socket, :password_changeset, to_form(changeset))
  end
end
