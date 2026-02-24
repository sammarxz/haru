defmodule HaruCore.Sites.SiteServer do
  @moduledoc """
  GenServer per-site holding in-memory state: active visitors map
  for real-time dashboard updates.

  Visitor tracking uses a map of ip_hash -> last_seen_ms with a 5-minute
  expiry window to count unique active visitors without storing raw IPs.
  """
  use GenServer, restart: :transient

  require Logger

  @visitor_ttl_ms 30 * 60 * 1_000

  # ── Public API ─────────────────────────────────────────────────────────────

  @doc "Start a SiteServer for the given site_id, registered in the Registry."
  @spec start_link(pos_integer()) :: GenServer.on_start()
  def start_link(site_id) do
    GenServer.start_link(__MODULE__, site_id, name: via(site_id))
  end

  @doc "Cast a new event into the server (fire-and-forget for the caller)."
  @spec record_event(pos_integer(), map()) :: :ok
  def record_event(site_id, event_params) do
    GenServer.cast(via(site_id), {:record_event, event_params})
  end

  @doc "Return the count of visitors active in the last 30 minutes."
  @spec active_visitor_count(pos_integer()) :: non_neg_integer()
  def active_visitor_count(site_id) do
    GenServer.call(via(site_id), :active_visitor_count)
  end

  # ── GenServer Callbacks ──────────────────────────────────────────────────────

  @impl GenServer
  def init(site_id) do
    Logger.info("SiteServer started for site_id=#{site_id}")

    {:ok,
     %{
       site_id: site_id,
       active_visitors: %{}
     }}
  end

  @impl GenServer
  def handle_cast({:record_event, %{ip_hash: ip_hash}}, state) do
    now = System.monotonic_time(:millisecond)

    updated_visitors = Map.put(state.active_visitors, ip_hash, now)

    {:noreply, %{state | active_visitors: updated_visitors}}
  end

  @impl GenServer
  def handle_cast({:record_event, _params}, state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:active_visitor_count, _from, state) do
    cutoff = System.monotonic_time(:millisecond) - @visitor_ttl_ms

    count =
      state.active_visitors
      |> Enum.count(fn {_ip_hash, last_seen} -> last_seen > cutoff end)

    {:reply, count, state}
  end

  # ── Helpers ─────────────────────────────────────────────────────────────────

  defp via(site_id) do
    {:via, Registry, {HaruCore.SiteRegistry, site_id}}
  end
end
