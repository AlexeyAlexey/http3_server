defmodule Http3Server.PackageStreamHandler.PackageEncoderTest do
  use ExUnit.Case, async: true

  alias Http3Server.PackageStreamHandler.PackageEncoder

  # <<77, 83, 69, extended_payload_length::32, participant_id::32, payload>>
  # 77, 83, 69 - header MSE
  # extended_payload_length - participant_id extension + payload size
  # payload = <<type::8, json_length::32, json>>
  test "encode builds an MSE package" do
    {:ok, package} = PackageEncoder.encode(:event, %{event_name: "participant_left"}, 123)

    assert <<77, 83, 69, extended_payload_length::size(4)-unit(8), 123::size(4)-unit(8), type::8,
             json_length::size(4)-unit(8), json::binary>> = package

    assert type == 4
    assert extended_payload_length == 4 + 1 + 4 + json_length
    assert byte_size(json) == json_length

    assert Jason.decode!(json) == %{
             "event_name" => "participant_left",
             "participant_id" => 123
           }
  end

  test "event map fields are preserved" do
    {:ok, package} = PackageEncoder.encode(:event, %{event_name: "NameIsSet", name: "Alex"}, 7)

    assert <<77, 83, 69, _extended::size(4)-unit(8), 7::size(4)-unit(8), 4::8,
             _json_length::size(4)-unit(8), json::binary>> = package

    assert Jason.decode!(json) == %{
             "event_name" => "NameIsSet",
             "name" => "Alex",
             "participant_id" => 7
           }
  end

  test "participant_id argument overrides the one in the event map" do
    {:ok, package} = PackageEncoder.encode(:event, %{event_name: "x", participant_id: 999}, 5)

    assert <<_header::size(11)-unit(8), _type::8, _json_length::size(4)-unit(8), json::binary>> =
             package

    assert Jason.decode!(json)["participant_id"] == 5
  end

  test "returns error when payload is not JSON-encodable" do
    assert {:error, %Protocol.UndefinedError{}} =
             PackageEncoder.encode(:event, %{pid: self()}, 1)
  end

  test "returns error for unknown stream type" do
    assert {:error, "unknown stream type"} =
             PackageEncoder.encode(:chat, %{event_name: "x"}, 1)
  end
end
