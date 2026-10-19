defmodule Http3Server.PackageStreamHandler.PackageParser do
  @moduledoc """
  Parses a single complete package, as emitted by
  `Http3Server.PackageStreamHandler.PackageDecoder`, into its type and
  JSON-decoded payload.

  ## Input package format

      <<'M', 'S', payload_length::32, type::8, payload>>

  - `'M', 'S'` — magic bytes (`77, 83`) marking the start of a package
  - `payload_length` — unsigned 32-bit big-endian integer, the size in bytes
    of the type byte plus payload (`1 + byte_size(payload)`)
  - `type` — unsigned 8-bit integer identifying the payload kind
  - `payload` — JSON-encoded binary

  ## Output

  - `{:ok, %{type: type, payload: decoded}}` — `type` is the integer type
    byte, `decoded` is the JSON-decoded payload term
  - `{:error, "package has a wrong format"}` — returned for wrong magic
    bytes, a `payload_length` that does not match the actual payload size,
    an incomplete package, a payload that is not valid JSON, or non-binary
    input
  """

  # bytes
  # @header_size 2
  # 'M'
  @magic_0 <<77>>
  # 'S'
  @magic_1 <<83>>
  @header_beginning @magic_0 <> @magic_1
  @type_bytes_length 1
  @payload_bytes_length 4

  # Package format
  # <<'M', 'S', payload_length::32, type::8, payload>>
  # payload_length = @type_bytes_length + byte_size(payload)

  @doc """
  Parses `package` into `{:ok, %{type: type, payload: decoded}}` where
  `decoded` is the JSON-decoded payload. See the module documentation for
  the package format and the error cases.

  ## Examples

      iex> Http3Server.PackageStreamHandler.PackageParser.parse(
      ...>   <<77, 83, 0, 0, 0, 8, 1, "{\\"a\\":1}">>
      ...> )
      {:ok, %{type: 1, payload: %{"a" => 1}}}

  """
  def parse(
        <<@header_beginning::binary, payload_length_bin::binary-size(@payload_bytes_length),
          type_bin::binary-size(@type_bytes_length), payload::binary>>
      ) do
    payload_length = :binary.decode_unsigned(payload_length_bin)

    with true <- byte_size(payload) + @type_bytes_length == payload_length,
         {:ok, decoded} <- Jason.decode(payload) do
      {:ok, %{type: :binary.decode_unsigned(type_bin), payload: decoded}}
    else
      _ -> {:error, "package has a wrong format"}
    end
  end

  def parse(_), do: {:error, "package has a wrong format"}
end
