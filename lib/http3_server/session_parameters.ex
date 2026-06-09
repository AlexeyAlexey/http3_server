defmodule Http3Server.SessionParameters do
  alias Wtransport.Session

  def parse(%Session{path: "/"}) do
    {:ok, %{path: "/", params: %{}}}
  end

  def parse(%Session{path: path}) do
    uri = URI.parse(path)
    params = URI.decode_query(uri.query)

    stream_type =
      cond do
        String.contains?(path, "video") ->
          "video"

        String.contains?(path, "audio") ->
          "audio"

        true ->
          nil
      end

    {:ok, %{path: path, params: params |> Map.put("stream_type", stream_type)}}
  end
end
