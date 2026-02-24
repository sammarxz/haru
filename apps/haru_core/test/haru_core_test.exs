defmodule HaruCoreTest do
  use ExUnit.Case
  doctest HaruCore

  test "greets the world" do
    assert HaruCore.hello() == :world
  end
end
