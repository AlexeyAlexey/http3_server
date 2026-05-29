defmodule Http3Server.ConnectionHandler do
  use Wtransport.ConnectionHandler

  require Logger

  alias Wtransport.Session
  alias Wtransport.Connection
  alias Http3Server.AuthUserConnection
  alias Http3Server.ConnectionHandlerErrorParser
  alias Http3Server.PhoneCallManager

  # ConnectionHandler specific callbacks

  @impl Wtransport.ConnectionHandler
  def handle_session(%Session{} = session) do
    case AuthUserConnection.auth(session) do
      {:ok, %{user_id: user_id, room_id: room_id, stream_type: stream_type}} ->
        state = %{user_id: user_id, room_id: room_id, stream_type: stream_type}

        Logger.info("user connecting: #{user_id} room_id: #{room_id} stream_type: #{stream_type}")

        {:continue, state}

      {:ok, %{from: from, to: to, direction: direction, stream_type: stream_type, type: type}} ->
        state = %{from: from, to: to, direction: direction, stream_type: stream_type, type: type}

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
    ConnectionHandlerErrorParser.parse(reason)
    |> case do
      "user_ended_call" ->
        Logger.info(
          "user_ended_call #{state |> Map.take([:direction, :from, :to, :type, :stream_type]) |> inspect()} reason: #{inspect(reason)}"
        )

        state
        |> Map.put(:reason, "user_ended_call")
        |> PhoneCallManager.user_ended_call()

      _ ->
        Logger.error("state: #{inspect(state)} reason: #{inspect(reason)}")

        nil
    end

    # state: %{type: "phone_call", to: 1234, from: 123, direction: "outcome", stream_type: "audio"} reason: "connection closed by peer: userEndCall (code 0)"

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
