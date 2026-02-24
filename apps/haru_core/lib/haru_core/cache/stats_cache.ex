defmodule HaruCore.Cache.StatsCache do
  @moduledoc """
  ETS-based stats cache with TTL support.
  The table is public and read_concurrency-enabled to support
  thousands of concurrent reads without bottleneck.

  Cache key is `{site_id, period}` so each time-range is cached independently.
  `invalidate_site/1` removes all periods for a site when a new event arrives.
  """
  use GenServer

  @table :haru_stats_cache
  @ttl_ms 60_000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Retrieve cached stats for a site + period, or nil if missing/expired."
  @spec get(pos_integer(), String.t()) :: map() | nil
  def get(site_id, period) do
    now = System.monotonic_time(:millisecond)
    key = {site_id, period}

    case :ets.lookup(@table, key) do
      [{^key, stats, expiry}] when expiry > now -> stats
      _ -> nil
    end
  end

  @doc "Store stats for a site + period with the default TTL."
  @spec put(pos_integer(), String.t(), map()) :: true
  def put(site_id, period, stats) do
    expiry = System.monotonic_time(:millisecond) + @ttl_ms
    :ets.insert(@table, {{site_id, period}, stats, expiry})
  end

  @doc "Invalidate all cached periods for a site (called on new event)."
  @spec invalidate_site(pos_integer()) :: non_neg_integer()
  def invalidate_site(site_id) do
    :ets.select_delete(@table, [{{{site_id, :_}, :_, :_}, [], [true]}])
  end

  @impl GenServer
  def init(_) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{}}
  end
end
