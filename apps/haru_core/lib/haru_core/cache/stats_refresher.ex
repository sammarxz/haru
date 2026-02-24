defmodule HaruCore.Cache.StatsRefresher do
  @moduledoc """
  Periodically flushes expired cache entries every 60 seconds to keep
  memory bounded without requiring manual expiry tracking.
  """
  use GenServer

  @flush_interval_ms 60_000
  @table :haru_stats_cache

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    schedule_flush()
    {:ok, %{}}
  end

  @impl GenServer
  def handle_info(:flush_expired, state) do
    now = System.monotonic_time(:millisecond)

    :ets.select_delete(@table, [
      {{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}
    ])

    schedule_flush()
    {:noreply, state}
  end

  defp schedule_flush do
    Process.send_after(self(), :flush_expired, @flush_interval_ms)
  end
end
