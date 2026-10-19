defmodule Http3Server.PackageStreamHandler.PackageParserTest do
  use ExUnit.Case, async: true

  alias Http3Server.PackageStreamHandler.PackageParser

  # <<77, 83, payload_length::size(4)-unit(8), type::8, payload>>
  # 77, 83 - header MS
  # payload_length - Package Size bytes (type byte + payload)
  # type::8 - 1 byte (integer, type)
  # payload - json encoded data
  test "package is parsed into type and decoded json payload" do
    payload = Jason.encode!(%{event_name: "participant_left", participant_id: 123})
    package = <<77, 83, byte_size(payload) + 1::size(4)-unit(8), 1::8, payload::binary>>

    assert {:ok,
            %{type: 1, payload: %{"event_name" => "participant_left", "participant_id" => 123}}} =
             PackageParser.parse(package)
  end

  test "non-json payload" do
    package = <<77, 83, 21::size(4)-unit(8), 3::8, "waiting_time_expired">>

    assert {:error, "package has a wrong format"} = PackageParser.parse(package)
  end

  test "package with empty payload" do
    assert {:error, "package has a wrong format"} =
             PackageParser.parse(<<77, 83, 0, 0, 0, 1, 3>>)
  end

  test "wrong magic bytes" do
    assert {:error, "package has a wrong format"} =
             PackageParser.parse(<<77, 0, 0, 0, 0, 2, 3, "a">>)
  end

  test "payload_length does not match the actual payload size" do
    # declares 21 bytes (1 type + 20 payload) but carries only 4
    assert {:error, "package has a wrong format"} =
             PackageParser.parse(<<77, 83, 21::size(4)-unit(8), 3::8, "abc">>)
  end

  test "incomplete package" do
    assert {:error, "package has a wrong format"} = PackageParser.parse(<<77, 83>>)
    assert {:error, "package has a wrong format"} = PackageParser.parse(<<77>>)
    assert {:error, "package has a wrong format"} = PackageParser.parse(<<>>)
  end

  test "not a binary" do
    assert {:error, "package has a wrong format"} = PackageParser.parse(nil)
  end
end
