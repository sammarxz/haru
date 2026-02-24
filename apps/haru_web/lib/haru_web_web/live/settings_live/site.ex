defmodule HaruWebWeb.SettingsLive.Site do
  use HaruWebWeb, :live_view

  alias HaruCore.Sites

  @impl true
  def mount(%{"id" => id_str}, _session, socket) do
    user = socket.assigns.current_user
    id = parse_int(id_str)

    case id && Sites.get_site(id) do
      nil ->
        {:ok, push_navigate(socket, to: "/dashboard")}

      site when site.user_id != user.id ->
        {:ok, push_navigate(socket, to: "/dashboard")}

      site ->
        changeset = Sites.change_site(site)
        sharing_changeset = Sites.change_site_sharing(site)

        {:ok,
         socket
         |> assign(:site, site)
         |> assign(:settings_changeset, to_form(changeset))
         |> assign(:sharing_changeset, to_form(sharing_changeset))
         |> assign(:show_delete_modal, false)}
    end
  end

  @impl true
  def handle_event("validate_settings", %{"site" => params}, socket) do
    changeset =
      socket.assigns.site
      |> Sites.change_site(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :settings_changeset, to_form(changeset))}
  end

  @impl true
  def handle_event("update_site", %{"site" => params}, socket) do
    case Sites.update_site(socket.assigns.site, params) do
      {:ok, site} ->
        {:noreply,
         socket
         |> put_flash(:info, "Site updated successfully.")
         |> assign(:site, site)
         |> assign(:settings_changeset, to_form(Sites.change_site(site)))}

      {:error, changeset} ->
        {:noreply, assign(socket, :settings_changeset, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("validate_sharing", %{"site" => params}, socket) do
    changeset =
      socket.assigns.site
      |> Sites.change_site_sharing(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :sharing_changeset, to_form(changeset))}
  end

  @impl true
  def handle_event("update_sharing", %{"site" => params}, socket) do
    case Sites.update_site_sharing(socket.assigns.site, params) do
      {:ok, site} ->
        {:noreply,
         socket
         |> put_flash(:info, "Sharing settings updated.")
         |> assign(:site, site)
         |> assign(:sharing_changeset, to_form(Sites.change_site_sharing(site)))}

      {:error, changeset} ->
        {:noreply, assign(socket, :sharing_changeset, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("toggle_delete_modal", _params, socket) do
    {:noreply, assign(socket, :show_delete_modal, !socket.assigns.show_delete_modal)}
  end

  @impl true
  def handle_event("delete_site", _params, socket) do
    case Sites.delete_site(socket.assigns.site) do
      {:ok, _site} ->
        {:noreply,
         socket
         |> put_flash(:info, "Site deleted successfully.")
         |> push_navigate(to: "/dashboard")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not delete site.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-surface-card">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
      <.app_nav current_user={@current_user}></.app_nav>
      
    <!-- Main Layout -->
      <main class="max-w-3xl mx-auto px-4 py-12">
        <header class="mb-12">
          <h1 class="text-3xl font-bold text-text-primary tracking-tight">Settings</h1>
          <p class="text-sm text-text-secondary mt-2">
            Manage your project <strong>"{@site.domain}"</strong>.
          </p>
        </header>
        <div class="space-y-6 ">
          <.section_card>
            <h3 class="text-base font-bold text-text-primary">Project settings</h3>
            <p class="text-sm text-text-secondary mb-5">
              The configuration to identify your project.
            </p>
            <.form
              for={@settings_changeset}
              id="settings-form"
              phx-change="validate_settings"
              phx-submit="update_site"
            >
              <div class="space-y-4">
                <.input
                  field={@settings_changeset[:name]}
                  label="Project name"
                  placeholder="My Awesome Project"
                  required
                />
                <.input
                  field={@settings_changeset[:domain]}
                  label="Domain"
                  placeholder="example.com"
                  required
                />
              </div>
            </.form>
            <:footer>
              <div class="flex items-center justify-between">
                <span class="text-xs text-text-muted">Maximum of 30 characters for the name</span>
                <.button
                  form="settings-form"
                  type="submit"
                  variant="primary"
                  size="sm"
                >
                  Save
                </.button>
              </div>
            </:footer>
          </.section_card>

          <.section_card>
            <h3 class="text-base font-bold text-text-primary">Project token</h3>
            <p class="text-sm text-text-secondary mb-5">
              A unique token assigned to your project API.
            </p>
            <div class="relative">
              <.input
                field={@settings_changeset[:api_token]}
                label="Project token"
                placeholder="My Awesome Project"
                value={@site.api_token}
                readonly
                class="w-full"
              />
            </div>
            <:footer>
              <div class="flex items-center justify-between">
                <span class="text-xs text-text-muted">
                  Used to identify your project on the pipeline
                </span>
                <.button
                  id="copy-token-btn"
                  phx-click="copy_to_clipboard"
                  data-target="project-token"
                  size="sm"
                  variant="primary"
                >
                  Copy
                </.button>
              </div>
            </:footer>
          </.section_card>

          <.section_card>
            <h3 class="text-base font-bold text-text-primary">Script Tags</h3>
            <p class="text-sm text-text-secondary mb-5">
              To start collecting data, embed this on your site &lt;head&gt;.
            </p>
            <div class="relative">
              <pre
                id="project-snippet"
                class="bg-action-strong text-text-on-dark rounded-xl px-5 py-4 text-xs font-mono break-all whitespace-pre-wrap leading-relaxed"
              >&lt;script defer src="<%= HaruWebWeb.Endpoint.url() %>/js/haru.js" data-token="{@site.api_token}"&gt;&lt;/script&gt;</pre>
            </div>
            <:footer>
              <div class="flex items-center justify-between">
                <span class="text-xs text-text-muted">It must be loaded in all routes.</span>
                <.button
                  id="copy-snippet-btn"
                  phx-hook="CopyToClipboard"
                  data-target="project-snippet"
                  variant="primary"
                  size="sm"
                >
                  Copy
                </.button>
              </div>
            </:footer>
          </.section_card>

          <.section_card>
            <h3 class="text-base font-bold text-text-primary">Public Sharing</h3>
            <p class="text-sm text-text-secondary mb-5">
              Share your dashboard with anyone — no login required.
            </p>
            <.form
              for={@sharing_changeset}
              id="sharing-form"
              phx-change="validate_sharing"
              phx-submit="update_sharing"
            >
              <div class="space-y-4">
                <.input
                  field={@sharing_changeset[:is_public]}
                  type="checkbox"
                  label="Make this site public"
                />
                <.input
                  field={@sharing_changeset[:slug]}
                  label="Public URL slug"
                  placeholder="my-blog"
                />
                <%= if @site.slug && @site.slug != "" && @site.is_public do %>
                  <div class="mt-1">
                    <p class="text-xs text-text-muted mb-1">Public dashboard URL:</p>
                    <pre
                      id="share-url"
                      class="bg-action-strong text-text-on-dark rounded-xl px-4 py-3 text-xs font-mono break-all whitespace-pre-wrap"
                    ><%= HaruWebWeb.Endpoint.url() %>/share/<%= @site.slug %></pre>
                  </div>
                <% end %>
              </div>
            </.form>
            <:footer>
              <div class="flex items-center justify-end gap-2">
                <%= if @site.slug && @site.slug != "" && @site.is_public do %>
                  <.button
                    id="copy-share-url"
                    phx-hook="CopyToClipboard"
                    data-target="share-url"
                    variant="secondary"
                    size="sm"
                  >
                    Copy URL
                  </.button>
                <% end %>
                <.button form="sharing-form" type="submit" variant="primary" size="sm">
                  Save
                </.button>
              </div>
            </:footer>
          </.section_card>

          <div class="h-[1px] bg-neutral-200 w-full " />

          <.section_card variant="danger">
            <h3 class="text-base font-bold text-red-900">Delete project</h3>
            <p class="text-sm text-red-800">
              Permanently delete your project and all of its stats. This action is practically immediate, and cannot be undone.
            </p>
            <:footer>
              <div class="flex items-center justify-between">
                <span class="text-xs text-red-800">Proceed with caution</span>
                <.button type="button" phx-click="toggle_delete_modal" variant="danger" size="sm">
                  Delete
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
        <h3 class="text-xl font-bold text-text-primary mb-2">Delete Project?</h3>
        <p class="text-sm text-text-secondary mb-8 leading-relaxed">
          You are about to permanently delete <strong class="text-text-primary">{@site.name}</strong>.
          All analytics and metrics will be wiped out from the platform.
        </p>
        <div class="flex flex-col gap-3">
          <.button type="button" phx-click="delete_site" variant="danger" class="w-full">
            Yes, delete project
          </.button>
          <.button type="button" phx-click="toggle_delete_modal" variant="secondary" class="w-full">
            Cancel
          </.button>
        </div>
      </.modal>
    </div>
    """
  end
end
