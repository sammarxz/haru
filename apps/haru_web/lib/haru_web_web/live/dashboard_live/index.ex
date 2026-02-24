defmodule HaruWebWeb.DashboardLive.Index do
  @moduledoc """
  Real-time analytics dashboard LiveView — Fathom-style redesign.

  Subscribes to site PubSub on mount. Each new event triggers a stats reload
  and pushes updated chart/realtime data to JS hooks.
  """
  use HaruWebWeb, :live_view

  alias HaruCore.Analytics
  alias HaruCore.Sites
  alias HaruCore.Sites.Supervisor

  @default_period "today"

  @period_options [
    {"today", "Today"},
    {"yesterday", "Yesterday"},
    {"week", "This week"},
    {"month", "This month"},
    {"year", "This year"},
    {"30d", "30 days"},
    {"6m", "6 months"},
    {"12m", "12 months"},
    {"all", "All time"}
  ]

  @period_labels Map.new(@period_options)

  @impl true
  def mount(params, _session, socket) do
    user = socket.assigns.current_user

    sites = Sites.list_sites_for_user(user.id)
    site_id = resolve_site_id(params, sites)
    current_site = find_site(sites, site_id)
    period = resolve_period(params)

    socket =
      socket
      |> assign(:show_create_modal, false)
      |> assign(:show_site_dropdown, false)
      |> assign(:show_user_dropdown, false)
      |> assign(:show_snippet, false)
      |> assign(:snippet_copied, false)
      |> assign(:snippet_activated, false)
      |> assign(:show_period_dropdown, false)
      |> assign(:stats, nil)
      |> assign_site_changeset()
      |> assign(:sites, sites)
      |> assign(:current_site_id, site_id)
      |> assign(:current_site, current_site)
      |> assign(:period, period)
      |> assign(:pages_tab, "top")
      |> assign(:sources_tab, "referrer")
      |> assign(:locations_tab, "countries")
      |> assign(:devices_tab, "browsers")

    socket =
      if site_id && connected?(socket) do
        Phoenix.PubSub.subscribe(HaruCore.PubSub, "site:#{site_id}")
        Supervisor.ensure_started(site_id)
        load_site_data(socket, site_id, period)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    user = socket.assigns.current_user

    site_id =
      case params do
        %{"site_id" => id_str} -> parse_int(id_str)
        _ -> socket.assigns[:current_site_id]
      end

    period = resolve_period(params)
    old_site_id = socket.assigns[:current_site_id]

    if old_site_id && old_site_id != site_id do
      Phoenix.PubSub.unsubscribe(HaruCore.PubSub, "site:#{old_site_id}")
    end

    sites = Sites.list_sites_for_user(user.id)

    socket =
      if site_id && Enum.find(sites, &(&1.id == site_id)) do
        current_site = find_site(sites, site_id)

        if old_site_id != site_id do
          Phoenix.PubSub.subscribe(HaruCore.PubSub, "site:#{site_id}")
        end

        Supervisor.ensure_started(site_id)

        socket
        |> assign(:sites, sites)
        |> assign(:current_site_id, site_id)
        |> assign(:current_site, current_site)
        |> assign(:period, period)
        |> assign(:show_snippet, params["setup"] == "true")
        |> assign(:snippet_copied, false)
        |> assign(:snippet_activated, false)
        |> assign(:show_period_dropdown, false)
        |> load_site_data(site_id, period)
      else
        socket
        |> assign(:sites, sites)
        |> assign(:period, period)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_event, site_id}, socket) do
    if socket.assigns[:current_site_id] == site_id do
      socket = load_site_data(socket, site_id, socket.assigns.period)

      socket =
        if socket.assigns[:show_snippet] && socket.assigns[:snippet_copied] &&
             not socket.assigns[:snippet_activated] do
          Process.send_after(self(), :close_snippet, 2500)
          assign(socket, :snippet_activated, true)
        else
          socket
        end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:close_snippet, socket) do
    site_id = socket.assigns[:current_site_id]
    period = socket.assigns[:period]
    base_path = if site_id, do: "/dashboard/#{site_id}", else: "/dashboard"

    {:noreply,
     socket
     |> assign(:show_snippet, false)
     |> assign(:snippet_copied, false)
     |> assign(:snippet_activated, false)
     |> push_patch(to: "#{base_path}?period=#{period}")}
  end

  @impl true
  def handle_event("change_site", %{"site_id" => site_id_str}, socket) do
    {:noreply,
     push_patch(socket, to: "/dashboard/#{site_id_str}?period=#{socket.assigns.period}")}
  end

  @impl true
  def handle_event("change_period", %{"period" => period}, socket) do
    site_id = socket.assigns[:current_site_id]
    period = if period in Analytics.valid_periods(), do: period, else: @default_period
    base_path = if site_id, do: "/dashboard/#{site_id}", else: "/dashboard"

    {:noreply,
     socket
     |> assign(:show_period_dropdown, false)
     |> push_patch(to: "#{base_path}?period=#{period}")}
  end

  @impl true
  def handle_event("toggle_period_dropdown", _params, socket) do
    {:noreply, assign(socket, :show_period_dropdown, !socket.assigns.show_period_dropdown)}
  end

  @impl true
  def handle_event("set_tab", %{"table" => table, "tab" => tab}, socket) do
    key = :"#{table}_tab"
    {:noreply, assign(socket, key, tab)}
  end

  @impl true
  def handle_event("toggle_site_dropdown", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_site_dropdown, !socket.assigns.show_site_dropdown)
     |> assign(:show_user_dropdown, false)}
  end

  @impl true
  def handle_event("toggle_user_dropdown", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_user_dropdown, !socket.assigns.show_user_dropdown)
     |> assign(:show_site_dropdown, false)}
  end

  @impl true
  def handle_event("toggle_create_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_create_modal, !socket.assigns.show_create_modal)
     |> assign(:show_site_dropdown, false)
     |> assign_site_changeset()}
  end

  @impl true
  def handle_event("validate_site", %{"site" => params}, socket) do
    changeset =
      %HaruCore.Sites.Site{}
      |> HaruCore.Sites.change_site(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :site_changeset, to_form(changeset))}
  end

  @impl true
  def handle_event("save_site", %{"site" => params}, socket) do
    params = Map.put(params, "user_id", socket.assigns.current_user.id)

    case HaruCore.Sites.create_site(params) do
      {:ok, site} ->
        sites = socket.assigns.sites ++ [site]

        {:noreply,
         socket
         |> put_flash(:info, "Site created successfully.")
         |> assign(:sites, sites)
         |> assign(:show_create_modal, false)
         |> push_patch(to: "/dashboard/#{site.id}?period=#{socket.assigns.period}&setup=true")}

      {:error, changeset} ->
        {:noreply, assign(socket, :site_changeset, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("toggle_snippet", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_snippet, !socket.assigns.show_snippet)
     |> assign(:snippet_copied, false)
     |> assign(:snippet_activated, false)}
  end

  @impl true
  def handle_event("snippet_copied", _params, socket) do
    {:noreply, assign(socket, :snippet_copied, true)}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :period_options, @period_options)

    ~H"""
    <div class="min-h-screen bg-surface-card">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
      <.app_nav current_user={@current_user}>
        <:breadcrumb>
          <.site_selector
            sites={@sites}
            current_site={@current_site}
            current_site_id={@current_site_id}
            show_dropdown={@show_site_dropdown}
          />
        </:breadcrumb>
        <:right>
          <%= if @current_site do %>
            <button
              phx-click="toggle_snippet"
              class="text-sm font-medium"
              title="View tracking snippet"
            >
              Get snippet
            </button>
          <% end %>
        </:right>
      </.app_nav>

      <.snippet_panel
        current_site={@current_site}
        show_snippet={@show_snippet}
        snippet_copied={@snippet_copied}
        snippet_activated={@snippet_activated}
      />

      <main class="max-w-3xl mx-auto px-4 py-8">
        <%= if @current_site_id && @stats do %>
          <.period_selector
            period={@period}
            show_dropdown={@show_period_dropdown}
            options={@period_options}
          />
          <.stats_row stats={@stats} />
          <div class="w-full mb-12">
            <div
              id="pageview-chart"
              phx-hook="PageviewChart"
              phx-update="ignore"
              data-chart={Jason.encode!(@stats.chart_views)}
              data-period={@period}
              class="h-64"
            >
            </div>
          </div>
          <.data_panels
            stats={@stats}
            pages_tab={@pages_tab}
            sources_tab={@sources_tab}
            locations_tab={@locations_tab}
            devices_tab={@devices_tab}
          />
        <% else %>
          <.empty_state>
            <:icon_block>
              <img
                src={~p"/images/logo-symbol.svg"}
                width="52"
                height="52"
                class="grayscale opacity-50"
              />
            </:icon_block>
            <:title>
              <%= if @sites == [] do %>
                Welcome to Haru
              <% else %>
                Select a site to view analytics
              <% end %>
            </:title>
            <%= if @sites == [] do %>
              Get started by <button
                phx-click="toggle_create_modal"
                class="text-action-primary font-bold hover:underline"
              >adding your first site</button>.
            <% else %>
              Use the dropdown above to switch between sites.
            <% end %>
          </.empty_state>
        <% end %>
      </main>

      <.modal show={@show_create_modal}>
        <header class="mb-8">
          <h2 class="text-2xl font-bold text-text-primary tracking-tight">Add New Site</h2>
          <p class="text-sm text-text-secondary mt-1">Configure a new property for tracking.</p>
        </header>
        <.form for={@site_changeset} id="site-form" phx-change="validate_site" phx-submit="save_site">
          <div class="space-y-5">
            <.input
              field={@site_changeset[:name]}
              label="Site Name"
              placeholder="My Awesome Blog"
              required
            />
            <.input
              field={@site_changeset[:domain]}
              label="Domain"
              placeholder="blog.example.com"
              required
            />
            <div class="flex flex-col gap-3">
              <.button type="submit" phx-disable-with="Creating..." variant="strong">
                Create Site
              </.button>
              <.button type="button" phx-click="toggle_create_modal" variant="secondary">
                Cancel
              </.button>
            </div>
          </div>
        </.form>
      </.modal>
    </div>
    """
  end

  # ── Sub-components ───────────────────────────────────────────────────────────

  defp site_selector(assigns) do
    ~H"""
    <div class="relative">
      <button
        phx-click="toggle_site_dropdown"
        class="flex items-center gap-2 text-sm font-medium text-text-primary transition-colors py-1.5 px-2 rounded-md hover:bg-neutral-100"
      >
        <%= if @current_site do %>
          <div class="flex items-center justify-center text-xs font-bold">
            <img
              src={favicon_url(@current_site.domain)}
              class="w-5 h-5 size-full object-contain"
              onerror="this.style.display='none'; this.nextElementSibling.style.display='flex'"
            />
            <span class="hidden w-full h-full items-center justify-center text-xs">
              {String.first(@current_site.name || @current_site.domain) |> String.upcase()}
            </span>
          </div>
          {@current_site.name || @current_site.domain}
        <% else %>
          Select a site...
        <% end %>
        <.icon
          name="hero-chevron-up-down"
          class={"size-3.5 text-text-muted transition-transform " <> if(@show_dropdown, do: "rotate-180", else: "")}
        />
      </button>
      <%= if @show_dropdown do %>
        <.dropdown_menu
          show={@show_dropdown}
          on_click_away="toggle_site_dropdown"
          class="min-w-[200px]"
        >
          <.dropdown_header>Sites</.dropdown_header>
          <div class="max-h-60 overflow-y-auto px-1.5">
            <%= for site <- @sites do %>
              <div class={"w-full px-2 py-1 h-[32px] rounded-md flex items-center justify-between group transition-colors " <>
                if(site.id == @current_site_id, do: "hover:bg-neutral-100 text-text-primary", else: "text-text-primary hover:bg-neutral-100")}>
                <button
                  phx-click="change_site"
                  phx-value-site_id={site.id}
                  class="flex-1 flex items-center gap-2 text-left truncate"
                >
                  <div class="size-4 rounded-sm bg-neutral-100 flex-shrink-0 flex items-center justify-center overflow-hidden">
                    <img
                      src={favicon_url(site.domain)}
                      class="size-full object-contain"
                      onerror="this.style.display='none'; this.nextElementSibling.style.display='flex'"
                    />
                    <span class="hidden w-full h-full items-center justify-center text-[9px] font-bold">
                      {String.first(site.name || site.domain) |> String.upcase()}
                    </span>
                  </div>
                  <span class="font-medium truncate">{site.name || site.domain}</span>
                </button>
                <div class="flex items-center pl-2 opacity-0 group-hover:opacity-100 transition-opacity">
                  <a
                    href={"/sites/#{site.id}/settings"}
                    class="p-1 text-text-muted hover:text-text-primary transition-colors rounded"
                    title="Edit site"
                  >
                    <.icon name="hero-cog-6-tooth" class="size-3.5" />
                  </a>
                </div>
              </div>
            <% end %>
          </div>
          <.dropdown_divider />
          <.dropdown_item phx-click="toggle_create_modal" class="my-0 h-[32px]">
            <.icon name="hero-plus" class="size-4" /> Create new site
          </.dropdown_item>
        </.dropdown_menu>
      <% end %>
    </div>
    """
  end

  defp snippet_panel(assigns) do
    ~H"""
    <%= if @show_snippet && @current_site do %>
      <div class="bg-action-strong text-text-on-dark px-4 py-8 border-b border-border-default shadow-inner relative overflow-hidden">
        <div class="max-w-3xl mx-auto relative">
          <div class="flex items-start justify-between gap-6 mb-6">
            <div class="flex-1">
              <div class="flex items-center gap-2 mb-2">
                <span class="bg-action-primary text-text-on-brand text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full">
                  First Step
                </span>
                <p class="text-sm font-bold tracking-tight">
                  Install tracking for <span class="text-action-primary">{@current_site.name}</span>
                </p>
              </div>
              <p class="text-xs text-text-muted max-w-lg leading-relaxed">
                Paste this snippet inside the
                <code class="bg-action-strong-hover px-1 rounded text-text-on-dark font-mono">
                  &lt;head&gt;
                </code>
                tag of every page on <span class="text-text-on-dark font-medium underline underline-offset-2">{@current_site.domain}</span>.
              </p>
            </div>
            <button
              phx-click="toggle_snippet"
              class="bg-action-strong-hover hover:bg-white/10 text-text-muted hover:text-text-on-dark h-10 w-10 flex items-center justify-center cursor-pointer rounded-full transition-all"
              title="Close"
            >
              <.icon name="hero-x-mark" class="size-5" />
            </button>
          </div>
          <div class="relative group">
            <pre
              id="snippet-code"
              class="bg-action-strong-hover rounded-xl p-6 text-sm font-mono text-text-on-dark overflow-x-auto whitespace-pre-wrap break-all border border-white/5 shadow-lg"
            ><%= snippet_tag(@current_site) %></pre>
            <button
              id="copy-snippet-btn"
              phx-hook="CopyToClipboard"
              data-target="snippet-code"
              data-notify="snippet_copied"
              class="absolute top-4 right-4 text-[11px] font-bold bg-action-primary hover:bg-action-primary-hover text-text-on-brand px-4 py-2 rounded-md shadow-md transition-all active:scale-95 flex items-center gap-2"
            >
              <.icon name="hero-document-duplicate" class="size-3.5" /> Copy Code
            </button>
          </div>
          <%= if @snippet_activated do %>
            <div class="mt-4 flex items-center gap-2 text-status-success bg-status-success/10 border border-status-success/20 px-3 py-2.5 rounded-md animate-in fade-in slide-in-from-bottom-2">
              <.icon name="hero-check-circle" class="size-4" />
              <span class="text-sm font-bold">Snippet activated! Data is coming in.</span>
            </div>
          <% else %>
            <%= if @snippet_copied do %>
              <div class="mt-4 flex items-center gap-2 text-status-warning bg-status-warning/10 border border-status-warning/20 px-3 py-2.5 rounded-md animate-in fade-in slide-in-from-bottom-2">
                <.icon name="hero-arrow-path" class="size-4 animate-spin" />
                <span class="text-sm font-bold">Waiting for first pageview...</span>
              </div>
            <% else %>
              <p class="mt-4 text-[10px] text-text-muted flex items-center gap-1.5 animate-in fade-in">
                <.icon name="hero-information-circle" class="size-3.5" />
                Haru only starts tracking once the first visit is detected.
              </p>
            <% end %>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  defp period_selector(assigns) do
    ~H"""
    <div class="flex items-center justify-between mb-6">
      <div class="relative">
        <button
          phx-click="toggle_period_dropdown"
          class="flex items-center gap-2 text-[14px] font-medium text-text-primary bg-white border border-neutral-200 rounded-full px-3 py-1.5 hover:bg-neutral-100 shadow-[0_1px_2px_rgba(0,0,0,0.04)] transition-all active:scale-95"
        >
          {period_label(@period)}
          <.icon
            name="hero-chevron-up-down"
            class={"size-3.5 text-text-muted transition-transform " <> if(@show_dropdown, do: "rotate-180", else: "")}
          />
        </button>
        <%= if @show_dropdown do %>
          <.dropdown_menu
            show={@show_dropdown}
            on_click_away="toggle_period_dropdown"
            class="min-w-[200px]"
          >
            <.dropdown_header>Period</.dropdown_header>
            <div class="flex flex-col">
              <%= for {value, label} <- Enum.slice(@options, 0..4) do %>
                <.dropdown_item
                  phx-click="change_period"
                  phx-value-period={value}
                  active={@period == value}
                >
                  {label}
                  <%= if @period == value do %>
                    <span class="size-1.5 bg-action-primary rounded-full shadow-sm"></span>
                  <% end %>
                </.dropdown_item>
              <% end %>
              <.dropdown_divider />
              <%= for {value, label} <- Enum.slice(@options, 5..7) do %>
                <.dropdown_item
                  phx-click="change_period"
                  phx-value-period={value}
                  active={@period == value}
                >
                  {label}
                  <%= if @period == value do %>
                    <span class="size-1.5 bg-action-primary rounded-full shadow-sm"></span>
                  <% end %>
                </.dropdown_item>
              <% end %>
              <.dropdown_divider />
              <%= for {value, label} <- Enum.slice(@options, 8..8) do %>
                <.dropdown_item
                  phx-click="change_period"
                  phx-value-period={value}
                  active={@period == value}
                >
                  {label}
                  <%= if @period == value do %>
                    <span class="size-1.5 bg-action-primary rounded-full shadow-sm"></span>
                  <% end %>
                </.dropdown_item>
              <% end %>
            </div>
          </.dropdown_menu>
        <% end %>
      </div>
    </div>
    """
  end

  defp stats_row(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-8 mb-10 overflow-x-auto pb-2">
      <div class="flex flex-col min-w-[120px]">
        <div class="flex items-center gap-1.5 mb-1.5 opacity-80">
          <span class="text-sm font-medium text-text-secondary">Online now</span>
        </div>
        <span class="text-[28px] font-bold text-text-primary leading-none tracking-tight mb-2">
          {@stats.realtime_count}
        </span>
      </div>
      <.stat_card
        label="People"
        value={format_number(@stats.unique_visitors)}
        delta={@stats.visitors_change && format_change(@stats.visitors_change)}
        delta_positive={@stats.visitors_change && @stats.visitors_change >= 0}
      />
      <.stat_card
        label="Views"
        value={format_number(@stats.total_views)}
        delta={@stats.views_change && format_change(@stats.views_change)}
        delta_positive={@stats.views_change && @stats.views_change >= 0}
      />
      <.stat_card
        label="Bounced"
        value={"#{@stats.bounce_rate}%"}
        delta={@stats.bounce_change && format_change(@stats.bounce_change)}
        delta_positive={@stats.bounce_change && @stats.bounce_change <= 0}
      />
      <.stat_card
        label="Duration"
        value={format_duration(@stats.avg_duration_ms)}
        delta={@stats.duration_change && format_change(@stats.duration_change)}
        delta_positive={@stats.duration_change && @stats.duration_change >= 0}
      />
    </div>
    """
  end

  defp data_panels(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6 pb-24">
      <.panel id="pages-panel" title="Pages" active_tab={@pages_tab} table="pages">
        <:tab value="top" label="Top pages" />
        <% max = if @stats.top_pages != [], do: List.first(@stats.top_pages).count, else: 0 %>
        <%= for page <- @stats.top_pages do %>
          <.progress_row value={page.count} max={max}>
            <:title>{page.path}</:title>
          </.progress_row>
        <% end %>
        <%= if @stats.top_pages == [] do %>
          <p class="text-sm text-text-muted italic text-center py-4">No data yet</p>
        <% end %>
      </.panel>

      <.panel id="sources-panel" title="Sources" active_tab={@sources_tab} table="sources">
        <:tab value="referrer" label="Referrers" />
        <% max = if @stats.top_referrers != [], do: List.first(@stats.top_referrers).count, else: 0 %>
        <%= for ref <- @stats.top_referrers do %>
          <.progress_row value={ref.count} max={max}>
            <:title>{ref.referrer}</:title>
          </.progress_row>
        <% end %>
        <%= if @stats.top_referrers == [] do %>
          <p class="text-sm text-text-muted italic text-center py-4">No referrers yet</p>
        <% end %>
      </.panel>

      <.panel id="locations-panel" title="Locations" active_tab={@locations_tab} table="locations">
        <:tab value="countries" label="Countries" />
        <% max = if @stats.top_countries != [], do: List.first(@stats.top_countries).count, else: 0 %>
        <%= for country <- @stats.top_countries do %>
          <.progress_row value={country.count} max={max}>
            <:title>
              <span class="mr-1.5">{country_flag(country.country)}</span>{country.country}
            </:title>
          </.progress_row>
        <% end %>
        <%= if @stats.top_countries == [] do %>
          <p class="text-sm text-text-muted italic text-center py-4">No data yet</p>
        <% end %>
      </.panel>

      <.panel id="devices-panel" title="Devices" active_tab={@devices_tab} table="devices">
        <:tab value="browsers" label="Browsers" />
        <:tab value="os" label="OS" />
        <:tab value="devices" label="Devices" />
        <%= cond do %>
          <% @devices_tab == "browsers" -> %>
            <% max = if @stats.top_browsers != [], do: List.first(@stats.top_browsers).count, else: 0 %>
            <%= for item <- @stats.top_browsers do %>
              <.progress_row value={item.count} max={max}>
                <:title>{item.browser}</:title>
              </.progress_row>
            <% end %>
            <%= if @stats.top_browsers == [] do %>
              <p class="text-sm text-text-muted italic text-center py-4">No data yet</p>
            <% end %>
          <% @devices_tab == "os" -> %>
            <% max = if @stats.top_os != [], do: List.first(@stats.top_os).count, else: 0 %>
            <%= for item <- @stats.top_os do %>
              <.progress_row value={item.count} max={max}>
                <:title>{item.os}</:title>
              </.progress_row>
            <% end %>
            <%= if @stats.top_os == [] do %>
              <p class="text-sm text-text-muted italic text-center py-4">No data yet</p>
            <% end %>
          <% true -> %>
            <% max = if @stats.top_devices != [], do: List.first(@stats.top_devices).count, else: 0 %>
            <%= for item <- @stats.top_devices do %>
              <.progress_row value={item.count} max={max}>
                <:title>{item.device}</:title>
              </.progress_row>
            <% end %>
            <%= if @stats.top_devices == [] do %>
              <p class="text-sm text-text-muted italic text-center py-4">No data yet</p>
            <% end %>
        <% end %>
      </.panel>
    </div>
    """
  end

  # ── Private Helpers ─────────────────────────────────────────────────────────

  defp assign_site_changeset(socket) do
    assign(socket, :site_changeset, to_form(HaruCore.Sites.change_site(%HaruCore.Sites.Site{})))
  end

  defp find_site(sites, site_id), do: Enum.find(sites, &(&1.id == site_id))

  defp snippet_tag(site) do
    host = HaruWebWeb.Endpoint.url()

    ~s(<script defer\n  src="#{host}/js/haru.js"\n  data-token="#{site.api_token}"\n  data-api="#{host}">\n</script>)
  end

  defp resolve_site_id(%{"site_id" => id_str}, _sites), do: parse_int(id_str)
  defp resolve_site_id(_params, [%{id: id} | _]), do: id
  defp resolve_site_id(_params, _), do: nil

  defp resolve_period(%{"period" => period}) when is_binary(period) do
    if period in Analytics.valid_periods(), do: period, else: @default_period
  end

  defp resolve_period(_), do: @default_period

  defp period_label(period), do: Map.get(@period_labels, period, "Today")

  defp format_duration(nil), do: "—"

  defp format_duration(ms) do
    total_s = div(ms, 1000)
    m = div(total_s, 60)
    s = rem(total_s, 60)
    if m > 0, do: "#{m}m #{s}s", else: "#{s}s"
  end

  defp format_number(n) when n >= 1_000_000, do: "#{Float.round(n / 1_000_000, 1)}M"
  defp format_number(n) when n >= 1_000, do: "#{Float.round(n / 1_000, 1)}k"
  defp format_number(n), do: to_string(n)

  defp format_change(nil), do: ""
  defp format_change(n) when n >= 0, do: "+#{n}%"
  defp format_change(n), do: "#{n}%"

  defp load_site_data(socket, site_id, period) do
    stats = Analytics.get_stats(site_id, period)

    socket
    |> assign(:stats, stats)
    |> push_event("update_chart", %{chart: stats.chart_views, period: period})
    |> push_event("update_realtime", %{chart: stats.realtime_chart})
  end

  defp favicon_url(domain) when is_binary(domain) do
    clean = domain |> String.replace(~r/:\d+$/, "") |> String.trim_leading("www.")
    "https://icons.duckduckgo.com/ip3/#{clean}.ico"
  end

  defp favicon_url(_), do: ""

  defp country_flag(code) when is_binary(code) and byte_size(code) == 2 do
    code
    |> String.upcase()
    |> String.to_charlist()
    |> Enum.map(&(&1 + 127_397))
    |> List.to_string()
  end

  defp country_flag(_), do: "🌐"
end
