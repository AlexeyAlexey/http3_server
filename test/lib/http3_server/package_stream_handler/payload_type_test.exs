defmodule Http3Server.PackageStreamHandler.PayloadTypeTest do
  use ExUnit.Case, async: true

  alias Http3Server.PackageStreamHandler.PayloadType

  test "to_byte maps a stream type to its payload type byte" do
    assert {:ok, 4} = PayloadType.to_byte(:event)
  end

  test "to_byte returns error for an unknown stream type" do
    assert {:error, "unknown stream type"} = PayloadType.to_byte(:chat)
  end

  test "from_byte maps a payload type byte to its stream type" do
    assert {:ok, :event} = PayloadType.from_byte(4)
  end

  test "from_byte returns error for an unknown payload type byte" do
    assert {:error, "unknown payload type"} = PayloadType.from_byte(99)
  end
end
