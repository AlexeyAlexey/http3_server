defmodule Http3Server.ConnectionHandler do
  use Wtransport.ConnectionHandler

  require Logger

  alias Wtransport.Session
  alias Wtransport.Connection
  alias Http3Server.AuthUserConnection

  # ConnectionHandler specific callbacks

  @impl Wtransport.ConnectionHandler
  def handle_session(%Session{} = session) do
    case AuthUserConnection.auth(session) |> IO.inspect() do
      {:ok, %{user_id: user_id, room_id: room_id, stream_type: stream_type}} ->
        state = %{user_id: user_id, room_id: room_id, stream_type: stream_type}

        Logger.info("user connecting: #{user_id} room_id: #{room_id} stream_type: #{stream_type}")

        {:continue, state}

      {:error, msg} ->
        Logger.error(msg)

        {:error, %{}}
    end
  end

  @impl Wtransport.ConnectionHandler
  def handle_connection(%Connection{} = _connection, state) do
    {:continue, state}
  end

  @impl Wtransport.ConnectionHandler
  def handle_datagram(dgram, %Connection{} = connection, state) do
    :ok = Connection.send_datagram(connection, dgram)

    {:continue, state}
  end

  @impl Wtransport.ConnectionHandler
  def handle_close(%Connection{} = _connection, _state) do
    :ok
  end

  @impl Wtransport.ConnectionHandler
  def handle_error(reason, %Connection{} = _connection, state) do
    Logger.error(
      "participant_id: #{state[:user_id]} room_id: #{state[:roo_id]} reason: #{inspect(reason)}"
    )

    :ok
  end

  # GenServer callbacks

  @impl true
  def handle_continue(_continue_arg, {%Connection{} = connection, state}) do
    {:noreply, {connection, state}}
  end

  @impl true
  def handle_info(_msg, {%Connection{} = connection, state}) do
    {:noreply, {connection, state}}
  end

  @impl true
  def handle_call(request, _from, {%Connection{} = connection, state}) do
    {:reply, request, {connection, state}}
  end

  @impl true
  def handle_cast(_request, {%Connection{} = connection, state}) do
    {:noreply, {connection, state}}
  end
end
