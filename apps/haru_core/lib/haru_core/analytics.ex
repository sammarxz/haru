defmodule HaruCore.Analytics do
  @moduledoc """
  Context for tracking analytics events and computing aggregated stats.

  Stats are cached in ETS for 60 seconds per (site_id, period) pair.
  Cache is fully invalidated for a site when a new event is recorded.

  Supported periods: today, yesterday, week, month, year, 30d, 6m, 12m, all
  """

  import Ecto.Query
  alias HaruCore.Analytics.Event
  alias HaruCore.Cache.StatsCache
  alias HaruCore.Repo
  alias HaruCore.Sites.{SiteServer, Supervisor}

  @valid_periods ~w(today yesterday week month year 30d 6m 12m all)
  @default_period "today"

  @doc """
  Hashes a raw IP string to a SHA-256 hex digest for GDPR-compliant storage.
  """
  @spec hash_ip(String.t()) :: String.t()
  def hash_ip(ip) when is_binary(ip) do
    :crypto.hash(:sha256, ip) |> Base.encode16(case: :lower)
  end

  @doc """
  Persists a new analytics event to the database.
  Accepts either `ip_hash` (pre-hashed) or `ip` (raw, will be hashed internally).
  """
  @spec create_event(map()) :: {:ok, Event.t()} | {:error, Ecto.Changeset.t()}
  def create_event(attrs) do
    attrs_with_hash = prepare_ip_attr(attrs)

    %Event{}
    |> Event.changeset(attrs_with_hash)
    |> Repo.insert()
  end

  @doc """
  Returns aggregated stats for a site and period, using ETS cache when available.
  Falls back to `compute_stats/2` on cache miss and stores the result.
  """
  @spec get_stats(pos_integer(), String.t()) :: map()
  def get_stats(site_id, period \\ @default_period) do
    period = if period in @valid_periods, do: period, else: @default_period

    case StatsCache.get(site_id, period) do
      nil ->
        stats = compute_stats(site_id, period)
        StatsCache.put(site_id, period, stats)
        stats

      stats ->
        stats
    end
  end

  @doc """
  Computes fresh stats directly from the database for the given period.
  """
  @spec compute_stats(pos_integer(), String.t()) :: map()
  def compute_stats(site_id, period \\ @default_period) do
    since = period_start(period)
    until_ = period_end(period)

    base =
      from(e in Event,
        where: e.site_id == ^site_id and e.inserted_at >= ^since and e.name == "pageview"
      )

    base = if until_, do: from(e in base, where: e.inserted_at < ^until_), else: base

    # Duration events are a separate event type sent on page hide — never counted as views
    duration_base =
      from(e in Event,
        where:
          e.site_id == ^site_id and e.inserted_at >= ^since and
            e.name == "duration" and e.duration_ms > 0
      )

    duration_base =
      if until_, do: from(e in duration_base, where: e.inserted_at < ^until_), else: duration_base

    total_views = Repo.aggregate(base, :count, :id) || 0

    unique_visitors =
      Repo.one(from(e in base, select: count(e.ip_hash, :distinct))) || 0

    # Bounce rate: visitors with only one pageview
    bounced =
      Repo.one(
        from(
          outer in subquery(
            from(e in base,
              group_by: e.ip_hash,
              select: %{ip_hash: e.ip_hash, cnt: count(e.id)}
            )
          ),
          where: outer.cnt == 1,
          select: count(outer.ip_hash)
        )
      ) || 0

    bounce_rate =
      if unique_visitors > 0,
        do: round(bounced / unique_visitors * 100),
        else: 0

    avg_duration_ms =
      Repo.one(from(e in duration_base, select: type(avg(e.duration_ms), :integer)))

    # Previous period for % change — skipped for "all time" (no meaningful prior period)
    {views_change, visitors_change, bounce_change, duration_change} =
      if period == "all" do
        {nil, nil, nil, nil}
      else
        prev_since = prev_period_start(period)
        prev_until = since

        prev_base =
          from(e in Event,
            where:
              e.site_id == ^site_id and
                e.inserted_at >= ^prev_since and
                e.inserted_at < ^prev_until and
                e.name == "pageview"
          )

        prev_views = Repo.aggregate(prev_base, :count, :id) || 0
        prev_visitors = Repo.one(from(e in prev_base, select: count(e.ip_hash, :distinct))) || 0

        prev_bounced =
          Repo.one(
            from(
              outer in subquery(
                from(e in prev_base,
                  group_by: e.ip_hash,
                  select: %{ip_hash: e.ip_hash, cnt: count(e.id)}
                )
              ),
              where: outer.cnt == 1,
              select: count(outer.ip_hash)
            )
          ) || 0

        prev_bounce_rate =
          if prev_visitors > 0, do: round(prev_bounced / prev_visitors * 100), else: 0

        prev_duration_base =
          from(e in Event,
            where:
              e.site_id == ^site_id and
                e.inserted_at >= ^prev_since and
                e.inserted_at < ^prev_until and
                e.name == "duration" and
                e.duration_ms > 0
          )

        prev_duration =
          Repo.one(from(e in prev_duration_base, select: type(avg(e.duration_ms), :integer)))

        {
          compute_change_pct(total_views, prev_views),
          compute_change_pct(unique_visitors, prev_visitors),
          compute_change_pct(bounce_rate, prev_bounce_rate),
          compute_change_pct(avg_duration_ms || 0, prev_duration || 0)
        }
      end

    top_pages =
      Repo.all(
        from(e in base,
          group_by: e.path,
          select: %{path: e.path, count: count(e.id)},
          order_by: [desc: count(e.id)],
          limit: 10
        )
      )

    top_referrers =
      Repo.all(
        from(e in base,
          where: not is_nil(e.referrer) and e.referrer != "",
          group_by: e.referrer,
          select: %{referrer: e.referrer, count: count(e.id)},
          order_by: [desc: count(e.id)],
          limit: 10
        )
      )

    top_countries =
      Repo.all(
        from(e in base,
          where: not is_nil(e.country) and e.country != "",
          group_by: e.country,
          select: %{country: e.country, count: count(e.id)},
          order_by: [desc: count(e.id)],
          limit: 10
        )
      )

    top_browsers = query_browsers(base)
    top_os = query_os(base)
    top_devices = query_devices(base)

    chart_views = query_chart_views(base, period)
    realtime_count = active_visitor_count(site_id)
    realtime_chart_data = realtime_chart(site_id)

    %{
      period: period,
      total_views: total_views,
      unique_visitors: unique_visitors,
      bounce_rate: bounce_rate,
      avg_duration_ms: avg_duration_ms,
      views_change: views_change,
      visitors_change: visitors_change,
      bounce_change: bounce_change,
      duration_change: duration_change,
      top_pages: top_pages,
      top_referrers: top_referrers,
      top_countries: top_countries,
      top_browsers: top_browsers,
      top_os: top_os,
      top_devices: top_devices,
      chart_views: chart_views,
      realtime_count: realtime_count,
      realtime_chart: realtime_chart_data
    }
  end

  @doc "Returns realtime chart: 5-minute buckets over the last 30 minutes."
  @spec realtime_chart(pos_integer()) :: list(map())
  def realtime_chart(site_id) do
    since = DateTime.add(DateTime.utc_now(), -30 * 60, :second)

    Repo.all(
      from(e in Event,
        where: e.site_id == ^site_id and e.inserted_at >= ^since and e.name == "pageview",
        group_by:
          fragment(
            "date_trunc('hour', ?) + (date_part('minute', ?)::int / 5) * interval '5 min'",
            e.inserted_at,
            e.inserted_at
          ),
        select: %{
          bucket:
            fragment(
              "date_trunc('hour', ?) + (date_part('minute', ?)::int / 5) * interval '5 min'",
              e.inserted_at,
              e.inserted_at
            ),
          count: count(e.id)
        },
        order_by: [
          asc:
            fragment(
              "date_trunc('hour', ?) + (date_part('minute', ?)::int / 5) * interval '5 min'",
              e.inserted_at,
              e.inserted_at
            )
        ]
      )
    )
  end

  @doc """
  Returns the number of events recorded for a site in the last N seconds.
  """
  @spec recent_event_count(pos_integer(), pos_integer()) :: non_neg_integer()
  def recent_event_count(site_id, seconds \\ 60) do
    since = DateTime.add(DateTime.utc_now(), -seconds, :second)

    Repo.aggregate(
      from(e in Event, where: e.site_id == ^site_id and e.inserted_at >= ^since),
      :count,
      :id
    )
  end

  @doc "Returns the list of valid period values."
  @spec valid_periods() :: [String.t()]
  def valid_periods, do: @valid_periods

  # ── Private Helpers ─────────────────────────────────────────────────────────

  # Uses in-memory SiteServer when available; falls back to a DB count otherwise.
  defp active_visitor_count(site_id) do
    case Registry.lookup(HaruCore.SiteRegistry, site_id) do
      [{_pid, _}] ->
        SiteServer.active_visitor_count(site_id)

      [] ->
        # Server not started yet — fall back to DB count for this request only.
        Supervisor.ensure_started(site_id)
        realtime_db_count(site_id)
    end
  end

  defp realtime_db_count(site_id) do
    since = DateTime.add(DateTime.utc_now(), -30 * 60, :second)

    Repo.one(
      from(e in Event,
        where: e.site_id == ^site_id and e.inserted_at >= ^since and e.name == "pageview",
        select: count(e.ip_hash, :distinct)
      )
    ) || 0
  end

  defp period_start("today"),
    do: DateTime.new!(Date.utc_today(), ~T[00:00:00], "Etc/UTC")

  defp period_start("yesterday"),
    do: Date.utc_today() |> Date.add(-1) |> DateTime.new!(~T[00:00:00], "Etc/UTC")

  defp period_start("week") do
    today = Date.utc_today()
    Date.add(today, -(Date.day_of_week(today) - 1)) |> DateTime.new!(~T[00:00:00], "Etc/UTC")
  end

  defp period_start("month") do
    today = Date.utc_today()
    Date.new!(today.year, today.month, 1) |> DateTime.new!(~T[00:00:00], "Etc/UTC")
  end

  defp period_start("year") do
    Date.new!(Date.utc_today().year, 1, 1) |> DateTime.new!(~T[00:00:00], "Etc/UTC")
  end

  defp period_start("30d"),
    do: DateTime.add(DateTime.utc_now(), -30 * 24 * 60 * 60, :second)

  defp period_start("6m"),
    do: DateTime.add(DateTime.utc_now(), -180 * 24 * 60 * 60, :second)

  defp period_start("12m"),
    do: DateTime.add(DateTime.utc_now(), -365 * 24 * 60 * 60, :second)

  defp period_start("all"), do: ~U[2000-01-01 00:00:00Z]
  defp period_start(_), do: period_start("today")

  # "yesterday" is the only complete bounded period — it must stop at midnight today.
  # All other periods run from their start up to "now", which is correct.
  defp period_end("yesterday"),
    do: DateTime.new!(Date.utc_today(), ~T[00:00:00], "Etc/UTC")

  defp period_end(_), do: nil

  defp prev_period_start("today"),
    do: Date.utc_today() |> Date.add(-1) |> DateTime.new!(~T[00:00:00], "Etc/UTC")

  defp prev_period_start("yesterday"),
    do: Date.utc_today() |> Date.add(-2) |> DateTime.new!(~T[00:00:00], "Etc/UTC")

  defp prev_period_start("week") do
    today = Date.utc_today()
    Date.add(today, -(Date.day_of_week(today) - 1) - 7) |> DateTime.new!(~T[00:00:00], "Etc/UTC")
  end

  defp prev_period_start("month") do
    today = Date.utc_today()
    prev = Date.add(Date.new!(today.year, today.month, 1), -1)
    Date.new!(prev.year, prev.month, 1) |> DateTime.new!(~T[00:00:00], "Etc/UTC")
  end

  defp prev_period_start("year") do
    Date.new!(Date.utc_today().year - 1, 1, 1) |> DateTime.new!(~T[00:00:00], "Etc/UTC")
  end

  defp prev_period_start("30d"),
    do: DateTime.add(DateTime.utc_now(), -60 * 24 * 60 * 60, :second)

  defp prev_period_start("6m"),
    do: DateTime.add(DateTime.utc_now(), -360 * 24 * 60 * 60, :second)

  defp prev_period_start("12m"),
    do: DateTime.add(DateTime.utc_now(), -730 * 24 * 60 * 60, :second)

  defp prev_period_start("all"), do: ~U[2000-01-01 00:00:00Z]
  defp prev_period_start(_), do: prev_period_start("today")

  defp compute_change_pct(_, 0), do: nil

  defp compute_change_pct(current, previous),
    do: round((current - previous) / previous * 100)

  defp query_chart_views(base, period) when period in ["today", "yesterday"] do
    Repo.all(
      from(e in base,
        group_by: fragment("date_trunc('hour', ?)", e.inserted_at),
        select: %{
          bucket: fragment("date_trunc('hour', ?)", e.inserted_at),
          count: count(e.id)
        },
        order_by: [asc: fragment("date_trunc('hour', ?)", e.inserted_at)]
      )
    )
  end

  defp query_chart_views(base, period) when period in ["week", "30d", "month"] do
    Repo.all(
      from(e in base,
        group_by: fragment("date_trunc('day', ?)", e.inserted_at),
        select: %{
          bucket: fragment("date_trunc('day', ?)", e.inserted_at),
          count: count(e.id)
        },
        order_by: [asc: fragment("date_trunc('day', ?)", e.inserted_at)]
      )
    )
  end

  defp query_chart_views(base, period) when period in ["6m"] do
    Repo.all(
      from(e in base,
        group_by: fragment("date_trunc('week', ?)", e.inserted_at),
        select: %{
          bucket: fragment("date_trunc('week', ?)", e.inserted_at),
          count: count(e.id)
        },
        order_by: [asc: fragment("date_trunc('week', ?)", e.inserted_at)]
      )
    )
  end

  defp query_chart_views(base, _period) do
    Repo.all(
      from(e in base,
        group_by: fragment("date_trunc('month', ?)", e.inserted_at),
        select: %{
          bucket: fragment("date_trunc('month', ?)", e.inserted_at),
          count: count(e.id)
        },
        order_by: [asc: fragment("date_trunc('month', ?)", e.inserted_at)]
      )
    )
  end

  defp query_browsers(base) do
    Repo.all(
      from(e in base,
        where: not is_nil(e.user_agent),
        group_by:
          fragment(
            "CASE WHEN ? ILIKE '%Edg/%' THEN 'Edge' WHEN ? ILIKE '%OPR%' OR ? ILIKE '%Opera%' THEN 'Opera' WHEN ? ILIKE '%Firefox%' THEN 'Firefox' WHEN ? ILIKE '%Chrome%' THEN 'Chrome' WHEN ? ILIKE '%Safari%' THEN 'Safari' ELSE 'Other' END",
            e.user_agent,
            e.user_agent,
            e.user_agent,
            e.user_agent,
            e.user_agent,
            e.user_agent
          ),
        select: %{
          browser:
            fragment(
              "CASE WHEN ? ILIKE '%Edg/%' THEN 'Edge' WHEN ? ILIKE '%OPR%' OR ? ILIKE '%Opera%' THEN 'Opera' WHEN ? ILIKE '%Firefox%' THEN 'Firefox' WHEN ? ILIKE '%Chrome%' THEN 'Chrome' WHEN ? ILIKE '%Safari%' THEN 'Safari' ELSE 'Other' END",
              e.user_agent,
              e.user_agent,
              e.user_agent,
              e.user_agent,
              e.user_agent,
              e.user_agent
            ),
          count: count(e.id)
        },
        order_by: [desc: count(e.id)],
        limit: 10
      )
    )
  end

  defp query_os(base) do
    Repo.all(
      from(e in base,
        where: not is_nil(e.user_agent),
        group_by:
          fragment(
            "CASE WHEN ? ILIKE '%Android%' THEN 'Android' WHEN ? ILIKE '%iPhone%' OR ? ILIKE '%iPad%' THEN 'iOS' WHEN ? ILIKE '%Windows%' THEN 'Windows' WHEN ? ILIKE '%Mac OS%' THEN 'macOS' WHEN ? ILIKE '%Linux%' THEN 'Linux' ELSE 'Other' END",
            e.user_agent,
            e.user_agent,
            e.user_agent,
            e.user_agent,
            e.user_agent,
            e.user_agent
          ),
        select: %{
          os:
            fragment(
              "CASE WHEN ? ILIKE '%Android%' THEN 'Android' WHEN ? ILIKE '%iPhone%' OR ? ILIKE '%iPad%' THEN 'iOS' WHEN ? ILIKE '%Windows%' THEN 'Windows' WHEN ? ILIKE '%Mac OS%' THEN 'macOS' WHEN ? ILIKE '%Linux%' THEN 'Linux' ELSE 'Other' END",
              e.user_agent,
              e.user_agent,
              e.user_agent,
              e.user_agent,
              e.user_agent,
              e.user_agent
            ),
          count: count(e.id)
        },
        order_by: [desc: count(e.id)],
        limit: 10
      )
    )
  end

  defp query_devices(base) do
    Repo.all(
      from(e in base,
        where: not is_nil(e.user_agent),
        group_by:
          fragment(
            "CASE WHEN ? ILIKE '%Mobile%' OR ? ILIKE '%Android%' THEN 'Mobile' WHEN ? ILIKE '%iPad%' OR ? ILIKE '%Tablet%' THEN 'Tablet' ELSE 'Desktop' END",
            e.user_agent,
            e.user_agent,
            e.user_agent,
            e.user_agent
          ),
        select: %{
          device:
            fragment(
              "CASE WHEN ? ILIKE '%Mobile%' OR ? ILIKE '%Android%' THEN 'Mobile' WHEN ? ILIKE '%iPad%' OR ? ILIKE '%Tablet%' THEN 'Tablet' ELSE 'Desktop' END",
              e.user_agent,
              e.user_agent,
              e.user_agent,
              e.user_agent
            ),
          count: count(e.id)
        },
        order_by: [desc: count(e.id)],
        limit: 10
      )
    )
  end

  defp prepare_ip_attr(%{ip: ip} = attrs) when is_binary(ip) do
    attrs |> Map.delete(:ip) |> Map.put(:ip_hash, hash_ip(ip))
  end

  defp prepare_ip_attr(attrs), do: attrs
end

