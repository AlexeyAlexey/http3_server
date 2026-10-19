defmodule Http3Server.PackageStreamHandler.PackageDecoderTest do
  use ExUnit.Case, async: true

  alias Http3Server.PackageStreamHandler.PackageDecoder

  # <77, 83, 21::size(4)-unit(8), 3::8, "waiting_time_expired", 77, 83, 0, 0, 0, 21>>
  # 77, 83 - header MS
  # 21::size(4)-unit(8) - Package Size bytes
  # Payload:
  #  3::8 - 1 byte (integer, type)
  # "waiting_time_expired" - payload
  test "leftover_bytes is used to skip (move through) a tail of the previous package" do
    stream =
      <<77, 83, 21::size(4)-unit(8), 3::8, "waiting_time_expired", 77, 83, 0, 0, 0, 21>>

    assert {<<77, 83, 21::size(4)-unit(8), 3::8, "waiting_time_expired">>, buffer, leftover_bytes} =
             PackageDecoder.decode(stream)

    assert <<77, 83, 0, 0, 0, 21>> = buffer
    assert leftover_bytes == 6
  end

  describe "Buffer. move to the buffer the rest of the stream that can be considered as beginning of the next package" do
    test "77 (magic 1) and 83 (magic 2) is the rest of the stream" do
      stream = <<77, 83, 21::size(4)-unit(8), 3::8, "waiting_time_expired", 77, 83>>

      assert {<<77, 83, 21::size(4)-unit(8), 3::8, "waiting_time_expired">>, buffer,
              leftover_bytes} =
               PackageDecoder.decode(stream)

      assert buffer == <<77, 83>>
      assert leftover_bytes == 2
    end

    test "77 magic 1 is the rest of the stream" do
      stream = <<77, 83, 21::size(4)-unit(8), 3::8, "waiting_time_expired", 77>>

      assert {<<77, 83, 21::size(4)-unit(8), 3::8, "waiting_time_expired">>, buffer,
              leftover_bytes} =
               PackageDecoder.decode(stream)

      assert buffer == <<77>>
      assert leftover_bytes == 1
    end

    test "77 (magic 1) and 83 (magic 2) and part of payload length is the rest of the stream" do
      stream =
        <<0, 77, 83, 21::size(4)-unit(8), 3::8, "waiting_time_expired", 77, 83, 0, 0>>

      assert {<<0, 77, 83, 21::size(4)-unit(8), 3::8, "waiting_time_expired">>, buffer,
              leftover_bytes} =
               PackageDecoder.decode(stream)

      assert buffer == <<77, 83, 0, 0>>
      assert leftover_bytes == 4
    end
  end

  test "decode" do
    assert {<<77, 83, 21::32, 3::8, "waiting_time_expired">>, <<77, 83>>, 2} =
             <<77, 83, 21::32, 3::8, "waiting_time_expired", 77, 83>>
             |> PackageDecoder.decode()

    assert {<<77, 83, 21::32, 3::8, "waiting_time_expired", 77, 83, 21::32, 3::8,
              "waiting_time_expired">>, <<>>, 0} =
             <<77, 83, 21::32, 3::8, "waiting_time_expired", 77, 83, 21::32, 3::8,
               "waiting_time_expired">>
             |> PackageDecoder.decode()

    assert {<<77, 83, 21::32, 3::8, "waiting_time_expired">>, <<>>, 0} =
             <<77, 83, 21::32, 3::8, "waiting_time_expired">>
             |> PackageDecoder.decode()

    assert {<<>>, <<77, 83, 21::32, 3::8>>, 7} =
             <<77, 83, 21::32, 3::8>>
             |> PackageDecoder.decode()

    assert {<<>>, <<77, 83, 0, 0, 0, 21>>, 6} =
             <<77, 83, 0, 0, 0, 21>>
             |> PackageDecoder.decode()

    assert {<<>>, <<77, 83, 0, 0, 0>>, 5} =
             <<77, 83, 0, 0, 0>>
             |> PackageDecoder.decode()

    assert {<<>>, <<77, 83>>, 2} =
             <<77, 83>>
             |> PackageDecoder.decode()

    assert {<<77, 0, 5, 6>>, <<>>, 0} =
             <<77, 0, 5, 6>>
             |> PackageDecoder.decode()
  end

  describe "decode when buffer is a parameter" do
    test "buffered part of previous stream is used to decode next" do
      stream =
        <<0, 77, 83, 21::size(4)-unit(8), 3::8, "waiting_time_expired", 77, 83, 0, 0>>

      assert {<<0, 77, 83, 21::size(4)-unit(8), 3::8, "waiting_time_expired">>, buffer,
              leftover_bytes} =
               PackageDecoder.decode(stream)

      assert buffer == <<77, 83, 0, 0>>

      next_stream_part = <<0, 21, 3::8, "waiting_time_expired">>

      assert {<<77, 83, 0, 0, 0, 21, 3::8, "waiting_time_expired">>, buffer, leftover_bytes} =
               PackageDecoder.decode(next_stream_part, buffer, leftover_bytes)

      assert buffer == <<>>
      assert leftover_bytes == 0
    end

    test "buffer is empty" do
      stream =
        <<0, 77, 83, 21::size(4)-unit(8), 3::8, "waiting_time_expired", 77, 83, 0, 0>>

      leftover_bytes = 0
      buffer = <<>>

      assert {<<0, 77, 83, 21::size(4)-unit(8), 3::8, "waiting_time_expired">>, buffer,
              leftover_bytes} =
               PackageDecoder.decode(stream, buffer, leftover_bytes)

      assert buffer == <<77, 83, 0, 0>>
      assert leftover_bytes == 4
    end

    test "package is decoded across several stream chunks" do
      assert {<<>>, buffer, leftover_bytes} = PackageDecoder.decode(<<77, 83, 0, 0>>)

      assert buffer == <<77, 83, 0, 0>>
      assert leftover_bytes == 4

      # the rest of the header
      assert {<<>>, buffer, leftover_bytes} =
               PackageDecoder.decode(<<0, 21>>, buffer, leftover_bytes)

      assert buffer == <<77, 83, 0, 0, 0, 21>>
      assert leftover_bytes == 6

      # part of the payload
      assert {<<>>, buffer, leftover_bytes} =
               PackageDecoder.decode(<<3::8, "waiting">>, buffer, leftover_bytes)

      assert buffer == <<77, 83, 0, 0, 0, 21, 3::8, "waiting">>
      assert leftover_bytes == 14

      # the rest of the payload
      assert {<<77, 83, 0, 0, 0, 21, 3::8, "waiting_time_expired">>, <<>>, 0} =
               PackageDecoder.decode(<<"_time_expired">>, buffer, leftover_bytes)
    end

    test "package with empty payload" do
      assert {<<77, 83, 0, 0, 0, 0>>, <<>>, 0} =
               PackageDecoder.decode(<<77, 83, 0, 0, 0, 0>>)
    end
  end

  describe "buffer exceeds 0.5 Mb" do
    test "buffer is dropped to init values" do
      oversized_buffer = :binary.copy(<<0>>, 512 * 1024 + 1)
      stream = <<77, 83, 0, 0, 0, 0>>

      assert {<<77, 83, 0, 0, 0, 0>>, <<>>, 0} =
               PackageDecoder.decode(stream, oversized_buffer, 999_999)
    end

    test "incomplete package exceeding 0.5 Mb is dropped" do
      stream = <<77, 83, 700_000::size(4)-unit(8)>> <> :binary.copy(<<0>>, 600_000)

      assert {<<>>, <<>>, 0} = PackageDecoder.decode(stream)
    end

    test "buffer at exactly 0.5 Mb is kept" do
      # 512 * 1024 bytes: 6-byte header + 524282 payload bytes of a
      # 524283-byte package (payload_length = 524283)
      buffer = <<77, 83, 524_283::size(4)-unit(8)>> <> :binary.copy(<<0>>, 524_282)

      assert {<<>>, ^buffer, 524_288} = PackageDecoder.decode(<<>>, buffer, byte_size(buffer))
    end
  end
end
