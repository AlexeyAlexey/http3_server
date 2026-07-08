defmodule Http3Server.StreamMock do
  alias Wtransport.Stream

  def mock_stream(),
    do: %Stream{
      stream_type: :bi,
      connection: nil,
      monitor_ref: make_ref(),
      request_tx: make_ref(),
      write_all_tx: make_ref()
    }
end

# field(:connection, Connection.t(), enforce: true)
