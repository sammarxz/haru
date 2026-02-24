defmodule HaruWebWeb.PublicDashboardLive.Index do
  @moduledoc """
  Read-only public analytics dashboard. Accessible without login via /share/:slug.
  Only renders if the site has is_public: true.
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
  def mount(%{"slug" => slug}, _session, socket) do
    case Sites.get_site_by_slug(slug) do
      nil ->
        {:ok, push_navigate(socket, to: "/")}

      site ->
        period = @default_period

        socket =
          socket
          |> assign(:site, site)
          |> assign(:period, period)
          |> assign(:show_period_dropdown, false)
          |> assign(:stats, nil)
          |> assign(:pages_tab, "top")
          |> assign(:sources_tab, "referrer")
          |> assign(:locations_tab, "countries")
          |> assign(:devices_tab, "browsers")

        socket =
          if connected?(socket) do
            Phoenix.PubSub.subscribe(HaruCore.PubSub, "site:#{site.id}")
            Supervisor.ensure_started(site.id)
            load_site_data(socket, site.id, period)
          else
            socket
          end

        {:ok, socket}
    end
  end

  @impl true
  def handle_info({:new_event, site_id}, socket) do
    if socket.assigns.site.id == site_id do
      {:noreply, load_site_data(socket, site_id, socket.assigns.period)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("change_period", %{"period" => period}, socket) do
    period = if period in Analytics.valid_periods(), do: period, else: @default_period

    socket =
      socket
      |> assign(:show_period_dropdown, false)
      |> assign(:period, period)
      |> load_site_data(socket.assigns.site.id, period)

    {:noreply, socket}
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
  def render(assigns) do
    assigns = assign(assigns, :period_options, @period_options)

    ~H"""
    <div class="min-h-screen bg-surface-card">
      <!-- Public nav — no user dropdown, no site selector -->
      <nav class="sticky top-0 z-30 bg-surface-card border-b border-border-default">
        <div class="max-w-3xl mx-auto px-4 h-14 flex items-center justify-between gap-4">
          <div class="flex items-center gap-3">
            <a href="/" class="flex items-center gap-2 shrink-0">
              <img src="/images/logo-symbol.svg" width="24" height="24" alt="Haru" />
            </a>
            <span class="text-text-muted">/</span>
            <div class="flex items-center gap-2 truncate">
              <div class="size-5 rounded-sm bg-neutral-100 flex-shrink-0 flex items-center justify-center overflow-hidden">
                <img
                  src={favicon_url(@site.domain)}
                  class="size-full object-contain"
                  onerror="this.style.display='none'; this.nextElementSibling.style.display='flex'"
                />
                <span class="hidden w-full h-full items-center justify-center text-[10px] font-bold">
                  {String.first(@site.name || @site.domain) |> String.upcase()}
                </span>
              </div>
              <span class="text-sm font-medium text-text-primary truncate">
                {@site.name || @site.domain}
              </span>
            </div>
          </div>
          <a
            href={site_url(@site.domain)}
            target="_blank"
            rel="noopener noreferrer"
            class="text-xs text-text-muted hidden sm:flex items-center gap-1 hover:text-text-secondary transition-colors"
          >
            {@site.domain}
            <.icon name="hero-arrow-top-right-on-square" class="size-3" />
          </a>
        </div>
      </nav>

      <main class="max-w-3xl mx-auto px-4 py-8">
        <%= if @stats do %>
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
        <% end %>
      </main>

      <footer class="border-t border-border-default py-6 mt-8">
        <p class="text-center text-xs text-text-muted">
          Analytics powered by <a href="/" class="font-medium text-text-secondary hover:underline">Haru</a>
        </p>
      </footer>
    </div>
    """
  end

  # ── Sub-components ───────────────────────────────────────────────────────────

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

  # ── Private Helpers ──────────────────────────────────────────────────────────

  defp load_site_data(socket, site_id, period) do
    stats = Analytics.get_stats(site_id, period)

    socket
    |> assign(:stats, stats)
    |> push_event("update_chart", %{chart: stats.chart_views, period: period})
    |> push_event("update_realtime", %{chart: stats.realtime_chart})
  end

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

  defp favicon_url(domain) when is_binary(domain) do
    clean = domain |> String.replace(~r/:\d+$/, "") |> String.trim_leading("www.")
    "https://icons.duckduckgo.com/ip3/#{clean}.ico"
  end

  defp favicon_url(_), do: ""

  defp site_url(domain) when is_binary(domain) do
    if String.starts_with?(domain, "http"), do: domain, else: "https://#{domain}"
  end

  defp site_url(_), do: "#"

  defp country_flag(code) when is_binary(code) and byte_size(code) == 2 do
    code
    |> String.upcase()
    |> String.to_charlist()
    |> Enum.map(&(&1 + 127_397))
    |> List.to_string()
  end

  defp country_flag(_), do: "🌐"
end
