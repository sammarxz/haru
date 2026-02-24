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
  @spec get_stats(pos_integer(), String.t(), String.t()) :: map()
  def get_stats(site_id, period \\ @default_period, timezone \\ "Etc/UTC") do
    period = if period in @valid_periods, do: period, else: @default_period

    case StatsCache.get(site_id, "#{period}:#{timezone}") do
      nil ->
        stats = compute_stats(site_id, period, timezone)
        StatsCache.put(site_id, "#{period}:#{timezone}", stats)
        stats

      stats ->
        stats
    end
  end

  @doc """
  Computes fresh stats directly from the database for the given period.
  """
  @spec compute_stats(pos_integer(), String.t(), String.t()) :: map()
  def compute_stats(site_id, period \\ @default_period, timezone \\ "Etc/UTC") do
    period = if period in @valid_periods, do: period, else: @default_period
    since = period_start(period, timezone)
    until = period_end(period, timezone)

    base =
      from(e in Event,
        where: e.site_id == ^site_id and e.inserted_at >= ^since and e.name == "pageview"
      )

    base = if until, do: from(e in base, where: e.inserted_at < ^until), else: base

    duration_base =
      from(e in Event,
        where:
          e.site_id == ^site_id and e.inserted_at >= ^since and
            e.name == "duration" and e.duration_ms > 0
      )

    duration_base =
      if until, do: from(e in duration_base, where: e.inserted_at < ^until), else: duration_base

    metrics = compute_metrics(base, duration_base)
    changes = compute_all_changes(site_id, period, since, metrics, timezone)

    %{
      period: period,
      total_views: metrics.total_views,
      unique_visitors: metrics.unique_visitors,
      bounce_rate: metrics.bounce_rate,
      avg_duration_ms: metrics.avg_duration_ms,
      top_pages: query_top_pages(base),
      top_referrers: query_top_referrers(base),
      top_countries: query_top_countries(base),
      top_browsers: query_browsers(base),
      top_os: query_os(base),
      top_devices: query_devices(base),
      chart_views: query_chart_views(base, period, timezone),
      realtime_count: active_visitor_count(site_id),
      realtime_chart: realtime_chart(site_id, timezone)
    }
    |> Map.merge(changes)
  end

  defp compute_metrics(base, duration_base) do
    total_views = Repo.aggregate(base, :count, :id) || 0
    unique_visitors = Repo.one(from(e in base, select: count(e.ip_hash, :distinct))) || 0

    bounce_rate = compute_bounce_rate(base, unique_visitors)

    avg_duration_ms =
      Repo.one(from(e in duration_base, select: type(avg(e.duration_ms), :integer)))

    %{
      total_views: total_views,
      unique_visitors: unique_visitors,
      bounce_rate: bounce_rate,
      avg_duration_ms: avg_duration_ms
    }
  end

  defp compute_bounce_rate(_base, 0), do: 0

  defp compute_bounce_rate(base, unique_visitors) do
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

    round(bounced / unique_visitors * 100)
  end

  defp compute_all_changes(_site_id, "all", _since, _metrics, _timezone) do
    %{views_change: nil, visitors_change: nil, bounce_change: nil, duration_change: nil}
  end

  defp compute_all_changes(site_id, period, since, metrics, timezone) do
    prev_metrics = compute_previous_metrics(site_id, period, since, timezone)

    %{
      views_change: compute_change_pct(metrics.total_views, prev_metrics.total_views),
      visitors_change: compute_change_pct(metrics.unique_visitors, prev_metrics.unique_visitors),
      bounce_change: compute_change_pct(metrics.bounce_rate, prev_metrics.bounce_rate),
      duration_change:
        compute_change_pct(metrics.avg_duration_ms || 0, prev_metrics.avg_duration_ms || 0)
    }
  end

  defp compute_previous_metrics(site_id, period, until, timezone) do
    since = prev_period_start(period, timezone)

    base =
      from(e in Event,
        where:
          e.site_id == ^site_id and
            e.inserted_at >= ^since and
            e.inserted_at < ^until and
            e.name == "pageview"
      )

    duration_base =
      from(e in Event,
        where:
          e.site_id == ^site_id and
            e.inserted_at >= ^since and
            e.inserted_at < ^until and
            e.name == "duration" and
            e.duration_ms > 0
      )

    compute_metrics(base, duration_base)
  end

  defp query_top_pages(base) do
    Repo.all(
      from(e in base,
        group_by: e.path,
        select: %{path: e.path, count: count(e.id)},
        order_by: [desc: count(e.id)],
        limit: 10
      )
    )
  end

  defp query_top_referrers(base) do
    Repo.all(
      from(e in base,
        where: not is_nil(e.referrer) and e.referrer != "",
        group_by: e.referrer,
        select: %{referrer: e.referrer, count: count(e.id)},
        order_by: [desc: count(e.id)],
        limit: 10
      )
    )
  end

  defp query_top_countries(base) do
    Repo.all(
      from(e in base,
        where: not is_nil(e.country) and e.country != "",
        group_by: e.country,
        select: %{country: e.country, count: count(e.id)},
        order_by: [desc: count(e.id)],
        limit: 10
      )
    )
  end

  @doc "Returns realtime chart: 5-minute buckets over the last 30 minutes."
  @spec realtime_chart(pos_integer(), String.t()) :: list(map())
  def realtime_chart(site_id, timezone \\ "Etc/UTC") do
    since = DateTime.add(DateTime.utc_now(), -30 * 60, :second)

    sub =
      from(e in Event,
        where: e.site_id == ^site_id and e.inserted_at >= ^since and e.name == "pageview",
        select: %{
          local_at: fragment("? AT TIME ZONE 'UTC' AT TIME ZONE ?", e.inserted_at, ^timezone),
          id: e.id
        }
      )

    Repo.all(
      from(s in subquery(sub),
        group_by:
          fragment(
            "date_trunc('hour', ?) + (date_part('minute', ?)::int / 5) * interval '5 min'",
            s.local_at,
            s.local_at
          ),
        select: %{
          bucket:
            fragment(
              "date_trunc('hour', ?) + (date_part('minute', ?)::int / 5) * interval '5 min'",
              s.local_at,
              s.local_at
            ),
          count: count(s.id)
        },
        order_by: [
          asc:
            fragment(
              "date_trunc('hour', ?) + (date_part('minute', ?)::int / 5) * interval '5 min'",
              s.local_at,
              s.local_at
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

  defp period_start("today", tz), do: today_at_midnight(tz)

  defp period_start("yesterday", tz) do
    today_at_midnight(tz) |> DateTime.add(-24 * 60 * 60, :second)
  end

  defp period_start("week", tz) do
    local_now = DateTime.now!(tz)

    Date.add(DateTime.to_date(local_now), -(Date.day_of_week(local_now) - 1))
    |> DateTime.new!(~T[00:00:00], tz)
    |> DateTime.shift_zone!("Etc/UTC")
  end

  defp period_start("month", tz) do
    local_now = DateTime.now!(tz)

    Date.new!(local_now.year, local_now.month, 1)
    |> DateTime.new!(~T[00:00:00], tz)
    |> DateTime.shift_zone!("Etc/UTC")
  end

  defp period_start("year", tz) do
    local_now = DateTime.now!(tz)

    Date.new!(local_now.year, 1, 1)
    |> DateTime.new!(~T[00:00:00], tz)
    |> DateTime.shift_zone!("Etc/UTC")
  end

  defp period_start("30d", _),
    do: DateTime.add(DateTime.utc_now(), -30 * 24 * 60 * 60, :second)

  defp period_start("6m", _),
    do: DateTime.add(DateTime.utc_now(), -180 * 24 * 60 * 60, :second)

  defp period_start("12m", _),
    do: DateTime.add(DateTime.utc_now(), -365 * 24 * 60 * 60, :second)

  defp period_start("all", _), do: ~U[2000-01-01 00:00:00Z]
  defp period_start(_, tz), do: period_start("today", tz)

  defp today_at_midnight(tz) do
    DateTime.now!(tz)
    |> DateTime.to_date()
    |> DateTime.new!(~T[00:00:00], tz)
    |> DateTime.shift_zone!("Etc/UTC")
  end

  # "yesterday" is the only complete bounded period — it must stop at midnight today.
  # All other periods run from their start up to "now", which is correct.
  defp period_end("yesterday", tz), do: today_at_midnight(tz)

  defp period_end(_, _), do: nil

  defp prev_period_start("today", tz) do
    today_at_midnight(tz) |> DateTime.add(-24 * 60 * 60, :second)
  end

  defp prev_period_start("yesterday", tz) do
    today_at_midnight(tz) |> DateTime.add(-48 * 60 * 60, :second)
  end

  defp prev_period_start("week", tz) do
    period_start("week", tz) |> DateTime.add(-7 * 24 * 60 * 60, :second)
  end

  defp prev_period_start("month", tz) do
    local_now = DateTime.now!(tz)

    prev =
      if local_now.month == 1 do
        Date.new!(local_now.year - 1, 12, 1)
      else
        Date.new!(local_now.year, local_now.month - 1, 1)
      end

    prev |> DateTime.new!(~T[00:00:00], tz) |> DateTime.shift_zone!("Etc/UTC")
  end

  defp prev_period_start("year", tz) do
    local_now = DateTime.now!(tz)

    Date.new!(local_now.year - 1, 1, 1)
    |> DateTime.new!(~T[00:00:00], tz)
    |> DateTime.shift_zone!("Etc/UTC")
  end

  defp prev_period_start("30d", _),
    do: DateTime.add(DateTime.utc_now(), -60 * 24 * 60 * 60, :second)

  defp prev_period_start("6m", _),
    do: DateTime.add(DateTime.utc_now(), -360 * 24 * 60 * 60, :second)

  defp prev_period_start("12m", _),
    do: DateTime.add(DateTime.utc_now(), -730 * 24 * 60 * 60, :second)

  defp prev_period_start("all", _), do: ~U[2000-01-01 00:00:00Z]
  defp prev_period_start(_, tz), do: prev_period_start("today", tz)

  defp compute_change_pct(_, 0), do: nil

  defp compute_change_pct(current, previous),
    do: round((current - previous) / previous * 100)

  defp query_chart_views(base, period, timezone) do
    sub =
      from(e in base,
        select: %{
          local_at: fragment("? AT TIME ZONE 'UTC' AT TIME ZONE ?", e.inserted_at, ^timezone),
          id: e.id
        }
      )

    case period do
      p when p in ["today", "yesterday"] ->
        Repo.all(
          from(s in subquery(sub),
            group_by: fragment("date_trunc('hour', ?)", s.local_at),
            select: %{
              bucket: fragment("date_trunc('hour', ?)", s.local_at),
              count: count(s.id)
            },
            order_by: [asc: fragment("date_trunc('hour', ?)", s.local_at)]
          )
        )

      p when p in ["week", "30d", "month"] ->
        Repo.all(
          from(s in subquery(sub),
            group_by: fragment("date_trunc('day', ?)", s.local_at),
            select: %{
              bucket: fragment("date_trunc('day', ?)", s.local_at),
              count: count(s.id)
            },
            order_by: [asc: fragment("date_trunc('day', ?)", s.local_at)]
          )
        )

      "6m" ->
        Repo.all(
          from(s in subquery(sub),
            group_by: fragment("date_trunc('week', ?)", s.local_at),
            select: %{
              bucket: fragment("date_trunc('week', ?)", s.local_at),
              count: count(s.id)
            },
            order_by: [asc: fragment("date_trunc('week', ?)", s.local_at)]
          )
        )

      _ ->
        Repo.all(
          from(s in subquery(sub),
            group_by: fragment("date_trunc('month', ?)", s.local_at),
            select: %{
              bucket: fragment("date_trunc('month', ?)", s.local_at),
              count: count(s.id)
            },
            order_by: [asc: fragment("date_trunc('month', ?)", s.local_at)]
          )
        )
    end
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
