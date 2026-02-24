defmodule HaruWebWeb.Plugs.AuthRateLimit do
  @moduledoc """
  Rate limits authentication form submissions (POST /login, POST /register)
  to 10 requests per minute per IP to prevent brute-force attacks.
  """
  import Plug.Conn
  import Phoenix.Controller

  @limit 10
  @period_ms 60_000

  def init(opts), do: opts

  def call(conn, _opts) do
    ip = format_ip(conn.remote_ip)

    case HaruWebWeb.RateLimiter.hit("auth:#{ip}", @period_ms, @limit) do
      {:allow, _count} ->
        conn

      {:deny, _timeout} ->
        conn
        |> put_flash(:error, "Too many attempts. Please try again in a minute.")
        |> redirect(to: conn.request_path)
        |> halt()
    end
  end

  defp format_ip(ip) when is_tuple(ip) do
    ip |> Tuple.to_list() |> Enum.join(".")
  end

  defp format_ip(ip), do: to_string(ip)
end
