defmodule HaruWebWeb.RegistrationLive do
  use HaruWebWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :password_strength, 0)}
  end

  @impl true
  def handle_event("validate", params, socket) do
    password = get_in(params, ["password"]) || ""
    {:noreply, assign(socket, :password_strength, calc_password_strength(password))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-surface-card px-4">
      <div class="max-w-md w-full p-8 bg-surface-card rounded-2xl">
        <div class="text-center mb-8">
          <a href="/" class="inline-flex items-center gap-2 mb-4">
            <img src="/images/logo-symbol.svg" width="52" height="52" />
          </a>
          <h1 class="text-2xl font-bold text-text-primary tracking-tight">Create your account</h1>
          <p class="mt-1 text-sm text-text-secondary font-medium">
            Start tracking your website with Haru
          </p>
        </div>

        <.flash kind={:error} flash={@flash} />

        <form method="post" action="/register" phx-change="validate" class="space-y-2">
          <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
          <.input
            type="email"
            name="email"
            id="email"
            label="Email"
            placeholder="your@email.com"
            required
          />
          <.password_input
            id="password"
            name="password"
            label="Password"
            placeholder="••••••••••••"
            required
          />
          <.password_strength strength={@password_strength} />
          <div class="pt-2">
            <.button type="submit" variant="strong" class="w-full">
              Create account
            </.button>
          </div>
        </form>

        <p class="mt-8 text-center text-sm text-text-secondary font-medium">
          Already have an account?
          <a href="/login" class="text-action-primary font-bold hover:underline">Sign in</a>
        </p>
      </div>
    </div>
    """
  end
end
