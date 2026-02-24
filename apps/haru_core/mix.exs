defmodule HaruCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :haru_core,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {HaruCore.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix_pubsub, "~> 2.1"},
      {:ecto_sql, "~> 3.12"},
      {:postgrex, "~> 0.20"},
      {:jason, "~> 1.4"},
      {:bcrypt_elixir, "~> 3.0"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:ex_machina, "~> 2.8", only: :test},
      {:tzdata, "~> 1.1"}
    ]
  end

  defp aliases do
    [
      "ecto.setup": [
        "ecto.create -r HaruCore.Repo",
        "ecto.migrate -r HaruCore.Repo",
        "run apps/haru_core/priv/repo/seeds.exs"
      ],
      "ecto.reset": ["ecto.drop -r HaruCore.Repo", "ecto.setup"]
    ]
  end
end
