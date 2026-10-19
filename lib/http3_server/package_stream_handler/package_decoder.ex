defmodule Http3Server.PackageStreamHandler.PackageDecoder do
  @moduledoc """
  Splits a byte stream into whole packages — the inverse of
  `Http3Server.PackageStreamHandler.Package` header expansion.

  ## Input package format

      <<'M', 'S', payload_length::32, payload>>

  - `'M', 'S'` — magic bytes (`77, 83`) marking the start of a package
  - `payload_length` — unsigned 32-bit big-endian integer, the size in bytes
    of the payload region (type byte + payload)
  - `payload` — `payload_length` bytes carried by the package

  ## Output

  `decode` returns `{decoded, buffer, leftover_bytes}`:

  - `decoded` — complete packages emitted verbatim (header + payload), with
    any bytes that do not belong to a package passed through unchanged
  - `buffer` — trailing bytes that form an incomplete package (a partial
    header, or a header with fewer than `payload_length` payload bytes)
  - `leftover_bytes` — the number of bytes of the in-progress package
    already received, i.e. `byte_size(buffer)`

  ## Streaming

  A stream chunk may split a package at any byte boundary. Pass `buffer`
  and `leftover_bytes` from the previous call into the next one — the head
  of the next chunk is that package's tail. When `buffer` grows beyond
  0.5 Mb it is dropped and parsing resynchronizes on the stream.
  """

  # bytes
  # @header_size 2
  # 'M'
  @magic_0 <<77>>
  # 'S'
  @magic_1 <<83>>
  @header_beginning @magic_0 <> @magic_1
  @payload_bytes_length 4
  @header_size byte_size(@header_beginning) + @payload_bytes_length
  # 0.5 Mb
  @max_buffer_size 512 * 1024

  # Package format
  # <<'M', 'S', payload_length::32, payload>>

  @doc """
  Extracts complete packages from `stream`.

  Bytes that do not belong to a package pass through unchanged. See the
  module documentation for the package format and the `buffer` /
  `leftover_bytes` streaming contract.

  ## Examples

      iex> Http3Server.PackageStreamHandler.PackageDecoder.decode(
      ...>   <<77, 83, 0, 0, 0, 4, 1, 2, 3, 4>>
      ...> )
      {<<77, 83, 0, 0, 0, 4, 1, 2, 3, 4>>, <<>>, 0}

  """
  def decode(stream, buffer \\ <<>>, leftover_bytes \\ 0)

  def decode(stream, buffer, _leftover_bytes)
      when is_binary(stream) and is_binary(buffer) and byte_size(buffer) > @max_buffer_size do
    decode(stream, <<>>, 0)
  end

  def decode(stream, buffer, leftover_bytes)
      when is_binary(stream) and is_binary(buffer) do
    # `buffer` holds the beginning of a package split across stream chunks
    # (`leftover_bytes` bytes already received); the head of `stream` is
    # that package's tail.
    (buffer <> stream)
    |> parse({<<>>, <<>>, leftover_bytes})
  end

  defp parse(
         <<@header_beginning::binary, payload_length_bin::binary-size(@payload_bytes_length),
           _rest::binary>> = matched,
         {acc, _buffer, _leftover_bytes}
       ) do
    package_size = @header_size + :binary.decode_unsigned(payload_length_bin)

    cond do
      byte_size(matched) >= package_size ->
        <<package::binary-size(package_size), rest::binary>> = matched
        parse(rest, {acc <> package, <<>>, 0})

      byte_size(matched) > @max_buffer_size ->
        {acc, <<>>, 0}

      true ->
        {acc, matched, byte_size(matched)}
    end
  end

  defp parse(
         <<@header_beginning::binary, rest::binary>> = buffer,
         {acc, _buffer, _leftover_bytes}
       )
       when byte_size(rest) < @payload_bytes_length do
    {acc, buffer, byte_size(buffer)}
  end

  defp parse(
         <<@magic_0::binary, rest::binary>> = buffer,
         {acc, _buffer, _leftover_bytes}
       )
       when byte_size(rest) == 0 do
    {acc, buffer, byte_size(buffer)}
  end

  defp parse(
         <<first::binary-size(1), rest::binary>>,
         {acc, buffer, leftover_bytes}
       ) do
    acc = acc <> first

    rest
    |> parse({acc, buffer, leftover_bytes})
  end

  defp parse(<<>>, {acc, buffer, leftover_bytes}) do
    {acc, buffer, leftover_bytes}
  end
end
