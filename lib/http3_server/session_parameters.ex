defmodule Http3Server.SessionParameters do
  alias Wtransport.Session

  def parse(%Session{path: "/"}) do
    {:ok, %{path: "/", params: %{}}}
  end

  def parse(%Session{path: path}) do
    uri = URI.parse(path)
    params = URI.decode_query(uri.query)

    {:ok, %{path: path, params: params}}
  end
end
