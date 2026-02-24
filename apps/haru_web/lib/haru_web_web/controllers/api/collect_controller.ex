defmodule HaruWebWeb.Api.CollectController do
  @moduledoc """
  Hot-path tracking endpoint. Responds in < 10ms by:
  1. Validating the site token synchronously
  2. Casting to SiteServer (fast GenServer cast)
  3. Dispatching the DB write + cache invalidation + PubSub broadcast
     asynchronously via Task.Supervisor (fire-and-forget)
  4. Returning 200 immediately
  """
  use HaruWebWeb, :controller

  import HaruWebWeb.Helpers

  require Logger

  alias HaruCore.Analytics
  alias HaruCore.Cache.StatsCache
  alias HaruCore.Sites
  alias HaruCore.Sites.{SiteServer, Supervisor}

  @doc """
  POST /api/collect

  Expects JSON body with optional fields:
    - p: page path (required)
    - r: referrer URL
    - sw: screen width (integer)
    - sh: screen height (integer)
    - n: event name (default: "pageview")
    - d: duration in ms (integer)
    - c: two-letter country code from browser locale (e.g. "BR", "US")

  Authentication: `Authorization: Bearer <token>` header or `?t=<token>` param.
  """
  def create(conn, params) do
    with token when not is_nil(token) <- extract_token(conn),
         site when not is_nil(site) <- Sites.get_site_by_token(token),
         path when is_binary(path) and path != "" <- Map.get(params, "p", "/") do
      ip = format_ip(conn.remote_ip)

      event_attrs = %{
        site_id: site.id,
        name: Map.get(params, "n", "pageview"),
        path: path,
        referrer: Map.get(params, "r"),
        user_agent: get_req_header(conn, "user-agent") |> List.first(),
        screen_width: parse_int(Map.get(params, "sw")),
        screen_height: parse_int(Map.get(params, "sh")),
        duration_ms: parse_int(Map.get(params, "d")),
        country: sanitize_country(Map.get(params, "c")),
        ip: ip
      }

      # Sync: ensure SiteServer is alive + cast the event (fast)
      Supervisor.ensure_started(site.id)
      SiteServer.record_event(site.id, %{ip_hash: Analytics.hash_ip(ip)})

      # Async: DB write + cache invalidation + PubSub broadcast
      Task.Supervisor.start_child(HaruCore.Tasks.Supervisor, fn ->
        persist_event(event_attrs, site.id)
      end)

      send_resp(conn, 200, "")
    else
      nil -> send_resp(conn, 401, "")
      _ -> send_resp(conn, 400, "")
    end
  end

  @doc "CORS preflight response."
  def options(conn, _params) do
    send_resp(conn, 204, "")
  end

  defp persist_event(event_attrs, site_id) do
    case Analytics.create_event(event_attrs) do
      {:ok, _event} ->
        StatsCache.invalidate_site(site_id)
        Phoenix.PubSub.broadcast(HaruCore.PubSub, "site:#{site_id}", {:new_event, site_id})

      {:error, reason} ->
        Logger.warning("Failed to persist event for site #{site_id}: #{inspect(reason)}")
    end
  end

  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token | _] -> token
      _ -> conn.params["t"]
    end
  end

  # Handles both IPv4 tuples {a, b, c, d} and IPv6 tuples {a, b, c, d, e, f, g, h}
  defp format_ip({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"

  defp format_ip({a, b, c, d, e, f, g, h}) do
    [a, b, c, d, e, f, g, h]
    |> Enum.map_join(":", &Integer.to_string(&1, 16))
  end

  defp format_ip(ip), do: to_string(ip)

  # Accepts only two-letter uppercase country codes (ISO 3166-1 alpha-2).
  # Rejects any other input to prevent arbitrary strings being stored.
  defp sanitize_country(code) when is_binary(code) do
    upcased = String.upcase(code)
    if String.match?(upcased, ~r/^[A-Z]{2}$/), do: upcased, else: nil
  end

  defp sanitize_country(_), do: nil
end
