defmodule HaruWebWeb.HelpersTest do
  use ExUnit.Case, async: true
  alias HaruWebWeb.Helpers

  describe "parse_int/1" do
    test "parses integer strings" do
      assert Helpers.parse_int("123") == 123
      assert Helpers.parse_int("0") == 0
    end

    test "returns integer as-is" do
      assert Helpers.parse_int(456) == 456
    end

    test "returns nil for invalid input" do
      assert Helpers.parse_int(nil) == nil
      assert Helpers.parse_int("abc") == nil
      assert Helpers.parse_int("") == nil
    end
  end

  describe "calc_password_strength/1" do
    test "returns 0 for empty or nil" do
      assert Helpers.calc_password_strength("") == 0
      assert Helpers.calc_password_strength(nil) == 0
    end

    test "calculates strength" do
      # too short
      assert Helpers.calc_password_strength("weak") == 0
      # length only
      assert Helpers.calc_password_strength("longpassword") == 1
      # length + case
      assert Helpers.calc_password_strength("LongPassword") == 2
      # length + case + digit
      assert Helpers.calc_password_strength("LongPassword1") == 3
      # all
      assert Helpers.calc_password_strength("LongPassword1!") == 4
    end
  end
end
