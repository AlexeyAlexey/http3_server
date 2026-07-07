defmodule Http3Server.ConnectionSessionMock do
  alias Wtransport.Session

  def mock_connection_session(path: path, auth_token: auth_token) do
    path = "#{path}?auth_token=#{URI.encode(auth_token)}"

    %Session{
      path: path,
      headers: [],
      user_agent: "test-client",
      origin: "http://localhost",
      authority: "localhost"
    }
  end
end
