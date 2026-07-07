defmodule Http3Server.ConnectionHandler do
  use Wtransport.ConnectionHandler

  require Logger

  alias Wtransport.Session
  alias Wtransport.Connection
  alias Http3Server.AuthUserConnection
  alias Http3Server.ConnectionHandlerErrorParser
  alias Http3Server.PhoneCallManager
  alias Http3Server.SessionParameters

  # ConnectionHandler specific callbacks

  @impl Wtransport.ConnectionHandler
  def handle_session(%Session{} = session) do
    with {:ok, %{params: params}} <- SessionParameters.parse(session) do
      stream_type = params["stream_type"]

      case AuthUserConnection.auth(params["auth_token"]) do
        # {:ok, %{user_id: user_id, room_id: room_id}} ->
        #   state = %{user_id: user_id, room_id: room_id, stream_type: stream_type}

        #   Logger.info("user connecting: #{user_id} room_id: #{room_id} stream_type: #{stream_type}")

        #   {:continue, state}

        {:ok,
         %{
           from: from,
           to: to,
           direction: direction,
           type: "phone_call" = type,
           custom_params: custom_params
         }} ->
          state = %{
            from: from,
            to: to,
            direction: direction,
            stream_type: stream_type,
            type: type,
            custom_params: custom_params
          }

          {:continue, state}

        {:ok,
         %{
           type: "conference" = type,
           conference_id: conference_id,
           participant_id: participant_id,
           custom_params: custom_params
         }} ->
          state = %{
            type: type,
            conference_id: conference_id,
            participant_id: participant_id,
            custom_params: custom_params
          }

          {:continue, state}

        {:error, msg} ->
          Logger.error(msg)

          {:error, %{error: msg}}
      end
    else
      error ->
        inspect(error)
        |> Logger.error()

        {:error, %{error: error}}
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
  def handle_error(reason, %Connection{} = _connection, %{type: "phone_call"} = state) do
    ConnectionHandlerErrorParser.parse(reason)
    |> case do
      "user_ended_call" ->
        Logger.info("user_ended_call #{state |> inspect()} reason: #{inspect(reason)}")

        state
        |> Map.put(:reason, "user_ended_call")
        |> PhoneCallManager.user_ended_call()

      _ ->
        Logger.error("state: #{inspect(state)} reason: #{inspect(reason)}")

        nil
    end

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
