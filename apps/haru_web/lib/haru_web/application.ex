defmodule HaruWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      HaruWebWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:haru_web, :dns_cluster_query) || :ignore},
      {HaruWebWeb.RateLimiter, clean_period: :timer.minutes(5)},
      # Start to serve requests, typically the last entry
      HaruWebWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HaruWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    HaruWebWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
