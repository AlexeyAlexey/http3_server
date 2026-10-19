defmodule Http3Server.PackageStreamHandler.PayloadType do
  @moduledoc """
  Maps stream types to the payload type byte carried inside a package
  payload (`<<type::8, ...>>`), and back.

  | Stream type | Type byte |
  |-------------|-----------|
  | `:event`    | `4`       |
  """

  @doc """
  Returns `{:ok, type_byte}` for a known `stream_type`, or
  `{:error, "unknown stream type"}` otherwise.

  ## Examples

      iex> Http3Server.PackageStreamHandler.PayloadType.to_byte(:event)
      {:ok, 4}

  """
  def to_byte(:event), do: {:ok, 4}
  def to_byte(_stream_type), do: {:error, "unknown stream type"}

  @doc """
  Returns `{:ok, stream_type}` for a known payload `type_byte`, or
  `{:error, "unknown payload type"}` otherwise.

  ## Examples

      iex> Http3Server.PackageStreamHandler.PayloadType.from_byte(4)
      {:ok, :event}

  """
  def from_byte(4), do: {:ok, :event}
  def from_byte(_type_byte), do: {:error, "unknown payload type"}
end
