defmodule QolTest do
  use ExUnit.Case
  doctest Qol

  test "greets the world" do
    assert Qol.hello() == :world
  end
end
