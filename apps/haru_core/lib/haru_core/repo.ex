defmodule HaruCore.Repo do
  use Ecto.Repo,
    otp_app: :haru_core,
    adapter: Ecto.Adapters.Postgres
end
