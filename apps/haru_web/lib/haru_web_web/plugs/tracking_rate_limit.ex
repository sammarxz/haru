defmodule HaruWebWeb.Plugs.TrackingRateLimit do
  @moduledoc """
  Rate limits the tracking endpoint to 100 requests per minute per IP.
  Uses Hammer with ETS backend — no external dependencies required.
  """
  import Plug.Conn

  @limit 100
  @period_ms 60_000

  def init(opts), do: opts

  def call(conn, _opts) do
    ip = format_ip(conn.remote_ip)

    case HaruWebWeb.RateLimiter.hit("tracking:#{ip}", @period_ms, @limit) do
      {:allow, _count} ->
        conn

      {:deny, _timeout} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(429, ~s({"error":"rate_limit_exceeded"}))
        |> halt()
    end
  end

  defp format_ip(ip) when is_tuple(ip) do
    ip |> Tuple.to_list() |> Enum.join(".")
  end

  defp format_ip(ip), do: to_string(ip)
end
