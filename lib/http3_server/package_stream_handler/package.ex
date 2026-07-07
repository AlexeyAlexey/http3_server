defmodule Http3Server.PackageStreamHandler.Package do
  # bytes
  # @header_size 2
  # 'M'
  @magic_0 <<77>>
  # 'S'
  @magic_1 <<83>>
  @header_beginning @magic_0 <> @magic_1
  @payload_bytes_length 4

  # Package format
  # <<'M', 'S', payload_length::32, payload>>
  # after adding header is changed <<'M', 'S', 'E', new_payload_length::32, binary_extension, payload>>
  # new_payload_length = binary_extension_length + payload_length

  def expand_with(stream, binary_extension, leftover_bytes \\ 0)

  def expand_with(stream, binary_extension, leftover_bytes)
      when is_binary(stream) and is_binary(binary_extension) and leftover_bytes > 0 do
    binary_slice(stream, leftover_bytes, byte_size(stream))
    |> parse({binary_slice(stream, 0, leftover_bytes), <<>>, 0, binary_extension})
  end

  def expand_with(stream, binary_extension, _leftover_bytes)
      when is_binary(stream) and is_binary(binary_extension) do
    parse(stream, {<<>>, <<>>, 0, binary_extension})
  end

  defp parse(
         <<@header_beginning::binary, _payload_length_bin::binary-size(@payload_bytes_length),
           _rest::binary>> = matched,
         {acc, acc_rest, leftover_bytes, binary_extension}
       )
       when byte_size(acc_rest) > 0 do
    acc = acc <> acc_rest

    parse(matched, {acc, <<>>, leftover_bytes, binary_extension})
  end

  defp parse(
         <<@header_beginning::binary, payload_length_bin::binary-size(@payload_bytes_length),
           rest::binary>>,
         {acc, acc_rest, _leftover_bytes, binary_extension}
       ) do
    payload_length = :binary.decode_unsigned(payload_length_bin)

    leftover_bytes =
      if byte_size(rest) >= payload_length, do: 0, else: payload_length - byte_size(rest)

    acc =
      acc <>
        extend_header(binary_slice(rest, 0, payload_length), payload_length, binary_extension)

    binary_slice(rest, payload_length, byte_size(rest))
    |> parse({acc, acc_rest, leftover_bytes, binary_extension})
  end

  defp parse(
         <<@header_beginning::binary, rest::binary>> = buffer,
         {acc, _acc_rest, leftover_bytes, _binary_extension}
       )
       when byte_size(rest) < 4 do
    {acc, buffer, leftover_bytes}
  end

  defp parse(
         <<@magic_0::binary, rest::binary>> = buffer,
         {acc, _acc_rest, leftover_bytes, _binary_extension}
       )
       when byte_size(rest) == 0 do
    {acc, buffer, leftover_bytes}
  end

  defp parse(
         <<first::binary-size(1), rest::binary>>,
         {acc, acc_rest, leftover_bytes, binary_extension}
       ) do
    acc = acc <> first

    rest
    |> parse({acc, acc_rest, leftover_bytes, binary_extension})
  end

  defp parse(<<>>, {acc, _acc_rest, leftover_bytes, _binary_extension}) do
    {acc, <<>>, leftover_bytes}
  end

  defp extend_header(payload, payload_length, binary_extension) do
    extended_payload_length = byte_size(binary_extension) + payload_length

    <<"M", "S", "E", extended_payload_length::size(@payload_bytes_length)-unit(8),
      binary_extension::binary, payload::binary>>
  end
end
