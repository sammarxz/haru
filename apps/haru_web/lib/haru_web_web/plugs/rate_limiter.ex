defmodule HaruWebWeb.RateLimiter do
  @moduledoc """
  ETS-backed rate limiter using Hammer 7.x.
  Must be started in the supervision tree.
  """
  use Hammer, backend: :ets
end
