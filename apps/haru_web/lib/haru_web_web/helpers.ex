defmodule HaruWebWeb.Helpers do
  @moduledoc "Shared helpers used across LiveViews and controllers."

  @doc """
  Safely parses an integer from a string or pass-through integer.
  Returns nil on failure.
  """
  def parse_int(nil), do: nil
  def parse_int(v) when is_integer(v), do: v

  def parse_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      :error -> nil
    end
  end

  @doc """
  Computes a 0–4 password strength score based on length, case mix,
  digits, and special characters.
  """
  def calc_password_strength(""), do: 0
  def calc_password_strength(nil), do: 0

  def calc_password_strength(password) do
    [
      String.length(password) >= 12,
      String.match?(password, ~r/[a-z]/) and String.match?(password, ~r/[A-Z]/),
      String.match?(password, ~r/[0-9]/),
      String.match?(password, ~r/[^a-zA-Z0-9]/)
    ]
    |> Enum.count(& &1)
  end
end
