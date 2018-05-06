defmodule PhoenixUtilsTest do
  use ExUnit.Case
  doctest PhoenixUtils

  test "greets the world" do
    assert PhoenixUtils.hello() == :world
  end
end
