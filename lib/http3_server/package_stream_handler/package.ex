defmodule Http3Server.PackageStreamHandler.Package do
  @moduledoc """
  Rewrites packages in a byte stream by extending each package header with a
  `binary_extension` (used to stamp the sender's `participant_id` before
  broadcasting to a room).

  ## Input package format

      <<'M', 'S', payload_length::32, payload>>

  - `'M', 'S'` — magic bytes (`77, 83`) marking the start of a package
  - `payload_length` — unsigned 32-bit big-endian integer, the size in bytes
    of the payload region (type byte + payload)
  - `payload` — `payload_length` bytes carried by the package

  ## Output package format

      <<'M', 'S', 'E', extended_payload_length::32, binary_extension, payload>>

  - `'E'` — marker byte (`69`) distinguishing an extended header
  - `extended_payload_length` — `byte_size(binary_extension) + payload_length`
  - `binary_extension` — inserted bytes, e.g. `<<participant_id::32>>`
  - `payload` — passed through unchanged

  ## Streaming

  A stream chunk may split a package at any byte boundary. `expand_with`
  returns `{expanded_stream, buffer, leftover_bytes}` — pass `buffer` and
  `leftover_bytes` into the next call so a package spread across chunks is
  completed correctly:

  - `buffer` — trailing bytes that may be the beginning of the next package
    (an incomplete header of fewer than 6 bytes). When `buffer` grows beyond
    0.5 Mb it is dropped and parsing resynchronizes on the stream.
  - `leftover_bytes` — how many bytes at the head of the next chunk are the
    payload tail of the in-progress package; they are passed through raw,
    without scanning for package headers.
  """

  # bytes
  # @header_size 2
  # 'M'
  @magic_0 <<77>>
  # 'S'
  @magic_1 <<83>>
  @header_beginning @magic_0 <> @magic_1
  @payload_bytes_length 4
  # 0.5 Mb
  @max_buffer_size 512 * 1024

  # Package format
  # <<'M', 'S', payload_length::32, payload>>
  # after adding header is changed <<'M', 'S', 'E', new_payload_length::32, binary_extension, payload>>
  # new_payload_length = binary_extension_length + payload_length

  @doc """
  Extends the header of every package found in `stream` with
  `binary_extension`.

  Bytes that do not belong to a package pass through unchanged. See the
  module documentation for the package formats and the `buffer` /
  `leftover_bytes` streaming contract.

  ## Examples

      iex> Http3Server.PackageStreamHandler.Package.expand_with(
      ...>   <<77, 83, 0, 0, 0, 4, 1, 2, 3, 4>>,
      ...>   <<0, 0, 0, 42>>
      ...> )
      {<<77, 83, 69, 0, 0, 0, 8, 0, 0, 0, 42, 1, 2, 3, 4>>, <<>>, 0}

  """
  def expand_with(stream, binary_extension, buffer, _leftover_bytes)
      when is_binary(stream) and is_binary(binary_extension) and is_binary(buffer) and
             byte_size(buffer) > @max_buffer_size do
    expand_with(stream, binary_extension, <<>>, 0)
  end

  def expand_with(stream, binary_extension, buffer, leftover_bytes)
      when is_binary(stream) and is_binary(binary_extension) and is_binary(buffer) do
    (buffer <> stream)
    |> expand_with(binary_extension, leftover_bytes)
  end

  @doc """
  Extends the header of every package found in `stream` with
  `binary_extension`. Equivalent to `expand_with/4` without a carry-over
  `buffer` from a previous stream chunk.
  """
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
