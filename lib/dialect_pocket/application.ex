defmodule DialectPocket.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DialectPocketWeb.Telemetry,
      DialectPocket.Repo,
      {DNSCluster, query: Application.get_env(:dialect_pocket, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: DialectPocket.PubSub},
      {DialectPocket.RateLimiter, [clean_period: :timer.minutes(10)]},
      {Oban, Application.fetch_env!(:dialect_pocket, Oban)},
      # Start to serve requests, typically the last entry
      DialectPocketWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DialectPocket.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DialectPocketWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
