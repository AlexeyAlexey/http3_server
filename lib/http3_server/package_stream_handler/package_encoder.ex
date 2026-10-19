defmodule Http3Server.PackageStreamHandler.PackageEncoder do
  alias Http3Server.PackageStreamHandler.PayloadType

  @moduledoc """
  Builds a single extended package from a stream type, an event map and a
  `participant_id` — the inverse of
  `Http3Server.PackageStreamHandler.PackageParser`.

  ## Output package format

      <<'M', 'S', 'E', extended_payload_length::32, participant_id::32, payload>>

  - `'M', 'S', 'E'` — magic bytes (`77, 83, 69`) marking an extended package
  - `extended_payload_length` — unsigned 32-bit big-endian integer, the size
    in bytes of the `participant_id` extension plus the payload region
  - `participant_id` — unsigned 32-bit integer identifying the sender

  ## Payload format

      <<type::8, json_length::32, json>>

  - `type` — unsigned 8-bit integer identifying the payload kind
  - `json_length` — unsigned 32-bit big-endian integer, `byte_size(json)`
  - `json` — JSON-encoded event map; `participant_id` is merged into the
    map before encoding
  """

  # 'M'
  @magic_0 <<77>>
  # 'S'
  @magic_1 <<83>>
  # 'E'
  @extended_magic <<69>>
  @header_beginning @magic_0 <> @magic_1 <> @extended_magic
  @type_bytes_length 1
  @payload_bytes_length 4
  @participant_id_bytes_length 4

  @doc """
  Encodes `payload_map` as a JSON payload of the type mapped from
  `stream_type` (`:event` — type byte `4`) and wraps it in an extended
  package stamped with `participant_id`.

  `participant_id` is placed both in the extended header and into the
  encoded JSON — it overrides any `participant_id` already present in
  `payload_map`. Returns `{:ok, package}`, `{:error, reason}` if
  `payload_map` is not JSON-encodable, or `{:error, "unknown stream type"}`
  for an unmapped `stream_type`.

  ## Examples

      iex> Http3Server.PackageStreamHandler.PackageEncoder.encode(:event, %{a: 1}, 1)
      {:ok,
       <<77, 83, 69, 0, 0, 0, 35, 0, 0, 0, 1, 4, 0, 0, 0, 26,
         '{"a":1,"participant_id":1}'::binary>>}

  """
  def encode(stream_type, payload_map, participant_id)
      when is_atom(stream_type) and is_map(payload_map) and is_integer(participant_id) do
    with {:ok, payload_type} <- PayloadType.to_byte(stream_type),
         {:ok, payload_binary} <-
           payload_map
           |> Map.put(:participant_id, participant_id)
           |> Jason.encode() do
      payload =
        <<payload_type::size(@type_bytes_length)-unit(8),
          byte_size(payload_binary)::size(@payload_bytes_length)-unit(8), payload_binary::binary>>

      binary_extension = <<participant_id::size(@participant_id_bytes_length)-unit(8)>>

      extended_payload_length = byte_size(binary_extension) + byte_size(payload)

      package =
        <<@header_beginning::binary, extended_payload_length::size(@payload_bytes_length)-unit(8),
          binary_extension::binary, payload::binary>>

      {:ok, package}
    end
  end
end
