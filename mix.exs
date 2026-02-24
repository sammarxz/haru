defmodule Haru.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader],
      releases: [
        haru: [
          include_executables_for: [:unix],
          applications: [haru_core: :permanent, haru_web: :permanent]
        ]
      ]
    ]
  end

  defp deps do
    []
  end

  defp aliases do
    [
      "ecto.setup": [
        "ecto.create -r HaruCore.Repo",
        "ecto.migrate -r HaruCore.Repo",
        "run apps/haru_core/priv/repo/seeds.exs"
      ],
      "ecto.reset": ["ecto.drop -r HaruCore.Repo", "ecto.setup"],
      check: ["credo --strict", "compile --warnings-as-errors"]
    ]
  end
end
