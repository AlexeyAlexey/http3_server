defmodule Http3Server.PackageStreamHandler.PackageTest do
  use ExUnit.Case, async: true

  alias Http3Server.PackageStreamHandler.Package

  test "leftover_bytes is used to skip (move through) a tail of the previous package" do
    stream_part1 =
      <<77, 83, 21::size(4)-unit(8), 3::8, "waiting_time_expired", 77, 83, 0, 0, 0, 21>>

    stream_part2 = <<3::8, "waiting_time_expired", 77, 83>>

    binary_extension = <<123::size(4)-unit(8)>>

    assert {<<77, 83, 69, 25::size(4)-unit(8), 123::size(4)-unit(8), 3::8, "waiting_time_expired",
              77, 83, 69, 0, 0, 0, 25, binary_extension::binary>>, buffer, leftover_bytes} =
             Package.expand_with(stream_part1, binary_extension)

    assert byte_size(buffer) == 0
    assert leftover_bytes == 21

    assert {<<3::8, "waiting_time_expired">>, buffer, leftover_bytes} =
             Package.expand_with(stream_part2, binary_extension, leftover_bytes)

    assert buffer == <<77, 83>>
    assert leftover_bytes == 0
  end

  describe "Buffer. move to the buffer the rest of the stream that can be considered as beginning of the next package" do
    test "77 (magic 1) and 83 (magic 2) is the rest of the stream" do
      stream = <<77, 83, 21::size(4)-unit(8), 3::8, "waiting_time_expired", 77, 83>>

      binary_extension = <<123::size(4)-unit(8)>>

      assert {<<77, 83, 69, 25::size(4)-unit(8), 123::size(4)-unit(8), 3::8,
                "waiting_time_expired">>, buffer, leftover_bytes} =
               Package.expand_with(stream, binary_extension)

      assert buffer == <<77, 83>>
      assert leftover_bytes == 0
    end

    test "77 magic 1 is the rest of the stream" do
      stream = <<77, 83, 21::size(4)-unit(8), 3::8, "waiting_time_expired", 77>>

      binary_extension = <<123::size(4)-unit(8)>>

      assert {<<77, 83, 69, 25::size(4)-unit(8), 123::size(4)-unit(8), 3::8,
                "waiting_time_expired">>, buffer, leftover_bytes} =
               Package.expand_with(stream, binary_extension)

      assert buffer == <<77>>
      assert leftover_bytes == 0
    end

    test "77 (magic 1) and 83 (magic 2) and part of payload length is the rest of the stream" do
      stream = <<0, 77, 83, 21::size(4)-unit(8), 3::8, "waiting_time_expired", 77, 83, 0, 0>>

      binary_extension = <<123::size(4)-unit(8)>>

      assert {<<0, 77, 83, 69, 25::size(4)-unit(8), 123::size(4)-unit(8), 3::8,
                "waiting_time_expired">>, buffer, leftover_bytes} =
               Package.expand_with(stream, binary_extension)

      assert buffer == <<77, 83, 0, 0>>
      assert leftover_bytes == 0
    end
  end

  test "" do
    binary_extension = <<123::size(4)-unit(8)>>

    assert {<<77, 83, 69, 25::size(4)-unit(8), 123::size(4)-unit(8), 3::8,
              "waiting_time_expired">>, <<77, 83>>, 0} =
             <<77, 83, 21::32, 3::8, "waiting_time_expired", 77, 83>>
             |> Package.expand_with(binary_extension)

    assert {<<77, 83, 69, 25::size(4)-unit(8), 123::size(4)-unit(8), 3::8,
              "waiting_time_expired">>, <<>>, 0} =
             <<77, 83, 21::32, 3::8, "waiting_time_expired">>
             |> Package.expand_with(binary_extension)

    assert {<<77, 83, 69, 25::size(4)-unit(8), 123::size(4)-unit(8), 3::8>>, <<>>, 20} =
             <<77, 83, 21::32, 3::8>>
             |> Package.expand_with(binary_extension)

    assert {<<77, 83, 69, 25::size(4)-unit(8), 123::size(4)-unit(8)>>, <<>>, 21} =
             <<77, 83, 0, 0, 0, 21>>
             |> Package.expand_with(binary_extension)

    assert {<<>>, <<77, 83, 0, 0, 0>>, 0} =
             <<77, 83, 0, 0, 0>>
             |> Package.expand_with(binary_extension)

    assert {<<>>, <<77, 83>>, 0} =
             <<77, 83>>
             |> Package.expand_with(binary_extension)

    assert {<<77, 0, 5, 6>>, <<>>, 0} =
             <<77, 0, 5, 6>>
             |> Package.expand_with(binary_extension)
  end
end
