defmodule HaruCore.Sites.Supervisor do
  @moduledoc """
  Manages the DynamicSupervisor for per-site GenServers.
  Provides `ensure_started/1` to lazily spin up a SiteServer on first event.
  """

  @supervisor HaruCore.Sites.DynamicSupervisor

  @doc """
  Ensures a SiteServer is running for the given site_id.
  Idempotent — safe to call on every request.
  """
  @spec ensure_started(pos_integer()) :: {:ok, pid()} | {:error, term()}
  def ensure_started(site_id) do
    case Registry.lookup(HaruCore.SiteRegistry, site_id) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        spec = {HaruCore.Sites.SiteServer, site_id}

        case DynamicSupervisor.start_child(@supervisor, spec) do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          {:error, reason} -> {:error, reason}
        end
    end
  end
end
