defmodule HaruCore.Cache.StatsRefresherTest do
  use ExUnit.Case, async: true
  alias HaruCore.Cache.StatsRefresher

  @table :haru_stats_cache

  test "cleans up expired items from ETS" do
    # Ensure table exists (it should if app started)
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:set, :public, :named_table])
    end

    now = System.monotonic_time(:millisecond)

    # One expired, one valid
    :ets.insert(@table, {{"k1", "today"}, %{}, now - 1000})
    :ets.insert(@table, {{"k2", "today"}, %{}, now + 10000})

    # Trigger manually
    send(StatsRefresher, :flush_expired)

    # Wait a bit
    Process.sleep(10)

    assert :ets.lookup(@table, {"k1", "today"}) == []
    assert :ets.lookup(@table, {"k2", "today"}) != []
  end
end
