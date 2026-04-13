defmodule Http3ServerTest do
  use ExUnit.Case
  doctest Http3Server

  test "greets the world" do
    assert Http3Server.hello() == :world
  end
end
